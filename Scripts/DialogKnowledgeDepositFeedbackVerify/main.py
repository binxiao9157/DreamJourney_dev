#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
CONVERSATION = ROOT / "DreamJourney/Sources/Services/ConversationMemoryManager.swift"
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
HOME = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DialogKnowledgeDepositFeedback verification failed: {message}", file=sys.stderr)
        sys.exit(1)


conversation = CONVERSATION.read_text(encoding="utf-8")
user_manager = USER_MANAGER.read_text(encoding="utf-8")
home = HOME.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

required_notification_fragments = [
    "djConversationKnowledgeExtractionFinished",
    "sessionId",
    "addedCount",
    "NotificationCenter.default.post",
]

for fragment in required_notification_fragments:
    require(
        fragment in conversation or fragment in user_manager,
        f"missing knowledge extraction notification fragment {fragment!r}",
    )

require(
    ".djConversationKnowledgeExtractionFinished" in home,
    "home dialog screen should observe knowledge extraction completion",
)
require(
    "handleKnowledgeExtractionFinished" in home,
    "home dialog screen should have an extraction completion handler",
)
require(
    "结构化知识库已沉淀" in home,
    "home dialog screen should show a success deposit receipt",
)
require(
    "本轮暂无可新增的结构化知识" in home,
    "home dialog screen should show a zero-new-knowledge receipt",
)
require(
    "DialogKnowledgeDepositFeedbackVerify/main.py" in phase1,
    "phase1 verification should include dialog knowledge deposit feedback coverage",
)

print("DialogKnowledgeDepositFeedback verification passed")
