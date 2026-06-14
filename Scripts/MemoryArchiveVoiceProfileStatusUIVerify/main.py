#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"

view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

missing = []

required_fragments = [
    ("voiceProfileStatusLabel", "archive screen should expose a persistent voice profile status label"),
    ("updateVoiceProfileStatusLabel()", "archive screen should refresh voice profile status on reload"),
    ("MemoryArchiveVoiceProfileStore.shared.profiles()", "voice profile status should read stored profiles"),
    ("声纹档案：暂无人物声纹", "empty voice profile status should be user-facing"),
    ("待补", "voice profile status should show collecting count"),
    ("可训练", "voice profile status should show ready-for-training count"),
    ("训练中", "voice profile status should show training count"),
    ("已就绪", "voice profile status should show ready count"),
    ("MemoryArchiveVoiceProfileStatusUIVerify/main.py", "phase1 verification should include voice profile status UI coverage"),
]

for fragment, message in required_fragments:
    haystack = phase1 if fragment.endswith("main.py") else view
    if fragment not in haystack:
        missing.append(message)

reload_match = re.search(r"private func reloadData\(\) \{(?P<body>[\s\S]*?)\n    \}", view)
if not reload_match or "updateVoiceProfileStatusLabel()" not in reload_match.group("body"):
    missing.append("reloadData should refresh the voice profile status line")

handle_start = view.find("private func handleVoiceProfileStatus")
handle_end = view.find("private func voiceSampleURLs", handle_start)
handle_body = view[handle_start:handle_end] if handle_start != -1 and handle_end != -1 else ""
if not handle_body:
    missing.append("voice profile status handling should be implemented in a focused helper")
elif "localizedDescription" in handle_body:
    missing.append("voice profile training failure UI should not expose raw localizedDescription")
if "voiceProfileTrainingFailureStatusMessage()" not in handle_body:
    missing.append("voice profile training failure UI should use a fixed friendly status message")

layout_match = re.search(r"\[(?P<body>.*?)\]\.forEach", view, re.S)
if not layout_match:
    missing.append("archive layout should declare status label order")
else:
    layout_body = layout_match.group("body")
    knowledge_index = layout_body.find("knowledgeDepositStatusLabel")
    voice_index = layout_body.find("voiceProfileStatusLabel")
    backend_index = layout_body.find("backendSyncStatusLabel")
    if not (knowledge_index != -1 and voice_index != -1 and backend_index != -1 and knowledge_index < voice_index < backend_index):
        missing.append("voice profile status should sit after knowledge deposit status and before backend sync")

if missing:
    for message in missing:
        print(f"MemoryArchiveVoiceProfileStatusUI verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("MemoryArchiveVoiceProfileStatusUI verification passed")
