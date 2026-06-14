#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from backend_repo import backend_file
CLIENT = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
VIEW = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
BACKEND = backend_file(ROOT, "app/main.py")
TESTS = backend_file(ROOT, "tests/test_core_services.py")
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"CareDashboardRequesterIdentity verification failed: {message}", file=sys.stderr)
        sys.exit(1)


client = CLIENT.read_text(encoding="utf-8")
view = VIEW.read_text(encoding="utf-8")
backend = BACKEND.read_text(encoding="utf-8")
tests = TESTS.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

for fragment in [
    "requesterPhone: String?",
    'URLQueryItem(name: "requesterPhone"',
    "fetchLatestCareSnapshot(",
    "fetchCareSnapshotHistory(",
]:
    require(fragment in client, f"backend client should pass requester identity: {fragment!r}")

for fragment in [
    "requesterPhoneForCareSnapshot()",
    "requesterPhone: requesterPhoneForCareSnapshot()",
    "UserManager.shared.currentUser?.phone",
]:
    require(fragment in view, f"care dashboard UI should send current requester phone: {fragment!r}")

for fragment in [
    "requesterPhone: str = None",
    "_ensure_active_family_viewer(",
    "require_requester_identity=True",
    "requester identity is required",
    "requester is not authorized for this care snapshot",
]:
    require(fragment in backend, f"backend should enforce requester identity: {fragment!r}")

require(
    "test_care_snapshot_member_reads_require_requester_phone" in tests,
    "backend tests should cover requester identity for care snapshots",
)
require(
    "CareDashboardRequesterIdentityVerify/main.py" in phase1,
    "phase1 verification should include care requester identity coverage",
)

print("CareDashboardRequesterIdentity verification passed")
