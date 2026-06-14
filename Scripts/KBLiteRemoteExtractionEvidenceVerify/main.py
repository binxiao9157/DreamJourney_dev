#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
CONVERSATION = ROOT / "DreamJourney/Sources/Services/ConversationMemoryManager.swift"
HOME = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"KBLiteRemoteExtractionEvidence verification failed: {message}", file=sys.stderr)
        sys.exit(1)


conversation = CONVERSATION.read_text(encoding="utf-8")
home = HOME.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

conversation_block = re.search(
    r"KBLiteManager\.shared\.extractFromTranscript[\s\S]*?NotificationCenter\.default\.post[\s\S]*?\)\n\s*\}",
    conversation,
)
conversation_body = conversation_block.group(0) if conversation_block else ""

handler_block = re.search(
    r"@objc private func handleKnowledgeExtractionFinished\([\s\S]*?\n    \}",
    home,
)
handler_body = handler_block.group(0) if handler_block else ""

required_notification_fragments = [
    "extractFromTranscriptDetailed",
    "summary.totalAddedCount",
    '"deterministicAddedCount": summary.deterministicAddedCount',
    '"llmAddedCount": summary.llmAddedCount',
    '"didAttemptLLM": summary.didAttemptLLM',
    '"didFailLLM": summary.didFailLLM',
    '"llmErrorDescription": summary.llmErrorDescription',
]
for fragment in required_notification_fragments:
    require(fragment in conversation_body, f"conversation extraction notification missing {fragment!r}")

required_handler_fragments = [
    'notification.userInfo?["deterministicAddedCount"] as? Int',
    'notification.userInfo?["llmAddedCount"] as? Int',
    'notification.userInfo?["didAttemptLLM"] as? Bool',
    'notification.userInfo?["didFailLLM"] as? Bool',
    "远端 AI 抽取暂未完成",
    "其中 AI 抽取",
    "AI 暂无新增线索",
]
for fragment in required_handler_fragments:
    require(fragment in handler_body, f"home extraction receipt should expose remote evidence {fragment!r}")

require(
    "KBLiteRemoteExtractionEvidenceVerify/main.py" in phase1,
    "phase1 verification should include KBLite remote extraction evidence coverage",
)

print("KBLiteRemoteExtractionEvidence verification passed")
