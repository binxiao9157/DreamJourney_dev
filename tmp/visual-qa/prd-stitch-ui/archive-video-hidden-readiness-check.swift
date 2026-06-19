import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
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

let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let videoEntry = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveVideoEntryViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let hiddenShellRunner = read("tmp/visual-qa/prd-stitch-ui/run-archive-hidden-shell-smoke.sh")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-video-hidden-readiness.md")

for required in [
    "archive-video-timeline-card",
    "archive-video-timeline-metadata",
    "archive-video-timeline-thumbnail",
    "archive-video-timeline-placeholder",
    "UIImage(contentsOfFile: thumbnailPath)",
] {
    assertContains(archive, required, "archive timeline should identify video readiness \(required)")
}
assertNotContains(videoEntry, "UIImagePickerController", "archive hidden video readiness must not open real video picker")

for required in [
    "MemoryArchiveMediaReleaseReadiness.videoFileSizeLimitMB",
    "MemoryArchiveItem.mediaThumbnailPathMetadataKey",
    "MemoryArchiveItem.mediaFileSizeBytesMetadataKey",
    "MemoryArchiveItem.mediaUploadStatusMetadataKey",
    "thumbnailStatus",
    "analysisStatus: MemoryArchiveAnalysisStatus = .pending",
    "uploadStatus: ArchiveMediaUploadStatus = .localOnly",
] {
    assertContains(factory, required, "video factory should keep mock readiness fields \(required)")
}

for required in [
    "archive-video-media-card",
    "archive-video-thumbnail-image",
    "archive-video-media-placeholder",
    "archive-video-file-size",
    "archive-video-analysis-state",
    "archive-hidden-media-failed-state",
    "archive-hidden-media-retry-copy",
    "重新上传",
] {
    assertContains(detail, required, "video detail should expose readiness states \(required)")
}

for required in [
    "persistence: \"local_mock_file\"",
    "videoFileSizeLimitMB = 200",
    "archiveVideoUpload",
] {
    assertContains(readiness, required, "video readiness contract should stay hidden/mock \(required)")
}
assertContains(videoEntry, "不会打开系统视频选择", "video entry should explicitly avoid the real video picker")

for required in [
    "videoTimelineThumbnailVisible",
    "videoTimelinePlaceholderVisible",
    "archiveHomeViewContainsIdentifier",
    "archive-video-timeline-thumbnail",
    "archive-video-timeline-placeholder",
] {
    assertContains(appDelegate, required, "hidden shell UIQA should verify video timeline readiness \(required)")
}

for required in [
    "\"videoTimelineThumbnailVisible\"",
    "\"videoTimelinePlaceholderVisible\"",
] {
    assertContains(hiddenShellRunner, required, "hidden shell runner should assert video timeline readiness \(required)")
}

assertContains(
    releaseRegression,
    "archive-video-hidden-readiness-check.swift",
    "release regression should run video hidden readiness guard"
)
assertContains(
    releaseQA,
    "archive-video-hidden-readiness-check.swift",
    "release QA package should include video hidden readiness guard"
)

for required in [
    "视频档案 Hidden Readiness",
    "mock 视频详情",
    "缩略图占位",
    "文件大小",
    "上传状态",
    "分析失败/重试",
    "不做真实视频选择和压缩",
] {
    assertContains(statusDoc, required, "status doc should document video hidden readiness \(required)")
}

print("Archive video hidden readiness checks passed")
