#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"

source = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

forbidden_copy = [
    "例如：林桂芳",
    "例如：1978 年在西湖边开过小照相馆",
]

failures = []
for token in forbidden_copy:
    if token in source:
        failures.append(f"memory archive input copy should not contain concrete sample: {token}")

required_neutral_copy = [
    "请输入具体姓名",
    "填写真实转写或摘要",
]
for token in required_neutral_copy:
    if token not in source:
        failures.append(f"memory archive input copy should keep neutral real-data guidance: {token}")

if "MemoryArchiveRealInputCopyVerify/main.py" not in phase1:
    failures.append("phase1 verification should include MemoryArchiveRealInputCopyVerify/main.py")

if failures:
    for failure in failures:
        print(f"MemoryArchiveRealInputCopy verification failed: {failure}", file=sys.stderr)
    sys.exit(1)

print("MemoryArchiveRealInputCopy verification passed")
