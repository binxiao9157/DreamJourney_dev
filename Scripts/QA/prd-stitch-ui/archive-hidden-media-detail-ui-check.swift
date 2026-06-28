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

let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let hiddenShellRunner = read("Scripts/QA/prd-stitch-ui/run-archive-hidden-shell-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-hidden-media-detail-ui.md")

for required in [
    "makeHiddenMediaStateCard",
    "archive-hidden-media-state-card",
    "archive-hidden-media-empty-state",
    "媒体文件待补充",
    "archive-hidden-media-local-state",
    "媒体文件仅保存在本地",
    "archive-hidden-media-uploaded-state",
    "媒体元数据已同步",
    "archive-hidden-media-failed-state",
    "上传失败，可重新同步",
    "archive-hidden-media-retry-copy",
] {
    assertContains(detail, required, "hidden media detail should expose \(required)")
}

for required in [
    "makeVideoMediaCard",
    "archive-video-media-card",
    "archive-video-thumbnail-image",
    "archive-video-thumbnail-overlay",
    "archive-video-media-placeholder",
    "overlayView.isHidden = !hasThumbnail",
    "视频待补充",
] {
    assertContains(detail, required, "video detail shell should expose \(required)")
}

for required in [
    "makeTimeLetterStateCard",
    "archive-time-letter-state-card",
    "archive-time-letter-draft-state",
    "草稿未封存",
    "archive-time-letter-sealed-state",
    "已封存，不可删除或修改",
    "本地通知 + 应用内提醒",
    "archive-time-letter-empty-body",
] {
    assertContains(detail, required, "time-letter detail should expose \(required)")
}

for required in [
    "本地待上传",
    "上传中",
    "已上传",
    "上传失败",
] {
    assertContains(display, required, "display metadata should keep upload status label \(required)")
}

for required in [
    "mediaDetailEmptyStateVisible",
    "mediaDetailFailedStateVisible",
    "mediaDetailRetryActionVisible",
    "audioDetailEmptyStateVisible",
    "audioDetailTranscriptionFailedStateVisible",
    "audioDetailTranscriptionRetryVisible",
    "videoDetailThumbnailPlaceholderVisible",
    "videoDetailFailedStateVisible",
    "videoDetailRetryActionVisible",
    "timeLetterDraftDetailVisible",
    "timeLetterSealedDetailVisible",
    "timeLetterEmptyBodyVisible",
    "renderArchiveDetailSnapshot",
    "writeArchiveHiddenShellDetailSnapshots",
    "archive-hidden-audio-empty-detail.png",
    "archive-hidden-audio-transcription-failed-detail.png",
    "archive-hidden-video-failed-detail.png",
    "archive-hidden-time-letter-draft-detail.png",
    "archive-hidden-time-letter-sealed-detail.png",
    "timeLetterDraftActionsVisible",
    "timeLetterSealedStateVisible",
    "releaseHiddenEntryPointsBlocked",
    "archiveDetailViewContainsIdentifier",
    "archiveDetailViewContainsText",
] {
    assertContains(appDelegate, required, "hidden shell smoke should verify detail UI \(required)")
}

for required in [
    "\"mediaDetailEmptyStateVisible\"",
    "\"mediaDetailFailedStateVisible\"",
    "\"mediaDetailRetryActionVisible\"",
    "\"audioDetailEmptyStateVisible\"",
    "\"audioDetailTranscriptionFailedStateVisible\"",
    "\"audioDetailTranscriptionRetryVisible\"",
    "\"videoDetailThumbnailPlaceholderVisible\"",
    "\"videoDetailFailedStateVisible\"",
    "\"videoDetailRetryActionVisible\"",
    "\"timeLetterDraftDetailVisible\"",
    "\"timeLetterSealedDetailVisible\"",
    "\"timeLetterEmptyBodyVisible\"",
    "archive-hidden-audio-empty-detail.png",
    "archive-hidden-audio-transcription-failed-detail.png",
    "archive-hidden-video-failed-detail.png",
    "archive-hidden-time-letter-draft-detail.png",
    "archive-hidden-time-letter-sealed-detail.png",
    "\"timeLetterDraftActionsVisible\"",
    "\"timeLetterSealedStateVisible\"",
    "\"timeLetterReminderPolicyVisible\"",
    "\"releaseHiddenEntryPointsBlocked\"",
] {
    assertContains(hiddenShellRunner, required, "hidden shell runner should assert \(required)")
}

assertContains(
    releaseRegression,
    "archive-hidden-media-detail-ui-check.swift",
    "release regression should run hidden media detail UI guard"
)
assertContains(
    releaseQA,
    "archive-hidden-media-detail-ui-check.swift",
    "release QA package should include hidden media detail UI guard"
)
assertContains(
    statusDoc,
    "隐藏媒体详情 UI",
    "status doc should document hidden media detail UI scope"
)
assertContains(
    statusDoc,
    "公开 release 不误暴露",
    "status doc should document release non-exposure"
)

print("Archive hidden media detail UI checks passed")
