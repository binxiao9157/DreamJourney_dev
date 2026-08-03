import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let dialogEngine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

for required in [
    "enum VoiceSDKReadinessState",
    "case mockASRTTS",
    "case providerCredentialBlocked",
    "case productionSDKNeedsTrueDeviceQA",
    "struct VoiceSDKReadinessSummary",
    "productionVoiceSDKQualityVerified: Bool",
    "实时语音凭据代理尚未开放",
    "客户端不会使用共享 Provider 密钥",
] {
    require(dialogEngine.contains(required), "voice readiness boundary is missing \(required)")
}

require(
    featureFlags.contains("DJShowVoiceSDKReadinessPreview")
        && featureFlags.contains("#if DEBUG || UI_QA_SIMULATOR"),
    "Voice SDK readiness preview must be registered as a compile-time QA flag"
)

for required in [
    "runUIQAVoiceSDKReadinessPreview",
    "echoVoiceSDKReadinessStatus",
    "handleBlockedRealtimeVoice",
    "echoRealtimeVoiceCredentialBlocked",
] {
    require((echoView + appDelegate).contains(required), "Echo QA readiness boundary is missing \(required)")
}

require(!dialogEngine.contains("VolcEngineAppKey"), "voice SDK must not read a packaged app key")
require(!dialogEngine.contains("VolcEngineAppToken"), "voice SDK must not read a packaged app token")
require(!echoView.contains("startDialogWithLocalVoiceFallback"), "blocked Provider capability must not start a local static fallback")
require(releaseRegression.contains("voice-sdk-readiness-boundary-check.swift"), "release regression must run this guard")
require(releaseQA.contains("voice-sdk-readiness-boundary-check.swift"), "release QA package must include this guard")

print("Voice SDK credential boundary checks passed")
