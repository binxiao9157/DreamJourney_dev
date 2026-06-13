#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys


DEFAULT_EVIDENCE_DIR = Path("artifacts/real_device")
TEXT_SUFFIXES = {
    ".txt",
    ".log",
    ".json",
    ".plist",
    ".md",
    ".yaml",
    ".yml",
    ".env",
    ".out",
}

FORBIDDEN_TOKENS = [
    "--seed-roadshow-demo",
    "--roadshow-offline-mode",
    "DREAMJOURNEY_SEED",
    "dreamjourney.roadshow.",
    "RoadshowDemoSeed",
    "RoadshowDemoSeeder",
    "MOCK_DIALOG",
    "mock dialog engine",
    "mock safety guard",
    "roadshow demo",
    "fm_daughter_chen_lan",
    "fm_son_chen_hao",
    "fm_granddaughter_chen_yu",
    "陈岚",
    "陈浩",
    "陈予",
    "外滩老照片",
    "roadshow_demo_photo_placeholder",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Verify real-device acceptance evidence is not polluted by roadshow/demo state."
    )
    parser.add_argument(
        "evidence_dir",
        nargs="?",
        default=str(DEFAULT_EVIDENCE_DIR),
        help="Directory containing real-device logs/preferences/diagnostics. Defaults to artifacts/real_device.",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if the evidence directory is missing or has no text files.",
    )
    return parser.parse_args()


def iter_text_files(root: Path) -> list[Path]:
    if root.is_file():
        return [root] if root.suffix.lower() in TEXT_SUFFIXES else []
    if not root.exists():
        return []
    return [
        path
        for path in sorted(root.rglob("*"))
        if path.is_file() and path.suffix.lower() in TEXT_SUFFIXES
    ]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except OSError as error:
        raise RuntimeError(f"cannot read {path}: {error}") from error


def scan(files: list[Path]) -> list[str]:
    findings: list[str] = []
    lowered_tokens = [(token, token.lower()) for token in FORBIDDEN_TOKENS]
    for path in files:
        text = read_text(path)
        lower = text.lower()
        for original, token in lowered_tokens:
            if token in lower:
                findings.append(f"{path}: contains forbidden demo marker {original!r}")
    return findings


def main() -> int:
    args = parse_args()
    evidence_dir = Path(args.evidence_dir)
    files = iter_text_files(evidence_dir)

    if not evidence_dir.exists():
        message = f"RealDeviceNoDemoState verification skipped: {evidence_dir} does not exist"
        if args.strict:
            print(message, file=sys.stderr)
            return 1
        print(message)
        return 0

    if not files:
        message = f"RealDeviceNoDemoState verification skipped: no text evidence files under {evidence_dir}"
        if args.strict:
            print(message, file=sys.stderr)
            return 1
        print(message)
        return 0

    findings = scan(files)
    if findings:
        for finding in findings:
            print(f"RealDeviceNoDemoState verification failed: {finding}", file=sys.stderr)
        return 1

    print(f"RealDeviceNoDemoState verification passed: scanned {len(files)} evidence files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
