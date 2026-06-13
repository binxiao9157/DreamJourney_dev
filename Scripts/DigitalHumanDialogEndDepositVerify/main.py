#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
VERIFY = ROOT / "Scripts/verify_phase1.sh"

text = SOURCE.read_text(encoding="utf-8")
phase1 = VERIFY.read_text(encoding="utf-8")

checks = [
    (
        "private var pendingDialogEndReasonAfterDigitalHumanPlayback: DialogEndReason?",
        "digital-human playback should remember a dialog-end reason instead of dropping it",
    ),
    (
        "private var hasFinalizedCurrentDialogSession = false",
        "dialog finalization should be guarded against duplicate SDK callbacks",
    ),
    (
        "pendingDialogEndReasonAfterDigitalHumanPlayback = nil",
        "new dialog/reset paths should clear deferred dialog-end state",
    ),
    (
        "hasFinalizedCurrentDialogSession = false",
        "new dialogs should reset the finalization guard",
    ),
    (
        "pendingDialogEndReasonAfterDigitalHumanPlayback = reason",
        "onDialogEnded should defer SDK end events while native avatar audio is speaking",
    ),
    (
        "finalizeDialogEnd(reason:",
        "deferred dialog-end events should be replayed through the same finalization path",
    ),
    (
        "Stage1MemoryFacade.shared.finishConversationSession()",
        "the finalization path must finish the conversation so KBLite extraction can run",
    ),
    (
        "DigitalHumanDialogEndDepositVerify/main.py",
        "phase1 verification should include the deferred dialog-end regression check",
    ),
]

missing = [message for needle, message in checks if needle not in (phase1 if needle.endswith("main.py") else text)]

finish_body = re.search(
    r"private func finishDigitalHumanSpeechPlayback\(source: String\) \{(?P<body>.*?)\n    \}",
    text,
    re.S,
)
if not finish_body:
    missing.append("finishDigitalHumanSpeechPlayback should exist")
else:
    body = finish_body.group("body")
    if "pendingDialogEndReasonAfterDigitalHumanPlayback" not in body:
        missing.append("avatar audio completion should consume a deferred dialog-end reason")
    if "finalizeDialogEnd(reason:" not in body:
        missing.append("avatar audio completion should finalize the deferred dialog-end")

on_ended = re.search(
    r"func onDialogEnded\(reason: DialogEndReason\) \{(?P<body>.*?)\n    \}",
    text,
    re.S,
)
if not on_ended:
    missing.append("onDialogEnded should exist")
else:
    body = on_ended.group("body")
    paused_branch = re.search(
        r"if isRealtimeDialogPausedForDigitalHumanPlayback \{(?P<branch>.*?)\n        \}",
        body,
        re.S,
    )
    if not paused_branch:
        missing.append("onDialogEnded should handle native-audio paused realtime dialogs")
    else:
        branch = paused_branch.group("branch")
        if "pendingDialogEndReasonAfterDigitalHumanPlayback = reason" not in branch:
            missing.append("paused onDialogEnded branch should store the reason for later finalization")
        if "dialog_end_deferred_for_native_audio" not in branch:
            missing.append("paused onDialogEnded branch should log deferred, not ignored, dialog-end events")
        if "return" not in branch:
            missing.append("paused onDialogEnded branch should return after deferring finalization")

if "dialog_end_ignored_for_native_audio" in text:
    missing.append("dialog-end during native audio should no longer be logged as ignored")

if missing:
    for message in missing:
        print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)

print("DigitalHuman dialog-end deposit verification passed")
