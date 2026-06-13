#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
AI = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DigitalHumanPlaybackInterrupt verification failed: {message}", file=sys.stderr)
        sys.exit(1)


ai = AI.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

publish_match = re.search(r"private func publishAssistantResponse\(_ text: String\)[\s\S]*?\n    \}", ai)
cancel_match = re.search(r"private func cancelInFlightDigitalHumanPlaybackForNewAssistantResponse\([\s\S]*?\n    \}", ai)

require(publish_match is not None, "publishAssistantResponse should exist")
require(cancel_match is not None, "new-response playback cancellation helper should exist")

publish_body = publish_match.group(0)
cancel_body = cancel_match.group(0)

require(
    "cancelInFlightDigitalHumanPlaybackForNewAssistantResponse()" in publish_body,
    "publishing a new assistant final should cancel previous in-flight playback before starting a new synthesis",
)
require(
    publish_body.find("cancelInFlightDigitalHumanPlaybackForNewAssistantResponse()") < publish_body.find("currentAssistantResponseText = trimmed"),
    "old playback should be cancelled before currentAssistantResponseText is replaced",
)
require(
    "isAwaitingDigitalHumanAudioEnd" in cancel_body
    and "digitalHumanNativeAudioPlayer != nil" in cancel_body
    and "isDigitalHumanSystemSpeechFallbackActive" in cancel_body,
    "helper should detect native, fallback, and pending playback",
)
require(
    "playback_cancelled_for_new_response" in cancel_body
    and "DigitalHumanPlaybackEvidenceStore.shared.appendEvent" in cancel_body,
    "helper should leave playback evidence for true-device debugging",
)
require(
    "cancelDigitalHumanPlaybackWatchdog()" in cancel_body
    and "stopDigitalHumanNativeAudio()" in cancel_body
    and "stopDigitalHumanSystemSpeechFallback()" in cancel_body
    and "digitalHumanAvatarView.clearSpeechAudio()" in cancel_body,
    "helper should stop old timers, audio, fallback speech, and avatar mouth envelope",
)
require(
    "wasRealtimeDialogPaused" in cancel_body
    and "isRealtimeDialogPausedForDigitalHumanPlayback = wasRealtimeDialogPaused" in cancel_body,
    "helper should preserve realtime pause state so finish handling remains consistent",
)
require(
    "DigitalHumanPlaybackInterruptVerify/main.py" in phase1,
    "phase1 verification should include digital-human playback interruption coverage",
)

print("DigitalHumanPlaybackInterrupt verification passed")
