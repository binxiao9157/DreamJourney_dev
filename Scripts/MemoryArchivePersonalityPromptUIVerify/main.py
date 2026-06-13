#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"MemoryArchivePersonalityPromptUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

composer_match = re.search(
    r"private final class MemoryArchiveTextComposerViewController[\s\S]*?\nprivate final class MemoryArchiveCell",
    view,
)
composer = composer_match.group(0) if composer_match else ""

require("添加文字/人格提示" in view, "archive action should expose personality prompt entry")
require('UISegmentedControl(items: ["回忆", "人格提示", "口头禅"])' in composer, "text composer should name personality prompt explicitly")
require('case .personalityNote: return "人格提示"' in view, "personality archive kind should display as personality prompt")
require(
    "MemoryArchivePersonalityPromptUIVerify/main.py" in phase1,
    "phase1 verification should include personality prompt UI coverage",
)

print("MemoryArchivePersonalityPromptUI verification passed")
