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
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let projectYML = read("project.yml")
let dialogEngine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let readinessDoc = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let coverage = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")

let voiceExamplePath = "DreamJourney/Config/VoiceSDK.example.xcconfig"
let preflightScriptPath = "tmp/visual-qa/prd-stitch-ui/run-true-device-voice-preflight.sh"
assertFileExists(voiceExamplePath, "Voice SDK example xcconfig should exist")
assertFileExists(preflightScriptPath, "True-device voice preflight script should exist")

let voiceExample = read(voiceExamplePath)
let preflightScript = read(preflightScriptPath)

for required in [
    "<key>VolcEngineAppID</key>",
    "<string>$(VOLCENGINE_APP_ID)</string>",
    "<key>VolcEngineAppKey</key>",
    "<string>$(VOLCENGINE_APP_KEY)</string>",
    "<key>VolcEngineAppToken</key>",
    "<string>$(VOLCENGINE_APP_TOKEN)</string>",
] {
    assertContains(plist, required, "Info.plist should inject production voice SDK config through build settings")
}

for forbidden in [
    "<string>YOUR_VOLCENGINE_APP_ID</string>",
    "<string>YOUR_VOLCENGINE_APP_KEY</string>",
    "<string>YOUR_VOLCENGINE_APP_TOKEN</string>",
] {
    assertNotContains(plist, forbidden, "Info.plist should not hard-code voice SDK placeholders")
}

assertContains(
    gitignore,
    "DreamJourney/Config/VoiceSDK.local.xcconfig",
    "Local voice SDK config should stay ignored"
)
assertContains(
    gitignore,
    "DreamJourney/Config/*.local.xcconfig",
    "All local xcconfig files, including signing overrides, should stay ignored"
)

for required in [
    "DreamJourney/Config/YXJ.local.xcconfig",
    "-xcconfig",
    "DREAMJOURNEY_DEVELOPMENT_TEAM",
    "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER",
] {
    assertContains(preflightScript, required, "True-device voice preflight should apply local signing override \(required)")
}

for required in [
    "VOLCENGINE_APP_ID = YOUR_VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY = YOUR_VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN = YOUR_VOLCENGINE_APP_TOKEN",
] {
    assertContains(voiceExample, required, "Voice SDK example should document \(required)")
    assertContains(project, required + ";", "Xcode project should default \(required)")
}

for required in [
    "VOLCENGINE_APP_ID: YOUR_VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY: YOUR_VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN: YOUR_VOLCENGINE_APP_TOKEN",
] {
    assertContains(projectYML, required, "XcodeGen project should default \(required)")
}

for required in [
    "var isProductionReady: Bool",
    "productionConfigurationMissing",
    "guard config.isProductionReady else",
    "YOUR_VOLCENGINE_APP_ID",
    "YOUR_VOLCENGINE_APP_KEY",
    "YOUR_VOLCENGINE_APP_TOKEN",
    "$(",
] {
    assertContains(dialogEngine, required, "DialogEngine should fail early when voice SDK config is not production-ready")
}

for required in [
    "load_local_xcconfig",
    "DreamJourney/Config/Backend.local.xcconfig",
    "DreamJourney/Config/VoiceSDK.local.xcconfig",
    "[[ \"$line\" == //* || \"$line\" == \\#* ]] && continue",
    "xcodebuild -showdestinations",
    "xcrun xctrace list devices",
    "No online physical iPhone/iPad detected",
    "VOLCENGINE_APP_ID",
    "VOLCENGINE_APP_KEY",
    "VOLCENGINE_APP_TOKEN",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "NSMicrophoneUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "xcodebuild -workspace DreamJourney.xcworkspace",
    "true-device-acceptance",
] {
    assertContains(preflightScript, required, "True-device preflight should check \(required)")
}

for required in [
    "VoiceSDK.example.xcconfig",
    "VoiceSDK.local.xcconfig",
    "run-true-device-voice-preflight.sh",
    "生产语音 SDK",
    "真机验收",
    "APNs provider delivery",
] {
    assertContains(readinessDoc, required, "Readiness doc should mention \(required)")
}

assertContains(
    coverage,
    "生产语音 SDK",
    "PRD coverage should keep production voice SDK as an external gate"
)

print("True-device and production voice readiness checks passed")
