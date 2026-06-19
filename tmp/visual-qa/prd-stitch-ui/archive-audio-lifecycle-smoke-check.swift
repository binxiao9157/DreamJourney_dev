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

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: url(relativePath).path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let recorder = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let factory = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let scriptPath = "tmp/visual-qa/prd-stitch-ui/run-archive-audio-lifecycle-smoke.sh"

assertFileExists(scriptPath, "archive audio lifecycle smoke script")
let script = read(scriptPath)

assertContains(appDelegate, "DJRunArchiveAudioLifecycleSmoke", "App delegate should expose archive audio lifecycle smoke launch argument")
assertContains(appDelegate, "runArchiveAudioLifecycleSmoke", "App delegate should run archive audio lifecycle smoke")
assertContains(appDelegate, "writeArchiveAudioLifecycleSmokeResult", "Archive audio lifecycle smoke should write pollable JSON")
assertContains(appDelegate, "archive-audio-lifecycle-smoke-result.json", "Archive audio lifecycle smoke result file should be stable")
assertContains(appDelegate, "makeUIQAArchiveAudioFile", "Archive audio lifecycle smoke should generate a local QA audio file")
assertContains(appDelegate, "AVAudioFile(forWriting:", "Archive audio lifecycle smoke should write a real audio file")
assertContains(appDelegate, "AVAudioPCMBuffer", "Archive audio lifecycle smoke should write audio samples")
assertContains(appDelegate, "MemoryArchiveItemFactory.makeAudioItem", "Archive audio lifecycle smoke should use the production audio item factory")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(audioItem, syncToBackend: false)", "Archive audio lifecycle smoke should save through the production repository without backend sync")
assertContains(appDelegate, "MemoryArchiveRepository.shared.allItems()", "Archive audio lifecycle smoke should reload persisted archive state")
assertContains(appDelegate, "MemoryArchiveDetailViewController(item:", "Archive audio lifecycle smoke should instantiate the real detail page")
assertContains(appDelegate, "AVAudioPlayer(contentsOf:", "Archive audio lifecycle smoke should verify local playback can load")
assertContains(appDelegate, "\"permissionDeniedRecoveryReady\"", "Archive audio lifecycle result should report permission-denied recovery")
assertContains(appDelegate, "\"audioFileExists\"", "Archive audio lifecycle result should report file persistence")
assertContains(appDelegate, "\"restoredAudioItem\"", "Archive audio lifecycle result should report repository restore")
assertContains(appDelegate, "\"detailPlaybackLoadable\"", "Archive audio lifecycle result should report detail playback readiness")
assertContains(appDelegate, "\"contextIncludesAudio\"", "Archive audio lifecycle result should report echo-context availability")

assertContains(recorder, "handleMicrophonePermissionDenied", "Recorder should centralize denied-permission recovery")
assertContains(recorder, "runUIQAPermissionDeniedRecoverySmoke", "Recorder should expose UIQA denied-permission recovery smoke")
assertContains(recorder, "录音需要麦克风权限", "Recorder should show a recoverable denied-permission state")
assertContains(detail, "AVAudioPlayer(contentsOf:", "Archive detail should load local audio with AVAudioPlayer")
assertContains(factory, "\"source\": \"manual_audio\"", "Audio factory should mark manual audio source")

assertContains(script, "DJRunArchiveAudioLifecycleSmoke", "Smoke script should launch archive audio lifecycle harness")
assertContains(script, "DJEnableArchiveHiddenBranches", "Smoke script should run hidden QA archive branches")
assertContains(script, "archive-audio-lifecycle-smoke-result.json", "Smoke script should poll result JSON")
assertContains(script, "\"permissionDeniedRecoveryReady\"", "Smoke script should validate denied-permission recovery")
assertContains(script, "\"audioFileExists\"", "Smoke script should validate saved audio file")
assertContains(script, "\"restoredAudioItem\"", "Smoke script should validate persisted item restore")
assertContains(script, "\"detailPlaybackLoadable\"", "Smoke script should validate playback loadability")
assertContains(script, "\"contextIncludesAudio\"", "Smoke script should validate archive context availability")
assertContains(script, "simctl io", "Smoke script should capture simulator screenshot")

assertContains(releaseRegression, "archive-audio-lifecycle-smoke-check.swift", "release regression should run audio lifecycle static guard")
assertContains(releaseQA, "archive-audio-lifecycle-smoke-check.swift", "release QA package should include audio lifecycle static guard")

print("Archive audio lifecycle smoke checks passed")
