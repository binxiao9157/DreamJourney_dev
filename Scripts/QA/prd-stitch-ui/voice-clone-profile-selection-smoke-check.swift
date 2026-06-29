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

let runner = "Scripts/QA/prd-stitch-ui/run-voice-clone-profile-selection-smoke.sh"
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertFileExists(runner, "voice clone profile selection smoke runner")

for required in [
    "DJRunVoiceCloneProfileSelectionSmoke",
    "runVoiceCloneProfileSelectionSmoke()",
    "makeUIQAVoiceCloneProfile(",
    "VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles)",
    "VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles, preferredProfileId: pendingProfile.voiceProfileId)",
    "VoiceCloneService.shared.persistSnapshot(VoiceCloneProfileSnapshot(backendContract: readyProfile))",
    "VoiceCloneService.shared.persistSnapshot(VoiceCloneProfileSnapshot(backendContract: pendingProfile))",
    "currentUsableSpeakerId",
    "pendingPreferredRespected",
    "pendingClearsUsableReady",
    "voice-clone-profile-selection-smoke-result.json",
] {
    assertContains(appDelegate, required, "AppDelegate should implement voice clone profile selection UIQA smoke \(required)")
}

for required in [
    "RUN_VOICE_CLONE_PROFILE_SELECTION_SMOKE",
    "run-voice-clone-profile-selection-smoke.sh",
    "voice-clone-profile-selection-smoke-check.swift",
    "voice-clone-profile-selection-smoke",
] {
    assertContains(releaseRegression, required, "release regression should include voice clone profile selection smoke \(required)")
}

for required in [
    "run-voice-clone-profile-selection-smoke.sh",
    "voice-clone-profile-selection-smoke-check.swift",
] {
    assertContains(releasePackage, required, "release QA package should include \(required)")
}

print("Voice clone profile selection smoke checks passed")
