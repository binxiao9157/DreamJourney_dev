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
        fputs("Echo trace owner isolation guard failed: \(message)\n", stderr)
        exit(1)
    }
}

func ordered(_ first: String, before second: String, in source: String, message: String) {
    guard let firstRange = source.range(of: first), let secondRange = source.range(of: second) else {
        require(false, "missing lifecycle call while checking: \(message)")
        return
    }
    require(firstRange.lowerBound < secondRange.lowerBound, message)
}

let backend = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let lifecycleRegistry = read("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")

for required in [
    "import CryptoKit",
    "final class EchoTraceOwnerScope",
    "private let lock = NSRecursiveLock()",
    "private var activeOwnerDigest: String?",
    "func withActiveOwner",
    "echo-trace-owner-v2|",
    "enum EchoTraceAccountLifecycle",
    "func activate(ownerUserId:",
    "func switchOwner(from previousOwnerUserId:",
    "func invalidateAndClear(ownerUserId:",
] {
    require(backend.contains(required), "backend owner scope should include \(required)")
}

for required in [
    "DreamJourney.EchoTraceStore.records.v2.owner.",
    "DreamJourney.EchoRuntimeDiagnosticsStore.snapshots.v2.owner.",
    "DreamJourney.EchoTraceEvidencePackageStore.packages.v2.owner.",
    "DreamJourney.EchoQAEvidenceBundleStore.bundles.v3.owner.",
    "DreamJourney.EchoTraceStore.records.v1",
    "DreamJourney.EchoRuntimeDiagnosticsStore.snapshots.v1",
    "DreamJourney.EchoTraceEvidencePackageStore.packages.v1",
    "DreamJourney.EchoQAEvidenceBundleStore.bundles.v2",
    "DreamJourneyEchoQAExports",
    "recordExportURL(",
    "removeExportedFiles(forOwnerDigest:",
    ".appendingPathComponent(ownerDigest, isDirectory: true)",
] {
    require(backend.contains(required), "owner storage/legacy purge contract should include \(required)")
}

for required in [
    "func record(_ record: EchoTraceRecord, ownerUserId: String) -> Bool",
    "func recentRecords(ownerUserId: String) -> [EchoTraceRecord]",
    "func exportRecentRecords(",
    "func record(_ snapshot: EchoRuntimeDiagnosticsSnapshot, ownerUserId: String) -> Bool",
    "func recentSnapshots(ownerUserId: String) -> [EchoRuntimeDiagnosticsSnapshot]",
    "func exportRecentSnapshots(",
    "func record(_ package: EchoTraceEvidencePackage, ownerUserId: String) -> Bool",
    "func recentPackages(ownerUserId: String) -> [EchoTraceEvidencePackage]",
    "func exportRecentPackages(",
    "func record(_ bundle: EchoQAEvidenceBundle, ownerUserId: String) -> Bool",
    "func recentBundles(ownerUserId: String) -> [EchoQAEvidenceBundle]",
    "func exportLatestBundle(",
    "var derivedOwnerUserId: String?",
] {
    require(backend.contains(required), "all store operations should bind an explicit owner: \(required)")
}

require(backend.contains("digitalHumanSession == nil || digitalHumanOwner == packageOwner"), "digital-human evidence must match package owner")
require(backend.contains("voiceSynthesis == nil || voiceSynthesisOwner == packageOwner"), "voice synthesis evidence must match package owner")
require(backend.contains("derivedOwnerUserId == normalizedOwnerUserId"), "evidence stores must reject unknown or mismatched owners")
require(backend.contains("storageKey(forOwnerDigest:"), "storage keys must be derived from owner digest")
require(backend.contains("ownerUserId: String? = nil"), "runtime snapshots must accept an explicit account owner before a trace exists")
require(echo.contains("EchoTraceOwnerScope.normalizedOwnerUserId(UserManager.shared.currentUser?.id)"), "runtime diagnostics must resolve the active owner before Context trace creation")
require(echo.contains("ownerUserId: ownerUserId"), "runtime diagnostics must bind the resolved active owner")
require(echo.contains("observeEchoAccountLifecycle()"), "Echo should observe login/logout account transitions")
require(echo.contains("@objc private func echoAccountDidChange()"), "Echo should clear page-level evidence caches on account transitions")
require(echo.contains("lastDigitalHumanSessionEvidenceSummary = nil"), "account transitions must clear digital-human evidence")
require(echo.contains("lastVoiceSynthesisEvidenceSummary = nil"), "account transitions must clear voice evidence")
require(echo.contains("trace: ownerTrace"), "runtime diagnostics must not consume a previous account trace")
require(backend.contains("let scopedTrace = explicitOwnerUserId == nil || explicitOwnerUserId == traceOwnerUserId"), "runtime snapshot must discard a trace that belongs to another explicit owner")
require(echo.contains("recordsDiagnostics: false"), "account transitions must release old runtime without writing it into the new owner store")
require(echo.contains("requestOwnerUserId: requestOwnerUserId"), "digital-human callbacks must retain their request owner")
require(echo.contains("activeOwnerUserId == EchoTraceOwnerScope.normalizedOwnerUserId(requestOwnerUserId)"), "digital-human callbacks must reject stale account responses")
require(echo.contains("activeOwnerUserId == EchoTraceOwnerScope.normalizedOwnerUserId(userId)"), "voice synthesis callbacks must reject stale account responses")

require(
    userManager.contains("func markPrivateAccessValidated(session: BackendAuthSessionContract) -> Bool") &&
        userManager.contains("session.isPrivateAccessEligible(for: userId)") &&
        userManager.contains("EchoTraceAccountLifecycle.activate(ownerUserId: userId)"),
    "a restored owner must be activated only after private session validation"
)
require(userManager.contains("EchoTraceAccountLifecycle.switchOwner(from: previousOwnerUserId, to: user.id)"), "login must switch and clean old owner")
require(
    userManager.contains("AccountLifecycleTransitionController.shared.perform(") &&
        userManager.contains("event: .logout"),
    "logout must enter the account lifecycle teardown flow"
)
require(
    lifecycleRegistry.contains("teardownQAEvidence") &&
        lifecycleRegistry.contains("EchoTraceAccountLifecycle.invalidateAndClear(") &&
        lifecycleRegistry.contains("ownerUserId: context.oldAccountLease?.subjectId"),
    "account lifecycle teardown must invalidate and clean Echo owner stores"
)
require(userManager.contains("private let accountStateLock = NSRecursiveLock()"), "account transitions must be serialized")
require(userManager.contains("private var storedCurrentUser: UserModel?"), "current account reads must share the transition lock")
require(userManager.contains("expectedUserId == nil || expectedUserId == user.id"), "profile saves captured before an account switch must not mutate the new account")
for required in [
    "EchoTraceStore.shared.record(record, ownerUserId:",
    "EchoRuntimeDiagnosticsStore.shared.record(snapshot, ownerUserId:",
    "EchoTraceEvidencePackageStore.shared.record(package, ownerUserId:",
    "EchoQAEvidenceBundleStore.shared.record(bundle, ownerUserId:",
    "EchoTraceStore.shared.exportRecentRecords(ownerUserId:",
    "EchoRuntimeDiagnosticsStore.shared.exportRecentSnapshots(ownerUserId:",
    "EchoTraceEvidencePackageStore.shared.exportRecentPackages(ownerUserId:",
    "EchoQAEvidenceBundleStore.shared.exportLatestBundle(ownerUserId:",
] {
    require(echo.contains(required), "Echo production and QA calls should pass explicit owner: \(required)")
}

print("Echo trace owner isolation guard passed")
