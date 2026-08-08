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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let voiceShell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct VoiceCloneRuntimeCapability",
    "let voiceClone: VoiceCloneRuntimeCapability",
    "json[\"voiceClone\"] as? [String: Any]",
    "let provider: String",
    "let synthesisProviderReady: Bool",
    "let identityEligibilityProviderReady: Bool",
    "let identityEligibilityProvider: String",
    "let trainingAdmissionEnabled: Bool",
    "let trainingAdmissionReason: String",
    "let trainingAdmissionContractVersion: Int",
    "let source: String?",
    "source == \"serverReceipt\"",
    "let voiceClone2TrialReady: Bool",
    "let tencentAudioDrive: VoiceCloneTencentAudioDriveCapability",
    "var canTrain: Bool",
    "var canQuery: Bool",
    "var canSynthesize: Bool",
    "axisSnapshot.isRuntimeContractUsable",
    "&& identityEligibilityProviderReady",
    "&& trainingAdmissionEnabled",
    "static func localFallback(isBackendConfigured: Bool)",
    "func fetchVoiceCloneRuntimeCapability(",
] {
    assertContains(backendClient, required, "backend client should parse voiceClone runtime capability \(required)")
}

for required in [
    "private var voiceCloneRuntimeCapability",
    "loadVoiceCloneRuntimeCapability()",
    "fetchVoiceCloneRuntimeCapability",
    "voiceCloneRuntimeCapability = capability",
    "voiceCloneRuntimeCapability.canTrain",
    "voiceCloneRuntimeCapability.canQuery",
    "voiceCloneRuntimeCapability.canSynthesize",
    "voiceCloneRuntimeCapability.trainingAdmissionReason",
    "voiceTrainingAdmissionHint()",
    "voiceCloneRuntimeCapability.voiceClone2TrialReady",
    "voiceCloneRuntimeCapability.tencentAudioDrive.supported",
] {
    assertContains(voiceShell, required, "voice clone shell should consume runtime capability \(required)")
}

assertNotContains(
    voiceShell,
    "DreamJourneyBackendClient.shared.isVoiceCloneSynthesisConfigured",
    "voice clone status UI should not use baseURL-only synthesis readiness once runtime capability is available"
)

assertContains(
    releaseRegression,
    "voice-clone-runtime-capability-check.swift",
    "release regression should run voice clone runtime capability guard"
)
assertContains(
    releaseQA,
    "voice-clone-runtime-capability-check.swift",
    "release QA package should include voice clone runtime capability guard"
)

print("Voice clone runtime capability checks passed")
