#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
MODELS = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveModels.swift"
REPO = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveRepository.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchiveScreenshotMaterial verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
models = MODELS.read_text(encoding="utf-8")
repo = REPO.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

save_image_match = re.search(r"private func savePickedImageMaterial\([\s\S]*?\n    \}", view)
save_image_body = save_image_match.group(0) if save_image_match else ""

require("case screenshot" in models, "archive model should have a first-class screenshot material kind")
require("let screenshotCount: Int" in models, "archive summary should count screenshots separately")
require("func addScreenshot(" in repo, "repository should expose explicit screenshot material insertion")
require('"聊天截图"' in repo and '"从相册加入的聊天记录或语音截图素材"' in repo, "screenshot defaults should not reuse old-photo copy")
require('case .screenshot: return "聊天截图"' in view, "screenshot kind should have its own display name")
require('case .screenshot: return "text.viewfinder"' in view, "screenshot kind should use a screenshot/chat icon")
require('screenshotButton = makeActionButton(title: "导入截图/聊天记录"' in view, "archive screen should expose screenshot/chat-record import")
require("@objc private func screenshotTapped()" in view, "screenshot button should have a dedicated action")
require("pendingImageMaterialKind = .screenshot" in view, "screenshot action should mark the next picker result as screenshot material")
require("photoButton, screenshotButton, voiceButton, textButton, knowledgeButton" in view, "screenshot button should be in the archive action stack")
require("savePickedImageMaterial" in view and "addScreenshot" in save_image_body, "image picker should save screenshot material through explicit repository path")
require('"截图素材"' in save_image_body and '"聊天记录"' in save_image_body, "screenshot save path should tag the material as screenshot/chat record")
require("MemoryArchiveScreenshotMaterialVerify/main.py" in phase1, "phase1 verification should include screenshot material coverage")

print("MemoryArchiveScreenshotMaterial verification passed")
