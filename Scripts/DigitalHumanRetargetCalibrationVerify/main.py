#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
mini_live = ROOT / "DreamJourney/Resources/web/MiniLive2.js"
home = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
phase1 = ROOT / "Scripts/verify_phase1.sh"

mini_live_text = mini_live.read_text(encoding="utf-8")
home_text = home.read_text(encoding="utf-8")
phase1_text = phase1.read_text(encoding="utf-8")

checks = [
    (
        "retarget calibration mode should be configured separately from risky overlay rendering",
        "faceRetargetMode" in mini_live_text
        and "CONFIG.faceRetargetMode = 'calibration'" in home_text,
    ),
    (
        "native startup should enable DHLive retarget data path for the calibration PoC",
        "CONFIG.faceRetargetEnabled = true" in home_text,
    ),
    (
        "MiniLive should expose a runtime retarget mode switch for true-device calibration",
        "setRetargetMode: function(mode)" in mini_live_text,
    ),
    (
        "retarget calibration should report blendshape and rect metrics without drawing black mouth patches",
        "avatar_retarget_calibration" in mini_live_text
        and "shouldDrawRetargetOverlay" in mini_live_text
        and "retarget_overlay_suppressed" in mini_live_text,
    ),
    (
        "chroma key transparency should be measured for the transparent floating-avatar PoC",
        "avatar_chroma_key_stats" in mini_live_text
        and "sampleCanvasAlphaStats" in mini_live_text,
    ),
    (
        "phase1 verification should include the DHLive retarget calibration PoC check",
        "DigitalHumanRetargetCalibrationVerify/main.py" in phase1_text,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"DigitalHumanRetargetCalibration verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("DigitalHumanRetargetCalibration verification passed")
