#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchivePrivacyDepositUX verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

composer_match = re.search(
    r"private final class MemoryArchiveTextComposerViewController[\s\S]*?\nprivate extension MemoryArchiveItemKind",
    view,
)
composer = composer_match.group(0) if composer_match else ""

require(
    "control.selectedSegmentIndex = 2" in composer,
    "text material composer should default to 可生成 so phase-1 archive tests build knowledge by default",
)
require(
    "privacyHintLabel" in composer,
    "text material composer should explain what the selected privacy scope will do",
)
for fragment in [
    "私密：只存档案馆，不进入知识库",
    "本机：进入本机知识库，不上传远端抽取",
    "可生成：进入知识库，并允许 AI 抽取补充线索",
    "亲友：进入知识库，并按亲友范围同步",
]:
    require(fragment in composer, f"composer privacy hint should include {fragment!r}")
require(
    "updatePrivacyHint()" in composer and "privacyChanged()" in composer,
    "privacy hint should refresh when the user changes scope",
)
require(
    "MemoryArchivePrivacyDepositUXVerify/main.py" in phase1,
    "phase1 verification should include archive privacy deposit UX coverage",
)

print("MemoryArchivePrivacyDepositUX verification passed")
