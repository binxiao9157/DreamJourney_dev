#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DialogPhotoPlaceholderPrivacy verification failed: {message}", file=sys.stderr)
        sys.exit(1)


vc = VC.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

image_picker_match = re.search(
    r"func imagePickerController\(_ picker: UIImagePickerController,[\s\S]*?\n    func imagePickerControllerDidCancel",
    vc,
)
body = image_picker_match.group(0) if image_picker_match else ""

require(body, "AIRecordingViewController imagePickerController should exist")
require(
    "let photoMaterialMetadata = selectedDialogPrivacyMetadata" in body,
    "photo analysis should keep the user's selected authorization metadata",
)
require(
    "let conversationPlaceholderMetadata = MemoryPrivacyMetadata(" in body
    and "scope: .localOnly" in body
    and "createdBySurface: .conversation" in body,
    "photo placeholder and AI prompt should be recorded as local-only conversation metadata",
)

placeholder_start = body.find('Stage1MemoryFacade.shared.recordUserTurn(Stage1MailboxMemoryInput(')
placeholder_end = body.find('Stage1MemoryFacade.shared.recordAssistantTurn', placeholder_start)
assistant_end = body.find('// 【KBLite】异步分析图片', placeholder_end)
placeholder_block = body[placeholder_start:placeholder_end]
assistant_block = body[placeholder_end:assistant_end]

require(
    "privacyMetadata: conversationPlaceholderMetadata" in placeholder_block,
    "image placeholder user turn should not reuse family-circle/generation metadata",
)
require(
    "privacyMetadata: conversationPlaceholderMetadata" in assistant_block,
    "image guidance assistant turn should not reuse family-circle/generation metadata",
)
require(
    "PrivacyScopePolicy.canUse(metadata: photoMaterialMetadata, surface: .remoteExtraction)" in body
    and "privacyMetadata: photoMaterialMetadata" in body,
    "photo analysis should still honor selected metadata for authorized extraction",
)
require(
    "DialogPhotoPlaceholderPrivacyVerify/main.py" in phase1,
    "phase1 verification should include dialog photo placeholder privacy coverage",
)

print("DialogPhotoPlaceholderPrivacy verification passed")
