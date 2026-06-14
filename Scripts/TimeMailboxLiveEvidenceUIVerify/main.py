#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VC = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"TimeMailboxLiveEvidenceUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


vc = VC.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

setup_match = re.search(r"private func setupLayout\(\)[\s\S]*?\n    private func reloadLetters", vc)
setup_body = setup_match.group(0) if setup_match else ""

require("mailboxEvidenceStatusCard" in vc, "mailbox should render a persistent live evidence card")
require(
    "mailboxEvidenceStatusCard" in setup_body
    and setup_body.find("boundaryLabel") < setup_body.find("mailboxEvidenceStatusCard") < setup_body.find("tableView"),
    "live evidence card should sit between privacy boundary copy and the letter list",
)

required_status_fragments = [
    "真实验收状态",
    "本机信件 \\(letters.count) 封",
    "授权元数据 \\(syncableCount) 封",
    "本机私密 \\(localOnlyCount) 封",
    "完整正文和回声不出端",
    "服务器同步",
]
for fragment in required_status_fragments:
    require(fragment in vc, f"live evidence status missing {fragment!r}")

require(
    "private let backendSyncStatusLabel" not in vc,
    "mailbox backend status should not remain a weak standalone label property",
)
require(
    "TimeMailboxLiveEvidenceUIVerify/main.py" in phase1,
    "phase1 verification should include mailbox live evidence UI coverage",
)

print("TimeMailboxLiveEvidenceUI verification passed")
