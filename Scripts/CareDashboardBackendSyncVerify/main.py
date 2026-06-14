#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from backend_repo import backend_file

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
publisher_file = ROOT / "DreamJourney/Sources/Services/CareDashboard/CareDashboardSnapshotPublisher.swift"
backend_main = backend_file(ROOT, "app/main.py")
backend_privacy = backend_file(ROOT, "app/services/privacy.py")
backend_tests = backend_file(ROOT, "tests/test_core_services.py")

client_text = client_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
publisher_text = publisher_file.read_text(encoding="utf-8") if publisher_file.exists() else ""
backend_text = backend_main.read_text(encoding="utf-8")
privacy_text = backend_privacy.read_text(encoding="utf-8")
tests_text = backend_tests.read_text(encoding="utf-8")

reload_start = vc_text.find("private func reloadSnapshot()")
reload_end = vc_text.find("private func syncSnapshotToBackend", reload_start)
reload_body = vc_text[reload_start:reload_end]

required_client_fragments = [
    "func syncCareSnapshot",
    "func fetchLatestCareSnapshot",
    "func fetchCareSnapshotHistory",
    "CareSnapshotResponse",
    "CareSnapshotHistoryResponse",
    "CareSnapshotItem",
    "path: \"care/snapshots\"",
    "care/snapshots/latest",
    "care/snapshots/",
    "viewerFamilyMemberID",
]

required_vc_fragments = [
    "syncSnapshotToBackend",
    "fetchLatestSnapshotFromBackend",
    "fetchSnapshotHistoryFromBackend",
    "applyRemoteSnapshotIfUseful",
    "getCareDashboardTranscriptHistory",
    "careOwnerUserID",
    "snapshotSourceText",
    "CareSignalSnapshot",
    "CareDashboardSnapshotPublisher.shared.makeLocalSnapshot",
    "CareDashboardSnapshotPublisher.shared.publish",
    "DreamJourneyBackendClient.shared.fetchLatestCareSnapshot",
    "DreamJourneyBackendClient.shared.fetchCareSnapshotHistory",
    "remoteSnapshotHistory",
    "makeSnapshotHistoryCard",
    "同步快照记录",
    "可生成周报",
    "采样中：",
]

required_publisher_fragments = [
    "final class CareDashboardSnapshotPublisher",
    "CareDashboardInputPolicy.eligibleInputTurns",
    "CareSignalAnalyzer",
    "publishLatestLocalSnapshotAfterConversationEnd",
    "DreamJourneyBackendClient.shared.syncCareSnapshot",
    "ownerUserId == currentUserId",
]

required_backend_fragments = [
    "@app.post(\"/care/snapshots\")",
    "@app.get(\"/care/snapshots/latest/{user_id}\")",
    "@app.get(\"/care/snapshots/{user_id}\")",
    "_normalize_viewer_family_member_id",
    "_ensure_active_family_viewer",
    "family member access is not active",
    "family member is not authorized",
    "sanitize_care_snapshot_payload",
    "except ValueError as exc",
    "status_code=400",
    "save_care_snapshot",
    "get_latest_care_snapshot",
    "list_care_snapshots",
]

required_privacy_fragments = [
    "CARE_SNAPSHOT_SCALAR_KEYS",
    "CARE_SNAPSHOT_REQUIRED_SCALAR_KEYS",
    "CARE_SNAPSHOT_STRING_LIST_KEYS",
    "CARE_SNAPSHOT_REQUIRED_STRING_LIST_KEYS",
    "CARE_SNAPSHOT_RAW_TEXT_MARKERS",
    "CARE_DAILY_TREND_SCALAR_KEYS",
    "CARE_DAILY_TREND_REQUIRED_KEYS",
    "def sanitize_care_snapshot_payload",
    "contentRedacted",
]

required_test_fragments = [
    "test_care_snapshot_sanitizer_keeps_only_aggregate_fields",
    "test_care_snapshot_api_never_persists_raw_conversation_payload",
    "test_care_snapshot_api_rejects_missing_required_fields",
    "test_care_snapshot_api_rejects_raw_text_inside_allowed_fields",
    "test_care_snapshot_api_requires_active_family_viewer",
    "pending_write.status_code, 403",
    "revoked_latest.status_code, 403",
    "CARE_RAW_SENTINEL",
]

missing = []
for fragment in required_client_fragments:
    if fragment not in client_text:
        missing.append(f"{client_file.name}: missing {fragment!r}")
for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc_file.name}: missing {fragment!r}")
for fragment in required_publisher_fragments:
    if fragment not in publisher_text:
        missing.append(f"{publisher_file.name}: missing {fragment!r}")
for fragment in required_backend_fragments:
    if fragment not in backend_text:
        missing.append(f"{backend_main.name}: missing {fragment!r}")
for fragment in required_privacy_fragments:
    if fragment not in privacy_text:
        missing.append(f"{backend_privacy.name}: missing {fragment!r}")
for fragment in required_test_fragments:
    if fragment not in tests_text:
        missing.append(f"{backend_tests.name}: missing {fragment!r}")

if "fetchSnapshotHistoryFromBackend()" not in reload_body:
    missing.append("CareDashboardViewController.swift: reloadSnapshot should fetch remote history after local analysis")
if "else {" in reload_body and "fetchSnapshotHistoryFromBackend()" in reload_body.split("else {", 1)[-1]:
    missing.append("CareDashboardViewController.swift: remote history fetch should not be limited to empty local snapshots")

if missing:
    raise SystemExit("\n".join(missing))

print("CareDashboardBackendSync verification passed")
