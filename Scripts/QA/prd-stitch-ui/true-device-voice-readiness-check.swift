import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertFileExists(_ relativePath: String, _ message: String) {
    let url = rootURL.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        fatalError(message)
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let plist = read("DreamJourney/Resources/Info.plist")
let gitignore = read(".gitignore")
let dialogEngine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let readinessDoc = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let coverage = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")
let voiceExamplePath = "DreamJourney/Config/VoiceSDK.example.xcconfig"
let preflightScriptPath = "Scripts/QA/prd-stitch-ui/run-true-device-voice-preflight.sh"

assertFileExists(voiceExamplePath, "Voice SDK boundary note should exist")
assertFileExists(preflightScriptPath, "True-device voice preflight script should exist")

let voiceExample = read(voiceExamplePath)
let preflightScript = read(preflightScriptPath)

assertContains(
    plist,
    "<key>DreamJourneyBackendBaseURL</key>",
    "Info.plist should retain the non-secret backend base URL setting"
)

for retiredKey in [
    "VolcEngineAppKey",
    "VolcEngineAppToken",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN",
] {
    assertNotContains(plist, retiredKey, "Info.plist must not package mobile Provider credentials")
}

assertContains(
    gitignore,
    "DreamJourney/Config/*.local.xcconfig",
    "Local signing configuration should stay ignored"
)

for required in [
    "Direct mobile Provider credential injection is retired.",
    "scoped session broker contract",
] {
    assertContains(voiceExample, required, "Voice SDK example should document the current boundary")
}

for retiredCredential in [
    "VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN",
] {
    assertNotContains(
        voiceExample,
        retiredCredential,
        "Voice SDK example must not instruct direct Provider credential injection"
    )
}

for required in [
    "load_local_xcconfig",
    "DreamJourney/Config/Backend.local.xcconfig",
    "DreamJourney/Config/YXJ.local.xcconfig",
    "-xcconfig",
    "DREAMJOURNEY_DEVELOPMENT_TEAM",
    "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "NSMicrophoneUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "xcodebuild -showdestinations",
    "xcrun devicectl list devices",
    "xcrun xctrace list devices",
    "No online physical iPhone/iPad detected",
    "-allowProvisioningUpdates",
    "true-device-acceptance",
] {
    assertContains(preflightScript, required, "True-device preflight should check \(required)")
}

for retiredCredential in [
    "VoiceSDK.local.xcconfig",
    "VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
] {
    assertNotContains(
        preflightScript,
        retiredCredential,
        "True-device preflight must not accept a mobile credential build setting"
    )
}

for required in [
    "enum VoiceSDKReadinessState",
    "case providerCredentialBlocked",
    "productionConfigurationMissing",
    "runtimeConfig.mobileDirectAllowed",
    "runtimeConfig.accessPath == \"scopedSessionCredential\"",
    "!runtimeConfig.isBlocked",
] {
    assertContains(dialogEngine, required, "DialogEngine should fail closed at the voice credential boundary")
}

for retiredAccessPath in [
    "VolcEngineAppKey",
    "VolcEngineAppToken",
    "func configure(token: String)",
] {
    assertNotContains(
        dialogEngine,
        retiredAccessPath,
        "DialogEngine must not restore direct Provider credential injection"
    )
}

for required in [
    "移动端不再注入火山 Provider 密钥",
    "scoped session broker",
    "run-true-device-voice-preflight.sh",
    "生产语音 SDK",
    "真机验收",
    "APNs provider delivery",
] {
    assertContains(readinessDoc, required, "Readiness doc should describe the current true-device boundary")
}

assertContains(
    coverage,
    "生产语音 SDK",
    "PRD coverage should keep production voice SDK as an external gate"
)

print("True-device and production voice readiness checks passed")
