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
    "knowledgeCoreCard" in view
    and "knowledgeCoreCountsLabel" in view
    and "knowledgeCoreDetailLabel" in view
    and "updateKnowledgeCoreCard()" in view,
    "archive screen should expose an always-visible structured knowledge core card",
)
require(
    "KBLiteManager.shared.displayGraphForLocalBrowsing()" in view
    and "KBLiteDepositStatusBuilder.build" in view
    and "sourceSummary" in view
    and "privacySummary" in view
    and "最近更新" in view,
    "knowledge core card should summarize visible KBLite counts, source, privacy, and freshness",
)
require(
    "archiveKnowledgeStatusText" in view
    and "detailLabel.text = [item.displayDetail, item.archiveKnowledgeStatusText]" in view
    and "来源：档案素材" in view
    and "权限：" in view,
    "archive material rows should show whether the item is entering the knowledge base and under which authorization",
)
require(
    "MemoryArchiveBuildReadiness.build" in view
    and "readiness.titleText" in view
    and "readiness.detailText" in view
    and "建库核心 ·" in view,
    "knowledge core card should show phase-one build readiness and missing material guidance",
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
    "ingestArchiveTextMaterialDetailed" in save_text_body,
    "text material ingestion should use the detailed KBLite extraction result",
)
require(
    "archiveTextDepositStatusMessage" in view
    and "暂无可抽取的新知识" in view
    and "远端 AI 抽取暂未完成" in view
    and "AI 暂无新增线索" in view,
    "text material deposit status should distinguish local fallback, empty AI extraction, and zero-new results",
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
    "照片分析失败，素材已保存" in analyze_photo_body,
    "photo analysis failure should surface a persistent diagnostic deposit status",
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
