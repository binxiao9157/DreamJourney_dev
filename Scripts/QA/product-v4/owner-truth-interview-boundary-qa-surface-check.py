#!/usr/bin/env python3
"""Guard the default-off Owner Truth interview-boundary QA surface."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SURFACE = ROOT / "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift"
CONTRACTS = ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
RUNNER = ROOT / "Scripts/QA/prd-stitch-ui/run-owner-truth-interview-boundary-smoke.sh"


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
    for path in (SURFACE, CONTRACTS, FLAGS, DELEGATE, RUNNER):
        require(path.is_file(), f"missing interview-boundary QA artifact: {path}")

    surface = SURFACE.read_text(encoding="utf-8")
    contracts = CONTRACTS.read_text(encoding="utf-8")
    flags = FLAGS.read_text(encoding="utf-8")
    delegate = DELEGATE.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    for snippet in (
        "private let skipOnceButton",
        "private let cooldownButton",
        "private let doNotAskButton",
        "private let restoreDoNotAskButton",
        "configureBoundaryControls()",
        "owner-truth-interview-boundary-skip-once",
        "owner-truth-interview-boundary-cooldown",
        "owner-truth-interview-boundary-do-not-ask",
        "owner-truth-interview-boundary-restore-do-not-ask",
        "case .skipOnce",
        "case .cooldown",
        "case .doNotAsk",
        "triggerBoundaryButtonForQA",
        "triggerDoNotAskRestoreForQA",
    ):
        require(snippet in surface, f"missing QA boundary surface: {snippet}")

    configure_body = body(surface, "private func configureBoundaryControls()")
    require(
        "guard presentation == .qa else" in configure_body,
        "boundary controls must remain QA presentation only",
    )
    require(
        "#if DEBUG || UI_QA_SIMULATOR" in configure_body,
        "Release builds must compile the boundary controls out",
    )
    require(
        "OwnerTruthCandidateReviewQAGate.isEnabled" in surface,
        "QA boundary surface must retain the existing QA gate",
    )
    require(
        "setBoundary(.open)" not in surface,
        "QA boundary surface must not reopen through the generic boundary command",
    )
    require(
        "UIAlertController(" in surface and "确认恢复" in surface,
        "doNotAsk restoration must require an explicit QA confirmation prompt",
    )

    require(
        "case setBoundary(OwnerTruthInterviewSessionBoundary)" in contracts,
        "boundary UI must reuse the lease-fenced natural-input use case",
    )
    require(
        "case restoreDoNotAsk" in contracts
        and "OwnerTruthInterviewRestoreDoNotAskCommand" in contracts,
        "doNotAsk restoration must use a separate typed command",
    )
    require(
        'case ownerTruthInterviewBoundarySmoke = "DJRunOwnerTruthInterviewBoundarySmoke"' in flags,
        "boundary UIQA requires an explicit launch scenario",
    )
    require(
        "runOwnerTruthInterviewBoundarySmoke" in delegate,
        "AppDelegate must dispatch the boundary UIQA scenario",
    )
    for argument in (
        "DJEnableOwnerTruthCandidateReviewQA",
        "DJRunOwnerTruthInterviewBoundarySmoke",
    ):
        require(argument in runner, f"boundary UIQA runner missing launch argument: {argument}")

    for forbidden in (
        "appendOwnerTruthInterviewNaturalInput",
        "startVoiceCapture",
        "openDigitalHuman",
    ):
        require(forbidden not in runner, f"boundary UIQA must remain isolated: {forbidden}")

    print("Owner Truth interview-boundary QA surface check passed: QA-only actions remain lease-fenced")


if __name__ == "__main__":
    main()
