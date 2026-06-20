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

let scriptPath = "tmp/visual-qa/prd-stitch-ui/run-true-device-archive-audio-preflight.sh"
let statusDocPath = "docs/superpowers/status/2026-06-19-true-device-archive-audio-acceptance.md"

assertFileExists(scriptPath, "true-device archive audio preflight script")
assertFileExists(statusDocPath, "true-device archive audio acceptance status doc")

let script = read(scriptPath)
let statusDoc = read(statusDocPath)
let readinessDoc = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let recorder = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")

for required in [
    "load_local_xcconfig",
    "DreamJourney/Config/VoiceSDK.local.xcconfig",
    "DreamJourney/Config/YXJ.local.xcconfig",
    "-xcconfig",
    "DREAMJOURNEY_DEVELOPMENT_TEAM",
    "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER",
    "xcodebuild -showdestinations",
    "xcrun devicectl list devices",
    "xcrun xctrace list devices",
    "No online physical iPhone/iPad detected",
    "NSMicrophoneUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "DJEnableArchiveHiddenBranches",
    "录入语音",
    "系统设置",
    "前后台",
    "RUN_DEVICE_BUILD",
    "device-build.log",
    "xcodebuild-destinations.txt",
    "devicectl-devices.txt",
    "xctrace-devices.txt",
    "report.md",
    "01-audio-permission-allow.png",
    "02-audio-permission-deny.png",
    "03-audio-permission-recover.png",
    "04-audio-created.png",
    "05-audio-detail-playback.png",
    "06-audio-after-background-foreground.png",
] {
    assertContains(script, required, "true-device archive audio preflight should include \(required)")
}

for required in [
    "DJRunArchiveAudioLifecycleSmoke",
    "runArchiveAudioLifecycleSmoke",
    "archive-audio-lifecycle-smoke-result.json",
    "runUIQAPermissionDeniedRecoverySmoke",
] {
    assertContains(appDelegate + recorder, required, "simulator archive audio lifecycle harness should remain available")
}

assertContains(recorder, "handleMicrophonePermissionDenied", "recorder should keep denied microphone recovery centralized")
assertContains(detail, "AVAudioPlayer(contentsOf:", "detail page should keep local audio playback route")

for required in [
    "语音档案真机前置验收",
    "run-true-device-archive-audio-preflight.sh",
    "run-archive-audio-lifecycle-smoke.sh",
    "DJEnableArchiveHiddenBranches",
    "设备离线",
    "模拟器 smoke 不能替代真机麦克风验收",
    "真实麦克风授权",
    "拒绝",
    "重新授权",
    "录音质量",
    "详情播放路由",
    "前后台切换后文件不丢",
] {
    assertContains(statusDoc, required, "status doc should document \(required)")
}

for required in [
    "run-true-device-archive-audio-preflight.sh",
    "语音档案真机前置验收",
] {
    assertContains(readinessDoc, required, "device readiness doc should mention \(required)")
}

assertContains(
    releaseRegression,
    "true-device-archive-audio-acceptance-check.swift",
    "release regression should run archive audio true-device acceptance guard"
)
assertContains(
    releaseQA,
    "true-device-archive-audio-acceptance-check.swift",
    "release QA package should include archive audio true-device acceptance guard"
)
assertContains(
    releaseQA,
    scriptPath,
    "release QA package should include archive audio true-device preflight script"
)

print("True-device archive audio acceptance checks passed")
