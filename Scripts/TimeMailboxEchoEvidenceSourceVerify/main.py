#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"TimeMailboxEchoEvidenceSource verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

make_evidence = re.search(
    r"private static func makeEchoEvidence\(for letter: TimeMailboxLetter\) -> TimeMailboxEchoEvidence \{(?P<body>[\s\S]*?)\n    \}",
    view,
)
body = make_evidence.group("body") if make_evidence else ""

require("private static func isEligibleEchoEvidence" in view, "time mailbox should define an echo evidence source filter")
require(".timeMailboxLetter" in view, "source filter should explicitly mention timeMailboxLetter")
require("!metadata.sourceRefs.contains" in view, "source filter should exclude specific source refs")
require("isEligibleEchoEvidence" in body, "makeEchoEvidence should apply the source filter before matching terms")
require(
    "TimeMailboxEchoEvidenceSourceVerify/main.py" in phase1,
    "phase1 verification should include time mailbox echo source filtering coverage",
)

print("TimeMailboxEchoEvidenceSource verification passed")
