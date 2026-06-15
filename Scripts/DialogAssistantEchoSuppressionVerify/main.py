#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
ENGINE = ROOT / "DreamJourney/Sources/Services/DialogEngineManager.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"DialogAssistantEchoSuppression verification failed: {message}", file=sys.stderr)
        sys.exit(1)


source = ENGINE.read_text(encoding="utf-8")

require(
    "private var recentAssistantEchoText: String?" in source
    and "private var recentAssistantEchoSentAt: Date?" in source
    and "private let assistantEchoFilterWindow" in source,
    "dialog engine should keep a short-lived assistant echo cache",
)

forward_match = re.search(
    r"private func forwardASRResult\(text: String, isFinal: Bool\) \{(?P<body>[\s\S]*?)\n    \}",
    source,
)
require(forward_match is not None, "forwardASRResult should exist")
forward_body = forward_match.group("body")
require(
    "shouldSuppressPlaybackEcho(text)" in forward_body,
    "all ASR forwarding should suppress recent playback echoes, even after isAISpeaking becomes false",
)

assistant_echo_match = re.search(
    r"private func shouldSuppressAssistantEcho\(_ text: String\) -> Bool \{(?P<body>[\s\S]*?)\n    \}",
    source,
)
require(assistant_echo_match is not None, "shouldSuppressAssistantEcho should exist")
assistant_echo_body = assistant_echo_match.group("body")
require(
    "recentAssistantEchoText" in assistant_echo_body
    and "recentAssistantEchoSentAt" in assistant_echo_body
    and "assistantEchoFilterWindow" in assistant_echo_body,
    "assistant echo suppression should use a timestamped recent assistant text cache",
)

require(
    source.count("rememberAssistantEchoText(") >= 3,
    "assistant text should be cached whenever a final assistant reply is delivered",
)

require(
    "DialogAssistantEchoSuppressionVerify/main.py" in PHASE1.read_text(encoding="utf-8"),
    "phase1 verification should include assistant echo suppression coverage",
)

print("DialogAssistantEchoSuppression verification passed")
