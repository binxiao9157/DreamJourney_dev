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

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let backendSmoke = read("Scripts/QA/prd-stitch-ui/backend-hidden-media-sync-smoke.py")
let backendSmokeRunner = read("Scripts/QA/prd-stitch-ui/run-backend-hidden-media-sync-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-hidden-media-backend-upload-lifecycle.md")
let backendTests = read("tests/test_core_services.py", in: backendRoot)

for required in [
    "static let mediaUploadIntentIdMetadataKey = \"uploadIntentId\"",
    "static let mediaObjectKeyMetadataKey = \"objectKey\"",
    "static let mediaUploadProviderMetadataKey = \"uploadProvider\"",
    "static let mediaUploadErrorMetadataKey = \"uploadError\"",
    "var isMediaUploadIntentEligible: Bool",
    "func markingMediaUploadPending() -> MemoryArchiveItem",
    "func markingMediaUploadUploaded(intent: ArchiveMediaUploadIntent",
    "func markingMediaUploadFailed",
    "var isTimeLetterDraft: Bool",
    "func updatingTimeLetterDraft(note:",
    "func sealingTimeLetterDraft()",
] {
    assertContains(item, required, "archive item should expose hidden media/time-letter lifecycle \(required)")
}

for required in [
    "func archiveMediaUploadIntentPayload(for item: MemoryArchiveItem)",
    "func remove(id:",
    "archiveMediaUploadIntentPayload(",
    "mediaUploadContentType",
] {
    assertContains(repository, required, "repository should expose upload-intent payload/remove lifecycle \(required)")
}

for required in [
    "requestMediaUploadIntentTapped",
    "archive-media-upload-intent-button",
    "上传中...",
    "重新上传",
    "markMediaUploadFailure",
    "editTimeLetterDraftTapped",
    "sealTimeLetterDraftTapped",
    "deleteTimeLetterDraftTapped",
    "archive-time-letter-edit-draft",
    "archive-time-letter-seal-draft",
    "archive-time-letter-delete-draft",
] {
    assertContains(detail, required, "archive detail should expose upload/time-letter controls \(required)")
}

for required in [
    "上传中",
    "上传失败",
    "已上传",
    "上传错误",
] {
    assertContains(display, required, "archive detail metadata should display upload status/error \(required)")
}

for required in [
    "mediaUploadUploaded",
    "mediaUploadFailed",
    "timeLetterDraftEdited",
    "timeLetterDraftDeleted",
    "timeLetterDraftSealed",
] {
    assertContains(appDelegate, required, "hidden shell smoke should verify \(required)")
}

for required in [
    "/archive/items",
    "/archive/media/upload-intent",
    "rawAudioURL",
    "rawVideoURL",
    "localThumbnailPath",
    "timeLetter",
    "assert_not_in",
] {
    assertContains(backendSmoke, required, "backend hidden media smoke should verify \(required)")
}
assertContains(backendSmokeRunner, "BACKEND_HIDDEN_MEDIA_SYNC_SMOKE", "backend hidden media runner should identify itself")
assertContains(backendTests, "test_archive_items_api_persists_time_letter_shell_contract", "backend time-letter shell contract should stay pinned")

assertContains(
    releaseRegression,
    "archive-hidden-media-backend-upload-lifecycle-check.swift",
    "release regression should run hidden media backend/upload lifecycle guard"
)
assertContains(
    releaseRegression,
    "RUN_BACKEND_HIDDEN_MEDIA_SYNC_SMOKE",
    "release regression should expose deployed hidden media sync smoke gate"
)
assertContains(
    releaseQA,
    "archive-hidden-media-backend-upload-lifecycle-check.swift",
    "release QA package should include hidden media backend/upload lifecycle guard"
)
assertContains(
    statusDoc,
    "隐藏媒体后端同步 smoke",
    "status doc should document hidden media backend sync smoke"
)
assertContains(
    statusDoc,
    "音视频 mock upload 状态闭环",
    "status doc should document media upload status lifecycle"
)
assertContains(
    statusDoc,
    "时间信件本地生命周期",
    "status doc should document time-letter local lifecycle"
)

print("Archive hidden media backend/upload lifecycle checks passed")
