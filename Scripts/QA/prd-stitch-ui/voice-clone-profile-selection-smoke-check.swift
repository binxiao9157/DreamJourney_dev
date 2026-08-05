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
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let voiceCloneService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let voiceCloneShell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertFileExists(runner, "voice clone profile selection smoke runner")

for required in [
    "DJRunVoiceCloneProfileSelectionSmoke",
    "case voiceCloneProfileSelectionSmoke",
    ".voiceCloneProfileSelectionSmoke",
] {
    assertContains(featureFlags, required, "voice clone profile selection smoke should stay centrally registered \(required)")
}

for required in [
    "case .voiceCloneProfileSelectionSmoke:",
    "runVoiceCloneProfileSelectionSmoke()",
    "makeUIQAVoiceCloneProfile(",
    "VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles)",
    "VoiceCloneService.shared.preferredVoiceCloneProfile(from: profiles, preferredProfileId: pendingProfile.voiceProfileId)",
    "VoiceCloneService.shared.persistSnapshot(VoiceCloneProfileSnapshot(backendContract: readyProfile))",
    "VoiceCloneService.shared.persistSnapshot(VoiceCloneProfileSnapshot(backendContract: pendingProfile))",
    "currentUsableSpeakerId",
    "pendingPreferredRespected",
    "pendingClearsUsableReady",
    "failedProfileCanRetry",
    "retryReusesSameVoiceProfileId",
    "retryGenerationAdvanced",
    "retryPendingNotUsable",
    "S_failed_retry_uiqa",
    "makeUIQALegacyReadyVoiceCloneProfile",
    "legacyReadyRejectedForEcho",
    "lifecycleSchemaVersion\": \"voice-profile-lifecycle-v1\"",
    "voice-clone-profile-selection-smoke-result.json",
] {
    assertContains(appDelegate, required, "AppDelegate should implement voice clone profile selection UIQA smoke \(required)")
}

for required in [
    "let retryGeneration: Int",
    "func retryVoiceCloneProfile(",
    "/voice/profiles/\\(pathComponent(userId))/\\(pathComponent(voiceProfileId))/retry",
    "\"retryGeneration\"] = retryGeneration",
    "\"expectedProfileVersion\"] = expectedProfileVersion",
    "struct VoiceCloneSampleAuthorizationContract",
    "func issueVoiceCloneSampleAuthorization(",
    "/voice/profiles/\\(pathComponent(userId))/sample-authorization",
] {
    assertContains(backendClient, required, "iOS backend client should expose the explicit same-profile retry contract \(required)")
}

for required in [
    "retryingProfile: VoiceCloneProfileSnapshot? = nil",
    "trainingRetryRequest(for:",
    "DreamJourneyBackendClient.shared.retryVoiceCloneProfile",
    "func prepareSampleAuthorization(",
    "sampleAuthorization: VoiceCloneSampleAuthorizationContract",
    "\"sampleVersion\": \"voice-sample-v1\"",
    "\"sampleAuthorizationReceiptId\": sampleAuthorization.receiptId",
    "url.pathExtension.lowercased() == \"wav\" ? \"wav\" : nil",
    "retryGeneration: snapshot.retryGeneration + 1",
    "var canRetryTraining: Bool",
    "currentSnapshot.sampleStatus != .failed || retryRequest != nil",
] {
    assertContains(voiceCloneService, required, "voice clone service should keep failed retries on the same profile and fail closed for Echo \(required)")
}

for required in [
    "retryingProfile: retryingProfile",
    "receipt.retryGeneration == snapshot.retryGeneration",
    "qualityPreviewReceipt?.retryGeneration != snapshot.retryGeneration",
    "UTType(filenameExtension: \"wav\") ?? .audio",
    "presentSampleAuthorizationConfirmation(",
    "确认本人声音样本",
    "sampleAuthorization: preparation.authorization",
] {
    assertContains(voiceCloneShell, required, "voice clone shell should invalidate stale preview acceptance after retry \(required)")
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
