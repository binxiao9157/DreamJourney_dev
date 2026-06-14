#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from backend_repo import backend_file

client_file = ROOT / "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"
repo_file = ROOT / "DreamJourney/Sources/Services/MemoryArchive/MemoryArchiveRepository.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/MemoryArchive/MemoryArchiveViewController.swift"
privacy_file = ROOT / "DreamJourney/Sources/Services/Privacy/MemoryPrivacyScope.swift"
backend_main_file = backend_file(ROOT, "app/main.py")
backend_privacy_file = backend_file(ROOT, "app/services/privacy.py")
backend_memory_store_file = backend_file(ROOT, "app/services/in_memory_store.py")
backend_postgres_store_file = backend_file(ROOT, "app/services/postgres_store.py")
backend_tests_file = backend_file(ROOT, "tests/test_core_services.py")
verify_phase1 = ROOT / "Scripts/verify_phase1.sh"

missing = []

client_text = client_file.read_text(encoding="utf-8")
repo_text = repo_file.read_text(encoding="utf-8")
vc_text = vc_file.read_text(encoding="utf-8")
privacy_text = privacy_file.read_text(encoding="utf-8")
backend_main_text = backend_main_file.read_text(encoding="utf-8")
backend_privacy_text = backend_privacy_file.read_text(encoding="utf-8")
backend_memory_store_text = backend_memory_store_file.read_text(encoding="utf-8")
backend_postgres_store_text = backend_postgres_store_file.read_text(encoding="utf-8")
backend_tests_text = backend_tests_file.read_text(encoding="utf-8")
phase1_text = verify_phase1.read_text(encoding="utf-8")

required_client_fragments = [
    "func syncArchiveItem",
    "func fetchArchiveItems",
    "archivePayload",
    "localPath",
    'path: "archive/items"',
    'path: "archive/items/',
    "ArchiveItemResponse",
    "ArchiveItemsResponse",
]

required_vc_fragments = [
    "backendSyncStatusLabel",
    "refreshArchiveBackendSyncStatus",
    "updateBackendSyncStatusLabel",
    "syncArchiveItemMetadataToBackend",
    "DreamJourneyBackendClient.shared.syncArchiveItem",
    "DreamJourneyBackendClient.shared.fetchArchiveItems",
    "syncArchiveItemMetadataToBackend(item)",
]

analysis_success_start = vc_text.find("try self.repository.applyImageAnalysis")
analysis_success_block = vc_text[
    analysis_success_start:
    vc_text.find("self.showToast(\"照片分析完成", analysis_success_start)
]
analysis_failure_block = vc_text[
    vc_text.find("markAnalysisFailed"):
    vc_text.find("self.setKnowledgeDepositStatus(\"结构化建库：照片分析失败", vc_text.find("markAnalysisFailed"))
]

required_privacy_fragments = [
    "case .generationAllowed:",
    ".backendSync",
    "case .familyCircle:",
]

required_backend_fragments = [
    '@app.post("/archive/items")',
    '@app.get("/archive/items/{user_id}")',
    "sanitize_archive_item_payload",
    "store.list_archive_items",
]

required_store_fragments = [
    "def list_archive_items",
]

required_backend_test_fragments = [
    "test_archive_items_api_saves_sanitized_metadata_and_lists_by_user",
    "test_archive_items_api_rejects_private_or_local_items",
    "test_store_lists_archive_items_by_user",
    "/archive/items",
    "localPath",
]

for fragment in required_client_fragments:
    if fragment not in client_text:
        missing.append(f"{client_file.name}: missing {fragment!r}")
for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc_file.name}: missing {fragment!r}")
if "self.syncArchiveItemMetadataToBackend(" not in analysis_success_block:
    missing.append(f"{vc_file.name}: image analysis success should resync updated archive metadata")
if "self.syncArchiveItemMetadataToBackend(failedItem)" not in analysis_failure_block:
    missing.append(f"{vc_file.name}: image analysis failure should resync failed archive metadata")

sync_function_start = vc_text.find("func syncArchiveItemMetadataToBackend")
sync_function_block = vc_text[
    sync_function_start:
    vc_text.find("static var backendSyncDateFormatter", sync_function_start)
]
sync_success_start = sync_function_block.find("case .success")
sync_success_block = sync_function_block[
    sync_success_start:
    sync_function_block.find("case .failure", sync_success_start)
]
if "self?.refreshArchiveBackendSyncStatus()" not in sync_success_block:
    missing.append(
        f"{vc_file.name}: archive sync success should fetch server state before showing server item count"
    )
if "backendArchiveItemCount = max(" in sync_success_block:
    missing.append(
        f"{vc_file.name}: archive sync success should not use local syncable count as server-confirmed count"
    )
refresh_start = vc_text.find("func refreshArchiveBackendSyncStatus")
refresh_block = vc_text[
    refresh_start:
    vc_text.find("func updateBackendSyncStatusLabel", refresh_start)
] if refresh_start >= 0 else ""
if "repository.mergeRemoteItems(response.items)" not in refresh_block:
    missing.append(
        f"{vc_file.name}: archive fetch success should merge backend items into the local archive repository"
    )
if "backfillKnowledgeForRestoredArchiveItems(response.items)" not in refresh_block:
    missing.append(
        f"{vc_file.name}: archive fetch success should backfill restored archive items into KBLite"
    )
if "self?.reloadData()" not in refresh_block:
    missing.append(
        f"{vc_file.name}: archive fetch success should refresh the archive list after merging backend items"
    )
if "mergeRemoteItems" not in repo_text:
    missing.append(f"{repo_file.name}: repository should expose remote archive metadata merge")
if "backfillRestoredArchiveItemKnowledge" not in vc_text:
    missing.append(f"{vc_file.name}: archive UI should expose restored archive knowledge backfill")
for fragment in required_privacy_fragments:
    if fragment not in privacy_text:
        missing.append(f"{privacy_file.name}: missing {fragment!r}")
for fragment in required_backend_fragments:
    if fragment not in backend_main_text and fragment != "sanitize_archive_item_payload":
        missing.append(f"{backend_main_file.name}: missing {fragment!r}")
    if fragment == "sanitize_archive_item_payload" and fragment not in backend_privacy_text:
        missing.append(f"{backend_privacy_file.name}: missing {fragment!r}")
for fragment in required_store_fragments:
    if fragment not in backend_memory_store_text:
        missing.append(f"{backend_memory_store_file.name}: missing {fragment!r}")
    if fragment not in backend_postgres_store_text:
        missing.append(f"{backend_postgres_store_file.name}: missing {fragment!r}")
for fragment in required_backend_test_fragments:
    if fragment not in backend_tests_text:
        missing.append(f"{backend_tests_file.name}: missing {fragment!r}")
if "MemoryArchiveBackendSyncVerify/main.py" not in phase1_text:
    missing.append(f"{verify_phase1.name}: missing MemoryArchiveBackendSyncVerify/main.py")
if "syncArchiveItemMetadataToBackend" in repo_text:
    missing.append(f"{repo_file.name}: backend sync should stay out of pure repository storage")

if missing:
    raise SystemExit("\n".join(missing))

print("MemoryArchiveBackendSync verification passed")
