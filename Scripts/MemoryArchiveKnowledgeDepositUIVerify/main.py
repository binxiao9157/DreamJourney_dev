#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
KB_VIEW = ROOT / "DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchiveKnowledgeDepositUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
kb_view = KB_VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

save_text = re.search(r"private func saveTextDraft\([\s\S]*?\n    \}", view)
save_text_body = save_text.group(0) if save_text else ""
save_voice = re.search(r"private func savePickedVoiceSample\([\s\S]*?\n    \}", view)
save_voice_body = save_voice.group(0) if save_voice else ""
analyze_photo = re.search(r"private func analyzePhoto\([\s\S]*?\n    \}", view)
analyze_photo_body = analyze_photo.group(0) if analyze_photo else ""

require(
    "knowledgeDepositStatusLabel" in view,
    "archive screen should expose a persistent local knowledge deposit status label",
)
require(
    "updateKnowledgeDepositStatusLabel()" in view,
    "archive screen should refresh local knowledge deposit status on reload",
)
require(
    "结构化建库：私密素材仅存档案馆，不进入知识库" in save_text_body,
    "private text material should explain why it does not enter KBLite",
)
require(
    "addedCount == 0" in save_text_body and "暂无可抽取的新知识" in save_text_body,
    "text material with zero extracted entities should surface a non-silent result",
)
require(
    "ingestArchiveVoiceSampleMetadata" in save_voice_body and "addedCount" in save_voice_body,
    "voice sample metadata ingestion should report whether KBLite changed",
)
require(
    "照片分析已沉淀到知识库" in analyze_photo_body,
    "photo analysis success should surface KBLite deposit feedback",
)
require(
    "档案馆" in kb_view and "照片、语音或文字素材" in kb_view,
    "knowledge base empty state should direct users to archive material ingestion",
)
require(
    "MemoryArchiveKnowledgeDepositUIVerify" in phase1,
    "phase1 verification should include archive deposit UI coverage",
)

print("MemoryArchiveKnowledgeDepositUI verification passed")
