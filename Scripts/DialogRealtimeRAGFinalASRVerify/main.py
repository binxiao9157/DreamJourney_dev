#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
MANAGER = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DialogRealtimeRAGFinalASR verification failed: {message}", file=sys.stderr)
        sys.exit(1)


source = MANAGER.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")


def case_body(case_name: str, next_marker: str) -> str:
    pattern = rf"case {re.escape(case_name)}:[\s\S]*?(?=\n\s*{re.escape(next_marker)})"
    match = re.search(pattern, source)
    require(match is not None, f"{case_name} block should exist")
    return match.group(0)


def require_final_branch_rag(block: str, label: str) -> None:
    require(
        "if result.isFinal" in block,
        f"{label} should have a final ASR branch",
    )
    require(
        "sendMemoryRAGIfAvailable(for: result.text)" in block,
        f"{label} final ASR should send query-specific RAG before forwarding",
    )
    require(
        "logMemoryGroundingPlan(for: result.text)" in block,
        f"{label} final ASR should log the grounding plan for device evidence",
    )

    rag_index = block.find("sendMemoryRAGIfAvailable(for: result.text)")
    log_index = block.find("logMemoryGroundingPlan(for: result.text)")
    safety_index = block.find("handleSafetyIfNeeded(text: result.text)")
    keyword_index = block.find("checkEndKeyword(in: result.text)")
    final_forward_index = block.find("forwardASRResult(text: result.text, isFinal: result.isFinal)")

    require(
        safety_index != -1 and safety_index < rag_index,
        f"{label} should run safety before sending RAG",
    )
    require(
        keyword_index != -1 and keyword_index < rag_index,
        f"{label} should suppress end commands before sending RAG",
    )
    require(
        final_forward_index != -1 and rag_index < final_forward_index,
        f"{label} should send RAG before the non-command final ASR reaches UI/session memory",
    )
    require(
        rag_index < log_index < final_forward_index,
        f"{label} should log grounding evidence after sending RAG and before forwarding",
    )


asr_info = case_body("SEEventASRInfo", "case SEEventASRResponse:")
asr_response = case_body("SEEventASRResponse", "case SEEventASREnded:")

require_final_branch_rag(asr_info, "SEEventASRInfo")
require_final_branch_rag(asr_response, "SEEventASRResponse")

require(
    "sendMemoryRAGIfAvailable(for: queryText)" in source,
    "ChatTextQueryConfirmed should keep sending RAG for SDK-confirmed query events",
)
require(
    "DialogRealtimeRAGFinalASRVerify/main.py" in phase1,
    "phase1 verification should include realtime final-ASR RAG coverage",
)

print("DialogRealtimeRAGFinalASR verification passed")
