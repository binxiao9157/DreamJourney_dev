import Foundation

private func read(_ relativePath: String) -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(relativePath)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Missing file: \(relativePath)\n", stderr)
        exit(1)
    }
    return value
}

private func require(_ source: String, _ token: String, _ message: String) {
    guard source.contains(token) else {
        fputs("Runtime capability axis integration check failed: \(message)\n", stderr)
        exit(1)
    }
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let regression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let snapshot = read("DreamJourney/Sources/Services/RuntimeCapabilitySnapshot.swift")

require(client, "let capabilitySnapshots: [String: RuntimeCapabilitySnapshot]", "runtime config must retain five-axis snapshots")
require(client, "RuntimeCapabilitySnapshotStore.shared.replace", "successful runtime fetch must update the shared immutable snapshot cache")
require(client, "axisSnapshot.isProviderOperational", "provider effects must use a complete five-axis contract")
require(client, "axisSnapshot.isRuntimeContractUsable", "operation-specific provider effects must reject stale runtime contracts")
require(client, "axisSnapshot.isProviderEffectAllowed", "real digital-human sessions must reject unavailable providers")
require(client, "var allowsClientSessionRequest: Bool", "QA mock sessions must use an explicit bounded contract path")
require(client, "RuntimeCapabilitySnapshot.conservativeLegacy", "old bool aliases must dual-decode as conservative unknown")
require(snapshot, "case blocked", "runtime capability contract must model automatic shutdown")
require(snapshot, "case stale", "expired operational evidence must remain distinct")
require(snapshot, "isReadinessEpochUsable", "recovered capabilities must require a fresh readiness epoch")
require(snapshot, "controlState != .blocked", "blocked operational state must fail closed")
require(echo, "failClosedDigitalHumanRuntimePreparation", "Echo must fail closed before opening an unavailable digital-human session")
require(echo, "voiceCloneRuntimeCapabilityUnknown", "Echo must not synthesize through an unknown clone capability")
require(profile, "snapshot?.isPubliclyAvailable == true", "profile release exposure must require all five axes")
require(archive, "snapshot?.isPubliclyAvailable == true", "archive release exposure must require all five axes")
require(echo, "diagnosticSummary", "Echo QA diagnostics must explain the five capability axes")
require(regression, "run-runtime-capability-snapshot-model-smoke.sh", "release regression must run the five-axis model smoke")
require(regression, "runtime-capability-axis-integration-check.swift", "release regression must run the integration gate")

print("Runtime capability axis integration checks passed")
