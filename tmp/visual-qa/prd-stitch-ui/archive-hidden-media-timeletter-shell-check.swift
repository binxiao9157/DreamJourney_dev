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

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let textEntry = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift")
let videoEntry = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveVideoEntryViewController.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let mediaReadinessGuard = read("tmp/visual-qa/prd-stitch-ui/archive-media-release-readiness-check.swift")
let hiddenStatusDoc = read("docs/superpowers/status/2026-06-19-archive-hidden-media-timeletter-shell.md")
let timeLetterStatusDoc = read("docs/superpowers/status/2026-06-21-time-letter-public-delivery.md")
let backendTests = read("tests/test_core_services.py", in: backendRoot)

for required in [
    "static func makeTimeLetterDraft(",
    "static func makeTimeLetter(",
    "openAt: Date",
    "recipients: [TimeLetterRecipientSelection]",
    "imageLocalPath: String?",
    "scheduled_local_and_in_app",
] {
    assertContains(factory, required, "time-letter factory should expose public draft/sealed contract \(required)")
}

for required in [
    "var onSaveDraftTimeLetter",
    "var onSaveTimeLetter",
    "TimeLetterEntryPayload",
    "UIDatePicker",
    "UIImagePickerController",
    "保存草稿",
    "封存时间信件",
    "time-letter-draft-button",
] {
    assertContains(textEntry, required, "time-letter entry should expose public draft/seal UI \(required)")
}

for required in [
    "entryViewController.onSaveDraftTimeLetter",
    "entryViewController.onSaveTimeLetter",
    "MemoryArchiveItemFactory.makeTimeLetterDraft",
    "MemoryArchiveItemFactory.makeTimeLetter(",
    "entryViewController.onCreateMockVideoArchive",
    "makeHiddenQAMockVideoArchiveItem",
    "MemoryArchiveItemFactory.makeVideoItem",
] {
    assertContains(archive, required, "archive hidden branches should wire \(required)")
}

for required in [
    "var onCreateMockVideoArchive: (() -> Void)?",
    "生成测试视频档案",
    "archive-video-entry-generate-mock",
    "mock 视频档案",
    "不会打开系统视频选择",
] {
    assertContains(videoEntry, required, "video hidden shell should allow mock-file QA creation \(required)")
}
assertNotContains(videoEntry, "UIImagePickerController", "video shell must still avoid the real video picker")

for required in [
    "MemoryArchiveMediaReleaseReadiness.audioFileSizeLimitMB",
    "backendStorageContract",
    "transcriptText",
    "MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB",
] {
    assertContains(factory, required, "media factories should emit non-device backend shell metadata \(required)")
}

for required in [
    "信件状态",
    "打开时间",
    "收件人",
    "提醒",
    "草稿",
    "已封存",
] {
    assertContains(display, required, "archive detail should display time-letter public metadata \(required)")
}

assertContains(readiness, "persistence: \"local_mock_file\"", "video readiness should document mock-file persistence")
assertContains(mediaReadinessGuard, "local_mock_file", "release readiness guard should track video mock-file boundary")
assertContains(mediaReadinessGuard, "生成测试视频档案", "release readiness guard should allow hidden mock video creation")

for required in [
    "DJRunArchiveHiddenShellSmoke",
    "runArchiveHiddenShellSmoke",
    "makeUIQAArchiveMockVideoFile",
    "makeUIQAArchiveMockThumbnailFile",
    "writeArchiveHiddenShellSmokeResult",
] {
    assertContains(appDelegate, required, "UIQA hidden shell smoke should expose \(required)")
}

assertContains(
    releaseRegression,
    "archive-hidden-media-timeletter-shell-check.swift",
    "release regression should run hidden shell static guard"
)
assertContains(
    releaseRegression,
    "RUN_ARCHIVE_HIDDEN_SHELL_SMOKE",
    "release regression should expose hidden shell simulator smoke gate"
)
assertContains(
    releaseQA,
    "archive-hidden-media-timeletter-shell-check.swift",
    "release QA package should include hidden shell guard"
)
assertContains(
    hiddenStatusDoc,
    "语音档案非真机部分",
    "status doc should document hidden audio shell scope"
)
assertContains(
    hiddenStatusDoc,
    "视频档案非真机部分",
    "status doc should document hidden video shell scope"
)
assertContains(
    timeLetterStatusDoc,
    "时间信件公开投递闭环",
    "status doc should document public time-letter scope"
)
assertContains(
    backendTests,
    "test_archive_items_api_persists_time_letter_shell_contract",
    "backend tests should pin time-letter archive shell contract"
)
assertContains(
    backendTests,
    "sealed timeLetter cannot be deleted",
    "backend time-letter shell contract should reject sealed deletion"
)

print("Archive hidden media/time-letter shell checks passed")
