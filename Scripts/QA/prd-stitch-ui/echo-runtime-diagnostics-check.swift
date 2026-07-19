import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Echo runtime diagnostics guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct EchoRuntimeDiagnosticsSnapshot",
    "final class EchoRuntimeDiagnosticsStore",
    "static let shared = EchoRuntimeDiagnosticsStore()",
    "func record(_ snapshot: EchoRuntimeDiagnosticsSnapshot, ownerUserId: String) -> Bool",
    "func exportRecentSnapshots(",
    "echo-runtime-diagnostics.json",
] {
    require(backendClient.contains(required), "backend client should define runtime diagnostics support: \(required)")
}

for field in [
    "schemaVersion",
    "snapshotId",
    "turnID",
    "traceId",
    "archiveItemIDs",
    "kbFactCount",
    "voiceProfileId",
    "voiceCloneReady",
    "voiceOutputMode",
    "audioOwner",
    "digitalHumanRuntimeState",
    "digitalHumanProviderMode",
    "providerLogId",
    "providerRequestId",
    "fallbackReason",
    "privacyScopeLabel",
    "crossScopeArchiveIncluded",
] {
    require(backendClient.contains("let \(field)"), "EchoRuntimeDiagnosticsSnapshot should include \(field)")
}

for required in [
    "private var lastVoiceCloneProviderLogId",
    "private var lastVoiceCloneProviderRequestId",
    "private var lastVoiceCloneProviderMode",
    "private var shouldShowEchoRuntimeDiagnosticsPanel",
    "DJShowEchoRuntimeDiagnosticsPanel",
    "echoRuntimeDiagnosticsPanelLabel",
    "renderEchoRuntimeDiagnosticsPanel(snapshot:",
    "Echo QA clues",
    "KBLite facts",
    "privacyScopeLabel",
    "makeEchoRuntimeDiagnosticsSnapshot(reason:",
    "EchoRuntimeDiagnosticsStore.shared.record(snapshot, ownerUserId:",
    "runUIQAEchoRuntimeDiagnosticsExportSmoke",
    "EchoRuntimeDiagnosticsStore.shared.exportRecentSnapshots",
    "diagnosticsPanelText",
] {
    require(echo.contains(required), "Echo should produce/export diagnostics snapshots: \(required)")
}

require(
    featureFlags.contains("DJRunEchoRuntimeDiagnosticsExportSmoke"),
    "centralized QA scenario registry should retain the Echo runtime diagnostics launch argument"
)

for required in [
    "runEchoRuntimeDiagnosticsExportSmoke",
    "writeEchoRuntimeDiagnosticsExportSmokeResult",
    "echo-runtime-diagnostics-export-smoke-result.json",
] {
    require(appDelegate.contains(required), "AppDelegate should expose Echo runtime diagnostics UIQA smoke: \(required)")
}

require(
    releaseRegression.contains("echo-runtime-diagnostics-check.swift"),
    "release regression should run Echo runtime diagnostics guard"
)

require(
    releaseQA.contains("echo-runtime-diagnostics-check.swift"),
    "release QA package should include Echo runtime diagnostics guard"
)

print("Echo runtime diagnostics guard passed")
