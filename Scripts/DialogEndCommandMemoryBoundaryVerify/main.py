#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
HOME = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
MODELS = ROOT / "DreamJourney/Sources/Services/DialogEngineModels.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DialogEndCommandMemoryBoundary verification failed: {message}", file=sys.stderr)
        sys.exit(1)


home = HOME.read_text(encoding="utf-8")
models = MODELS.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

require(
    "shouldRecordAsMemoryTurn" in models,
    "DialogEndIntentPolicy should expose a memory-turn boundary policy",
)
require(
    "matchedEndKeyword" in models,
    "DialogEndIntentPolicy should expose shared end-keyword matching for UI and SDK fallback paths",
)

on_asr = re.search(
    r"func onASRResult\(text: String, isFinal: Bool\) \{(?P<body>.*?)\n    \}",
    home,
    re.S,
)
require(on_asr is not None, "AIRecordingViewController.onASRResult should exist")
on_asr_body = on_asr.group("body")
record_policy_index = on_asr_body.find("DialogEndIntentPolicy.shouldRecordAsMemoryTurn(text)")
append_index = on_asr_body.find("messages.append(.user")
record_index = on_asr_body.find("recordUserSpeechTurn(text")
require(record_policy_index >= 0, "ASR final handling should check shouldRecordAsMemoryTurn")
require(
    "if let keyword = DialogEndIntentPolicy.matchedEndKeyword(in: text)" in on_asr_body,
    "ASR final handling should detect standalone end commands at the page layer",
)
require(
    "dialogEngine.stopDialog(reason: .keyword(keyword))" in on_asr_body,
    "ASR final end-command handling should actively stop the dialog so session deposit runs even if the SDK omits onDialogEnded",
)
require(
    append_index >= 0 and record_policy_index < append_index,
    "ASR final should suppress end commands before appending a user bubble",
)
require(
    record_index >= 0 and record_policy_index < record_index,
    "ASR final should suppress end commands before recording memory",
)

flush_body = re.search(
    r"private func flushPendingUserText\(\) \{(?P<body>.*?)\n    \}",
    home,
    re.S,
)
require(flush_body is not None, "flushPendingUserText should exist")
require(
    "DialogEndIntentPolicy.shouldRecordAsMemoryTurn(text)" in flush_body.group("body"),
    "pending ASR text should use the same memory-turn boundary before flush",
)

record_body = re.search(
    r"private func recordUserSpeechTurn\(_ text: String, speechSignal: UserSpeechTurnSignal\?\) \{(?P<body>.*?)\n    \}",
    home,
    re.S,
)
require(record_body is not None, "recordUserSpeechTurn should exist")
require(
    "DialogEndIntentPolicy.shouldRecordAsMemoryTurn(text)" in record_body.group("body"),
    "recordUserSpeechTurn should defend against direct command-only memory recording",
)

require(
    "DialogEndCommandMemoryBoundaryVerify/main.py" in phase1,
    "phase1 verification should include end-command memory boundary coverage",
)

print("DialogEndCommandMemoryBoundary verification passed")
