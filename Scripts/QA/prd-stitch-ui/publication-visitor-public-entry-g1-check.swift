#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let sourcesRoot = root.appendingPathComponent("DreamJourney/Sources")

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Publication/visitor public-entry G1 check failed: \(message)\n", stderr)
        exit(1)
    }
}

func swiftSources() throws -> [URL] {
    let keys: Set<URLResourceKey> = [.isRegularFileKey]
    let enumerator = FileManager.default.enumerator(
        at: sourcesRoot,
        includingPropertiesForKeys: Array(keys),
        options: [.skipsHiddenFiles]
    )
    return try enumerator?.compactMap { candidate in
        guard let url = candidate as? URL,
              url.pathExtension == "swift",
              (try url.resourceValues(forKeys: keys).isRegularFile == true) else {
            return nil
        }
        return url
    } ?? []
}

func relativePath(_ url: URL) -> String {
    url.path.replacingOccurrences(of: root.path + "/", with: "")
}

let tabCoordinator = try read("DreamJourney/Sources/App/TabCoordinator.swift")
let routeModel = try read("DreamJourney/Sources/App/AccountLease.swift")
let archive = try read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let map = try read("DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift")
let repository = try read("DreamJourney/Sources/Services/MemoryRepository.swift")
let multiUser = try read("DreamJourney/Sources/Services/KBLiteMultiUser.swift")
let knowledge = try read("DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift")
let userManager = try read("DreamJourney/Sources/Services/UserManager.swift")
let appCoordinator = try read("DreamJourney/Sources/App/AppCoordinator.swift")
let infoPlist = try read("DreamJourney/Resources/Info.plist")
let sourceFiles = try swiftSources()

// Release navigation is deliberately limited to the closed owner-core shell.
require(
    tabCoordinator.contains("tabBarController.viewControllers = [archiveNav, echoNav, profileNav]"),
    "release shell must expose only archive, echo and profile"
)
for forbidden in [
    "MapFootprintViewController",
    "KBSyncViewController",
    "FamilyCircleViewController",
    "Publication",
    "Visitor",
] {
    require(!tabCoordinator.contains(forbidden), "release tab shell must not expose \(forbidden)")
}

// The remaining map entry is owner-only; the guest branch is not a release route.
require(
    archive.contains("MapFootprintViewController(\n            viewMode: .host,"),
    "archive map entry must construct host mode"
)
require(
    map.contains("case .guest:\n            memories = MemoryRepository.shared.getPublicByOwner("),
    "legacy public-memory query must remain confined to the map guest branch"
)
require(
    repository.contains("getAllByOwner(ownerId, accountLease: accountLease).filter { !$0.isPrivate }"),
    "legacy public-memory query must remain a local visibility filter"
)

let publicMemoryReferences = try sourceFiles.filter { url in
    try String(contentsOf: url, encoding: .utf8).contains("getPublicByOwner(")
}.map(relativePath).sorted()
require(
    publicMemoryReferences == [
        "DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift",
        "DreamJourney/Sources/Services/MemoryRepository.swift",
    ],
    "getPublicByOwner must not be reused outside the legacy map guest path: \(publicMemoryReferences)"
)

let guestReferencesOutsideLegacyMap = try sourceFiles.compactMap { url -> String? in
    let path = relativePath(url)
    guard path != "DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift",
          path != "DreamJourney/Sources/Modules/Memory/MemoryDetailViewController.swift" else {
        return nil
    }
    return try String(contentsOf: url, encoding: .utf8).contains(".guest") ? path : nil
}.sorted()
require(
    guestReferencesOutsideLegacyMap.isEmpty,
    "production sources must not create guest mode outside legacy map/detail code: \(guestReferencesOutsideLegacyMap)"
)

// Legacy local graph packages are QA-simulator-only and have no release entry.
require(
    multiUser.contains("#if UI_QA_SIMULATOR && targetEnvironment(simulator)")
        && multiUser.contains("return false"),
    "legacy local knowledge sharing must be compile-time closed in release"
)
require(
    knowledge.contains("if FamilyKnowledgeSharePolicy.allowsLegacyLocalPackages"),
    "knowledge UI must gate the legacy family-sync entry"
)
let syncControllerReferences = try sourceFiles.filter { url in
    try String(contentsOf: url, encoding: .utf8).contains("KBSyncViewController(")
}.map(relativePath).sorted()
require(
    syncControllerReferences == ["DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift"],
    "KBSync must only be created from its compile-time-gated knowledge UI entry: \(syncControllerReferences)"
)

// Notification deeplinks can select neutral tabs only; they cannot create visitor/public routes.
let kindStart = routeModel.range(of: "enum NotificationRuntimeRouteKind")
let kindEnd = routeModel.range(of: "enum NotificationRuntimeRouteAction")
require(kindStart != nil && kindEnd != nil, "notification route kind declaration is required")
let routeKinds = String(routeModel[kindStart!.lowerBound..<kindEnd!.lowerBound]).lowercased()
for required in ["echodelayedreply", "timeletter", "familyinvitation", "caresignal", "systemnotice"] {
    require(routeKinds.contains(required), "notification route kind must include \(required)")
}
for forbidden in ["guest", "public", "share", "visitor", "publication"] {
    require(!routeKinds.contains(forbidden), "notification route kinds must not expose \(forbidden)")
}
require(!infoPlist.contains("CFBundleURLTypes"), "release build must not register an unvalidated custom URL scheme")

// A locally seeded legacy profile is not sufficient to enter a private release
// route. Release smoke must remain behind a verified backend session.
require(
    userManager.contains("guard state == .authenticated else { return false }")
        && userManager.contains("session.isPrivateAccessEligible(for: user.id)"),
    "private UI must require an authenticated, eligible backend session"
)
require(
    appCoordinator.contains("let credential = UserManager.shared.accountSessionCredentialSnapshot()")
        && appCoordinator.contains("case .authentication:")
        && appCoordinator.contains("self.transitionToAuth()"),
    "cold start must route an unverified local profile to authentication"
)

print("Publication/visitor public-entry G1 check passed")
