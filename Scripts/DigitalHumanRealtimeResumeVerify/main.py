#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"

text = SOURCE.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DigitalHumanRealtimeResume verification failed: {message}", file=sys.stderr)
        sys.exit(1)


require(
    "private var shouldResumeRealtimeDialogAfterDigitalHumanPlayback = false" in text,
    "controller should track internal native-audio pauses that must resume realtime listening",
)
require(
    "private func resumeRealtimeDialogAfterDigitalHumanPlayback()" in text,
    "controller should have an explicit resume path after native avatar audio",
)

pause = re.search(
    r"private func pauseRealtimeDialogForDigitalHumanPlayback\(requestID: Int\) \{(?P<body>.*?)\n    \}",
    text,
    re.S,
)
require(pause is not None, "pauseRealtimeDialogForDigitalHumanPlayback should exist")
pause_body = pause.group("body")
require(
    "shouldResumeRealtimeDialogAfterDigitalHumanPlayback = true" in pause_body,
    "internal playback pause should mark that realtime listening must resume",
)
require(
    "realtime_dialog_suspending" in pause_body,
    "internal playback pause should log suspension rather than a user-visible manual end",
)

ended = re.search(
    r"func onDialogEnded\(reason: DialogEndReason\) \{(?P<body>.*?)\n    \}",
    text,
    re.S,
)
require(ended is not None, "onDialogEnded should exist")
ended_body = ended.group("body")
require(
    "shouldResumeRealtimeDialogAfterDigitalHumanPlayback" in ended_body
    and "dialog_end_deferred_for_realtime_resume" in ended_body,
    "manual SDK end caused by native-audio suspension should be consumed for later resume, not finalized",
)

finish = re.search(
    r"private func finishDigitalHumanSpeechPlayback\(source: String\) \{(?P<body>.*?)\n    \}",
    text,
    re.S,
)
require(finish is not None, "finishDigitalHumanSpeechPlayback should exist")
finish_body = finish.group("body")
require(
    "resumeRealtimeDialogAfterDigitalHumanPlayback()" in finish_body,
    "avatar audio completion should restart realtime dialog listening when it was internally suspended",
)
require(
    "playback_finished_realtime_resuming" in finish_body,
    "resume path should leave true-device evidence",
)
require(
    "DigitalHumanRealtimeResumeVerify/main.py" in phase1,
    "phase1 verification should include realtime resume coverage",
)

print("DigitalHumanRealtimeResume verification passed")
