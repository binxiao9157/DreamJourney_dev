#!/usr/bin/env python3
"""Guard the B3 Owner Truth media status, failure, and retry surface."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RECOVERY = ROOT / "DreamJourney/Sources/Services/OwnerTruthMediaTaskRecovery.swift"
ARCHIVE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
TESTS = ROOT / "DreamJourneyTests/OwnerTruthContractsTests.swift"
UIQA_SMOKE = ROOT / "Scripts/QA/product-v4/run-ios-owner-media-task-status-uiqa-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    recovery = RECOVERY.read_text(encoding="utf-8")
    archive = ARCHIVE.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")
    uiqa_smoke = UIQA_SMOKE.read_text(encoding="utf-8")

    for required in (
        "case uploadRetryableFailed",
        "func markUploadRetryableFailure(",
        "func retryProcessing(",
        "OwnerTruthMediaTaskPresentation",
        "云端文件未同步",
        "文件已同步，处理暂不可用",
        "无需重新选择文件",
        "重新上传",
        "重新处理",
        "task.phase == .prepared || task.phase == .uploadRetryableFailed",
    ):
        require(required in recovery, f"B3 media status contract missing: {required}")

    require(
        "SourceObject IDs, object-store identities or provider error codes" in recovery,
        "user-facing status projection must explicitly exclude private provider details",
    )
    require(
        "ownerTruthMediaTaskStatusStack" in archive
        and "refreshOwnerTruthMediaTaskStatus()" in archive
        and "OwnerTruthMediaTaskPresentation.init(receipt:)" in archive,
        "archive must render status from the durable task receipt",
    )
    require(
        "isOwnerTruthMediaCaptureClosedPilotEnabled" in archive
        and "shouldShowOwnerTruthMediaTaskStatus" in archive,
        "media status must remain scoped to the server-authorized closed pilot",
    )
    require(
        "OwnerTruthMediaTaskRecoveryCoordinator.shared.restore" in archive
        and "OwnerTruthMediaTaskRecoveryCoordinator.shared.retryProcessing" in archive,
        "upload and processing retries must use the existing durable task path",
    )
    require(
        "sourceObjectID" not in archive.split("makeOwnerTruthMediaTaskStatusCard", 1)[1].split(
            "private func ownerTruthMediaTaskStatusTint", 1
        )[0],
        "ordinary status UI must not render SourceObject IDs",
    )

    for required in (
        'case ownerMediaTaskStatusSmoke = "DJRunOwnerMediaTaskStatusSmoke"',
        ".ownerMediaTaskStatusSmoke,",
    ):
        require(required in feature_flags, f"B3 UIQA launch scenario missing: {required}")
    for required in (
        "runOwnerMediaTaskStatusSmoke()",
        "func runOwnerMediaTaskStatusSmoke(",
        '"persistentOwnerTruthWriteStarted": false',
        '"backendNetworkStarted": false',
    ):
        require(required in app_delegate, f"B3 UIQA harness missing: {required}")
    for test_name in (
        "func testMediaTaskRecoveryResumesUploadAndRefreshesProcessingAfterRestart()",
        "func testMediaTaskRecoveryLifecycleCancellationDropsDeferredUploadCallback() throws",
        "func testRealHTTPMediaSourceObjectDropsResponseAfterAccountLeaseSwitch() throws",
        "func testOwnerTruthMediaTaskPresentationKeepsUploadAndProcessingFailuresDistinct()",
        "func testMediaTaskProcessingRetryUsesExistingSourceWithoutRepickingContent()",
    ):
        require(test_name in tests, f"B3 XCTest missing: {test_name}")
    for required in (
        "run-installable-simulator-uiqa.sh",
        "DJRunOwnerMediaTaskStatusSmoke",
        "owner-media-task-status-smoke-result.json",
        "01-owner-media-task-status.png",
    ):
        require(required in uiqa_smoke, f"B3 UIQA script missing: {required}")

    print("Owner Truth media task status iOS check passed")


if __name__ == "__main__":
    main()
