#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
home = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
mini_live = ROOT / "DreamJourney/Resources/web/MiniLive2.js"
phase1 = ROOT / "Scripts/verify_phase1.sh"

home_text = home.read_text(encoding="utf-8")
mini_live_text = mini_live.read_text(encoding="utf-8")
phase1_text = phase1.read_text(encoding="utf-8")

checks = [
    (
        "native playback should derive an audio energy envelope from the same WAV bytes",
        "DigitalHumanSpeechEnvelope.make(fromWAVData: wavData" in home_text,
    ),
    (
        "native playback should send the WAV bytes to the web avatar layer without double-playing audio",
        "bufferSpeechAudioBase64(base64Wav)" in home_text
        and "bufferAudioBase64ForLipSync" in home_text,
    ),
    (
        "avatar envelope playback should pass envelope samples to Web",
        "playSpeechEnvelope(duration: player.duration, prompt: text, envelope: envelope)" in home_text,
    ),
    (
        "web avatar runtime should expose a speech envelope argument",
        "playSpeechEnvelope: function(durationSeconds, energyEnvelope)" in home_text,
    ),
    (
        "MiniLive should modulate avatar video playback using audio energy",
        "avatarSpeechEnvelope" in mini_live_text
        and "updateAvatarSpeechEnvelope" in mini_live_text
        and "playForDuration: function(durationSeconds, energyEnvelope)" in mini_live_text,
    ),
    (
        "phase1 verification should include speech envelope checks",
        "DigitalHumanSpeechEnvelopeVerify/main.swift" in phase1_text
        and "DigitalHumanSpeechEnvelopeIntegrationVerify/main.py" in phase1_text,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"DigitalHumanSpeechEnvelopeIntegration verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("DigitalHumanSpeechEnvelopeIntegration verification passed")
