#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def fail(message: str) -> None:
    raise SystemExit(f"KnowledgeBaseSourcePrivacyUI verification failed: {message}")


source = SOURCE.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

checks = [
    (
        "KBEntityDetailFormatter" in source,
        "knowledge detail should use a dedicated formatter",
    ),
    (
        "privacyText(for metadata: MemoryPrivacyMetadata)" in source,
        "detail formatter should expose privacy text",
    ),
    (
        re.search(r"sourceRefsText\s*\(\s*for\s+metadata:\s*MemoryPrivacyMetadata", source) is not None,
        "detail formatter should expose source refs text",
    ),
    (
        "case .conversationTurn" in source
        and "case .memoryArchiveItem" in source
        and "case .timeMailboxLetter" in source,
        "source formatter should cover conversation, archive, and mailbox refs",
    ),
    (
        "隐私范围" in source and "来源素材" in source,
        "detail page should render privacy and source labels",
    ),
    (
        "case place(KBPlace)" in source and "case fact(KBFact)" in source,
        "detail entity enum should support place and fact details",
    ),
    (
        "KBEntityDetailViewController(entity: .place" in source
        and "KBEntityDetailViewController(entity: .fact" in source,
        "table selection should navigate to place and fact details",
    ),
    (
        "KnowledgeBaseSourcePrivacyUIVerify" in phase1,
        "phase1 verification should include source/privacy UI coverage",
    ),
]

for condition, message in checks:
    if not condition:
        fail(message)

print("KnowledgeBaseSourcePrivacyUI verification passed")
