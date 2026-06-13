#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
facade = (root / "DreamJourney/Sources/Services/Stage1MemoryFacade.swift").read_text()
view = (root / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift").read_text()
phase1 = (root / "Scripts/verify_phase1.sh").read_text()

save_voice = re.search(
    r"private func savePickedVoiceSample\([\s\S]*?\n    \}",
    view,
)
save_voice_body = save_voice.group(0) if save_voice else ""

checks = [
    (
        "Stage1 facade should expose archive voice metadata ingestion",
        "func ingestArchiveVoiceSampleMetadata" in facade,
    ),
    (
        "voice sample save flow should call archive voice metadata ingestion",
        "Stage1MemoryFacade.shared.ingestArchiveVoiceSampleMetadata" in save_voice_body,
    ),
    (
        "voice sample save flow should not rely on recordUserTurn for KBLite deposit",
        "Stage1MemoryFacade.shared.recordUserTurn" not in save_voice_body,
    ),
    (
        "archive voice ingestion should pass concrete archive item id",
        "archiveItemID: item.id" in save_voice_body,
    ),
    (
        "archive text ingestion should pass concrete archive item id",
        "ingestArchiveTextMaterial" in view and "archiveItemID: item.id" in view and "archiveTitle: item.title" in view,
    ),
    (
        "archive image analysis ingestion should pass concrete archive item id",
        "ingestImageAnalysis" in view and "archiveItemID: item.id" in view and "capturedAt: item.createdAt" in view,
    ),
    (
        "Stage1 facade should build memoryArchiveItem source refs",
        "archiveSourceRef" in facade and "kind: .memoryArchiveItem" in facade,
    ),
    (
        "phase1 verification should cover archive voice metadata KBLite ingestion",
        "KBLiteArchiveVoiceVerify" in phase1 and "KBLiteSourceRefPropagationVerify" in phase1 and "MemoryArchiveVoiceKnowledgeVerify" in phase1,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"MemoryArchiveVoiceKnowledge verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("MemoryArchiveVoiceKnowledge verification passed")
