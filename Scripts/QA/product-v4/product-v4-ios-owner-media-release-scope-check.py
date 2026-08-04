#!/usr/bin/env python3
"""Guard B5 media UIQA coverage and the closed-pilot/public release boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"
CANDIDATE_SMOKE = ROOT / "Scripts/QA/prd-stitch-ui/run-owner-truth-candidate-inbox-smoke.sh"
CREATION_SMOKE = ROOT / "Scripts/QA/product-v4/run-ios-owner-media-unified-creation-uiqa-smoke.sh"
STATUS_SMOKE = ROOT / "Scripts/QA/product-v4/run-ios-owner-media-task-status-uiqa-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def section(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing section start: {start}")
    end_index = source.find(end, start_index + len(start))
    require(end_index >= 0, f"missing section end: {end}")
    return source[start_index:end_index]


def main() -> None:
    archive = ARCHIVE.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")
    candidate_smoke = CANDIDATE_SMOKE.read_text(encoding="utf-8")
    creation_smoke = CREATION_SMOKE.read_text(encoding="utf-8")
    status_smoke = STATUS_SMOKE.read_text(encoding="utf-8")

    text_capture_policy = section(
        archive,
        "private var isOwnerTruthTextCaptureClosedPilotEnabled: Bool",
        "private var isOwnerTruthMediaCaptureClosedPilotEnabled: Bool",
    )
    media_policy = section(
        archive,
        "private var isOwnerTruthMediaCaptureClosedPilotEnabled: Bool",
        "private var archivePersonaName",
    )
    require(
        ".ownerTextCaptureV1" in text_capture_policy
        and ".ownerTruthCandidateReview" in text_capture_policy
        and "isOwnerTruthTextCaptureClosedPilotEnabled" in media_policy
        and ".ownerMediaCaptureV1" in media_policy,
        "media creation must require the text, Candidate and media closed-pilot policies",
    )
    require(
        "shouldShowOwnerTruthMediaTaskStatus" in media_policy
        and "isOwnerTruthMediaCaptureClosedPilotEnabled" in media_policy,
        "ordinary release must not render live media task state without the closed-pilot policy",
    )

    handoff = section(
        archive,
        "@objc private func ownerTruthMediaCandidateHandoffTapped",
        "func runUIQAOwnerTruthMediaTaskStatusSmoke",
    )
    require(
        "isOwnerTruthMediaCaptureClosedPilotEnabled" in handoff
        and "OwnerTruthCandidateInboxViewController(" in handoff,
        "media-to-Candidate handoff must remain closed-pilot gated",
    )

    candidate_surface = section(
        archive,
        "final class OwnerTruthCandidateInboxViewController",
        "extension OwnerTruthCandidateInboxViewController: UITableViewDataSource",
    )
    for required in (
        "owner-truth-candidate-formal-memory-status",
        "formalMemoryNoticeText(for: state)",
        "createdMemoryVersion == true",
        "已纳入正式记忆，可在后续回顾与回响中使用。",
        "已按更正内容纳入正式记忆，可在后续回顾与回响中使用。",
        "formalMemoryNoticeVisibleForUIQA",
    ):
        require(required in candidate_surface, f"formal memory presentation missing: {required}")

    review_entry = section(
        archive,
        "private func updateCandidateReviewQAButton()",
        "private func reloadFeatureCards",
    )
    require(
        "isServerPolicyManagedClosedPilotRouteAllowed(.ownerTruthCandidateReview)" in review_entry
        and "candidateReviewQAButton.isHidden = !isVisible" in review_entry,
        "Candidate review entry must remain hidden outside QA or closed-pilot policy",
    )
    require(
        "candidateConfirmationButton.isHidden = !isVisible" in review_entry
        and "candidateMemoryActivationButton.isHidden = !isVisible" in review_entry,
        "formal Candidate paths must stay hidden in the public default state",
    )

    for required in (
        'expectedReleaseOptionTitles = ["添加文字描述", "选择照片"]',
        'expectedHiddenOptionTitles = ["添加文字描述", "选择照片", "录入语音", "录入视频片段", "录入时间信件"]',
        '"candidateHandoffVisible"',
    ):
        require(required in app_delegate, f"B5 release/UIQA fixture missing: {required}")

    require(
        "case ownerTruthCandidateReview" in feature_flags
        and "nonPersistentFeatures" in feature_flags,
        "Candidate review must remain default-off in the feature registry",
    )
    for test_name in (
        "func testArchiveCreationOptionsKeepOwnerTruthSourceHiddenByDefault()",
        "func testGenericCandidateReviewPathsUseClosedPilotFeatureGate()",
        "func testCandidateReviewUseCaseScopesMediaHandoffToDerivedSource() throws",
    ):
        require(test_name in tests, f"B5 release boundary XCTest missing: {test_name}")

    for required in (
        "run-installable-simulator-uiqa.sh",
        "LOCAL_BUNDLE_ID=\"${LOCAL_BUNDLE_ID:-com.yxj.dreamjourney.app}\"",
        '"formalMemoryPresentationVisible"',
        "正式记忆",
    ):
        require(required in candidate_smoke, f"Candidate UIQA smoke missing: {required}")

    require(
        "publicOptionTitles" in creation_smoke
        and "unifiedOptionTitles" in creation_smoke
        and "backendNetworkStarted" in creation_smoke,
        "creation UIQA must cover public and closed-pilot scope without backend writes",
    )
    require(
        "candidateHandoffVisible" in status_smoke
        and "persistentOwnerTruthWriteStarted" in status_smoke,
        "media status UIQA must cover Candidate handoff without local writes",
    )

    print("Owner Truth Stage 2 B5 release scope iOS check passed")


if __name__ == "__main__":
    main()
