#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"TimeMailboxDeliveryDelay verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

composer_match = re.search(
    r"private final class TimeMailboxComposerViewController[\s\S]*?\nprivate final class TimeMailboxCell",
    view,
)
composer = composer_match.group(0) if composer_match else ""
seal_match = re.search(r"@objc private func sealTapped\(\) \{([\s\S]*?)\n    \}", composer)
seal_body = seal_match.group(1) if seal_match else ""

require(composer, "composer view controller block should be readable")
require("立即" not in composer, "time mailbox must not offer immediate delivery")
require(
    'UISegmentedControl(items: ["5 分钟", "明日", "一周"])' in composer,
    "delivery choices should start at 5 minutes and avoid instant-chat framing",
)
require(
    re.search(r"deliverAt\s*=\s*Date\(\)(?!\.)", seal_body) is None,
    "seal flow must not create immediately due letters",
)
require(
    "TimeMailboxRepository.defaultMinimumDeliveryDelay" in composer
    and "Date().addingTimeInterval(Self.shortestDeliveryDelay)" in seal_body,
    "shortest real-device path should use the production five-minute delivery delay",
)
require(
    "TimeMailboxDeliveryDelayVerify/main.py" in phase1,
    "phase1 verification should include time mailbox delayed delivery coverage",
)

print("TimeMailboxDeliveryDelay verification passed")
