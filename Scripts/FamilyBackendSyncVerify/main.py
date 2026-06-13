#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
repo_file = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift"
backend_main_file = ROOT / "DreamJourneyBackend/app/main.py"
backend_memory_store_file = ROOT / "DreamJourneyBackend/app/services/in_memory_store.py"
backend_postgres_store_file = ROOT / "DreamJourneyBackend/app/services/postgres_store.py"
backend_tests_file = ROOT / "DreamJourneyBackend/tests/test_core_services.py"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

missing = []

client_text = client_file.read_text(encoding="utf-8")
repo_text = repo_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
backend_main_text = backend_main_file.read_text(encoding="utf-8")
backend_memory_store_text = backend_memory_store_file.read_text(encoding="utf-8")
backend_postgres_store_text = backend_postgres_store_file.read_text(encoding="utf-8")
backend_tests_text = backend_tests_file.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

required_client_fragments = [
    "func inviteFamilyMember",
    'path: "family/invite"',
    "func fetchFamilyMembers",
    'path: "family/members/',
    "func revokeFamilyMember",
    "func acceptFamilyMember",
    'path: "family/members/',
    "/revoke",
    "/accept",
    "struct FamilyInviteResponse",
    "struct FamilyMembersResponse",
    "struct FamilyRevokeResponse",
    "struct FamilyAcceptResponse",
    "accessStatus",
    "invitationStatus",
    "accessStatus: accessStatus",
    "invitationStatus: invitationStatus",
]

required_repo_fragments = [
    "func syncFromBackend",
    "func inviteBackendMember",
    "func revokeBackendAccess",
    "func acceptBackendInvitation",
    "DreamJourneyBackendClient.shared.fetchFamilyMembers",
    "DreamJourneyBackendClient.shared.inviteFamilyMember",
    "DreamJourneyBackendClient.shared.revokeFamilyMember",
    "DreamJourneyBackendClient.shared.acceptFamilyMember",
    "mergeBackendMembers",
]

required_vc_fragments = [
    "FamilyRepository.shared.syncFromBackend",
    "FamilyRepository.shared.inviteBackendMember",
    "FamilyRepository.shared.revokeBackendAccess",
    "FamilyRepository.shared.acceptBackendInvitation",
    "syncFamilyMembersFromBackend",
]

required_backend_fragments = [
    '@app.post("/family/members/{user_id}/{member_id}/revoke")',
    '@app.post("/family/members/{user_id}/{member_id}/accept")',
    "def revoke_family_member",
    "def accept_family_member",
    "store.revoke_family_member",
    "store.accept_family_member",
]

required_store_fragments = [
    "def revoke_family_member",
    "def accept_family_member",
    '"accessStatus"',
    '"revoked"',
    '"active"',
    '"accepted"',
    '"revokedAt"',
    '"acceptedAt"',
]

required_backend_test_fragments = [
    "test_family_member_revoke_api_marks_member_revoked",
    "test_family_member_accept_api_marks_member_active",
    "/family/members/u1/",
    "/revoke",
    "/accept",
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
for fragment in required_backend_fragments:
    if fragment not in backend_main_text:
        missing.append(f"{backend_main_file.name}: missing {fragment!r}")
for fragment in required_store_fragments:
    if fragment not in backend_memory_store_text:
        missing.append(f"{backend_memory_store_file.name}: missing {fragment!r}")
    if fragment not in backend_postgres_store_text:
        missing.append(f"{backend_postgres_store_file.name}: missing {fragment!r}")
for fragment in required_backend_test_fragments:
    if fragment not in backend_tests_text:
        missing.append(f"{backend_tests_file.name}: missing {fragment!r}")
if "FamilyBackendSyncVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing FamilyBackendSyncVerify/main.py")

postgres_code_accept_start = backend_postgres_store_text.find("def accept_family_invitation_code")
postgres_code_accept_end = backend_postgres_store_text.find("def revoke_family_member", postgres_code_accept_start)
postgres_code_accept_body = backend_postgres_store_text[postgres_code_accept_start:postgres_code_accept_end]
if 'item.get("accessStatus") == "revoked"' not in postgres_code_accept_body:
    missing.append("postgres_store.py: invitation-code accept should reject revoked accessStatus")
if 'item.get("invitationStatus") == "revoked"' not in postgres_code_accept_body:
    missing.append("postgres_store.py: invitation-code accept should reject revoked invitationStatus")
if 'item.get("accessStatus") == "active" and item.get("invitationStatus") == "accepted"' not in postgres_code_accept_body:
    missing.append("postgres_store.py: invitation-code accept should be idempotent for already accepted members")

if missing:
    raise SystemExit("\n".join(missing))

print("FamilyBackendSync verification passed")
