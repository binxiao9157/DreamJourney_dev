#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
repo_file = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

missing = []

client_text = client_file.read_text(encoding="utf-8")
repo_text = repo_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

required_client_fragments = [
    "func inviteFamilyMember",
    'path: "family/invite"',
    "func fetchFamilyMembers",
    'path: "family/members/',
    "struct FamilyInviteResponse",
    "struct FamilyMembersResponse",
]

required_repo_fragments = [
    "func syncFromBackend",
    "func inviteBackendMember",
    "DreamJourneyBackendClient.shared.fetchFamilyMembers",
    "DreamJourneyBackendClient.shared.inviteFamilyMember",
    "mergeBackendMembers",
]

required_vc_fragments = [
    "FamilyRepository.shared.syncFromBackend",
    "FamilyRepository.shared.inviteBackendMember",
    "syncFamilyMembersFromBackend",
]

for fragment in required_client_fragments:
    if fragment not in client_text:
        missing.append(f"{client_file.name}: missing {fragment!r}")
for fragment in required_repo_fragments:
    if fragment not in repo_text:
        missing.append(f"{repo_file.name}: missing {fragment!r}")
for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc_file.name}: missing {fragment!r}")
if "FamilyBackendSyncVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing FamilyBackendSyncVerify/main.py")

if missing:
    raise SystemExit("\n".join(missing))

print("FamilyBackendSync verification passed")
