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
        "final class KBDetailCell" in source
        and "super.init(style: .subtitle" in source
        and "detailTextLabel?.numberOfLines = 0" in source,
        "knowledge list should use subtitle cells so extracted source context is visible before drilling into details",
    ),
    (
        source.count("KBEntityDetailFormatter.listAuditSummary(") >= 4
        and "来源：" in source
        and "权限：" in source,
        "knowledge list rows should show source and authorization summaries without requiring a detail drill-in",
    ),
    (
        "conversationTurnCount" in source
        and "memoryArchiveItemCount" in source
        and "timeMailboxLetterCount" in source,
        "knowledge list audit summary should count real source refs by kind",
    ),
    (
        not any(icon in source for icon in ["🧠", "📍", "🗓", "📝"]),
        "knowledge stats and rows should not use decorative emoji icons",
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
