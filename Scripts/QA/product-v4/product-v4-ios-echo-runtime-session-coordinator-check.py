#!/usr/bin/env python3
"""Guard the first incremental Echo runtime-session coordinator boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
COORDINATOR = ROOT / "DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift"
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
    coordinator = COORDINATOR.read_text(encoding="utf-8")
    view_controller = VIEW_CONTROLLER.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for required in (
        "enum EchoRuntimeLeaseStatus: String, Equatable",
        "enum EchoRuntimeCallbackScope: Equatable",
        "enum EchoRuntimeCallbackRejection: Equatable",
        "enum EchoRuntimeCallbackValidation: Equatable",
        "struct EchoRuntimeLease: Equatable",
        "struct EchoRuntimeCallbackToken: Equatable",
        "final class EchoRuntimeSessionCoordinator",
        "func beginSessionRequest(",
        "func activateSession(",
        "func beginInteraction(",
        "func finishInteraction()",
        "func invalidatePendingSessionRequest()",
        "func releaseRuntime()",
        "func validate(_ callback: EchoRuntimeCallbackToken)",
    ):
        require(required in coordinator, f"runtime session coordinator contract missing: {required}")

    require(
        "private let echoRuntimeSessionCoordinator = EchoRuntimeSessionCoordinator()" in view_controller,
        "EchoViewController must own the runtime session coordinator",
    )
    for required in (
        "echoRuntimeSessionCoordinator.beginSessionRequest(",
        "isCurrentEchoRuntimeSessionCallback(",
        "echoRuntimeSessionCoordinator.activateSession(",
        "echoRuntimeSessionCoordinator.invalidatePendingSessionRequest()",
        "echoRuntimeSessionCoordinator.finishInteraction()",
        "echoRuntimeSessionCoordinator.releaseRuntime()",
        "runtimeSessionCallback: EchoRuntimeCallbackToken",
    ):
        require(required in view_controller, f"Echo runtime session integration missing: {required}")

    preparation = source_slice(
        view_controller,
        "    private func prepareCloudDigitalHumanRuntimeIfNeeded(",
        "    private func normalizedDigitalHumanReplyText(",
    )
    require(
        "runtimeSessionCallback" in preparation,
        "session preparation must capture a runtime callback lease",
    )
    require(
        "runtimeSessionActivationRejected" in preparation,
        "stale session activation must be released before it can bind a runtime",
    )
    require(
        "runtimeSessionCallback: activeRuntimeSessionCallback" in preparation,
        "provider runtime state must receive the active runtime session callback",
    )
    heartbeat = source_slice(
        view_controller,
        "    private func scheduleDigitalHumanSessionHeartbeat(",
        "    private func cancelDigitalHumanSessionHeartbeat(",
    )
    require(
        "runtimeSessionCallback: EchoRuntimeCallbackToken" in heartbeat,
        "heartbeat must retain the active runtime session callback",
    )
    require(
        "reason: \"digitalHumanSessionHeartbeatResponse\"" in heartbeat,
        "heartbeat response must validate its runtime session callback",
    )

    for test_name in (
        "func testLateRoleSwitchSessionCallbackIsRejectedBeforeActivation()",
        "func testStopInvalidatesInteractionButPreservesActiveSession()",
        "func testReleaseRejectsAllOutstandingSessionCallbacks()",
        "func testSessionCallbackRejectsDifferentProviderSession()",
    ):
        require(test_name in tests, f"runtime session coordinator test missing: {test_name}")

    print(
        "Product V4 Echo runtime session coordinator check passed: session callbacks "
        "are fenced by account, context, runtime, lifecycle and interaction state"
    )


if __name__ == "__main__":
    main()
