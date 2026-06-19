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

let dialogEngine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let deviceReadiness = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let statusDoc = read("docs/superpowers/status/2026-06-19-production-voice-sdk-readiness-boundary.md")

for required in [
    "enum VoiceSDKReadinessState",
    "case mockASRTTS",
    "case backendTokenFallback",
    "case productionSDKNeedsTrueDeviceQA",
    "struct VoiceSDKReadinessSummary",
    "static func current(",
    "productionVoiceSDKQualityVerified: Bool",
    "isProductionReady",
] {
    assertContains(dialogEngine, required, "DialogEngine should model explicit voice SDK readiness boundary \(required)")
}

for required in [
    "DJShowVoiceSDKReadinessPreview",
    "showVoiceSDKReadinessPreview",
    "runUIQAVoiceSDKReadinessPreview",
    "echoVoiceSDKReadinessStatus",
    "VoiceSDKReadinessSummary.current",
    "生产语音待真机验收",
    "后端 token 不可用，使用本地语音配置",
    "UIQA mock ASR/TTS，仅验证状态机",
] {
    assertContains(echoView + appDelegate + dialogEngine, required, "Echo hidden UIQA should expose readiness boundary \(required)")
}

assertContains(releaseRegression, "voice-sdk-readiness-boundary-check.swift", "release regression should run voice SDK readiness guard")
assertContains(releaseQA, "voice-sdk-readiness-boundary-check.swift", "release QA package should include voice SDK readiness guard")
assertContains(releaseQA, "docs/superpowers/status/2026-06-19-production-voice-sdk-readiness-boundary.md", "release QA package should include voice SDK readiness status doc")

for required in [
    "mock ASR/TTS",
    "后端 token fallback",
    "生产 SDK readiness",
    "不声明生产语音闭环完成",
    "真机验收",
] {
    assertContains(deviceReadiness, required, "device readiness doc should state production voice boundary \(required)")
    assertContains(statusDoc, required, "status doc should state production voice boundary \(required)")
}

print("Voice SDK readiness boundary checks passed")
