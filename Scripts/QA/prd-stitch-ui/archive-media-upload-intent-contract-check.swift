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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-media-upload-intent-contract.md")

let backendMain = read("app/main.py", in: backendRoot)
let backendRuntime = read("app/services/runtime_config.py", in: backendRoot)
let backendTests = read("tests/test_core_services.py", in: backendRoot)
let backendReadme = read("README.md", in: backendRoot)

for required in [
    "archiveMediaUploadIntentAvailable",
    "archiveMediaUploadIntentEndpoint",
    "struct ArchiveMediaUploadIntent",
    "let uploadIntentId: String",
    "let storageProvider: String",
    "let objectKey: String",
    "let uploadURL: String",
    "let expiresAt: Date",
    "let maxFileSizeBytes: Int64",
    "let requiredHeaders: [String: String]",
    "requestArchiveMediaUploadIntent(",
    "requestJSON(path: \"/archive/media/upload-intent\"",
] {
    assertContains(client, required, "iOS backend client should define \(required)")
}

for required in [
    "func archiveMediaUploadIntentPayload(",
    "\"archiveItemId\": id",
    "\"kind\": kind.rawValue",
    "\"fileName\": fileName",
    "\"contentType\": contentType",
    "\"fileSizeBytes\": fileSizeBytes",
    "\"personaScope\": personaScope",
    "\"digitalHumanId\": digitalHumanId",
] {
    assertContains(item, required, "archive item should build upload-intent payload \(required)")
}

for required in [
    "static let mediaUploadIntentEndpoint = \"/archive/media/upload-intent\"",
    "static let uploadIntentTTLSeconds = 900",
    "static let audioFileSizeLimitMB = 50",
] {
    assertContains(readiness, required, "media readiness should expose \(required)")
}

for required in [
    "@app.post(\"/archive/media/upload-intent\")",
    "archive_media_upload_intent",
    "mockObjectStorage",
    "uploadIntentId",
    "objectKey",
    "uploadURL",
    "expiresAt",
    "requiredHeaders",
    "maxFileSizeBytes",
    "_safe_object_segment",
    "contentType does not match media kind",
] {
    assertContains(backendMain, required, "backend should expose upload intent field \(required)")
}

for required in [
    "\"archiveMediaUploadIntent\": True",
    "\"uploadIntentEndpoint\": \"/archive/media/upload-intent\"",
    "\"storageProvider\": \"mockObjectStorage\"",
] {
    assertContains(backendRuntime, required, "runtime config should expose upload intent \(required)")
}

for required in [
    "test_archive_media_upload_intent_returns_mock_contract",
    "test_archive_media_upload_intent_rejects_unsupported_kind_or_size",
    "archive/media/upload-intent",
    "mockObjectStorage",
    "fileSizeLimitMB",
    "uploadIntentId",
] {
    assertContains(backendTests, required, "backend tests should cover \(required)")
}

assertContains(backendReadme, "POST /archive/media/upload-intent", "README should list upload intent endpoint")
assertNotContains(backendMain, "AWS_SECRET", "mock upload intent must not embed cloud provider secrets")
assertNotContains(backendMain, "ALIYUN_ACCESS", "mock upload intent must not embed cloud provider secrets")

assertContains(
    releaseRegression,
    "archive-media-upload-intent-contract-check.swift",
    "release regression should run upload-intent contract guard"
)
assertContains(
    releaseQA,
    "archive-media-upload-intent-contract-check.swift",
    "release QA package should include upload-intent contract guard"
)
assertContains(
    statusDoc,
    "对象存储/上传 intent 的 mock 合同",
    "status doc should document upload intent contract"
)

print("Archive media upload intent contract checks passed")
