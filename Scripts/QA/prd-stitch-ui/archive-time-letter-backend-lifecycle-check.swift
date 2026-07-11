import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, in baseURL: URL = root) -> String {
    let fileURL = baseURL.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let backendMain = read("app/main.py", in: backendRoot)
let archiveStore = read("app/services/archive_store.py", in: backendRoot)
let inMemoryStore = read("app/services/in_memory_store.py", in: backendRoot)
let postgresStore = read("app/services/postgres_store.py", in: backendRoot)
let backendApiTests = read("tests/test_core_services.py", in: backendRoot)
let backendStoreTests = read("tests/test_postgres_store.py", in: backendRoot)
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let backendSmoke = read("Scripts/QA/prd-stitch-ui/backend-time-letter-lifecycle-smoke.py")
let backendSmokeRunner = read("Scripts/QA/prd-stitch-ui/run-backend-time-letter-lifecycle-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-21-time-letter-public-delivery.md")

for required in [
    "@app.delete(\"/archive/items/{user_id}/{item_id}\")",
    "store.delete_archive_item_with_kb_mutation(",
    "except ArchiveItemDeletionForbidden as exc:",
    "\"status\": \"deleted\"",
] {
    assertContains(backendMain, required, "backend API should expose timeLetter archive delete contract \(required)")
}
assertContains(archiveStore, "def is_sealed_time_letter", "shared archive store contract should identify sealed timeLetter")

for required in [
    "def delete_archive_item(self, user_id: str, item_id: str)",
    "def delete_archive_item_with_kb_mutation(",
    "sealed timeLetter cannot be deleted",
    "items[:] = [entry for entry in items if entry.get(\"id\") != item[\"id\"]]",
] {
    assertContains(inMemoryStore, required, "memory store should upsert/delete archive items \(required)")
}

for required in [
    "def delete_archive_item(self, user_id: str, item_id: str)",
    "def delete_archive_item_with_kb_mutation(",
    "sealed timeLetter cannot be deleted",
    "DELETE FROM archive_items",
    "ON CONFLICT (id) DO UPDATE SET",
] {
    assertContains(postgresStore, required, "postgres store should upsert/delete archive items \(required)")
}

for required in [
    "test_archive_items_api_upserts_time_letter_draft_and_sealed_contract",
    "test_archive_items_api_deletes_time_letter_by_user_and_id",
    "test_archive_items_api_rejects_sealed_time_letter_delete",
] {
    assertContains(backendApiTests, required, "backend API tests should pin timeLetter lifecycle \(required)")
}
assertContains(
    backendStoreTests,
    "test_store_upserts_and_deletes_archive_items_by_user_and_id",
    "postgres store tests should pin archive upsert/delete"
)

for required in [
    "func deleteArchiveItem(",
    "method: .delete",
] {
    assertContains(client, required, "iOS backend client should expose archive delete \(required)")
}

for required in [
    "if kind == .timeLetter",
    "payload[\"deliveryState\"]",
    "payload[\"timeLetterStatus\"]",
    "payload[\"deliveryPolicy\"]",
    "payload[\"openAt\"]",
    "payload[\"recipients\"]",
    "payload[\"sealedAt\"]",
    "payload[\"deliveryStatus\"]",
] {
    assertContains(item, required, "archive backend payload should include timeLetter lifecycle fields \(required)")
}

for required in [
    "draft_delete_response",
    "sealed_delete_response",
    "sealed timeLetter cannot be deleted",
    "listed_after_seal",
    "metadataOnly",
] {
    assertContains(backendSmoke, required, "backend timeLetter smoke should verify \(required)")
}
assertContains(backendSmokeRunner, "BACKEND_TIME_LETTER_LIFECYCLE_SMOKE", "backend timeLetter runner should identify itself")

for required in [
    "RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE",
    "backend-time-letter-lifecycle-smoke.py",
    "archive-time-letter-backend-lifecycle-check.swift",
] {
    assertContains(releaseRegression, required, "release regression should include timeLetter lifecycle gate \(required)")
}
assertContains(
    releaseQA,
    "archive-time-letter-backend-lifecycle-check.swift",
    "release QA package should include timeLetter lifecycle guard"
)

for required in [
    "时间信件公开投递闭环",
    "/archive/items",
    "封存后不可删除",
    "deliveryStatus",
    "RUN_BACKEND_TIME_LETTER_LIFECYCLE_SMOKE",
] {
    assertContains(statusDoc, required, "status doc should document timeLetter backend lifecycle \(required)")
}

print("Archive time-letter backend lifecycle checks passed")
