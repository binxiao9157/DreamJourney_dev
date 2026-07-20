#!/usr/bin/env python3
"""Guard the QA-only Echo surface for V4 M0-A natural input."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
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
    for path in (ECHO, FEATURE_FLAGS, APP_DELEGATE, RUNNER):
        require(path.is_file(), f"missing Echo natural-input QA artifact: {path}")

    echo = ECHO.read_text(encoding="utf-8")
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
        "double-gated, QA-only, and side-effect free"
    )


if __name__ == "__main__":
    main()
