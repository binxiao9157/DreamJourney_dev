import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func url(_ relativePath: String) -> URL {
    root.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
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

let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let option = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let metadata = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let hiddenEntries = read("tmp/visual-qa/prd-stitch-ui/release-like-hidden-entries-check.swift")

assertContains(archive, "title: \"语音档案\"", "archive home should expose voice archive as a category card")
assertContains(archive, "detail: \"\\(summary.audio) 段声音\"", "voice archive card should show audio count")
assertContains(archive, "action: #selector(audioCardTapped)", "voice archive card should open category filter")
assertContains(archive, "applyArchiveKindFilter(.audio)", "voice archive card should filter timeline to audio items")
assertContains(archive, "return \"还没有语音档案\"", "voice archive category should have a dedicated empty title")
assertContains(
    archive,
    "语音档案入口已就位，录音创建会在真机录音验收后开放。",
    "voice archive empty state should explain creation is not public yet"
)
assertContains(archive, "guard isArchiveAudioCreationEnabled else", "voice creation should stay gated")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.unavailableCopy(for: .audio)", "release mode should show non-public copy instead of opening recorder")

assertContains(readiness, "feature: .archiveAudioUpload", "voice recording should be tied to the audio upload feature flag")
assertContains(readiness, "DJEnableArchiveHiddenBranches", "voice recording should also be available only in QA hidden branches")
assertContains(readiness, "requiresMicrophonePermission: true", "voice recording should declare microphone permission dependency")
assertContains(readiness, "等待真机麦克风、权限拒绝恢复和音频播放验收后再公开。", "release reason should document true-device gate")
assertContains(option, "title: \"录入语音\"", "voice recording option should remain explicitly named")

assertContains(item, "case audio", "archive item model should support audio kind")
assertContains(item, "return \"已根据声音说明整理语气、称呼与情绪线索。\"", "audio analysis should have a voice-specific summary")
assertContains(item, "return [\"语音档案\", \"语气线索\"]", "audio analysis should tag voice clues")
assertContains(metadata, "return \"声音片段\"", "audio detail metadata should name the media section")
assertContains(metadata, "return archiveListMetadataSummary ?? \"记录语气、称呼与情绪线索\"", "audio detail metadata should explain voice clues")

assertContains(detail, "case .audio:", "archive detail should branch for audio items")
assertContains(detail, "return makeAudioMediaCard()", "archive detail should render an audio media card")
assertContains(detail, "private func makeAudioMediaCard() -> UIView?", "archive detail should own audio card structure")
assertContains(detail, "guard item.localPath != nil else { return nil }", "audio detail should avoid broken playback without a local file")
assertContains(detail, "playButton.setImage(UIImage(systemName: \"play.fill\")", "audio detail should show a play affordance")
assertContains(detail, "@objc private func playAudioTapped()", "audio detail should handle playback")
assertContains(detail, "AVAudioPlayer(contentsOf:", "audio detail should use local audio playback")
assertContains(detail, "private func audioDurationText()", "audio detail should expose duration structure")

assertContains(matrix, "| Archive | Audio upload / `录入语音` |", "release matrix should keep audio upload hidden by default")
assertContains(hiddenEntries, "FeatureFlagService.shared.isEnabled(.archiveAudioUpload)", "hidden-entry guard should protect voice recording flag")
assertContains(hiddenEntries, "DJEnableArchiveHiddenBranches", "hidden-entry guard should protect QA-only archive branches")
assertContains(releaseRegression, "archive-audio-ia-release-check.swift", "release regression should run voice archive IA guard")
assertContains(releaseQA, "archive-audio-ia-release-check.swift", "release QA package should include voice archive IA guard")

print("Archive audio IA release checks passed")
