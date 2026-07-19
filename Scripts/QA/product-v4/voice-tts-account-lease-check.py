#!/usr/bin/env python3

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_all(source: str, snippets: tuple[str, ...], label: str) -> None:
    for snippet in snippets:
        require(snippet in source, f"{label} missing: {snippet}")


def main() -> None:
    voice = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
    tts = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")
    dialog = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
    echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

    require_all(
        voice,
        (
            "private let accountLeaseRuntime: AccountLeaseRuntimePort",
            "private var trainingRuntimeOperation: VoiceCloneTrainingRuntimeOperation?",
            "private var nextTrainingRuntimeGeneration: UInt64 = 0",
            "private func beginTrainingRuntime(",
            "private func isCurrentTrainingRuntimeOperation(",
            "private func handleDigitalHumanContextChange(",
            "accountLeaseRuntime.capture(forSubjectId:",
            "validate(accountLease, at: .request).allowed",
            "validate(accountLease, at: .commit).allowed",
            "validate(accountLease, at: .runtime).allowed",
            "validate(accountLease, at: .ui).allowed",
            "isCurrentTrainingRuntimeOperation(operation, at: .timer)",
            "isCurrentTrainingRuntimeOperation(operation, at: .runtime)",
            "isCurrentTrainingRuntimeOperation(operation, at: .commit)",
            "isCurrentTrainingRuntimeOperation(operation, at: .ui)",
            "accountLease: AccountLease",
        ),
        "VoiceClone AccountLease contract",
    )
    require(
        re.search(
            r"startPollingStatus\([\s\S]*?operation:\s*VoiceCloneTrainingRuntimeOperation",
            voice,
        ) is not None,
        "voice training polling must retain the typed owner/persona runtime operation",
    )
    require(
        re.search(
            r"queryStatus\([\s\S]*?trainingOperation:\s*VoiceCloneTrainingRuntimeOperation\?\s*=\s*nil",
            voice,
        ) is not None,
        "voice status callbacks must carry the optional typed runtime operation",
    )

    require_all(
        tts,
        (
            "private let accountLeaseRuntime: AccountLeaseRuntimePort",
            "private struct SynthesisOperation",
            "accountLeaseRuntime.capture(forSubjectId: memoir.authorId)",
            "accountLease: AccountLease",
            "validate(accountLease, at: .request).allowed",
            "validate(accountLease, at: .commit).allowed",
            "validate(accountLease, at: .runtime).allowed",
            "validate(accountLease, at: .ui).allowed",
            "stagingFileURL",
            "commitSynthesisArtifacts",
        ),
        "Memoir TTS AccountLease contract",
    )

    require_all(
        dialog,
        (
            "struct DialogEngineScopedTTSVoiceSelection",
            "struct DialogEngineScopedTTSVoiceSelectionStore",
            "func setLocalTTSVoiceSelection(",
            "scopedTTSVoiceSelectionStore.resolvedVoiceProfileId(",
            "candidate.lifecycleGeneration >= selection.lifecycleGeneration",
        ),
        "DialogEngine scoped local TTS selection contract",
    )
    require(
        "VoiceCloneService.shared.currentUsableSpeakerId" not in dialog,
        "DialogEngine must not read process-global VoiceCloneService selection",
    )
    require_all(
        echo,
        (
            "private func updateDialogEngineLocalTTSVoiceSelection(",
            "DialogEngineManager.shared.setLocalTTSVoiceSelection(",
            "voiceCloneRuntimeCapability?.canSynthesize == true",
            "_ = updateDialogEngineLocalTTSVoiceSelection(reason: \"contextDidChange\")",
        ),
        "Echo scoped local TTS selection integration",
    )

    memoir_detail = read("DreamJourney/Sources/Memoir/MemoirDetailViewController.swift")
    require_all(
        voice,
        (
            "func currentUsablePersonalSpeakerId(forOwnerId ownerId: String)",
            "accountLeaseRuntime.capture(forSubjectId: normalizedOwnerId)",
            "let personalTarget = VoiceClonePersonaTarget(",
            "personaScope: \"personal\"",
        ),
        "VoiceClone personal owner-scoped fallback contract",
    )
    require(
        "VoiceCloneService.shared.currentUsableSpeakerId" not in tts,
        "MemoirTTSService must not use the active persona's process-global profile",
    )
    require_all(
        tts,
        (
            "currentUsablePersonalSpeakerId(\n                forOwnerId: accountLease.subjectId",
            "resolvedVoiceProfileId(\n                  for: memoir,\n                  accountLease: access.accountLease",
        ),
        "Memoir TTS owner-scoped fallback integration",
    )
    require_all(
        memoir_detail,
        (
            "private func resolvedMemoirVoiceProfileId() -> String?",
            "currentUsablePersonalSpeakerId(forOwnerId: memoir.authorId)",
            "generateAudioWithClone(voiceProfileId: voiceProfileId)",
        ),
        "Memoir detail owner-scoped voice selection integration",
    )

    print("Voice/TTS AccountLease check passed")


if __name__ == "__main__":
    main()
