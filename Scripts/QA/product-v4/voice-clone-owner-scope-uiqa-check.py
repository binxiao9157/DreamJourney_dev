#!/usr/bin/env python3
"""Static guard for the simulator-only Voice Clone account isolation smoke."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
VOICE_CLONE = ROOT / "DreamJourney/Sources/Memoir/VoiceCloneService.swift"
FEATURE_FLAGS = ROOT / "DreamJourney/Sources/App/FeatureFlagService.swift"
APP_DELEGATE = ROOT / "DreamJourney/Sources/AppDelegate.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
RUNNER = ROOT / "Scripts/QA/product-v4/run-voice-clone-owner-scope-uiqa-smoke.sh"


def require(source: str, fragment: str, context: str) -> None:
    if fragment not in source:
        raise AssertionError(f"{context}: missing {fragment!r}")


def main() -> None:
    voice_clone = VOICE_CLONE.read_text(encoding="utf-8")
    feature_flags = FEATURE_FLAGS.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")
    project = PROJECT.read_text(encoding="utf-8")
    runner = RUNNER.read_text(encoding="utf-8")

    for fragment in (
        "#if UI_QA_SIMULATOR && targetEnvironment(simulator)",
        "private struct VoiceCloneOwnerScopeUIQAResult: Codable",
        'static let fileName = "voice-clone-owner-scope-uiqa-result.json"',
        "enum VoiceCloneOwnerScopeUIQASmoke",
        "VoiceCloneLocalStateStore(",
        "let accountIsolation: Bool",
        "let generationFence: Bool",
        "let staleWriteRejected: Bool",
        "let deletePurgesOnlyOldScope: Bool",
        "let legacyPayloadQuarantined: Bool",
        "store.handleAccountLifecycle(accountLease: leaseA, purge: true)",
        "private final class VoiceCloneOwnerScopeUIQAMutableLeaseRuntime",
        "private final class VoiceCloneOwnerScopeUIQAViewController",
        "VoiceCloneOwnerScopeSmoke completed",
    ):
        require(voice_clone, fragment, "Voice Clone UIQA smoke")

    require(
        feature_flags,
        'case voiceCloneOwnerScopeSmoke = "DJRunVoiceCloneOwnerScopeSmoke"',
        "QA launch scenario",
    )
    require(feature_flags, ".voiceCloneOwnerScopeSmoke,", "QA launch order")
    require(
        feature_flags,
        ".globalPrivateStoreRetirementSmoke,\n             .voiceCloneOwnerScopeSmoke,",
        "QA no-login session preparation",
    )
    require(
        app_delegate,
        "case .voiceCloneOwnerScopeSmoke:\n            scheduleUIQAScenario(scenario) { _ in\n                VoiceCloneOwnerScopeUIQASmoke.runAndPresent()",
        "AppDelegate Voice Clone UIQA route",
    )
    require(project, "VoiceCloneService.swift in Sources", "Voice Clone target membership")

    for fragment in (
        "DJRunVoiceCloneOwnerScopeSmoke",
        "voice-clone-owner-scope-uiqa-result.json",
        "run-installable-simulator-uiqa.sh",
        "01-voice-clone-owner-scope.png",
        "VoiceCloneOwnerScopeSmoke completed",
    ):
        require(runner, fragment, "Voice Clone UIQA runner")

    print("Voice Clone owner scope UIQA static check passed")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError) as error:
        print(f"Voice Clone owner scope UIQA static check failed: {error}", file=sys.stderr)
        sys.exit(1)
