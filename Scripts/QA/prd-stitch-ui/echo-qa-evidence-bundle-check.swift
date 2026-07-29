import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func readIfPresent(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Echo QA evidence bundle guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let ownerTruthContracts = read("DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let uiqaSmoke = readIfPresent("Scripts/QA/prd-stitch-ui/run-echo-qa-evidence-bundle-export-smoke.sh")
let statusDoc = readIfPresent("docs/superpowers/status/2026-07-02-echo-qa-evidence-bundle-v2.md")

for required in [
    "struct EchoQAEvidenceBundle",
    "struct EchoQAFallbackSummary",
    "final class EchoQAEvidenceBundleStore",
    "struct EchoQAEvidenceManifest",
    "final class EchoQAEvidenceManifestStore",
    "configuredSourceCommit",
    "func exportLatestBundle(",
    "func exportLatestManifest(",
    "echo-qa-evidence-bundle.json",
    "echo-qa-evidence-manifest.json",
    "schemaVersion = 3",
    "ownerTruthContextCitationEvidence",
    "ownerTruthContextParityEvidence",
] {
    require(backendClient.contains(required), "backend client should define QA bundle support: \(required)")
}

for field in [
    "bundleId",
    "evidencePackage",
    "contextClues",
    "digitalHumanSession",
    "voiceSynthesis",
    "fallbackSummary",
    "runtimeDiagnostics",
    "redactionPolicy",
    "artifactHashes",
    "expiresAt",
    "ownerLeaseHash",
] {
    require(backendClient.contains("let \(field)"), "EchoQAEvidenceBundle should include \(field)")
}

for forbidden in [
    "audioBase64",
    "appkey",
    "accesstoken",
] {
    let qaBundleSection = backendClient.components(separatedBy: "struct EchoQAEvidenceBundle").dropFirst().first ?? ""
    require(!qaBundleSection.contains("let \(forbidden)"), "QA bundle must not store raw secret/audio field \(forbidden)")
}

for required in [
    "makeEchoQAEvidenceBundle(",
    "exportEchoQAEvidenceBundleForQA(source:",
    "EchoQAEvidenceBundleStore.shared.record(bundle, ownerUserId:",
    "EchoQAEvidenceBundleStore.shared.exportLatestBundle",
    "EchoQAEvidenceManifestStore.shared.record(",
    "EchoQAEvidenceManifestStore.shared.exportLatestManifest",
    "manifestOwnerIsolation",
    "manifestExpiryObserved",
    "runUIQAEchoQAEvidenceBundleExportSmoke",
    "latestFallbacks",
    "latestVoiceOutputMode",
    "latestDigitalHumanStatus",
    "latestArchiveClueHashes",
    "recordOwnerTruthContextCitationQAEvidence",
    "recordOwnerTruthContextParityQAEvidence",
    "ownerTruthContextEvidenceSchemaVersion",
    "ownerTruthContextReferenceDigestCount",
    "ownerTruthContextParityEvidenceSchemaVersion",
    "ownerTruthContextParityPromotionDecision",
] {
    require(echo.contains(required), "Echo should build/export QA evidence bundle: \(required)")
}

for required in [
    "struct OwnerTruthContextCitationQAEvidenceReadout",
    "owner-truth-context-citation-readout-v1",
    "contextHashDigest",
    "projectionCheckpointDigest",
    "selectedContextRefDigests",
    "selectedContextRefDigestsBySource",
    "enum OwnerTruthContextCitationQAGate",
    "DJEnableOwnerTruthContextCitationQA",
    "enum OwnerTruthMigrationParityQAGate",
    "DJEnableOwnerTruthMigrationParityQA",
] {
    require(ownerTruthContracts.contains(required), "Owner Truth QA readout must stay value-free: \(required)")
}

for required in [
    "struct EchoOwnerTruthContextParityQAEvidenceReadout",
    "echo-owner-truth-context-parity-readout-v1",
    "observedNonPromoting",
    "promotionDecision",
] {
    require(echoViewModel.contains(required), "Owner Truth Context parity readout must remain QA-only: \(required)")
}

require(
    !echo.contains("buildOwnerTruthContextShadow(") &&
        !echo.contains("recordOwnerTruthAnswerCitationReceipt("),
    "public Echo must not call the Owner Truth QA routes directly"
)

for required in [
    "case .echoQAEvidenceBundleExportSmoke:",
    "runEchoQAEvidenceBundleExportSmoke",
    "QAScenarioResultWriter.writeAndLog(",
    "echo-qa-evidence-bundle-export-smoke-result.json",
] {
    require(appDelegate.contains(required), "AppDelegate should expose QA evidence bundle smoke: \(required)")
}

for required in [
    "case echoQAEvidenceBundleExportSmoke = \"DJRunEchoQAEvidenceBundleExportSmoke\"",
] {
    require(featureFlags.contains(required), "Feature flags should register QA evidence bundle smoke: \(required)")
}

require(
    releaseRegression.contains("echo-qa-evidence-bundle-check.swift"),
    "release regression should run QA evidence bundle guard"
)

require(
    releaseRegression.contains("RUN_ECHO_QA_EVIDENCE_BUNDLE_EXPORT_SMOKE") &&
        releaseRegression.contains("run-echo-qa-evidence-bundle-export-smoke.sh"),
    "release regression should expose optional QA evidence bundle UIQA smoke"
)

require(
    releaseQA.contains("echo-qa-evidence-bundle-check.swift"),
    "release QA package should include QA evidence bundle guard"
)

require(
    releaseQA.contains("run-echo-qa-evidence-bundle-export-smoke.sh"),
    "release QA package should include QA evidence bundle UIQA smoke"
)

for required in [
    "run-installable-simulator-uiqa.sh",
    "DJRunEchoQAEvidenceBundleExportSmoke",
    "echo-qa-evidence-bundle-export-smoke-result.json",
    "echo-qa-evidence-bundle.json",
    "echo-qa-evidence-manifest.json",
    "DJEvidenceSourceCommit=",
    "artifactHashes",
    "manifestOwnerIsolation",
    "manifestExpiryObserved",
    "schemaVersion",
    "contextClues",
    "digitalHumanSession",
    "voiceSynthesis",
    "fallbackSummary",
    "ownerTruthContextCitationEvidence",
    "ownerTruthContextParityEvidence",
    "selectedContextRefDigests",
    "DJEnableOwnerTruthContextCitationQA",
    "DJEnableOwnerTruthMigrationParityQA",
    "audioBase64",
    "appkey",
    "accesstoken",
] {
    require(uiqaSmoke.contains(required), "QA evidence bundle UIQA smoke should verify \(required)")
}

for required in [
    "Echo QA Evidence Bundle v2",
    "Context V2 clue summary",
    "digital human session",
    "voice synthesis",
    "fallback summary",
    "Owner Truth Context QA",
    "不导出 raw audio",
    "不导出 appkey/accesstoken",
] {
    require(statusDoc.contains(required), "status doc should document \(required)")
}

print("Echo QA evidence bundle guard passed")
