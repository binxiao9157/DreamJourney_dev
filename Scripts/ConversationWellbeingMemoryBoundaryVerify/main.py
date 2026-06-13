#!/usr/bin/env python3
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[2]
source = root / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
text = source.read_text(encoding="utf-8")

checks = [
    (
        "case wellbeingNotice(text: String, timestamp: Date = Date())",
        "wellbeing notices should have a non-memory TGMessage case",
    ),
    (
        "messages.append(.wellbeingNotice(text: message, timestamp: Date()))",
        "wellbeing notices should not be appended as normal AI turns",
    ),
    (
        "sessionMessages.filter { !$0.isWellbeingNotice }",
        "memoir generation should exclude wellbeing notices from session content",
    ),
    (
        "var isWellbeingNotice: Bool",
        "TGMessage should expose a boundary flag for archive filtering",
    ),
]

missing = [message for needle, message in checks if needle not in text]
if missing:
    for message in missing:
        print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)

print("Conversation wellbeing memory-boundary verification passed")
