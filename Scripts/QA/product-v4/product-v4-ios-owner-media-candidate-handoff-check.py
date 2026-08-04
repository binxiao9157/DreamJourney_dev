#!/usr/bin/env python3
"""Guard the B4 Owner Truth media-to-Candidate handoff boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RECOVERY = ROOT / "DreamJourney/Sources/Services/OwnerTruthMediaTaskRecovery.swift"
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"
UIQA_SMOKE = ROOT / "Scripts/QA/product-v4/run-ios-owner-media-task-status-uiqa-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    recovery = RECOVERY.read_text(encoding="utf-8")
    archive = ARCHIVE.read_text(encoding="utf-8")
    contracts = CONTRACTS.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")
    uiqa_smoke = UIQA_SMOKE.read_text(encoding="utf-8")

    for required in (
        "var derivedSourceID: UUID?",
        "receipt.derivedSourceID = sourceObject.derivedSourceID?.rawValue",
        "candidateHandoffAvailable",
        "candidateHandoffTitle",
        "素材已整理为待确认记忆",
        "确认后才会进入正式记忆",
    ):
        require(required in recovery, f"B4 durable media handoff contract missing: {required}")

    for required in (
        "owner-truth-media-candidate-handoff-button",
        "ownerTruthMediaCandidateHandoffTapped",
        "OwnerTruthCandidateInboxViewController(",
        "sourceIDFilter: OwnerTruthRecordID(rawValue: derivedSourceID)",
        "isOwnerTruthMediaCaptureClosedPilotEnabled",
    ):
        require(required in archive, f"B4 archive handoff surface missing: {required}")

    card_body = archive.split("makeOwnerTruthMediaTaskStatusCard", 1)[1].split(
        "private func ownerTruthMediaTaskStatusTint", 1
    )[0]
    require(
        "derivedSourceID" not in card_body and "sourceObjectID" not in card_body,
        "ordinary media status cards must not render private Source identifiers",
    )

    for required in (
        "private let sourceIDFilter: OwnerTruthRecordID?",
        "candidate.sourceID == sourceIDFilter",
        "candidate.sourceReferences.contains(where: { $0.sourceID == sourceIDFilter })",
        "本次素材整理出的内容会先留在这里",
        "当前素材暂未生成可确认内容，可稍后刷新。",
    ):
        require(required in contracts + archive, f"B4 scoped Candidate review contract missing: {required}")

    for test_name in (
        "func testCandidateReviewUseCaseScopesMediaHandoffToDerivedSource() throws",
        "func testMediaTaskRecoveryResumesUploadAndRefreshesProcessingAfterRestart() throws",
    ):
        require(test_name in tests, f"B4 XCTest missing: {test_name}")

    require(
        '"candidateHandoffVisible":' in archive
        and 'payload["candidateHandoffVisible"]' in app_delegate,
        "B4 UIQA harness must assert the media handoff action",
    )
    for required in (
        "DJRunOwnerMediaTaskStatusSmoke",
        "candidateHandoffVisible",
        "01-owner-media-task-status.png",
    ):
        require(required in uiqa_smoke, f"B4 UIQA smoke contract missing: {required}")

    print("Owner Truth media Candidate handoff iOS check passed")


if __name__ == "__main__":
    main()
