#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchiveScreenshotOCR verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

ocr_match = re.search(r"private func extractScreenshotTextForKnowledge\([\s\S]*?\n    \}", view)
ocr_body = ocr_match.group(0) if ocr_match else ""
save_match = re.search(r"private func savePickedImageMaterial\([\s\S]*?\n    \}", view)
save_body = save_match.group(0) if save_match else ""

require("import Vision" in view, "screenshot OCR should use Apple's local Vision framework")
require("extractScreenshotTextForKnowledge" in view, "archive screen should have a dedicated screenshot OCR path")
require("guard item.kind == .screenshot" in ocr_body, "OCR should only run for screenshot materials")
require("item.privacyMetadata.scope != .privateOnly" in ocr_body, "private screenshots should not enter KBLite")
require("VNRecognizeTextRequest" in ocr_body, "OCR should use Vision text recognition")
require("VNImageRequestHandler" in ocr_body, "OCR should perform a Vision image request")
require(".accurate" in ocr_body and "usesLanguageCorrection = true" in ocr_body, "OCR should prefer accurate recognition with language correction")
require('"zh-Hans"' in ocr_body and '"zh-Hant"' in ocr_body and '"en-US"' in ocr_body, "OCR should support common Chinese and English screenshot text")
require("ingestArchiveTextMaterialDetailed" in ocr_body, "recognized screenshot text should enter the archive text material pipeline")
require('archiveMaterialKind: "截图文字"' in ocr_body, "screenshot OCR should be labeled as screenshot text in KBLite")
require("archiveTextDepositStatusMessage" in ocr_body, "OCR deposit should reuse the archive text deposit status formatter")
require("extractScreenshotTextForKnowledge(from: image, item: item)" in save_body, "saving a screenshot should trigger OCR after archive insertion")
require("MemoryArchiveScreenshotOCRVerify/main.py" in phase1, "phase1 verification should include screenshot OCR coverage")

print("MemoryArchiveScreenshotOCR verification passed")
