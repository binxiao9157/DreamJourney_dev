#!/usr/bin/env python3
"""Guard WI-S1-03-07's pure lease model and direct AVAudioSession inventory."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "DreamJourney/Sources/App/AudioOwnerLeaseModel.swift"
TESTS = ROOT / "DreamJourneyTests/AudioOwnerLeaseModelTests.swift"
SOURCE_ROOT = ROOT / "DreamJourney/Sources"

EXPECTED_DIRECT_AUDIO_SESSION_CONFIGURATORS = {
    "DreamJourney/Sources/Memoir/MemoirAudioPlayer.swift",
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift",
    "DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift",
    "DreamJourney/Sources/Modules/Echo/EchoViewController.swift",
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
    tests = read(TESTS)

    for required in (
        "enum AudioOwnerLeasePurpose",
        "enum AudioOwnerLeaseRoute",
        "enum AudioOwnerLeaseState",
        "let purpose: AudioOwnerLeasePurpose",
        "let route: AudioOwnerLeaseRoute",
        "let state: AudioOwnerLeaseState",
        "mutating func interruptActiveLease()",
        "mutating func resume(_ lease: AudioOwnerLease)",
    ):
        require(required in model, f"audio owner lease contract missing: {required}")

    for test_name in (
        "func testDigitalHumanPlaybackPreemptsEchoCaptureAndStaleReleaseCannotClearIt()",
        "func testOlderRuntimeGenerationCannotPreemptCurrentAudioOwner()",
        "func testSystemInterruptionOnlyResumesCurrentLease()",
        "func testOwnerDefaultPurposeAndRouteAreStable()",
    ):
        require(test_name in tests, f"audio owner lease XCTest missing: {test_name}")

    for forbidden in ("UIKit", "AVFoundation", "URLSession", "UserDefaults", ".shared"):
        require(forbidden not in model, f"pure audio owner model must not depend on {forbidden}")

    actual_configurators = direct_audio_session_configurators()
    require(
        actual_configurators == EXPECTED_DIRECT_AUDIO_SESSION_CONFIGURATORS,
        "direct AVAudioSession configurator inventory drift: "
        f"expected={sorted(EXPECTED_DIRECT_AUDIO_SESSION_CONFIGURATORS)} "
        f"actual={sorted(actual_configurators)}",
    )

    print(
        "Product V4 iOS audio owner lease check passed: pure interruption model and "
        f"{len(actual_configurators)} direct AVAudioSession configurators are inventoried"
    )


if __name__ == "__main__":
    main()
