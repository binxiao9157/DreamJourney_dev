#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Knowledge family sync/import authorization check failed: \(message)\n", stderr)
        exit(1)
    }
}

let engine = try read("DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift")
let coordinator = try read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")
let manager = try read("DreamJourney/Sources/Services/KBLiteManager.swift")
let multiUser = try read("DreamJourney/Sources/Services/KBLiteMultiUser.swift")
let knowledgeUI = try read("DreamJourney/Sources/Modules/Knowledge/KnowledgeBaseViewController.swift")
let syncUI = try read("DreamJourney/Sources/Modules/Knowledge/KBSyncViewController.swift")

for required in [
    "KnowledgeSyncAuthorizationScope",
    "authorization: KnowledgeSyncAuthorizationScope",
    "additionalIdentities: [KBPersonaIdentity] = []",
    "authorization.allows(",
] {
    require(engine.contains(required), "sync engine must include \(required)")
}

require(coordinator.contains("currentSyncAuthorization(userId:"), "coordinator must derive an authorization scope")
require(coordinator.contains("FamilyRepository.shared.acceptedMembersForKnowledgeSync(ownerUserId: userId)"), "coordinator must use a verified current-owner family authorization snapshot")
require(coordinator.contains("personaScope: \"personal\""), "coordinator must always include the authenticated user's personal identity")
require(coordinator.contains("let authorizedRemoteGraph = try KnowledgeSyncGraphEngine.syncPayloadGraph"), "remote base persistence must exclude unauthorized persona data")
require(!coordinator.contains("syncPayloadGraph(from: localGraph)"), "sync calls must not omit authorization")
require(manager.contains("evidenceStatus: \"observed\",\n                    sourceTurnIndices: [],\n                    to: &place"), "image-analysis places must receive an authorized identity")
require(manager.contains("evidenceStatus: \"observed\",\n                    sourceTurnIndices: [],\n                    to: &person"), "image-analysis people must receive an authorized identity")
require(manager.contains("kb_graph_legacy_quarantine"), "ownerless legacy graph files must be quarantined instead of assigned to the next login")

require(multiUser.contains("FamilyKnowledgeSharePolicy"), "legacy family sharing needs an explicit policy")
require(multiUser.contains("case backendGrantRequired"), "release import must fail with a grant-required reason")
require(multiUser.contains("normalizedSource.lowercased() != \"unknown\""), "unknown/raw graph source must be rejected")
require(syncUI.contains("FamilyKnowledgeSharePolicy.allowsLegacyLocalPackages ? 2 : 0"), "release UI must hide legacy share actions")
require(knowledgeUI.contains("if FamilyKnowledgeSharePolicy.allowsLegacyLocalPackages"), "release UI must hide the dead legacy family-sync entry")
require(syncUI.contains("FamilyKnowledgeShareError.invalidSourceIdentity"), "raw graph UI must report rejection")
require(!syncUI.contains("mergeFromFamilyMember(json: jsonString, sourceUserId: \"unknown\")"), "raw graph must not be merged")

print("Knowledge family sync/import authorization check passed")
