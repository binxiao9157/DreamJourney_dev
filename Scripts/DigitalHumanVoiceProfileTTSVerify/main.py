#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
SERVICE = ROOT / "DreamJourney/Sources/Services/DigitalHumanSpeechService.swift"
STORE = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DigitalHumanVoiceProfileTTS verification failed: {message}", file=sys.stderr)
        sys.exit(1)


service = SERVICE.read_text(encoding="utf-8")
store = STORE.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

require(
    "func readySpeakerId(matching text: String" in store,
    "voice profile store should expose a conservative ready-speaker resolver",
)
require(
    "voiceType: String? = nil" in service,
    "digital-human WAV synthesis should allow an explicit voiceType override",
)
require(
    "MemoryArchiveVoiceProfileStore.shared.readySpeakerId(matching: trimmedText)" in service,
    "digital-human TTS should try a ready matching person voice profile before falling back to global voice type",
)
require(
    "voiceType ??" in service and "VolcEngineCredentialProvider.voiceType()" in service,
    "digital-human TTS should preserve the global VolcEngineVoiceType fallback",
)
require(
    "DigitalHumanVoiceProfileTTSVerify/main.py" in phase1,
    "phase1 verification should include digital-human voice-profile TTS coverage",
)

print("DigitalHumanVoiceProfileTTS verification passed")
