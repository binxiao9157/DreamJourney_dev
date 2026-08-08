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
    guard condition() else {
        fputs("voice-clone-c1-c2-contract-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let service = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let combinedGate = read("Scripts/QA/prd-stitch-ui/run-voice-clone-c1-c2-non-device-gate.sh")

// C1: Echo eligibility has to be the canonical accepted lifecycle, backed by
// server-issued consent and an explicit synthesis permission. Client-side UI
// labels or a preview state are never sufficient.
for required in [
    "var isReadyForEcho: Bool",
    "lifecycleState == .accepted",
    "sampleStatus == .ready",
    "isEnabled",
    "realCloneProviderReady",
    "eligibility.isAllowed",
    "consent.grantsPrivateSynthesis",
    "allowedOperations.contains(\"synthesize\")",
    "var canPreviewQuality: Bool",
    "lifecycleState == .previewReady || lifecycleState == .accepted",
    "var canAcceptQuality: Bool",
    "allowedOperations.contains(\"accept\")",
] {
    require(client.contains(required), "typed profile contract must retain \(required)")
}

for required in [
    "var isUseRevoked: Bool",
    "lifecycleState == .deleting",
    "lifecycleState == .deleted",
    "providerCleanupReceiptAvailable",
    "case \"partial\":",
    "case \"unsupported\":",
    "第三方服务清理尚未接入",
] {
    require(service.contains(required), "iOS must render only a redacted deletion state: \(required)")
}

// C2: a successful response must be bound to this owner/profile/role/purpose
// and carry the exact Tencent audio-drive PCM contract. Any mismatch follows
// the explicit failure path rather than a default provider voice.
for required in [
    "var isTencentAudioDrivePCMCompatible: Bool",
    "outputMode == \"tencentAudioDrive\"",
    "audioFormat == \"pcm16kMono\"",
    "sampleRate == 16000",
    "bitsPerSample == 16",
    "channelCount == 1",
    "func isBound(",
    "let synthesisBinding: VoiceCloneSynthesisBinding?",
] {
    require(client.contains(required), "typed synthesis contract must retain \(required)")
}

for required in [
    "guard synthesis.voiceProfileId == voiceProfileId",
    "synthesis.isBound(",
    "synthesis.isTencentAudioDrivePCMCompatible",
    "handleVoiceClonePCMDriveFailureWithoutDefaultVoice",
    "synthesisBindingMismatch",
    "incompatibleAudioFormat",
    "outputMode: \"tencentAudioDrive\"",
    "audioOwner: \"tencentDigitalHuman\"",
    "lastVoiceSynthesisEvidenceSummary",
    "lastVoiceCloneProviderLogId",
    "currentEchoAudioOwner.rawValue",
    "roleVoiceSource: voiceSelection.source.rawValue",
] {
    require(echo.contains(required), "Echo must keep strict accepted-profile PCM routing: \(required)")
}

for required in [
    "RUN_VOICE_CLONE_C1_C2_NON_DEVICE_GATE",
    "run-voice-clone-c1-c2-non-device-gate.sh",
] {
    require(releaseRegression.contains(required), "release regression must expose \(required)")
}

require(
    combinedGate.contains("run-backend-voice-clone-c1-lifecycle-gate.sh"),
    "combined gate must include the fake-provider C1 lifecycle worker gate"
)
require(
    combinedGate.contains("voice-clone-c1-c2-contract-check.swift"),
    "combined gate must include this iOS C1/C2 contract guard"
)

print("Voice clone C1/C2 iOS contract gate passed")
