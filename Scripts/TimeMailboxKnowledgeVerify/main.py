#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
facade = (root / "DreamJourney/Sources/Services/Stage1MemoryFacade.swift").read_text()
view = (root / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift").read_text()
phase1 = (root / "Scripts/verify_phase1.sh").read_text()

seal = re.search(r"private func sealLetter\(_ draft: TimeMailboxDraft\) \{([\s\S]*?)\n    \}", view)
seal_body = seal.group(1) if seal else ""

checks = [
    (
        "Stage1 facade should expose time mailbox metadata ingestion",
        "func ingestTimeMailboxLetterMetadata" in facade,
    ),
    (
        "sealed mailbox flow should ingest metadata into KBLite",
        "Stage1MemoryFacade.shared.ingestTimeMailboxLetterMetadata" in seal_body,
    ),
    (
        "sealed mailbox flow should pass saved letter, not draft body, into KBLite",
        "ingestTimeMailboxLetterMetadata(letter)" in seal_body and "draft.body" not in seal_body.split("ingestTimeMailboxLetterMetadata")[1],
    ),
    (
        "phase1 verification should cover time mailbox KBLite metadata ingestion",
        "KBLiteTimeMailboxVerify" in phase1 and "TimeMailboxKnowledgeVerify" in phase1,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"TimeMailboxKnowledge verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("TimeMailboxKnowledge verification passed")
