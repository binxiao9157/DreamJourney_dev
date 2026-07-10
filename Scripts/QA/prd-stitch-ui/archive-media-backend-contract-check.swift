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
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let videoShell = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveVideoEntryViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-media-backend-contract.md")

let backendPrivacy = read("app/services/privacy.py", in: backendRoot)
let backendTests = read("tests/test_core_services.py", in: backendRoot)

for required in [
    "static let mediaUploadStatusMetadataKey = \"uploadStatus\"",
    "static let mediaTranscriptionStatusMetadataKey = \"transcriptionStatus\"",
    "static let mediaTranscriptTextMetadataKey = \"transcriptText\"",
    "static let mediaThumbnailPathMetadataKey = \"thumbnailPath\"",
    "static let mediaFileSizeBytesMetadataKey = \"fileSizeBytes\"",
    "static let mediaFileSizeLimitMBMetadataKey = \"fileSizeLimitMB\"",
    "func archiveBackendPayload(",
    "\"uploadedByUserId\": ownerUserId",
    "\"uploaderUserId\": ownerUserId",
    "\"personaScope\": personaScope",
    "\"digitalHumanId\": digitalHumanId",
    "\"privacyMetadata\": [",
    "\"scope\": \"generationAllowed\"",
    "\"kind\": \"archiveItem\"",
] {
    assertContains(item, required, "archive item should define media backend contract \(required)")
}

for required in [
    "transcriptText: String? = nil",
    "transcriptionStatus",
    "transcriptLanguage",
    "uploadStatus",
    "makeVideoItem(",
    "thumbnailPath",
    "fileSizeBytes",
    "MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB",
    "\"source\": \"manual_video\"",
    "\"contentKind\": \"video\"",
] {
    assertContains(factory, required, "factory should emit media schema \(required)")
}

assertContains(
    repository,
    "item.archiveBackendPayload(",
    "repository should use the shared archive backend payload contract"
)

for required in [
    "上传状态",
    "转写状态",
    "转写结果",
    "缩略图",
    "文件上限",
    "云端合同",
] {
    assertContains(display, required, "archive detail metadata should expose \(required)")
}

for required in [
    "static let videoFileSizeLimitMB = 200",
    "static let backendMediaStorageContract = \"metadata_only_object_storage\"",
] {
    assertContains(readiness, required, "media readiness should define \(required)")
}

for required in [
    "MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB",
    "backendMediaStorageContract",
    "分析状态",
    "后端存储合同",
] {
    assertContains(videoShell, required, "video hidden shell should present \(required)")
}

for required in [
    "rawTranscript",
    "rawAudioURL",
    "rawVideoURL",
    "thumbnailPath",
    "localThumbnailPath",
    "transcriptText",
    "thumbnailObjectKey",
] {
    assertContains(backendPrivacy, required, "backend privacy sanitizer should handle \(required)")
}

for required in [
    "test_archive_items_api_persists_audio_contract_fields",
    "test_archive_items_api_persists_video_contract_fields",
    "transcriptText",
    "transcriptionStatus",
    "thumbnailObjectKey",
    "fileSizeLimitMB",
] {
    assertContains(backendTests, required, "backend tests should cover \(required)")
}

assertContains(
    releaseRegression,
    "archive-media-backend-contract-check.swift",
    "release regression should run archive media backend contract guard"
)
assertContains(
    releaseQA,
    "archive-media-backend-contract-check.swift",
    "release QA package should include archive media backend contract guard"
)
assertContains(
    statusDoc,
    "录音档案的数据模型和后端合同",
    "status doc should document audio media backend contract"
)
assertContains(
    statusDoc,
    "视频档案壳层和合同",
    "status doc should document video media backend contract"
)

print("Archive media backend contract checks passed")
