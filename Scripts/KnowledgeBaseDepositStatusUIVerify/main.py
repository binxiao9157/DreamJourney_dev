#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path.cwd()
SOURCE = ROOT / "DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"KnowledgeBaseDepositStatusUI verification failed: {message}", file=sys.stderr)
        sys.exit(1)


source = SOURCE.read_text(encoding="utf-8")

required_fragments = [
    "KBLiteDepositStatusBuilder.build",
    "沉淀状态",
    "sourceSummary",
    "privacySummary",
    "最近更新",
]

for fragment in required_fragments:
    require(fragment in source, f"missing {fragment}")

require(
    "KBStatsCell" in source and "depositStatus" in source,
    "stats cell should render deposit status, not only entity counts",
)

print("KnowledgeBaseDepositStatusUI verification passed")
