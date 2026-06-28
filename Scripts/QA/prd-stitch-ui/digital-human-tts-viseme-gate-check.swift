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

let backendSmoke = "Scripts/QA/prd-stitch-ui/backend-voice-synthesis-viseme-smoke.py"
let backendRunner = "Scripts/QA/prd-stitch-ui/run-backend-voice-synthesis-viseme-smoke.sh"
let comboRunner = "Scripts/QA/prd-stitch-ui/run-digital-human-tts-viseme-gate.sh"

assertFileExists(backendSmoke, "backend voice synthesis viseme smoke")
assertFileExists(backendRunner, "backend voice synthesis viseme runner")
assertFileExists(comboRunner, "digital-human TTS/viseme combo gate")

let backendSmokeContent = read(backendSmoke)
let backendRunnerContent = read(backendRunner)
let comboRunnerContent = read(comboRunner)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")

for required in [
    "/voice/synthesis",
    "VoiceCloneTTSProviderFactory",
    "visemeTimeline",
    "providerVisemeTimeline",
    "missingTimelineFallbackAccepted",
    "lipSyncFrameCount",
] {
    assertContains(backendSmokeContent, required, "backend smoke should cover \(required)")
}

for required in [
    "backend-voice-synthesis-viseme-smoke.py",
    "backend-voice-synthesis-viseme-smoke-result.json",
    "providerVisemeTimeline",
] {
    assertContains(backendRunnerContent, required, "backend runner should include \(required)")
}

for required in [
    "run-backend-voice-synthesis-viseme-smoke.sh",
    "run-digital-human-live-panel-smoke.sh",
    "DIGITAL_HUMAN_LIPSYNC_MODE=providerVisemeTimeline",
    "DIGITAL_HUMAN_LIPSYNC_MODE=avAudioPlayerMetering",
    "lipSyncSource",
    "currentMouthShape",
    "meteringSampleCount",
] {
    assertContains(comboRunnerContent, required, "combo gate should include \(required)")
}

assertContains(releaseRegression, "RUN_DIGITAL_HUMAN_TTS_VISEME_GATE", "release regression should expose optional digital-human TTS/viseme gate")
assertContains(releaseRegression, "run-digital-human-tts-viseme-gate.sh", "release regression should call digital-human TTS/viseme gate")
assertContains(releaseRegression, "digital-human-tts-viseme-gate", "release regression report should mention digital-human TTS/viseme gate evidence")
assertContains(releaseRegression, "digital-human-tts-viseme-gate-check.swift", "release regression should run this static guard")

for requiredPackageEntry in [
    "backend-voice-synthesis-viseme-smoke.py",
    "run-backend-voice-synthesis-viseme-smoke.sh",
    "run-digital-human-tts-viseme-gate.sh",
    "digital-human-tts-viseme-gate-check.swift",
] {
    assertContains(releasePackage, requiredPackageEntry, "release QA package should include \(requiredPackageEntry)")
}

assertContains(echo, "VoiceCloneSynthesisResult(json:", "Digital-human UIQA should construct a mock synthesis result")
assertContains(echo, "lipSyncPlaybackEvent", "Digital-human UIQA should feed synthesis lip-sync event to the panel")
assertContains(echo, "applyPlaybackEvent", "Digital-human UIQA should use the panel playback event bridge")
assertContains(backendClient, "let visemeTimeline: DigitalHumanLipSyncTimeline?", "backend client should retain optional viseme timeline")

print("Digital human TTS/viseme gate checks passed")
