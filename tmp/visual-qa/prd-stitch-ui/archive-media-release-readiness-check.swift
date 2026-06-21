import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
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

func substringBetween(_ source: String, start: String, end: String) -> String {
    guard let startRange = source.range(of: start),
          let endRange = source[startRange.upperBound...].range(of: end) else {
        fatalError("Unable to find substring between \(start) and \(end)")
    }
    return String(source[startRange.upperBound..<endRange.lowerBound])
}

let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let options = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let audio = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift")
let video = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveVideoEntryViewController.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let status = read("docs/superpowers/status/2026-06-18-archive-media-release-readiness.md")

assertContains(readiness, "enum MemoryArchiveMediaReleaseReadiness", "archive media release readiness contract must exist")
assertContains(readiness, "static let hiddenBranchesLaunchArgument = \"DJEnableArchiveHiddenBranches\"", "archive media contract must name the QA-only launch argument")
assertContains(readiness, "case .text, .photo:", "text/photo must be the public archive creation baseline")
assertContains(readiness, "case .audio:", "audio readiness must be explicit")
assertContains(readiness, "case .timeLetter:", "time-letter readiness must be explicit")
assertContains(readiness, "case .video:", "video readiness must be explicit")
assertContains(readiness, "feature: .archiveAudioUpload", "audio must stay behind archiveAudioUpload")
assertContains(readiness, "时间信件录入已作为公开档案入口。", "time-letter must be documented as public")
assertContains(readiness, "feature: .archiveVideoUpload", "video must stay behind archiveVideoUpload")
assertContains(readiness, "requiresMicrophonePermission: true", "audio readiness must preserve microphone permission boundary")
assertContains(readiness, "local_file", "audio/photo readiness must document local file persistence")
assertContains(readiness, "local_user_defaults", "text/time-letter readiness must document local user defaults persistence")
assertContains(readiness, "等待视频选择、压缩、缩略图、存储和后端媒体策略确认后再公开。", "video must keep explicit hidden-candidate release boundary")
assertContains(readiness, "视频片段暂为隐藏候选入口", "video must keep non-public release copy")
assertContains(readiness, "local_mock_file", "video hidden QA shell should document mock-file persistence")

assertContains(archive, "MemoryArchiveMediaReleaseReadiness.isCreationVisible", "archive screen must use readiness contract for hidden creation visibility")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument", "archive screen must use the shared hidden launch argument")
assertContains(options, "var options: [MemoryArchiveCreationOption] = [\n            .text,\n            .photo,\n        ]", "creation options must default to text/photo only")
assertContains(options, "isVideoUploadEnabled", "creation options must accept a video hidden-candidate gate")
assertContains(options, "options.append(.video)", "video may appear only when the hidden-candidate gate is enabled")

assertContains(audio, "MicrophonePermissionManager.shared.requestPermission", "audio creation must request microphone permission before recording")
assertContains(audio, "archive-audio", "audio recording must stay in the local archive audio directory")
assertContains(video, "final class MemoryArchiveVideoEntryViewController", "video hidden shell should exist")
assertContains(video, "视频素材暂为隐藏候选入口", "video shell must declare hidden candidate boundary")
assertContains(video, "不会打开系统视频选择、不会上传视频", "video shell must not imply a real picker/upload flow")
assertContains(video, "生成测试视频档案", "video shell should expose hidden QA mock creation")
assertContains(video, "archive-video-entry-shell", "video shell should have stable QA identifier")
assertNotContains(video, "UIImagePickerController", "video shell must not open media picker yet")
assertContains(factory, "\"storage\": \"local_file\"", "media files must declare local file persistence")
assertContains(factory, "\"storage\": \"local_user_defaults\"", "manual text/time-letter records must declare local user defaults persistence")

for hiddenFeature in ["archiveAudioUpload", "archiveVideoUpload", "timeLetters"] {
    assertContains(flags, "case \(hiddenFeature)", "feature flag must declare \(hiddenFeature)")
}
let defaultEnabledBlock = substringBetween(
    flags,
    start: "private static let defaultEnabled: Set<DJFeature> = [",
    end: "]"
)
for hiddenFeature in [".archiveAudioUpload", ".archiveVideoUpload"] {
    assertNotContains(defaultEnabledBlock, hiddenFeature, "media flags must stay out of default release flags")
}
assertContains(defaultEnabledBlock, ".timeLetters", "time-letter should be default public after product decision")

assertContains(project, "MemoryArchiveMediaReleaseReadiness.swift", "readiness contract must be added to the Xcode target")
assertContains(project, "MemoryArchiveVideoEntryViewController.swift in Sources", "video shell must be added to the Xcode target")

assertContains(status, "Audio archive", "status doc must include audio readiness")
assertContains(status, "Time letter", "status doc must include time-letter readiness")
assertContains(status, "Video", "status doc must include video boundary")
assertContains(status, "Hidden ready", "status doc must mark video as hidden ready")
assertContains(status, "archiveVideoUpload", "status doc must document video feature gate")
assertContains(status, "DJEnableArchiveHiddenBranches", "status doc must document hidden QA launch argument")
