#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Family repository authorization lifecycle check failed: \(message)\n", stderr)
        exit(1)
    }
}

let model = try read("DreamJourney/Sources/Services/MemoryModel.swift")
let policy = try read("DreamJourney/Sources/Services/FamilyRelationshipAuthorizationPolicy.swift")
let repository = try read("DreamJourney/Sources/Services/FamilyRepository.swift")
let coordinator = try read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")
let appDelegate = try read("DreamJourney/Sources/AppDelegate.swift")
let sceneDelegate = try read("DreamJourney/Sources/SceneDelegate.swift")
let appCoordinator = try read("DreamJourney/Sources/App/AppCoordinator.swift")

require(model.contains("relationshipOwnerUserId: String = \"\""), "local model default must have no owner authority")
require(model.contains("relationshipAuthoritySource: FamilyRelationshipAuthoritySource = .legacyUnverified"), "local model default must be legacy-unverified")
require(model.contains("accessStatus: String = \"pending\""), "local model access must default pending")
require(model.contains("invitationStatus: String = \"pending\""), "local invitation must default pending")
require(model.contains("relationshipAuthoritySource: .backendInvitation"), "backend parser must mark backend invitation authority")

for required in [
    "private(set) var knowledgeCandidates",
    "private var activeOwnerUserId",
    "private var userGeneration",
    "bootstrapCurrentUserFromBackend(",
    "private var authorizationFreshness = FamilyAuthorizationFreshness()",
    "acceptedMembersForKnowledgeSync(ownerUserId:",
    "func acceptedMember(by id: String)",
    "replaceRemoteMembers",
    "capturedGeneration",
    "capturedRefreshGeneration",
    "FamilyAuthorizationRefreshResponsePolicy.accepts(",
    "FamilyRepositoryError.staleResponse",
    "relationshipAuthoritySource: .localInvitationAttempt",
    "ownerScopedKey(base:",
    ".djUserDidLogin",
    ".djUserDidLogout",
] {
    require(repository.contains(required), "repository must include \(required)")
}

require(!repository.contains("seedMockData()"), "release repository must not seed accepted mock family members")
require(repository.contains("FamilyRelationshipCandidate("), "KB people must be projected as candidates")
require(repository.contains("未授予家庭权限"), "candidate projection must document non-authorization")
require(repository.contains("KnowledgeSyncCoordinator.shared.familyAuthorizationDidRefresh"), "verified family authority refresh must update account sync")
require(repository.contains("KnowledgeSyncCoordinator.shared.familyAuthorizationRefreshFailed"), "failed family refresh must invalidate account sync")
require(policy.contains("case .knowledgeCandidate, .localInvitationAttempt, .legacyUnverified"), "non-backend sources must fail closed")
require(policy.contains("currentBuildAllowsQAFixtures"), "QA fixture behavior must be compile-time explicit")

for required in [
    "additionalIdentities:",
    "FamilyRepository.shared.acceptedMembersForKnowledgeSync(ownerUserId: userId)",
    "private var activeSyncAuthorization",
    "guard Thread.isMainThread",
    "func familyAuthorizationRefreshStarted(ownerUserId: String)",
    "func familyAuthorizationDidRefresh(ownerUserId: String, authorizationChanged: Bool)",
    "func familyAuthorizationRefreshFailed(ownerUserId: String)",
] {
    require(coordinator.contains(required), "knowledge sync must consume an account-level immutable family authorization snapshot: \(required)")
}

require(
    sceneDelegate.contains("handleSceneLifecycleEvent(.willEnterForeground)"),
    "SceneDelegate must forward foreground lifecycle events to AppCoordinator"
)
let foregroundRefreshStart = appCoordinator.range(
    of: "private static func refreshPrivateForegroundRuntime"
)
let foregroundFamilyRefresh = appCoordinator.range(
    of: "FamilyRepository.shared.bootstrapCurrentUserFromBackend",
    range: foregroundRefreshStart.map { $0.lowerBound..<appCoordinator.endIndex }
)
let foregroundKnowledgeSync = appCoordinator.range(
    of: "reason: \"foregroundAfterFamilyRefresh\"",
    range: foregroundRefreshStart.map { $0.lowerBound..<appCoordinator.endIndex }
)
require(
    foregroundFamilyRefresh != nil,
    "foreground must refresh family authorization before knowledge sync"
)
require(
    foregroundKnowledgeSync != nil,
    "foreground sync must run only after family refresh completion"
)
if let foregroundFamilyRefresh, let foregroundKnowledgeSync {
    require(
        foregroundFamilyRefresh.lowerBound < foregroundKnowledgeSync.lowerBound,
        "family authorization refresh must be registered before foreground knowledge sync"
    )
}

let qaFixtureCount = appDelegate.components(separatedBy: "relationshipAuthoritySource: .qaFixture").count - 1
require(qaFixtureCount >= 4, "existing AppDelegate family QA fixtures must be explicitly marked")

print("Family repository authorization lifecycle check passed")
