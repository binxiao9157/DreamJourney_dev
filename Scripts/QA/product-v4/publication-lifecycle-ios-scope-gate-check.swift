#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Publication lifecycle iOS scope gate failed: \(message)\n", stderr)
        exit(1)
    }
}

let featureFlags = try read("DreamJourney/Sources/App/FeatureFlagService.swift")
let backendClient = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let managementAccess = try read("DreamJourney/Sources/Services/PublicationManagementAccess.swift")
let visitorAccess = try read("DreamJourney/Sources/Services/PublicationVisitorAccess.swift")
let managementView = try read("DreamJourney/Sources/Modules/Profile/ProfilePublicationManagementQAViewController.swift")
let appDelegate = try read("DreamJourney/Sources/AppDelegate.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")
let smokeRunner = try read("Scripts/QA/prd-stitch-ui/run-publication-lifecycle-m2-smoke.sh")

require(
    featureFlags.contains("case publicationLifecycleM2Smoke")
        && featureFlags.contains(".publicationLifecycleM2Smoke,"),
    "lifecycle UIQA scenario must stay explicitly registered"
)
require(
    managementAccess.contains("enum PublicationLifecycleM2QAGate")
        && managementAccess.contains("static let launchArgument = \"DJEnablePublicationLifecycleM2QA\"")
        && managementAccess.contains("PublicationManagementM2QAGate.isEnabled")
        && managementAccess.contains("PublicationVisitorM2QAGate.isEnabled")
        && managementAccess.contains("#if DEBUG || UI_QA_SIMULATOR")
        && managementAccess.contains("#else\n        false"),
    "lifecycle command must remain compile-time and triple-launch-argument gated"
)
require(
    managementAccess.contains("struct PublicationLifecycleCommand")
        && managementAccess.contains("expectedAuthorityEpoch")
        && managementAccess.contains("struct PublicationLifecycleReceipt")
        && managementAccess.contains("accessDenyState")
        && managementAccess.contains("publicIndexCleanupState"),
    "lifecycle command and receipt must keep explicit concurrency and cleanup contracts"
)
require(
    managementAccess.contains("final class PublicationLifecycleUseCase")
        && managementAccess.contains("pendingCommandIDs")
        && managementAccess.contains("PublicationWithdrawalPresentationPolicy")
        && managementAccess.contains("routeAllowed: Bool")
        && managementAccess.contains("accountLeaseRuntime.validate(accountLease, at: .request)")
        && managementAccess.contains("accountLeaseRuntime.validate(accountLease, at: .commit)"),
    "ordinary withdrawal presentation and lifecycle use case must remain route-, lease-, and retry-bound"
)
require(
    backendClient.contains("/v2/internal/publication-lifecycle/vaults/")
        && backendClient.contains("X-DreamJourney-QA-Publication-Lifecycle")
        && backendClient.contains("X-DreamJourney-QA-Publication")
        && backendClient.contains("X-DreamJourney-QA-Visitor-Access")
        && backendClient.contains("PublicationLifecycleM2QAGate.isEnabled"),
    "lifecycle transport must require all three internal QA boundaries"
)
require(
    backendClient.contains("return .publicationManagementM2")
        && backendClient.contains("isExplicitPublicationLifecycleQARequest"),
    "lifecycle route must remain feature classified and explicit-QA scoped"
)
require(
    visitorAccess.contains("case accessRevoked")
        && visitorAccess.contains("sessionCoordinator.invalidate(resolution.invalidationReason)")
        && visitorAccess.contains("publicationVisitorAccessUnavailable")
        && visitorAccess.contains("publicationVisitorAccessDenied"),
    "visitor reads must clear in-memory scope on withdrawal/access revocation"
)
require(
    managementView.contains("PublicationManagementM2AccessGate.isLifecycleRouteAllowed")
        && managementView.contains("PublicationWithdrawalPresentationPolicy.isAvailable")
        && managementView.contains("UIAlertController(")
        && managementView.contains("撤回后，现有受邀访问会立即停止")
        && managementView.contains("profile-publication-management-qa-withdraw")
        && managementView.contains("profile-publication-management-qa-withdraw-receipt")
        && managementView.contains("stack.accessibilityValue = \"\\(grant.state):\\(grant.useRemaining)\"")
        && managementView.contains("访问阻断已完成；公开索引清理待处理"),
    "ordinary withdrawal must require the server-managed route, explicit confirmation, and a visible receipt"
)
require(
    appDelegate.contains("case .publicationLifecycleM2Smoke")
        && appDelegate.contains("runPublicationLifecycleM2Smoke()")
        && appDelegate.contains("publication-lifecycle-m2-smoke-result.json")
        && appDelegate.contains("grantRevokedRendered")
        && appDelegate.contains("grantState = \"revoked\"")
        && appDelegate.contains("[UI_QA] PublicationLifecycleM2Smoke completed"),
    "UIQA harness must produce a pollable lifecycle result"
)
require(
    smokeRunner.contains("DJEnablePublicationManagementM2QA")
        && smokeRunner.contains("DJEnablePublicationVisitorM2QA")
        && smokeRunner.contains("DJEnablePublicationLifecycleM2QA")
        && smokeRunner.contains("withdrawButtonRendered")
        && smokeRunner.contains("grantRevokedRendered")
        && smokeRunner.contains("fixtureWithdrawalObserved"),
    "simulator smoke must prove the three gates and withdrawal receipt"
)
require(
    project.contains("PublicationManagementAccess.swift in Sources")
        && project.contains("PublicationVisitorAccess.swift in Sources")
        && project.contains("PublicationManagementAccessTests.swift in Sources")
        && project.contains("PublicationVisitorAccessTests.swift in Sources"),
    "lifecycle source and its focused tests must stay in Xcode targets"
)

for forbiddenSymbol in [
    "UserDefaults",
    "grantCredential",
    "sessionCredential",
    "DigitalHumanContextStore",
    "VoiceClone",
    "KBLite",
    "MemoryRepository",
] {
    require(
        !managementAccess.contains(forbiddenSymbol)
            && !managementView.contains(forbiddenSymbol),
        "lifecycle QA shell must not persist or expose private runtime symbol \(forbiddenSymbol)"
    )
}

print("Publication lifecycle iOS scope gate passed")
