#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
TRANSCRIBER = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceTranscriber.swift"
PROJECT = ROOT / "DreamJourney.xcodeproj/project.pbxproj"
INFO = ROOT / "DreamJourney/Resources/Info.plist"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"MemoryArchiveVoiceAutoTranscription verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VC.read_text()
transcriber = TRANSCRIBER.read_text() if TRANSCRIBER.exists() else ""
project = PROJECT.read_text()
info = INFO.read_text()
phase1 = PHASE1.read_text()

require(TRANSCRIBER.exists(), "voice auto transcription service should exist")
require(
    "import Speech" in transcriber
    and "SFSpeechRecognizer.requestAuthorization" in transcriber
    and "SFSpeechURLRecognitionRequest" in transcriber
    and "recognitionTask" in transcriber,
    "voice transcriber should use iOS Speech file transcription",
)
require(
    "自动识别转写" in view
    and "presentVoiceAutoTranscriptionConsent(for: item)" in view
    and "MemoryArchiveVoiceTranscriber.shared.transcribeAudio" in view,
    "voice archive item menu should expose manual auto transcription",
)
require(
    "可能由系统语音识别服务处理音频" in view
    and "私密素材只回填档案" in view,
    "auto transcription flow should explain privacy and private-scope behavior",
)
require(
    "saveVoiceTranscriptBackfill(transcript, for: item)" in view,
    "auto transcription should reuse voice transcript backfill deposit path",
)
require(
    "NSSpeechRecognitionUsageDescription" in info,
    "Info.plist should include speech recognition permission usage text",
)
require(
    "MemoryArchiveVoiceTranscriber.swift in Sources" in project,
    "Xcode project should compile the voice transcriber",
)
require(
    "MemoryArchiveVoiceAutoTranscriptionVerify/main.py" in phase1,
    "phase1 verification should include voice auto transcription coverage",
)

print("MemoryArchiveVoiceAutoTranscription verification passed")
