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
        "protocol EchoContextBuildTransport",
        "struct EchoContextBuildLease: Equatable",
        "struct EchoContextBuildIdentityMismatch: Equatable",
        "struct EchoContextBuildAuthorityInvalidation: Equatable",
        "enum EchoContextBuildDelivery",
        "final class EchoApplicationCoordinator",
        "private(set) var activeContextBuildLease: EchoContextBuildLease?",
        "private let accountLeaseValidator: (AccountLease, AccountLeaseCheckpoint) -> AccountLeaseValidationDecision",
        "func beginContextBuild(",
        "func requestContextBuild(",
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
        "echoApplicationCoordinator.requestContextBuild(" in context_build,
        "context build must start through the application coordinator",
    )
    require(
        "DreamJourneyBackendClient.shared.buildEchoContextPacket" not in context_build,
        "EchoViewController must not directly compose context-build transport",
    )
    require(
        "echoApplicationCoordinator.isCurrent(contextBuildLease)" not in context_build,
        "the coordinator must own stale lease filtering before invoking the controller callback",
    )
    require(
        "EchoKnowledgeContextPolicy.responseIdentityMatches" not in context_build,
        "the coordinator must classify context identity mismatches before controller delivery",
    )
    require(
        "case .identityMismatch(let mismatch):" in context_build,
        "the controller must retain its explicit local fallback for rejected context identity",
    )
    require(
        "accountLease: accountLease" in context_build,
        "context build requests must bind the caller's AccountLease",
    )
    require(
        "case .authorityInvalidated(let invalidation):" in context_build,
        "the controller must cancel a context turn after authority invalidation",
    )
    require(
        "contextPacketAuthorityInvalidated" in context_build,
        "authority-invalidated Context packets must not reach local fallback submission",
    )

    for test_name in (
        "func testContextBuildLeaseSupersedesEarlierRequest()",
        "func testInvalidatingContextBuildRejectsLateCallback()",
        "func testSameTurnNewGenerationRejectsOldCallback()",
        "func testCoordinatorDropsSupersededTransportCallbackBeforeDelivery()",
        "func testCoordinatorDoesNotStartWhenContextTransportIsUnavailable()",
        "func testCoordinatorClassifiesIdentityMismatchedPacketBeforeControllerDelivery()",
        "func testCoordinatorRejectsLateContextPacketAfterAuthorityEpochChanges()",
    ):
        require(test_name in tests, f"Echo application coordinator test missing: {test_name}")

    print(
        "Product V4 Echo application coordinator check passed: context-build callbacks "
        "are generation-fenced before trace persistence or Echo submission"
    )


if __name__ == "__main__":
    main()
