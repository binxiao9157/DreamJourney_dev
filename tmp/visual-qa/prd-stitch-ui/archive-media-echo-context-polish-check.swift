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

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let display = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-media-echo-context-polish.md")

for required in [
    "var metadataTranscriptTextForDisplay: String?",
    "var metadataFileSizeDisplayName: String?",
    "var videoAnalysisStatusDisplayName: String?",
    "var audioTranscriptionStatusDisplayName: String?",
    "var isSealedTimeLetter: Bool",
    "var echoContextText: String?",
    "var echoContextAllowsClues: Bool",
] {
    assertContains(item, required, "archive item should expose media/Echo context helpers \(required)")
}

for required in [
    "metadataTranscriptTextForDisplay",
    "metadataFileSizeDisplayName",
    "videoAnalysisStatusDisplayName",
    "audioTranscriptionStatusDisplayName",
    "动态影像",
    "转写失败，可重试",
] {
    assertContains(display, required, "display metadata should expose video/audio polish \(required)")
}

for required in [
    "makeVideoMediaMetaStrip()",
    "archive-video-meta-strip",
    "archive-video-file-size",
    "archive-video-analysis-state",
    "makeAudioTranscriptCard()",
    "archive-audio-transcript-card",
    "archive-audio-transcription-state",
    "archive-audio-transcription-retry-copy",
    "mock 视频失败/重试",
] {
    assertContains(detail, required, "detail UI should expose video/audio non-device states \(required)")
}

for required in [
    "guard !isTimeLetterDraft else { return false }",
    "let contextText = echoContextText",
    "echoContextAllowsClues",
    "case .audio:",
    "case .video:",
    "case .timeLetter:",
] {
    assertContains(repository, required, "Archive -> Echo context should filter media/timeLetter rules \(required)")
}

for required in [
    "transcriptionStatus: ArchiveMediaTranscriptionStatus = .notRequested",
    "analysisStatus: MemoryArchiveAnalysisStatus = .pending",
    "uploadStatus: ArchiveMediaUploadStatus = .localOnly",
] {
    assertContains(factory, required, "factory should allow fake audio/video status payloads \(required)")
}

for required in [
    "archive-media-echo-context-polish-check.swift",
    "2026-06-19-archive-media-echo-context-polish.md",
] {
    assertContains(releaseRegression, required, "release regression should include media Echo context polish guard \(required)")
}
assertContains(
    releaseQA,
    "archive-media-echo-context-polish-check.swift",
    "release QA package should include media Echo context polish guard"
)

for required in [
    "视频档案详情/列表 polish",
    "语音档案详情非真机增强",
    "档案媒体进入 Echo 上下文规则",
] {
    assertContains(statusDoc, required, "status doc should describe \(required)")
}

print("Archive media Echo context polish checks passed")
