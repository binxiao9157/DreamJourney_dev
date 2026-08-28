#!/usr/bin/env python3
"""Guard WI-S1-03-07's pure model and Echo-only AudioSession enforcement."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "DreamJourney/Sources/App/AudioOwnerLeaseModel.swift"
COORDINATOR = ROOT / "DreamJourney/Sources/App/AudioOwnerLeaseCoordinator.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"
ECHO = ROOT / "DreamJourney/Sources/Modules/Echo/EchoViewController.swift"
DIALOG = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"
SOURCE_ROOT = ROOT / "DreamJourney/Sources"

EXPECTED_DIRECT_AUDIO_SESSION_CONFIGURATORS = {
    "DreamJourney/Sources/App/AudioOwnerLeaseCoordinator.swift",
    "DreamJourney/Sources/Memoir/MemoirAudioPlayer.swift",
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift",
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift",
    "DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift",
    "DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift",
    "DreamJourney/Sources/Services/DialogEngineManager.swift",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def direct_audio_session_configurators() -> set[str]:
    result: set[str] = set()
    for path in SOURCE_ROOT.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        if "AVAudioSession" not in text:
            continue
        if "setCategory(" in text or "setActive(" in text:
            result.add(str(path.relative_to(ROOT)))
    return result


def main() -> None:
    model = read(MODEL)
    coordinator = read(COORDINATOR)
    tests = read(TESTS)
    echo = read(ECHO)
    dialog = read(DIALOG)

    for required in (
        "enum AudioOwnerLeasePurpose",
        "enum AudioOwnerLeaseRoute",
        "enum AudioOwnerLeaseState",
        "case echoLocalPlayback",
        "case echoLocalTTSPlayback",
        "let purpose: AudioOwnerLeasePurpose",
        "let route: AudioOwnerLeaseRoute",
        "let state: AudioOwnerLeaseState",
        "mutating func interruptActiveLease()",
        "mutating func interrupt(_ lease: AudioOwnerLease)",
        "mutating func resume(_ lease: AudioOwnerLease)",
    ):
        require(required in model, f"audio owner lease contract missing: {required}")

    for test_name in (
        "func testDigitalHumanPlaybackPreemptsEchoCaptureAndStaleReleaseCannotClearIt()",
        "func testOlderRuntimeGenerationCannotPreemptCurrentAudioOwner()",
        "func testSystemInterruptionOnlyResumesCurrentLease()",
        "func testOwnerDefaultPurposeAndRouteAreStable()",
        "func testEchoLocalPlaybackDefaultPurposeAndRouteAreStable()",
        "func testObserveOnlyTransitionRejectsStaleRelease()",
        "func testRepeatedObserveOnlyOwnerDoesNotCreateAnotherLease()",
        "func testObserveOnlySystemEventsRequireTheCurrentLeaseToken()",
        "func testFallbackOrBackgroundReleaseClearsTencentLeaseBeforeNewCapture()",
        "func testTencentPlaybackPreemptsCaptureAndStaleReleaseCannotDeactivateIt()",
        "func testFailedTencentPreemptionRestoresCaptureAndDoesNotCommitNewOwner()",
        "func testOnlyCurrentInterruptedLeaseCanResumeAndResumeReactivatesDriver()",
        "func testFailedDeactivationRetainsCurrentLease()",
    ):
        require(test_name in tests, f"audio owner lease XCTest missing: {test_name}")

    for forbidden in ("UIKit", "AVFoundation", "URLSession", "UserDefaults", ".shared"):
        require(forbidden not in model, f"pure audio owner model must not depend on {forbidden}")

    for required in (
        "final class AudioOwnerLeaseCoordinator",
        "func observeOwner(",
        "func releaseObservedLease(",
        "func observeInterruption(for lease: AudioOwnerLease)",
        "func observeResume(for lease: AudioOwnerLease)",
        "func observeRouteChange(for lease: AudioOwnerLease)",
        "static let shared = AudioOwnerLeaseCoordinator()",
        "protocol AudioSessionDriving",
        "final class AudioSessionCoordinator",
        "func acquire(",
        "func release(_ lease: AudioOwnerLease)",
        "func interrupt(_ lease: AudioOwnerLease)",
        "func resume(_ lease: AudioOwnerLease)",
        "func routeDidChange(for lease: AudioOwnerLease)",
        "func isCurrentActiveLease(_ lease: AudioOwnerLease)",
        "static let shared = AudioSessionCoordinator(driver: SystemAudioSessionDriver())",
        "private final class SystemAudioSessionDriver",
        "AVAudioSession.sharedInstance",
    ):
        require(required in coordinator, f"audio owner coordinator missing: {required}")

    for forbidden in ("AVAudioSession.sharedInstance", ".setCategory(", ".setActive("):
        require(
            forbidden not in echo,
            f"Echo must not configure AVAudioSession directly: {forbidden}",
        )
    for required in (
        "private var activeEchoAudioOwnerLease: AudioOwnerLease?",
        "private var audioSessionCoordinator = AudioSessionCoordinator.shared",
        "acquireEchoRuntimeAudioOwner(",
        "releaseEchoAudioOwnerLease(",
        "audioSessionCoordinator.acquire(",
        "audioSessionCoordinator.release(",
        "prepareEchoCaptureAudioSession(reason:",
        "DialogEngineManager.shared.adoptExternallyManagedAudioSessionLease(lease)",
        "AVAudioSession.interruptionNotification",
        "AVAudioSession.routeChangeNotification",
        "reason: \"dialogStarted\"",
        "reason: \"digitalHumanRuntimeSpeaking\"",
        "releaseEchoAudioOwnerLease(reason: \"viewWillDisappear\")",
        "expectedOwner: .tencentDigitalHumanPlayback",
        "reason: \"runtimeReleased:\\(reason)\"",
        "reason: \"contextChanged\"",
        "interruptDigitalHumanPlayback(reason: \"appLifecycle:\\(reason)\")",
        "reason: \"appLifecycle:backgroundGraceExpired\"",
        "audioSessionCoordinatorActivationFailed",
    ):
        require(required in echo, f"Echo AudioSession coordinator adapter missing: {required}")

    for required in (
        "private var externallyManagedAudioSessionLease: AudioOwnerLease?",
        "func adoptExternallyManagedAudioSessionLease(_ lease: AudioOwnerLease) -> Bool",
        "AudioSessionCoordinator.shared.isCurrentActiveLease(externallyManagedAudioSessionLease)",
        "DialogAudioSessionOwnershipPolicy.allowsDirectConfiguration(",
        "Echo Live 缺少 AudioSessionCoordinator lease",
        "guard configureAudioSession() else",
        "跳过 AudioSession 恢复：AudioSessionCoordinator 持有会话",
    ):
        require(required in dialog, f"DialogEngine managed-audio lease guard missing: {required}")

    actual_configurators = direct_audio_session_configurators()
    require(
        actual_configurators == EXPECTED_DIRECT_AUDIO_SESSION_CONFIGURATORS,
        "direct AVAudioSession configurator inventory drift: "
        f"expected={sorted(EXPECTED_DIRECT_AUDIO_SESSION_CONFIGURATORS)} "
        f"actual={sorted(actual_configurators)}",
    )

    print(
        "Product V4 iOS audio owner lease check passed: pure interruption model, Echo-only "
        "AudioSessionCoordinator enforcement, and "
        f"{len(actual_configurators)} direct AVAudioSession configurators are inventoried"
    )


if __name__ == "__main__":
    main()
