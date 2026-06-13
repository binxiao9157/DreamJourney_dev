#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
SEED = ROOT / "DreamJourney/Sources/Services/RoadshowDemoSeed.swift"
REPO = ROOT / "DreamJourney/Sources/Services/TimeMailbox/TimeMailboxRepository.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"RoadshowMailboxSeed verification failed: {message}", file=sys.stderr)
        sys.exit(1)


seed = SEED.read_text(encoding="utf-8")
repo = REPO.read_text(encoding="utf-8")

require(
    "id: \"roadshow_time_mailbox_" in seed,
    "roadshow mailbox seed should create stable roadshow_ letter ids",
)
require(
    "id: String = UUID().uuidString" in repo,
    "TimeMailboxRepository.createLetter should allow explicit ids for seed cleanup",
)
require(
    'letter.id.hasPrefix("roadshow_")' in repo,
    "repository should clean every roadshow_ mailbox letter",
)

print("RoadshowMailboxSeed verification passed")
