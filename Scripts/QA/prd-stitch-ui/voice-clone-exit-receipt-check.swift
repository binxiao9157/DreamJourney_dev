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
        fputs("voice-clone-exit-receipt-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func section(in source: String, from marker: String, until nextMarker: String) -> String {
    guard let start = source.range(of: marker) else {
        return ""
    }
    let remaining = source[start.upperBound...]
    guard let end = remaining.range(of: nextMarker) else {
        return String(source[start.lowerBound...])
    }
    return String(source[start.lowerBound..<end.lowerBound])
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let service = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let shell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "let exitState: String",
    "let accessRevoked: Bool",
    "let localCleanupState: String",
    "let providerCleanupState: String",
    "let providerCleanupReceiptAvailable: Bool",
    "case paused",
    "case deleting",
    "case deleted",
    "let allowedOperations: Set<String>",
] {
    require(client.contains(required), "typed voice profile contract should retain \(required)")
}
let deleteClientSection = section(
    in: client,
    from: "func deleteVoiceCloneProfile(",
    until: "func requestArchiveMediaUploadIntent("
)
require(
    deleteClientSection.contains("sessionUserId: userId"),
    "voice profile deletion must stay bound to the authenticated owner"
)

for required in [
    "case \"accessRevoked\":",
    "case \"pending\":",
    "case \"partial\":",
    "case \"completed\":",
    "case \"unsupported\":",
    "var isUseRevoked: Bool",
    "var canDisableRemotely: Bool",
    "var canDeleteRemotely: Bool",
    "var canRefreshExitState: Bool",
    "allowedOperations.contains(\"disable\")",
    "allowedOperations.contains(\"delete\")",
] {
    require(service.contains(required), "voice clone service should model \(required)")
}

for required in [
    "在收到确认前，不会把第三方清理误报为完成",
    "snapshot.canDisableRemotely",
    "snapshot.canDeleteRemotely",
    "snapshot.canRefreshExitState",
    "case .paused:",
    "case .deleting:",
    "case .deleted:",
    "正在确认删除",
    "voiceSampleStatusText(for snapshot: VoiceCloneProfileSnapshot)",
    "return \"清理中\"",
    "音色已暂停，回响会使用普通语音",
] {
    require(shell.contains(required), "voice clone shell should safely render \(required)")
}

for required in [
    "selectedVoiceProfileId: voiceSelection.voiceProfileId",
    "roleVoiceSource: voiceSelection.source.rawValue",
    "audioOwner: currentEchoAudioOwner.rawValue",
    "providerLogId: lastVoiceCloneProviderLogId",
    "outputMode: \\(PrivacySafeDiagnostics.safeCode(snapshot.voiceOutputMode",
] {
    require(echo.contains(required), "QA runtime evidence should include \(required)")
}
require(
    read("DreamJourney/Sources/AppDelegate.swift").contains("DJVoiceCloneStatusFeedbackState=")
        && read("DreamJourney/Sources/AppDelegate.swift").contains("deletionPending"),
    "QA preview should render a pending external deletion state"
)
require(
    read("DreamJourney/Sources/AppDelegate.swift").contains("deletionPendingRevokesUse")
        && read("Scripts/QA/prd-stitch-ui/run-voice-clone-profile-selection-smoke.sh").contains("pausedProfileCanDelete"),
    "Voice clone UIQA smoke should cover pending deletion and paused-profile deletion"
)

require(
    releaseRegression.contains("voice-clone-exit-receipt-check.swift"),
    "release regression should execute the voice exit receipt guard"
)
require(
    releaseQA.contains("voice-clone-exit-receipt-check.swift"),
    "release QA package should include the voice exit receipt guard"
)

print("voice-clone-exit-receipt-check passed")
