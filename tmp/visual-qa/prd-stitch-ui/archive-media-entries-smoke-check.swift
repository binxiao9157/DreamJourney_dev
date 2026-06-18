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

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let script = read("tmp/visual-qa/prd-stitch-ui/run-archive-media-entries-smoke.sh")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let option = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let status = read("docs/superpowers/status/2026-06-18-archive-media-release-readiness.md")

assertContains(appDelegate, "DJRunArchiveMediaEntriesSmoke", "archive media entries smoke launch argument")
assertContains(appDelegate, "runArchiveMediaEntriesSmoke()", "archive media entries smoke runner")
assertContains(appDelegate, "writeArchiveMediaEntriesSmokeResult", "archive media entries smoke should write pollable JSON")
assertContains(appDelegate, "archive-media-entries-smoke-result.json", "archive media entries smoke result file")
assertContains(appDelegate, "[UI_QA] ArchiveMediaEntriesSmoke completed", "archive media entries smoke completion log")
assertContains(appDelegate, "MemoryArchiveMediaReleaseReadiness.isCreationVisible", "smoke should verify the same release readiness contract as UI")
assertContains(appDelegate, "MemoryArchiveCreationOption.availableOptions", "smoke should verify creation option output")

assertContains(script, "DJRunArchiveMediaEntriesSmoke", "script should launch archive media entries smoke")
assertContains(script, "SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'", "script must build UIQA variant")
assertContains(script, "archive-media-entries-smoke-result.json", "script must poll result JSON")
assertContains(script, "\"releaseOptionTitles\"", "script must validate release option titles")
assertContains(script, "\"hiddenOptionTitles\"", "script must validate hidden option titles")
assertContains(script, "添加文字描述", "script must validate text option")
assertContains(script, "选择照片", "script must validate photo option")
assertContains(script, "录入语音", "script must validate hidden audio option")
assertContains(script, "录入时间信件", "script must validate hidden time-letter option")
assertContains(script, "录入视频片段", "script must validate hidden video option")
assertContains(script, "\"releaseVideoVisible\"[[:space:]]*:[[:space:]]*false", "script must ensure video stays hidden in release mode")
assertContains(script, "\"hiddenVideoVisible\"[[:space:]]*:[[:space:]]*true", "script must ensure video is available only in hidden QA mode")
assertContains(script, "simctl io", "script should save simulator screenshot evidence")

assertContains(readiness, "hiddenBranchesLaunchArgument", "readiness contract still names hidden branch arg")
assertContains(readiness, "archiveVideoUpload", "readiness contract should include video hidden-candidate gate")
assertContains(option, "availableOptions", "creation options remain centralized")
assertContains(status, "run-archive-media-entries-smoke.sh", "status doc should document the media entries smoke script")
