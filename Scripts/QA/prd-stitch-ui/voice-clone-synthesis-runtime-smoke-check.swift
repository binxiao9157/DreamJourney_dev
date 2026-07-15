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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let runner = "Scripts/QA/prd-stitch-ui/run-voice-clone-synthesis-runtime-smoke.sh"
assertFileExists(runner, "voice clone synthesis runtime smoke runner")

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let runnerContent = read(runner)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "DJRunVoiceCloneSynthesisRuntimeSmoke",
    "DJVoiceCloneProbeProfileId=",
    "DJVoiceCloneProbeUserId=",
    "runVoiceCloneSynthesisRuntimeSmoke()",
    "fetchVoiceCloneRuntimeCapability",
    "capability.canSynthesize",
    "capability.tencentAudioDrive.supported",
    "DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(",
    "outputMode: capability.tencentAudioDrive.requestOutputMode",
    "synthesis.isTencentAudioDrivePCMCompatible",
    "synthesis.tencentAudioDrivePCMData",
    "voice-clone-synthesis-runtime-smoke-result.json",
] {
    assertContains(appDelegate, required, "AppDelegate should implement voice clone synthesis runtime smoke \(required)")
}
assertNotContains(
    appDelegate,
    "print(synthesis.audioBase64)",
    "iOS synthesis smoke must not print raw audio"
)

for required in [
    "DJRunVoiceCloneSynthesisRuntimeSmoke",
    "DJVoiceCloneProbeProfileId=",
    "VOICE_CLONE_READY_PROFILE_ID",
    "DJVoiceCloneProbeUserId=",
    "VOICE_CLONE_READY_PROFILE_USER_ID",
    "LOCAL_BUNDLE_ID",
    "LOCAL_DEVELOPMENT_TEAM",
    "resolve_deployed_backend_config",
    "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=\"$LOCAL_BUNDLE_ID\"",
    "DREAMJOURNEY_DEVELOPMENT_TEAM=\"$LOCAL_DEVELOPMENT_TEAM\"",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "QA_MOBILE_CREDENTIAL_APP_PATH",
    "product-v4-qa-mobile-credential-artifact-check.py",
    "[[ \"$BUNDLE_ID\" == \"$LOCAL_BUNDLE_ID\" ]]",
    "[[ \"$BUNDLE_ID\" != \"com.gaominge.dreamjourney.app\" ]]",
    "voice-clone-synthesis-runtime-smoke-result.json",
    "\"completed\"",
    "\"pcmCompatible\"",
    "\"audioDataOmitted\"",
] {
    assertContains(runnerContent, required, "runner should verify iOS synthesis smoke \(required)")
}
assertNotContains(runnerContent, "DREAMJOURNEY_BACKEND_API_TOKEN", "runner must not inject a server compatibility token into iOS")
assertNotContains(runnerContent, "DreamJourneyBackendAPIToken", "runner must not write a backend token to Info.plist")

assertContains(
    releaseRegression,
    "RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE",
    "release regression should expose optional iOS voice clone synthesis runtime smoke"
)
assertContains(
    releaseRegression,
    "run-voice-clone-synthesis-runtime-smoke.sh",
    "release regression should call iOS voice clone synthesis runtime smoke"
)
assertContains(
    releaseRegression,
    "voice-clone-synthesis-runtime-smoke-check.swift",
    "release regression should run iOS voice clone synthesis runtime smoke guard"
)

for required in [
    "run-voice-clone-synthesis-runtime-smoke.sh",
    "voice-clone-synthesis-runtime-smoke-check.swift",
] {
    assertContains(releaseQA, required, "release QA package should include \(required)")
}

print("Voice clone synthesis runtime smoke checks passed")
