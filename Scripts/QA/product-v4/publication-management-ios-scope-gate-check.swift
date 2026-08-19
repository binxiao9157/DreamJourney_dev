#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Publication management iOS scope gate failed: \(message)\n", stderr)
        exit(1)
    }
}

let featureFlags = try read("DreamJourney/Sources/App/FeatureFlagService.swift")
let backendClient = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let managementAccess = try read("DreamJourney/Sources/Services/PublicationManagementAccess.swift")
let managementView = try read("DreamJourney/Sources/Modules/Profile/ProfilePublicationManagementQAViewController.swift")
let publicationEditor = try read("DreamJourney/Sources/Modules/Archive/OwnerPublicationDraftViewControllers.swift")
let profile = try read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let tabCoordinator = try read("DreamJourney/Sources/App/TabCoordinator.swift")
let appDelegate = try read("DreamJourney/Sources/AppDelegate.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(
    featureFlags.contains("case publication")
        && featureFlags.contains(".publication,"),
    "M2 management feature must be non-persistent and default-off"
)
require(
    managementAccess.contains("static let launchArgument = \"DJEnablePublicationManagementM2QA\"")
        && managementAccess.contains("QALaunchConfiguration.shared.contains(launchArgument)")
        && managementAccess.contains("PublicationManagementAccessGate")
        && managementAccess.contains("isServerPolicyManagedRouteAllowed"),
    "management must preserve QA access while requiring server policy for formal routes"
)
require(
    backendClient.contains("/v2/internal/owner-authority/vaults/")
        && backendClient.contains("/v2/internal/publication-access/vaults/")
        && backendClient.contains("/v2/vaults/\\(pathComponent(normalizedVaultID))/publications")
        && backendClient.contains("/v2/vaults/\\(pathComponent(normalizedVaultID))/publication-grants")
        && backendClient.contains("X-DreamJourney-QA-Publication")
        && backendClient.contains("X-DreamJourney-QA-Visitor-Access")
        && backendClient.contains("PublicationManagementM2QAGate.isEnabled"),
    "management transport must separate internal QA and formal closed-beta routes"
)
require(
    backendClient.contains("return .publication")
        && backendClient.contains("return .publicationGrantManagement")
        && backendClient.contains("return \"publicationManagement\""),
    "management requests must be purpose and feature classified"
)
require(
    managementAccess.contains("accountLeaseRuntime.validate(accountLease, at: .request)")
        && managementAccess.contains("accountLeaseRuntime.validate(accountLease, at: .commit)")
        && managementAccess.contains("responseScopeMismatch"),
    "management reads must bind request and response to the AccountLease vault"
)
require(
    managementAccess.contains("publication-owner-management-v1")
        && managementAccess.contains("publication-owner-grant-list-v2")
        && managementAccess.contains("publication-owner-grant-issue-v1")
        && managementAccess.contains("publication-owner-version-audit-v1")
        && !managementAccess.contains("UserDefaults")
        && !managementAccess.contains(": Codable"),
    "management state must remain schema-checked and in memory only"
)
require(
    managementAccess.contains("protocol PublicationGrantManagementClient")
        && managementAccess.contains("final class PublicationGrantManagementUseCase")
        && managementAccess.contains("recipientDisplayLabel")
        && backendClient.contains("func issueOwnerPublicationGrant(")
        && backendClient.contains("func revokeOwnerPublicationGrant(")
        && managementView.contains("profile-publication-management-create-grant")
        && managementView.contains("profile-publication-management-revoke-grant")
        && managementView.contains("不限制产品查询次数")
        && !managementView.contains("剩余 "),
    "registered-account ShareGrant management must be typed and must not expose a product query balance"
)
require(
    !managementAccess.contains("grantCredential")
        && !managementAccess.contains("invitationURL")
        && !managementView.contains("grantCredential")
        && !managementView.contains("granteeUserId"),
    "registered-account invitations must not create or expose anonymous share credentials"
)
require(
    managementAccess.contains("protocol PublicationVersionAuditReaderClient")
        && managementAccess.contains("final class PublicationVersionAuditUseCase")
        && backendClient.contains("/publications/\\(pathComponent(normalizedPublicationID))/versions")
        && managementView.contains("查看版本记录"),
    "owner version audit must use a typed, lease-bound publication route"
)
require(
    managementAccess.contains("struct PublicationRevisionDraftCreateCommand")
        && managementAccess.contains("func createRevision(")
        && backendClient.contains("/publications/\\(pathComponent(normalizedPublicationID))/drafts")
        && managementView.contains("基于当前版本创建新版本")
        && managementView.contains("profile-publication-management-create-revision")
        && publicationEditor.contains("case revision(publicationID: String, baseVersion: PublicationOwnerVersion)")
        && publicationEditor.contains("当前版本的条目与顺序保持不变"),
    "owner revision must reuse the typed editor, preserve order and use the formal v3 route"
)
require(
    managementAccess.contains("publication-authority-v3")
        && managementAccess.contains("basePublicationVersionId")
        && managementAccess.contains("targetPublicationVersion")
        && !managementAccess.contains("UserDefaults"),
    "revision receipts must remain schema-checked, transient and bound to the immutable base version"
)

for forbiddenSymbol in [
    "EchoViewController",
    "DigitalHumanContextStore",
    "DialogEngineManager",
    "TencentDigitalHuman",
    "VoiceClone",
    "KBLite",
    "MemoryRepository",
    "sessionCredential",
] {
    require(
        !managementAccess.contains(forbiddenSymbol)
            && !managementView.contains(forbiddenSymbol)
            && !publicationEditor.contains(forbiddenSymbol),
        "management shell must not expose or depend on private runtime symbol \(forbiddenSymbol)"
    )
}

require(
    profile.contains("PublicationManagementAccessGate.isManagementRouteAllowed")
        && profile.contains("case publicationManagementQA")
        && profile.contains("profile-publication-management-qa-entry"),
    "management route must be Profile-only and policy gated"
)
require(
    !tabCoordinator.contains("PublicationManagement"),
    "M2 management must not add a public Tab"
)
require(
    appDelegate.contains("case .publicationManagementM2Smoke")
        && appDelegate.contains("runPublicationManagementM2Smoke()")
        && appDelegate.contains("publication-management-m2-smoke-result.json")
        && appDelegate.contains("[UI_QA] PublicationManagementM2Smoke completed"),
    "UIQA harness must produce a pollable M2 result"
)
require(
    project.contains("PublicationManagementAccess.swift in Sources")
        && project.contains("ProfilePublicationManagementQAViewController.swift in Sources")
        && project.contains("PublicationManagementAccessTests.swift in Sources"),
    "management source and tests must be in Xcode targets"
)

print("Publication management iOS scope gate passed")
