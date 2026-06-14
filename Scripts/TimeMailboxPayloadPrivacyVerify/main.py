#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
VIEW = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
BACKEND_PRIVACY = ROOT / "DreamJourneyBackend/app/services/privacy.py"
BACKEND_TESTS = ROOT / "DreamJourneyBackend/tests/test_core_services.py"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"TimeMailboxPayloadPrivacy verification failed: {message}", file=sys.stderr)
        sys.exit(1)


client = CLIENT.read_text(encoding="utf-8")
view = VIEW.read_text(encoding="utf-8")
privacy = BACKEND_PRIVACY.read_text(encoding="utf-8")
tests = BACKEND_TESTS.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

payload_match = re.search(r"private static func mailboxLetterPayload[\s\S]*?\n    \}", client)
payload_body = payload_match.group(0) if payload_match else ""
cell_config_match = re.search(r"func configure\(with letter: TimeMailboxLetter\)[\s\S]*?\n    \}", view)
cell_config = cell_config_match.group(0) if cell_config_match else ""
reader_match = re.search(r"private func presentReader\(for letter: TimeMailboxLetter\)[\s\S]*?\n    \}", view)
reader_body = reader_match.group(0) if reader_match else ""

require("mailboxLetterPayload" in payload_body, "client mailbox payload builder should exist")
require("removeValue(forKey: \"body\")" in payload_body, "client payload must remove full body")
require("removeValue(forKey: \"replyText\")" in payload_body, "client payload must remove echo text")
require(
    "bodyPreview" not in payload_body and "prefix(80)" not in payload_body,
    "client payload must not derive or send bodyPreview from full body",
)
require(
    "bodyPreview" not in client,
    "client response model should not keep bodyPreview as an accepted backend field",
)
require(
    "letter.body" not in cell_config and "replyText" not in cell_config,
    "mailbox list cells must not display letter body or echo text",
)
require(
    "正文仅本机保存" in cell_config or "完整正文不出端" in cell_config,
    "mailbox list should explain that full content remains local",
)
require(
    "收件人，如：妈妈" not in view and "收件人姓名，如：林桂芳" in view,
    "mailbox composer should guide real named recipients, not generic kinship placeholders",
)
require(
    "latest.body" in reader_body and "原信仅本机显示" in reader_body,
    "mailbox reader should show the original letter body only inside the local reader",
)
require(
    "回声边界" in reader_body and "latest.replyText" in reader_body,
    "mailbox reader should separate local original letter from bounded echo text",
)
require(
    '"bodyPreview"' not in privacy and "payload.get(\"body\")" not in privacy,
    "backend sanitizer must not allow or derive bodyPreview",
)
require(
    "MAILBOX_PRIVATE_BODY_SENTINEL" in tests and "ECHO_SENTINEL" in tests,
    "backend tests should use sentinels for body and echo privacy",
)
require(
    "assertNotIn(\"bodyPreview\"" in tests,
    "backend tests should assert bodyPreview is absent",
)
require(
    "TimeMailboxPayloadPrivacyVerify/main.py" in phase1,
    "phase1 verification should include mailbox payload privacy coverage",
)

print("TimeMailboxPayloadPrivacy verification passed")
