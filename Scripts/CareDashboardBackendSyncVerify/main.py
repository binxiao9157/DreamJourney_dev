#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/CareDashboard/CareDashboardViewController.swift"
backend_main = ROOT / "DreamJourneyBackend/app/main.py"

client_text = client_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
backend_text = backend_main.read_text(encoding="utf-8")

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
    "snapshotSourceText",
    "CareSignalSnapshot",
    "DreamJourneyBackendClient.shared.syncCareSnapshot",
    "DreamJourneyBackendClient.shared.fetchLatestCareSnapshot",
    "DreamJourneyBackendClient.shared.fetchCareSnapshotHistory",
]

required_backend_fragments = [
    "@app.post(\"/care/snapshots\")",
    "@app.get(\"/care/snapshots/latest/{user_id}\")",
    "@app.get(\"/care/snapshots/{user_id}\")",
    "save_care_snapshot",
    "get_latest_care_snapshot",
    "list_care_snapshots",
]

missing = []
for fragment in required_client_fragments:
    if fragment not in client_text:
        missing.append(f"{client_file.name}: missing {fragment!r}")
for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc_file.name}: missing {fragment!r}")
for fragment in required_backend_fragments:
    if fragment not in backend_text:
        missing.append(f"{backend_main.name}: missing {fragment!r}")

if missing:
    raise SystemExit("\n".join(missing))

print("CareDashboardBackendSync verification passed")
