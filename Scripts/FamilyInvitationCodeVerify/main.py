#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
repo_file = ROOT / "DreamJourney/Sources/Services/FamilyRepository.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift"
scene_file = ROOT / "DreamJourney/Sources/SceneDelegate.swift"
tab_coordinator_file = ROOT / "DreamJourney/Sources/App/TabCoordinator.swift"
info_plist_file = ROOT / "DreamJourney/Resources/Info.plist"
backend_main_file = ROOT / "DreamJourneyBackend/app/main.py"
backend_memory_store_file = ROOT / "DreamJourneyBackend/app/services/in_memory_store.py"
backend_postgres_store_file = ROOT / "DreamJourneyBackend/app/services/postgres_store.py"
backend_tests_file = ROOT / "DreamJourneyBackend/tests/test_core_services.py"
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

missing = []

client_text = client_file.read_text(encoding="utf-8")
repo_text = repo_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
scene_text = scene_file.read_text(encoding="utf-8")
tab_coordinator_text = tab_coordinator_file.read_text(encoding="utf-8")
info_plist_text = info_plist_file.read_text(encoding="utf-8")
backend_main_text = backend_main_file.read_text(encoding="utf-8")
backend_memory_store_text = backend_memory_store_file.read_text(encoding="utf-8")
backend_postgres_store_text = backend_postgres_store_file.read_text(encoding="utf-8")
backend_tests_text = backend_tests_file.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

required_client_fragments = [
    "func acceptFamilyInvitationCode",
    'path: "family/invitations/',
    "/accept",
    "invitationCode",
    "invitationURL",
]

required_repo_fragments = [
    "FamilyInvitationDeepLinkService",
    "acceptBackendInvitationCode",
    "invitationCode(from rawValue",
    "consumePendingInvitationCode",
    "DreamJourneyBackendClient.shared.acceptFamilyInvitationCode",
    "currentUser?.phone",
]

required_vc_fragments = [
    "invitationCode",
    "shareText",
    "UIPasteboard.general.string",
    "acceptBackendInvitationCode",
    "acceptInvitationCodeFromDeepLink",
    "邀请码",
]

required_deeplink_fragments = [
    "CFBundleURLTypes",
    "dreamjourney",
    "openURLContexts",
    "FamilyInvitationDeepLinkService.handle",
    "djFamilyInvitationDeepLinkReceived",
    "consumePendingFamilyInvitationDeepLink",
    "openFamilyInvitation",
]

required_backend_fragments = [
    '@app.post("/family/invitations/{invitation_code}/accept")',
    "invitationCode",
    "invitationURL",
    "accept_family_invitation_code",
]

required_store_fragments = [
    "def accept_family_invitation_code",
    '"invitationCode"',
    '"invitationURL"',
]

required_backend_test_fragments = [
    "test_family_invitation_code_accept_api_marks_member_active",
    "/family/invitations/",
    "invitationCode",
    "invitationURL",
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
for fragment in required_deeplink_fragments:
    if fragment in ["CFBundleURLTypes", "dreamjourney"] and fragment not in info_plist_text:
        missing.append(f"{info_plist_file.name}: missing {fragment!r}")
    elif fragment in ["openURLContexts", "FamilyInvitationDeepLinkService.handle"] and fragment not in scene_text:
        missing.append(f"{scene_file.name}: missing {fragment!r}")
    elif fragment in ["djFamilyInvitationDeepLinkReceived", "consumePendingFamilyInvitationDeepLink", "openFamilyInvitation"] and fragment not in tab_coordinator_text and fragment not in repo_text:
        missing.append(f"deeplink implementation: missing {fragment!r}")
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
if "FamilyInvitationCodeVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing FamilyInvitationCodeVerify/main.py")

if missing:
    raise SystemExit("\n".join(missing))

print("FamilyInvitationCode verification passed")
