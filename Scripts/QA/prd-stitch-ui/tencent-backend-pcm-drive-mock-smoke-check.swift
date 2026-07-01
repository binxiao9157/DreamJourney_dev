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

let runnerPath = "Scripts/QA/prd-stitch-ui/run-tencent-backend-pcm-drive-mock-smoke.sh"
assertFileExists(runnerPath, "Tencent backend PCM-drive mock smoke runner")

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let runtimeStub = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanRuntimeStub.swift")
let runner = read(runnerPath)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct TencentDigitalHumanPCMChunkRecord",
    "private(set) var sentPCMChunks",
    "private(set) var interruptCount",
    "sentPCMChunks.append",
    "isFinal",
    "sequence",
] {
    assertContains(runtimeStub, required, "Tencent runtime stub should record backend PCM-drive calls \(required)")
}

for required in [
    "DJRunTencentBackendPCMDriveMockSmoke",
    "runTencentBackendPCMDriveMockSmoke",
    "writeTencentBackendPCMDriveMockSmokeResult",
    "tencent-backend-pcm-drive-mock-smoke-result.json",
] {
    assertContains(appDelegate, required, "AppDelegate should expose Tencent backend PCM-drive mock smoke \(required)")
}

for required in [
    "runUIQATencentBackendPCMDriveMockSmoke",
    "TencentDigitalHumanRuntimeStub",
    "DreamJourneyBackendClient.shared.fetchVoiceCloneRuntimeCapability",
    "DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(",
    "outputMode: capability.tencentAudioDrive.requestOutputMode",
    "sendTencentAudioDriveSynthesisToDigitalHumanRuntime",
    "preparedByteCount",
    "nonFinalByteCount == preparedByteCount",
    "stub.sentPCMChunks",
    "stub.interruptCount",
    "finalChunkObserved",
    "sequenceIsContiguous",
    "completed",
] {
    assertContains(echo, required, "Echo should run fake Tencent backend PCM-drive mock smoke \(required)")
}

assertContains(runner, "DJRunTencentBackendPCMDriveMockSmoke", "runner should launch the app-side mock smoke")
assertContains(runner, "DJTencentBackendPCMDriveMockVoiceProfileId=", "runner should pass an explicit ready voiceProfileId")
assertContains(runner, "tencent-backend-pcm-drive-mock-smoke-result.json", "runner should poll the smoke result")
assertContains(runner, "\"pcmChunkCount\"", "runner should verify PCM chunks were recorded")
assertContains(runner, "\"finalChunkObserved\"", "runner should verify final chunk")
assertContains(runner, "\"sequenceIsContiguous\"", "runner should verify chunk order")
assertContains(runner, "\"audioDataOmitted\"", "runner should verify raw audio is omitted")
assertContains(runner, "\"preparedByteCount\"", "runner should verify prepared PCM byte count")
assertContains(runner, "Prepared PCM bytes should include original synthesis PCM", "runner should allow preroll/tail silence while preserving original PCM")
assertContains(runner, "Sent PCM bytes should equal prepared PCM byteCount", "runner should compare sent bytes against prepared PCM")
assertContains(runner, "<redacted-backend-token>", "runner should redact backend token from build logs")
assertContains(runner, "APP_INFO_PLIST=\"$APP_PATH/Info.plist\"", "runner should locate the built app Info.plist")
assertContains(runner, "Set :DreamJourneyBackendBaseURL $BACKEND_BASE_URL", "runner should reapply backend base URL after LocalConfig build phase")
assertContains(runner, "Set :DreamJourneyBackendAPIToken $BACKEND_API_TOKEN", "runner should reapply backend token after LocalConfig build phase")
assertContains(runner, "DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=\"$LOCAL_BUNDLE_ID\"", "runner should build with the local installable Bundle ID")
assertContains(runner, "DREAMJOURNEY_DEVELOPMENT_TEAM=\"$LOCAL_DEVELOPMENT_TEAM\"", "runner should build with the local development team")
assertContains(runner, "[[ \"$BUNDLE_ID\" == \"$LOCAL_BUNDLE_ID\" ]]", "runner should assert the built Bundle ID")
assertContains(runner, "[[ \"$BUNDLE_ID\" != \"com.gaominge.dreamjourney.app\" ]]", "runner should reject the shared default Bundle ID")
assertNotContains(runner, "cat \"$BACKEND_API_TOKEN\"", "runner must not print backend token")

assertContains(
    releaseRegression,
    "RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE",
    "release regression should expose optional fake Tencent backend PCM-drive mock smoke"
)
assertContains(
    releaseRegression,
    "run-tencent-backend-pcm-drive-mock-smoke.sh",
    "release regression should call fake Tencent backend PCM-drive mock smoke"
)
assertContains(
    releaseRegression,
    "tencent-backend-pcm-drive-mock-smoke-check.swift",
    "release regression should run fake Tencent backend PCM-drive mock smoke guard"
)

for required in [
    "run-tencent-backend-pcm-drive-mock-smoke.sh",
    "tencent-backend-pcm-drive-mock-smoke-check.swift",
] {
    assertContains(releaseQA, required, "release QA package should include \(required)")
}

print("Tencent backend PCM-drive mock smoke checks passed")
