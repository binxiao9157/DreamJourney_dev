#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Echo family context authorization check failed: \(message)\n", stderr)
        exit(1)
    }
}

let identity = try read("DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift")
let manager = try read("DreamJourney/Sources/Services/KBLiteManager.swift")
let contextStore = try read("DreamJourney/Sources/App/DigitalHumanContextStore.swift")
let echo = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

require(!identity.contains("personalRelations"), "relation labels must not grant personal identity")
require(manager.contains("resolveAuthorizedPersonaIdentity"), "KBLite must expose an authorized identity resolver")
require(manager.contains("FamilyRepository.shared.acceptedMember"), "family identity must require an accepted repository member")
require(contextStore.contains("validatedContext"), "persisted digital-human context must be revalidated")
require(contextStore.contains("FamilyRepository.shared.acceptedMember"), "context restore must require accepted member")
require(contextStore.contains("keyBase"), "digital-human context persistence must be owner scoped")
require(echo.contains("familyRelationshipUnauthorized"), "Echo must record an explicit unauthorized-family fallback")
require(echo.contains("guard let expectedIdentity = echoKnowledgeContextIdentity"), "Echo must preflight identity before backend request")
require(echo.contains("viewerFamilyMemberID: context.isSelfAssistant ? nil : context.ownerId"), "family context request must carry the accepted member ID")

print("Echo family context authorization check passed")
