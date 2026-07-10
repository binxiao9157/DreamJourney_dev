import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Echo digital-human Phase 2 stability check failed: \(message)\n", stderr)
        exit(1)
    }
}

let coordinator = read("DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

for required in [
    "struct DigitalHumanLifecycleToken",
    "struct DigitalHumanBackgroundReleaseLease",
    "final class DigitalHumanLifecycleCoordinator",
    "private(set) var generation",
    "func token(for contextKey:",
    "func invalidate(contextKey:",
    "func isCurrent(_ token:",
    "func beginBackgroundReleaseLease(contextKey:",
    "func cancelBackgroundReleaseLease()",
    "func isCurrentBackgroundReleaseLease(",
] {
    require(coordinator.contains(required), "lifecycle coordinator should implement \(required)")
}

for required in [
    "digitalHumanLifecycle",
    "captureDigitalHumanLifecycleToken",
    "isCurrentDigitalHumanLifecycleToken",
    "invalidateDigitalHumanLifecycle",
    "ignored stale lifecycle callback",
] {
    require(echo.contains(required), "Echo should integrate lifecycle generation through \(required)")
}

for pathMarker in [
    "prepareCloudDigitalHumanRuntimeIfNeeded",
    "loadVoiceCloneRuntimeCapabilityIfNeeded",
    "configureVoiceRuntimeThenStart",
    "sendEchoReplyViaTencentVoiceClonePCMDrive",
    "scheduleTencentDigitalHumanPCMDriveChunks",
    "resumeVoiceCaptureAfterTencentProviderSpeech",
] {
    guard let range = echo.range(of: pathMarker) else {
        require(false, "missing async path \(pathMarker)")
        continue
    }
    let tail = String(echo[range.lowerBound...].prefix(12_000))
    require(
        tail.contains("DigitalHumanLifecycleToken") || tail.contains("lifecycleToken"),
        "\(pathMarker) should capture or accept a lifecycle token"
    )
}

require(
    echo.contains("invalidateDigitalHumanLifecycle(reason: \"viewWillDisappear\")"),
    "page exit should invalidate pending callbacks before releasing the runtime"
)
let pageExit = sourceSlice(
    from: "override func viewWillDisappear",
    to: "override func viewDidLayoutSubviews"
)
require(
    pageExit.contains("let ownsDialogDelegate = DialogEngineManager.shared.delegate === self"),
    "page exit should separate provider release from DialogEngine delegate ownership"
)
require(
    pageExit.contains("releaseDigitalHumanRuntime(reason: \"viewWillDisappear\""),
    "page exit should always release the provider runtime"
)
require(
    echo.contains("captureDigitalHumanLifecycleToken(reason: \"contextReconcile:"),
    "context reconciliation should advance or capture the current generation"
)

for required in [
    "activeVoiceInteractionLifecycleToken",
    "invalidateDigitalHumanInteraction(reason: \"userBargeIn\")",
    "invalidateDigitalHumanInteraction(reason: \"userStoppedVoiceCapture\")",
    "scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded",
    "cancelCloudDigitalHumanBackgroundRelease(reason: \"willEnterForeground\")",
    "backgroundReleaseGraceExpired",
    "isDigitalHumanQuotaFailure",
    "digitalHumanRuntimeLifecycleGeneration",
    "digitalHumanRuntimeLifecycleGeneration == digitalHumanLifecycle.generation",
    "bindDigitalHumanRuntimeState(runtime, lifecycleToken: lifecycleToken)",
    "closed duplicate runtime before binding current session",
] {
    require(echo.contains(required), "Echo Phase 2 should implement \(required)")
}

func sourceSlice(from start: String, to end: String) -> String {
    guard let startRange = echo.range(of: start),
          let endRange = echo.range(of: end, range: startRange.upperBound..<echo.endIndex) else {
        return ""
    }
    return String(echo[startRange.lowerBound..<endRange.lowerBound])
}

let backgroundEntry = sourceSlice(
    from: "@objc private func echoAppDidEnterBackground()",
    to: "@objc private func echoAppWillEnterForeground()"
)
require(
    backgroundEntry.contains("scheduleCloudDigitalHumanRuntimeReleaseForBackgroundIfNeeded"),
    "background entry should schedule a grace lease"
)
require(
    !backgroundEntry.contains("releaseDigitalHumanRuntime("),
    "background entry should not release the runtime immediately"
)

let recoveryPolicy = sourceSlice(
    from: "private func shouldRecoverFromDigitalHumanRuntimeFailure",
    to: "private func isDigitalHumanQuotaFailure"
)
require(
    recoveryPolicy.contains("!isDigitalHumanQuotaFailure(reason)"),
    "quota failures should be excluded from automatic recovery"
)
require(
    !recoveryPolicy.contains("tencent_cloud_quota_exceeded"),
    "quota failures should not be listed as retryable recovery reasons"
)

let pcmScheduling = sourceSlice(
    from: "private func scheduleTencentDigitalHumanPCMDriveChunks",
    to: "private func makeTencentDigitalHumanPCMDriveTestSignal"
)
require(
    !pcmScheduling.contains("clearProviderRequestAndResumeState"),
    "PCM send failures should preserve the pending microphone-resume state"
)
require(
    pcmScheduling.components(separatedBy: "clearProviderRequest()").count >= 3,
    "PCM chunk and final failures should clear only the failed provider request"
)

print("Echo digital-human Phase 2 stability check passed")
