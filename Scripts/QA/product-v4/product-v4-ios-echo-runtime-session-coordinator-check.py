#!/usr/bin/env python3
"""Guard the first incremental Echo runtime-session coordinator boundary."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
COORDINATOR = ROOT / "DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift"
VIEW_CONTROLLER = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
RUNTIME = ROOT / "DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift"
CLOUD_RUNTIME = ROOT / "DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift"
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
    runtime = RUNTIME.read_text(encoding="utf-8")
    cloud_runtime = CLOUD_RUNTIME.read_text(encoding="utf-8")
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
        "func renewSession(",
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
        "beginEchoRuntimeInteraction(",
        "runtimeInteractionCallback: EchoRuntimeCallbackToken?",
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
    require(
        "refreshedContract.replaceLease(operation.lease)" in heartbeat
        and "echoRuntimeSessionCoordinator.renewSession(" in heartbeat,
        "heartbeat success must refresh both the session contract and callback expiry boundary",
    )
    interaction = source_slice(
        view_controller,
        "    private func sendEchoReplyViaTencentVoiceClonePCMDrive(",
        "    private func showVoiceCloneNotEnabledStatusIfNeeded(",
    )
    require(
        "beginEchoRuntimeInteraction(" in interaction,
        "voice-clone synthesis must begin a runtime interaction lease",
    )
    require(
        "reason: \"voiceClonePCMDriveResponse\"" in interaction,
        "voice-clone synthesis response must validate its runtime interaction lease",
    )
    pcm_drive = source_slice(
        view_controller,
        "    private func startPCMDriveSignalToDigitalHumanRuntime(",
        "    private func makeTencentDigitalHumanPCMDriveTestSignal(",
    )
    require(
        "runtimeInteractionCallback" in pcm_drive,
        "PCM drive chunks must consume the runtime interaction callback",
    )
    background_release = source_slice(
        view_controller,
        "    private func scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded()",
        "    private var digitalHumanBackgroundReleaseGracePeriod",
    )
    require(
        "let runtimeSessionCallback = echoRuntimeSessionCoordinator.currentSessionCallbackToken()" in background_release,
        "background grace release must capture the active runtime session callback",
    )
    require(
        "reason: \"backgroundReleaseLeaseExpired\"" in background_release,
        "background grace release must validate the captured runtime session callback",
    )
    fallback = source_slice(
        view_controller,
        "    private func degradeTencentDigitalHumanRoute(reason: String)",
        "    private func digitalHumanRouteFailureMessage",
    )
    require(
        "releaseDigitalHumanRuntime(" in fallback,
        "quota and provider fallback must release the active runtime lease",
    )

    require(
        "case completed(requestID: String)" in runtime,
        "runtime completion must carry the provider request identity",
    )
    require(
        "func completeProviderRequest(matching requestID: String)" in coordinator,
        "provider completion must require the current request identity",
    )
    require(
        "case .completed(let requestID):" in view_controller
        and "completeTencentDigitalHumanReplyIfNeeded(requestID: requestID)" in view_controller,
        "Echo must only complete a request from a request-specific provider terminal event",
    )
    require(
        "case .textOver(let requestID):" in cloud_runtime
        and "handleProviderTextOver(requestID: requestID)" in cloud_runtime,
        "TextOver must remain distinct from terminal audio completion",
    )
    require(
        "case .audioOver(let requestID):" in cloud_runtime
        and "handleProviderAudioOver(requestID: requestID)" in cloud_runtime,
        "AudioOver must carry a request-specific completion boundary",
    )

    for test_name in (
        "func testLateRoleSwitchSessionCallbackIsRejectedBeforeActivation()",
        "func testStopInvalidatesInteractionButPreservesActiveSession()",
        "func testReleaseRejectsAllOutstandingSessionCallbacks()",
        "func testBackgroundOrFallbackReleaseRejectsSessionAndInteractionCallbacks()",
        "func testSessionCallbackRejectsDifferentProviderSession()",
        "func testNewInteractionRejectsPriorRequestCallbacks()",
        "func testExpiredSessionRejectsNewWork()",
        "func testHeartbeatRenewalExtendsSessionCallbackBoundary()",
        "func testProviderCompletionRequiresMatchingRequestID()",
    ):
        require(test_name in tests, f"runtime session coordinator test missing: {test_name}")

    print(
        "Product V4 Echo runtime session coordinator check passed: session callbacks "
        "are fenced by account, context, runtime, lifecycle and interaction state"
    )


if __name__ == "__main__":
    main()
