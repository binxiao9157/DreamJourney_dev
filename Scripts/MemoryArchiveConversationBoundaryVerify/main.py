#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
FACADE = ROOT / "DreamJourney/Sources/Services/Stage1MemoryFacade.swift"
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchiveConversationBoundary verification failed: {message}", file=sys.stderr)
        sys.exit(1)


facade = FACADE.read_text(encoding="utf-8")
view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

text_ingest = re.search(
    r"func ingestArchiveTextMaterial\([\s\S]*?\n    func ingestArchiveVoiceSampleMetadata",
    facade,
)
photo_analysis = re.search(
    r"private func analyzePhoto\([\s\S]*?\n    private func analyzePhotoViaBackendOrDirect",
    view,
)

text_ingest_body = text_ingest.group(0) if text_ingest else ""
photo_analysis_body = photo_analysis.group(0) if photo_analysis else ""

require(text_ingest_body, "Stage1 archive text ingestion body should be found")
require(photo_analysis_body, "archive photo analysis body should be found")
require(
    "recordUserTurn(" not in text_ingest_body
    and "conversationMemory.recordUserTurn" not in text_ingest_body,
    "archive text material should deposit directly to KBLite, not conversation transcript",
)
require(
    "Stage1MemoryFacade.shared.recordUserTurn" not in photo_analysis_body,
    "archive photo analysis should not synthesize a user dialog turn",
)
require(
    "MemoryArchiveConversationBoundaryVerify" in phase1,
    "phase1 verification should cover archive/conversation boundary",
)

print("MemoryArchiveConversationBoundary verification passed")
