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

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("voice-clone-runtime-fault-injection-smoke-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func section(_ content: String, from start: String, until end: String) -> String {
    guard let startRange = content.range(of: start) else {
        return ""
    }
    let tail = content[startRange.lowerBound...]
    guard let endRange = tail.range(of: end) else {
        return String(tail)
    }
    return String(tail[..<endRange.lowerBound])
}

let service = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let runner = read("Scripts/QA/prd-stitch-ui/run-voice-clone-runtime-fault-injection-smoke.sh")
let combinedGate = read("Scripts/QA/prd-stitch-ui/run-voice-clone-c2-runtime-fault-injection-gate.sh")

for required in [
    "struct VoiceCloneSynthesisUseTicket",
    "func capturePersonalSynthesisUseTicket",
    "func validatesPersonalSynthesisUseTicket",
    "VoiceCloneConsentValidity.isActiveAndUnexpired",
    "snapshot.profileVersion == profileVersion",
    "snapshot.allowedOperations == allowedOperations",
] {
    require(service.contains(required), "voice-clone local ticket must retain \(required)")
}

for required in [
    "rejectInvalidVoiceCloneSynthesisUseTicketIfNeeded",
    "voiceCloneUseTicketRevoked",
    "voiceCloneUseTicket: VoiceCloneSynthesisUseTicket?",
    "voiceCloneUseTicket: voiceCloneUseTicket",
    "runUIQAVoiceCloneRuntimeFaultInjectionSmoke",
    "pausedPCMRejected",
    "deletedTicketRejected",
    "expiredTicketRejected",
    "staleGenerationPCMRejected",
    "accountSwitchPCMRejected",
    "stoppedPCMRejected",
    "bindingMismatchRejected",
    "invalidPCMRejected",
    "providerFailureRejected",
    "evidenceRedacted",
    "bindingResult",
    "textHash",
    "providerLogId\": \"redacted\"",
    "rawAudioOmitted\": true",
    "setEchoAudioOwner(.fallbackMuted",
] {
    require(echo.contains(required), "Echo fault-injection path must retain \(required)")
}

let failureHandler = section(
    echo,
    from: "private func handleVoiceClonePCMDriveFailureWithoutDefaultVoice",
    until: "private func sendEchoReplyToTencentTextRuntime"
)
require(!failureHandler.isEmpty, "voice-clone explicit failure handler must exist")
require(
    !failureHandler.contains("sendEchoReplyToTencentTextRuntime("),
    "voice-clone failure handler must not silently play Tencent default text voice"
)

require(
    featureFlags.contains("case voiceCloneRuntimeFaultInjectionSmoke = \"DJRunVoiceCloneRuntimeFaultInjectionSmoke\"")
        && featureFlags.contains("voiceCloneRuntimeFaultInjectionSmoke"),
    "central QA registry must expose the runtime fault-injection scenario"
)
for required in [
    "case .voiceCloneRuntimeFaultInjectionSmoke:",
    "runVoiceCloneRuntimeFaultInjectionSmoke",
    "voice-clone-runtime-fault-injection-smoke-result.json",
    "VoiceCloneRuntimeFaultInjectionSmoke completed",
] {
    require(appDelegate.contains(required), "AppDelegate must wire \(required)")
}

for required in [
    "DJRunVoiceCloneRuntimeFaultInjectionSmoke",
    "pausedPCMRejected",
    "deletedTicketRejected",
    "expiredTicketRejected",
    "staleGenerationPCMRejected",
    "stoppedPCMRejected",
    "bindingMismatchRejected",
    "invalidPCMRejected",
    "providerFailureRejected",
    "evidenceRedacted",
    "rawAudioOmitted",
    "providerLogId",
    "bindingResult",
    "textHash",
    "01-voice-clone-runtime-fault-injection-smoke.png",
] {
    require(runner.contains(required), "runtime fault-injection runner must verify \(required)")
}

for required in [
    "voice-clone-runtime-fault-injection-smoke-check.swift",
    "RUN_VOICE_CLONE_C2_RUNTIME_FAULT_INJECTION_GATE",
    "run-voice-clone-c2-runtime-fault-injection-gate.sh",
] {
    require(releaseRegression.contains(required), "release regression must expose \(required)")
    require(releaseQA.contains(required), "release QA package must list \(required)")
}

for required in [
    "run-voice-clone-runtime-fault-injection-smoke.sh",
    "run-echo-audio-owner-coordinator-uiqa-smoke.sh",
    "run-echo-continuous-turn-uiqa-smoke.sh",
    "Voice clone C2 runtime fault-injection gate",
] {
    require(combinedGate.contains(required), "combined C2 gate must include \(required)")
}

print("Voice clone C2 runtime fault-injection static check passed")
