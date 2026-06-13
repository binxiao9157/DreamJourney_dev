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
        print(f"MemoryArchiveMetadataOnlyDeposit verification failed: {message}", file=sys.stderr)
        sys.exit(1)


facade = FACADE.read_text(encoding="utf-8")
view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

result_model = re.search(r"struct Stage1ArchiveTextDepositResult \{[\s\S]*?\n\}", facade)
result_body = result_model.group(0) if result_model else ""
save_text = re.search(r"private func saveTextDraft\([\s\S]*?\n    private func archiveTextDepositStatusMessage", view)
save_text_body = save_text.group(0) if save_text else ""
screenshot_ocr = re.search(r"Stage1MemoryFacade\.shared\.ingestArchiveTextMaterialDetailed\([\s\S]*?self\.reloadData\(\)\n                    \}\n                \}", view)
screenshot_ocr_body = screenshot_ocr.group(0) if screenshot_ocr else ""
status_message = re.search(r"private func archiveTextDepositStatusMessage\([\s\S]*?\n    private func saveArchiveImage", view)
status_message_body = status_message.group(0) if status_message else ""

require("var knowledgeAddedCount" in result_body, "archive text result should expose structured knowledge count separately")
require("var storedAddedCount" in result_body, "archive text result should keep total stored count for source traceability")
require(
    "completion(result.knowledgeAddedCount)" in facade,
    "legacy archive text completion should report structured knowledge additions, not archive metadata additions",
)
require(
    "if result.knowledgeAddedCount > 0" in save_text_body
    and "知识库已更新 \\(result.knowledgeAddedCount) 条" in save_text_body,
    "text material toast should only claim knowledge updates when structured knowledge changed",
)
require(
    "if result.knowledgeAddedCount > 0" in screenshot_ocr_body
    and "截图文字已整理到知识库 \\(result.knowledgeAddedCount) 条" in screenshot_ocr_body,
    "screenshot OCR toast should only claim knowledge updates when structured knowledge changed",
)
require(
    "素材已归档为可追溯来源，暂无结构化知识" in status_message_body,
    "metadata-only archive deposits should be described as archived source material, not completed knowledge building",
)
require(
    "已保存档案元信息" not in status_message_body,
    "archive metadata count should not be surfaced as a knowledge-building success",
)
require(
    "MemoryArchiveMetadataOnlyDepositVerify/main.py" in phase1,
    "phase1 verification should include metadata-only archive deposit coverage",
)

print("MemoryArchiveMetadataOnlyDeposit verification passed")
