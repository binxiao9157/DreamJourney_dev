#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HOME = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"CareDashboardSpeechSignal verification failed: {message}", file=sys.stderr)
        sys.exit(1)


home = HOME.read_text()
phase1 = PHASE1.read_text()

require("private struct UserSpeechTurnSignal" in home, "missing user speech signal value type")
require("private final class UserSpeechSignalTracker" in home, "missing ASR speech signal tracker")
require("pauseThresholdSeconds" in home and "minimumTrackedDurationSeconds" in home, "tracker thresholds are not explicit")
require("observeASRUpdate(text: String, isFinal: Bool" in home, "ASR updates are not observed")
require("finalizePending" in home, "pending ASR text is not finalized")
require("private let userSpeechSignalTracker = UserSpeechSignalTracker()" in home, "home controller does not own tracker")
require(
    "let speechSignal = userSpeechSignalTracker.observeASRUpdate(text: text, isFinal: isFinal)" in home,
    "onASRResult does not collect speech signal",
)
require(
    "recordUserSpeechTurn(text, speechSignal: speechSignal)" in home,
    "final ASR user turn is not recorded with speech signal",
)
require(
    "let speechSignal = userSpeechSignalTracker.finalizePending()" in home,
    "pending ASR user turn is not recorded with finalized signal",
)
require("speechDurationSeconds: speechSignal?.durationSeconds" in home, "speech duration is not passed to memory")
require("pauseCount: speechSignal?.pauseCount" in home, "pause count is not passed to memory")
require(
    home.count("userSpeechSignalTracker.reset()") >= 5,
    "tracker is not reset across start/end/error/safety paths",
)
require(
    "CareDashboardSpeechSignalVerify/main.py" in phase1,
    "phase1 verification does not include speech signal check",
)

print("CareDashboardSpeechSignal verification passed")
