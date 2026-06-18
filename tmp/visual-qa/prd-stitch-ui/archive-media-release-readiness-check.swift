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

let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let options = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let audio = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift")
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
assertContains(readiness, "feature: .timeLetters", "time-letter must stay behind timeLetters")
assertContains(readiness, "requiresMicrophonePermission: true", "audio readiness must preserve microphone permission boundary")
assertContains(readiness, "local_file", "audio/photo readiness must document local file persistence")
assertContains(readiness, "local_user_defaults", "text/time-letter readiness must document local user defaults persistence")
assertContains(readiness, "视频素材录入将在后续开放", "video must remain unavailable with explicit copy")

assertContains(archive, "MemoryArchiveMediaReleaseReadiness.isCreationVisible", "archive screen must use readiness contract for hidden creation visibility")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument", "archive screen must use the shared hidden launch argument")
assertContains(options, "var options: [MemoryArchiveCreationOption] = [\n            .text,\n            .photo,\n        ]", "creation options must default to text/photo only")
assertNotContains(options, "options.append(.video)", "video must not appear in creation options")

assertContains(audio, "MicrophonePermissionManager.shared.requestPermission", "audio creation must request microphone permission before recording")
assertContains(audio, "archive-audio", "audio recording must stay in the local archive audio directory")
assertContains(factory, "\"storage\": \"local_file\"", "media files must declare local file persistence")
assertContains(factory, "\"storage\": \"local_user_defaults\"", "manual text/time-letter records must declare local user defaults persistence")

for hiddenFeature in ["archiveAudioUpload", "timeLetters"] {
    assertContains(flags, "case \(hiddenFeature)", "feature flag must declare \(hiddenFeature)")
}
assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .careDashboard,\n        .profileSettings,\n        .legalCenter,\n    ]", "audio and time-letter flags must stay out of default release flags")

assertContains(project, "MemoryArchiveMediaReleaseReadiness.swift", "readiness contract must be added to the Xcode target")

assertContains(status, "Audio archive", "status doc must include audio readiness")
assertContains(status, "Time letter", "status doc must include time-letter readiness")
assertContains(status, "Video", "status doc must include video boundary")
assertContains(status, "DJEnableArchiveHiddenBranches", "status doc must document hidden QA launch argument")
