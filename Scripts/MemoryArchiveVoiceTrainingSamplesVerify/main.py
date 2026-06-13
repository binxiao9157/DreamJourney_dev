#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
STORE = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveVoiceProfileStore.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchiveVoiceTrainingSamples verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
store = STORE.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

require("func trainVoice(\n        audioURLs: [URL]," in store, "voice training client should accept all collected sample URLs")
require("func startTraining(\n        profileID: String,\n        sampleURLs: [URL]," in store, "voice profile store should start training with a sample URL batch")
require("guard sampleURLs.count >= profile.requiredSampleCount" in store, "training should require the configured minimum sample count")
require("trainer.trainVoice(audioURLs: sampleURLs" in store, "profile training should pass the full sample URL batch to the trainer")
require("AVMutableComposition" in store and "AVAssetExportSession" in store, "production trainer should merge multiple samples before calling single-file voice clone API")
require("voiceSampleURLs(for: profile, latestSamplePath: latestSamplePath)" in view, "memory archive UI should resolve all stored sample paths for the profile")
require("sampleURLs:" in view and "latestSamplePath" in view, "memory archive UI should not train only the latest file")
require("MemoryArchiveVoiceTrainingSamplesVerify/main.py" in phase1, "phase1 verification should include voice sample batch coverage")

print("MemoryArchiveVoiceTrainingSamples verification passed")
