#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
source = root / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
text = source.read_text(encoding="utf-8")

checks = [
    (
        "private let conversationWellbeingLimiter = ConversationWellbeingLimiter()",
        "AIRecordingViewController should own a ConversationWellbeingLimiter",
    ),
    (
        "handleConversationWellbeingBeforeRecording()",
        "startRecording should check wellbeing limits before requesting microphone permission",
    ),
    (
        "conversationWellbeingLimiter.recordFinalUserTurn(text)",
        "final ASR results should count user turns",
    ),
    (
        "presentConversationWellbeingDecisionIfNeeded(afterAssistantPlayback: true)",
        "AI playback completion should nudge only after assistant output finishes",
    ),
    (
        "conversationWellbeingLimiter.markNudgeShown()",
        "soft nudge should be marked to avoid repeated interruptions",
    ),
    (
        "dialogEngine.stopDialog(reason: .manual)",
        "hard limit should close the active dialog cleanly",
    ),
]

missing = [message for needle, message in checks if needle not in text]

if missing:
    for message in missing:
        print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)

print("Conversation wellbeing UI integration verification passed")
