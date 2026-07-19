#!/usr/bin/env python3
"""Guard the incremental Echo application coordinator seam."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
VIEW_MODEL = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewModel.swift"
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def source_slice(source: str, start: str, end: str) -> str:
    start_index = source.find(start)
    require(start_index >= 0, f"missing source slice start: {start}")
    end_index = source.find(end, start_index + len(start))
    require(end_index >= 0, f"missing source slice end: {end}")
    return source[start_index:end_index]


def main() -> None:
    view_model = VIEW_MODEL.read_text(encoding="utf-8")
    view_controller = VIEW_CONTROLLER.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "struct EchoContextBuildLease: Equatable",
        "final class EchoApplicationCoordinator",
        "private(set) var activeContextBuildLease: EchoContextBuildLease?",
        "func beginContextBuild(",
        "func invalidateContextBuild() -> EchoContextBuildLease?",
        "func isCurrent(_ lease: EchoContextBuildLease) -> Bool",
    ):
        require(required in view_model, f"Echo application coordinator contract missing: {required}")

    require(
        "private let echoApplicationCoordinator = EchoApplicationCoordinator()" in view_controller,
        "EchoViewController must own the incremental application coordinator",
    )
    require(
        "private func cancelActiveEchoContextBuild(reason: String)" in view_controller,
        "EchoViewController must invalidate context-build leases on lifecycle changes",
    )
    require(
        "latestEchoContextRequestTurnID" not in view_controller,
        "string-only context request tracking must be retired",
    )

    context_build = source_slice(
        view_controller,
        "    private func recordEchoContextPacketForUserTurn(",
        "    private func submitLocalEchoTurnKnowledgeContext(",
    )
    require(
        "let contextBuildLease = echoApplicationCoordinator.beginContextBuild(" in context_build,
        "context build must allocate a coordinator lease before calling the backend",
    )
    require(
        "echoApplicationCoordinator.isCurrent(contextBuildLease)" in context_build,
        "backend callbacks must be fenced by the coordinator lease",
    )
    require(
        context_build.find("echoApplicationCoordinator.isCurrent(contextBuildLease)")
        < context_build.find("EchoTraceStore.shared.record"),
        "stale context packets must be rejected before trace persistence",
    )

    for test_name in (
        "func testContextBuildLeaseSupersedesEarlierRequest()",
        "func testInvalidatingContextBuildRejectsLateCallback()",
        "func testSameTurnNewGenerationRejectsOldCallback()",
    ):
        require(test_name in tests, f"Echo application coordinator test missing: {test_name}")

    print(
        "Product V4 Echo application coordinator check passed: context-build callbacks "
        "are generation-fenced before trace persistence or Echo submission"
    )


if __name__ == "__main__":
    main()
