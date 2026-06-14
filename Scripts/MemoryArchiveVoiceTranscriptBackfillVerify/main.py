#!/usr/bin/env python3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
REPOSITORY = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveRepository.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition, message):
    if not condition:
        print(f"MemoryArchiveVoiceTranscriptBackfill verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VC.read_text()
repository = REPOSITORY.read_text()
phase1 = PHASE1.read_text()

require(
    "补充语音转写" in view and "presentVoiceTranscriptBackfill(for: item)" in view,
    "voice archive item menu should expose a transcript backfill entry",
)
require(
    "private func presentVoiceTranscriptBackfill(for item: MemoryArchiveItem)" in view
    and "这段语音讲了什么" in view
    and "existingVoiceTranscriptText" in view,
    "voice transcript backfill should present an editable transcript dialog",
)
require(
    "func updateVoiceTranscript" in repository
    and "语音转写" in repository
    and "updatedAt = now" in repository,
    "repository should persist backfilled transcript and mark voice item updated",
)
require(
    "repository.updateVoiceTranscript" in view
    and "Stage1MemoryFacade.shared.ingestArchiveTextMaterialDetailed" in view
    and 'archiveMaterialKind: "语音转写"' in view
    and "archiveItemID: updatedItem.id" in view,
    "backfilled transcript should deposit into KBLite using the same archive item source ref",
)
require(
    "syncArchiveItemMetadataToBackend(updatedItem)" in view,
    "backfilled voice transcript should resync archive metadata to backend",
)
require(
    "结构化建库：私密语音转写仅保存到档案馆" in view,
    "private voice transcript should not be deposited into KBLite",
)
require(
    "MemoryArchiveVoiceTranscriptBackfillVerify/main.py" in phase1,
    "phase1 verification should include voice transcript backfill coverage",
)

print("MemoryArchiveVoiceTranscriptBackfill verification passed")
