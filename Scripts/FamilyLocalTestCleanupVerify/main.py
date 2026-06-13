#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

family_file = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"
seed_file = ROOT / "DreamJourney/Sources/Services/RoadshowDemoSeed.swift"

family_text = family_file.read_text(encoding="utf-8")
seed_text = seed_file.read_text(encoding="utf-8")

required_family_fragments = [
    "func removeDemoAndDerivedMembersForLocalTesting()",
    'id.hasPrefix("roadshow_")',
    'id.hasPrefix("kb_")',
    'lastUpdated == "路演数据"',
    'phone == "18800000001"',
]

required_seed_fragments = [
    "FamilyRepository.shared.removeDemoAndDerivedMembersForLocalTesting()",
    '"FamilyDerivedMembers"',
]

missing = []
for fragment in required_family_fragments:
    if fragment not in family_text:
        missing.append(f"{family_file.name}: missing {fragment!r}")

for fragment in required_seed_fragments:
    if fragment not in seed_text:
        missing.append(f"{seed_file.name}: missing {fragment!r}")

if missing:
    raise SystemExit("\n".join(missing))

print("FamilyLocalTestCleanup verification passed")
