#!/usr/bin/env python3
"""Static G0 gate for the typed Voice/Digital Human client-port boundary."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RUNTIME = ROOT / "DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift"
TTS = ROOT / "DreamJourney/Sources/Memoir/MemoirTTSService.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def body(source: str, marker: str) -> str:
    start = source.find(marker)
    require(start >= 0, f"missing declaration: {marker}")
    opening = source.find("{", start)
    require(opening >= 0, f"missing declaration body: {marker}")
    depth = 0
    for cursor in range(opening, len(source)):
        if source[cursor] == "{":
            depth += 1
        elif source[cursor] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : cursor + 1]
    raise AssertionError(f"unterminated declaration: {marker}")


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{label} missing: {snippet}")


def main() -> None:
    runtime = RUNTIME.read_text()
    tts = TTS.read_text()
    echo = ECHO.read_text()
    tests = TESTS.read_text()

    require_all(
        runtime,
        (
            "struct VoiceDigitalHumanOperationScope: Equatable, Sendable",
            "let accountLease: AccountLease",
            "let personaOwnerId: String",
            "let roleKey: String",
            "let runtimeGeneration: UInt64",
            "struct VoiceCloneSynthesisRequest: Equatable, Sendable",
            "struct DigitalHumanSessionRequest: Equatable, Sendable",
            "struct DigitalHumanSessionLeaseOperationRequest",
            "protocol VoiceCloneSynthesisClientPort: AnyObject",
            "func fetchVoiceCloneRuntimeCapability(",
            "protocol DigitalHumanSessionClientPort: AnyObject",
            "extension DreamJourneyBackendClient: VoiceCloneSynthesisClientPort, DigitalHumanSessionClientPort",
            "case accountContractMismatch",
            "guard request.isAccountBound else",
        ),
        "typed Voice/Digital Human port boundary",
    )

    require_all(
        tts,
        (
            "private let voiceCloneSynthesisClient: VoiceCloneSynthesisClientPort",
            "voiceCloneSynthesisClient: VoiceCloneSynthesisClientPort = DreamJourneyBackendClient.shared",
            "guard voiceCloneSynthesisClient.isVoiceCloneSynthesisConfigured else",
            "voiceCloneSynthesisClient.fetchVoiceCloneRuntimeCapability",
            "capability.canSynthesize",
            ".runtimeCapabilityUnavailable",
            "VoiceDigitalHumanOperationScope(",
            "VoiceCloneSynthesisRequest(",
            "voiceCloneSynthesisClient.requestVoiceCloneSynthesis(request)",
        ),
        "Memoir TTS typed port use",
    )
    require(
        "DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(" not in tts,
        "Memoir TTS must not bypass its typed synthesis port",
    )

    heartbeat = body(echo, "private func scheduleDigitalHumanSessionHeartbeat(")
    release = body(echo, "private func performDigitalHumanSessionRelease(")
    create = body(echo, "private func createCloudDigitalHumanSession(")
    require_all(
        echo,
        (
            "private let digitalHumanSessionClient: DigitalHumanSessionClientPort",
            "digitalHumanSessionClient: DigitalHumanSessionClientPort = DreamJourneyBackendClient.shared",
        ),
        "Echo typed port injection",
    )
    require_all(
        heartbeat,
        (
            "DigitalHumanSessionLeaseOperationRequest(",
            "accountLease: accountLease",
            "digitalHumanSessionClient.heartbeatDigitalHumanSession(leaseRequest)",
        ),
        "Echo heartbeat typed port use",
    )
    require_all(
        release,
        (
            "DigitalHumanSessionLeaseOperationRequest(",
            "accountLease: accountLease",
            "digitalHumanSessionClient.releaseDigitalHumanSession(leaseRequest)",
        ),
        "Echo release typed port use",
    )
    require_all(
        create,
        (
            "VoiceDigitalHumanOperationScope(",
            "runtimeGeneration: runtimeSessionCallback.runtimeGeneration",
            "DigitalHumanSessionRequest(",
            "digitalHumanSessionClient.createDigitalHumanSession(request)",
            "event: \"sessionRequestRejected\"",
        ),
        "Echo session-create typed port use",
    )

    require_all(
        tests,
        (
            "final class VoiceDigitalHumanClientPortModelTests: XCTestCase",
            "func testOperationScopeCarriesAccountPersonaRoleAndRuntimeGeneration()",
            "func testOperationScopeRejectsMissingPersonaOrRole()",
            "func testVoiceCloneRequestPreservesScopedProfileAndNormalizesOptionalOutputMode()",
            "func testDigitalHumanSessionRequestUsesScopedOwnerAndPersona()",
        ),
        "typed port model coverage",
    )

    print("Product V4 iOS Voice/Digital Human typed client-port check passed")


if __name__ == "__main__":
    main()
