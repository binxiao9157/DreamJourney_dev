#!/usr/bin/env python3
"""Guard V4 M0-A QA and policy-controlled Echo natural-input surfaces."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
NATURAL_INPUT_SURFACE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
OWNER_TRUTH_CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
BACKEND_CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
RUNNER = ROOT / "Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-echo-surface-smoke.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing surface: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing body: {marker}")
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening + 1 : index]
    raise AssertionError(f"unterminated body: {marker}")


def main() -> None:
    for path in (
        ECHO,
        NATURAL_INPUT_SURFACE,
        OWNER_TRUTH_CONTRACTS,
        BACKEND_CLIENT,
        FEATURE_FLAGS,
        APP_DELEGATE,
        RUNNER,
    ):
        require(path.is_file(), f"missing Echo natural-input QA artifact: {path}")

    echo = ECHO.read_text(encoding="utf-8")
    natural_input_surface = NATURAL_INPUT_SURFACE.read_text(encoding="utf-8")
    owner_truth_contracts = OWNER_TRUTH_CONTRACTS.read_text(encoding="utf-8")
    backend_client = BACKEND_CLIENT.read_text(encoding="utf-8")
    flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    delegate = APP_DELEGATE.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    require(
        'case ownerTruthInterviewNaturalInputEntry = "DJShowOwnerTruthInterviewNaturalInputEntryQA"' in flags,
        "natural-input Echo entry must have an explicit QA launch feature",
    )
    require(
        'case ownerTruthInterviewNaturalInputEchoSurfaceSmoke = "DJRunOwnerTruthInterviewNaturalInputEchoSurfaceSmoke"' in flags,
        "natural-input Echo surface must have an explicit QA scenario",
    )
    gate_body = body(echo, "private var shouldShowOwnerTruthInterviewNaturalInputEntry")
    for snippet in (
        "#if DEBUG || UI_QA_SIMULATOR",
        "OwnerTruthCandidateReviewQAGate.isEnabled",
        "QALaunchFeature.ownerTruthInterviewNaturalInputEntry.rawValue",
        "#else",
        "return false",
    ):
        require(snippet in gate_body, f"QA-only entry gate missing: {snippet}")

    for snippet in (
        'accessibilityIdentifier = "ownerTruthInterviewNaturalInputEntryButton"',
        "OwnerTruthInterviewNaturalInputUIQASmoke.makePreviewViewController(",
        "navigationController.modalPresentationStyle = .pageSheet",
        "func runUIQAOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(",
    ):
        require(snippet in echo, f"Echo natural-input QA surface missing: {snippet}")

    # The product surface must remain invisible without fresh policy authority.
    # Its visibility needs both a release-visible route decision and a write
    # decision, so a read-only fallback cannot expose a new private write.
    for snippet in (
        'accessibilityIdentifier = "ownerTruthInterviewNaturalInputProductEntryButton"',
        'configuration.title = "今天想聊点什么？"',
        "button.isHidden = true",
        "FeatureGateService.shared.refreshPolicy",
        "FeatureGateService.shared.captureRoute(",
        "FeatureGateService.shared.requestDecision(for: .echoTextInput)",
        "surfaceDecision.allowed",
        "writeDecision.allowed",
        "presentOwnerTruthInterviewNaturalInputSheet(presentation: .product)",
        "isOwnerTruthInterviewNaturalInputProductEntryVisible",
        "isOwnerTruthInterviewNaturalInputProductPolicyPermitted = false",
        "refreshOwnerTruthInterviewNaturalInputProductEntryPolicy()",
    ):
        require(snippet in echo, f"policy-controlled product entry missing: {snippet}")

    for snippet in (
        "enum OwnerTruthInterviewNaturalInputPresentation",
        "case product",
        'return "今天想聊点什么？"',
        'return "写下此刻想分享的故事。"',
        'return "发送"',
    ):
        require(
            snippet in natural_input_surface,
            f"product natural-input presentation missing: {snippet}",
        )

    # Slice 3D must give the owner an honest continuation/review boundary
    # without returning transcript text, Candidate content or internal pacing.
    for snippet in (
        "OwnerTruthInterviewNaturalInputContinuation",
        "OwnerTruthInterviewNaturalInputCurrentSession",
        '"owner-truth-interview-session-presentation-v1"',
        '"owner-truth-interview-current-session-v1"',
        "case readyForNarrative",
        "case narrativeRecorded",
        "case reviewPending",
        "fetchOwnerTruthInterviewNaturalInputCurrentSession",
        "fetchOwnerTruthInterviewNaturalInputContinuation",
        "startNewSession(vaultID: vaultID)",
        "failed current-session read could bypass an existing boundary",
    ):
        require(snippet in owner_truth_contracts, f"continuation contract missing: {snippet}")

    for snippet in (
        "/interview-sessions/current\"",
        "fetchOwnerTruthInterviewNaturalInputCurrentSession",
        "/presentation\"",
        "fetchOwnerTruthInterviewNaturalInputContinuation",
        "ownerTruthInterviewNaturalInputTransport()",
    ):
        require(snippet in backend_client, f"policy-bound continuation transport missing: {snippet}")

    for snippet in (
        "sessionResumed: Bool",
        "startRequestCount: Int",
        "resumeReceiptMismatch",
        "unexpectedSecondStart",
        "OwnerTruthInterviewNaturalInputReceiptOutcome.resumed.rawValue",
    ):
        require(snippet in natural_input_surface, f"resume UIQA coverage missing: {snippet}")

    for snippet in (
        "这段分享已经留好。想起来时，可以继续补充。",
        "有内容等待你确认",
        "确认后才会进入你的记忆。",
        "canContinue",
    ):
        require(snippet in natural_input_surface, f"value-minimized product summary missing: {snippet}")

    smoke_body = body(echo, "func runUIQAOwnerTruthInterviewNaturalInputEchoSurfaceSmoke(")
    for forbidden in (
        "startVoiceCapture()",
        "openDigitalHuman",
        "createOwnerTruthInterview",
        "appendOwnerTruthInterview",
    ):
        require(forbidden not in smoke_body, f"surface smoke must not cause side effect: {forbidden}")
    for required in (
        '"voiceTurnStarted": false',
        '"digitalHumanSessionStarted": false',
        '"backendNetworkStarted": false',
        '"persistentInterviewWriteStarted": false',
        '"publicRouteChanged": false',
    ):
        require(required in smoke_body, f"surface smoke must evidence its isolation: {required}")

    require(
        "runOwnerTruthInterviewNaturalInputEchoSurfaceSmoke" in delegate
        and "writeOwnerTruthInterviewNaturalInputEchoSurfaceSmokeResult" in delegate,
        "AppDelegate must dispatch and persist the Echo surface smoke",
    )
    for argument in (
        "DJEnableOwnerTruthCandidateReviewQA",
        "DJShowOwnerTruthInterviewNaturalInputEntryQA",
        "DJRunOwnerTruthInterviewNaturalInputEchoSurfaceSmoke",
    ):
        require(argument in runner, f"surface smoke runner missing launch argument: {argument}")

    print(
        "Owner Truth natural-input Echo surface check passed: "
        "QA isolation retained and product entry policy-controlled"
    )


if __name__ == "__main__":
    main()
