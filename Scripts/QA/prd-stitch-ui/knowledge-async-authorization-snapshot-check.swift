#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Knowledge async authorization snapshot check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(_ signature: String, in source: String) -> String {
    guard let signatureRange = source.range(of: signature),
          let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
        fputs("Knowledge async authorization snapshot check failed: missing \(signature)\n", stderr)
        exit(1)
    }
    var depth = 0
    var cursor = openingBrace
    while cursor < source.endIndex {
        if source[cursor] == "{" {
            depth += 1
        } else if source[cursor] == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[openingBrace...cursor])
            }
        }
        cursor = source.index(after: cursor)
    }
    fputs("Knowledge async authorization snapshot check failed: unterminated \(signature)\n", stderr)
    exit(1)
}

let policy = try read("DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift")
let manager = try read("DreamJourney/Sources/Services/KBLiteManager.swift")
let memory = try read("DreamJourney/Sources/Services/ConversationMemoryManager.swift")
let coordinator = try read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")
let merge = try read("DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift")
let contextStore = try read("DreamJourney/Sources/App/DigitalHumanContextStore.swift")
let familyRepository = try read("DreamJourney/Sources/Services/FamilyRepository.swift")

for required in [
    "struct KBPersonaAuthorizationSnapshot: Equatable",
    "let userGeneration: UUID",
    "let personaGeneration: UUID",
    "let familyAuthorizationGeneration: UUID?",
] {
    require(policy.contains(required), "snapshot model must include \(required)")
}

for required in [
    "private var activePersonaIdentity: KBPersonaIdentity?",
    "private var personaGeneration = UUID()",
    "private var familyAuthorizationGeneration: UUID?",
    "captureCurrentPersonaAuthorizationSnapshot()",
    "familyAuthorizationGenerationDidChange(ownerUserId:",
    "isCurrentAuthorizationSnapshotLocked",
] {
    require(manager.contains(required), "KBLite must own immutable authorization state: \(required)")
}

let captureBody = functionBody("static func captureCurrentPersonaAuthorizationSnapshot()", in: manager)
require(captureBody.contains("guard Thread.isMainThread"), "FamilyRepository authorization must be captured on the main thread")
require(captureBody.contains("FamilyRepository.shared.authorizationGeneration"), "family snapshots must capture the authority generation")

let finishBody = functionBody("private func finishExtraction(", in: manager)
require(finishBody.contains("isCurrentAuthorizationSnapshotLocked"), "extraction completion must compare the captured token")
require(!finishBody.contains("resolveCurrentPersonaIdentity"), "extraction completion must not resolve mutable current context")
require(!finishBody.contains("FamilyRepository"), "extraction completion must not read FamilyRepository")

let capturePosition = memory.range(of: "captureCurrentPersonaAuthorizationSnapshot()")?.lowerBound
let dispatchPosition = memory.range(of: "DispatchQueue.global(qos: .utility).async")?.lowerBound
require(capturePosition != nil && dispatchPosition != nil && capturePosition! < dispatchPosition!, "conversation memory must capture authorization before background dispatch")
require(memory.contains("authorizationSnapshot: knowledgeAuthorization"), "conversation extraction must pass the immutable snapshot")

let startGovernanceBody = functionBody("private func startNextGovernance(", in: coordinator)
let successBody = functionBody("private func handleGovernanceSuccess(", in: coordinator)
for body in [startGovernanceBody, successBody] {
    require(!body.contains("resolveCurrentPersonaIdentity"), "governance queue paths must not resolve mutable context")
    require(!body.contains("FamilyRepository"), "governance queue paths must not read FamilyRepository")
}
require(startGovernanceBody.contains("activePersonaIdentity"), "governance dispatch must use queue-owned persona identity")
require(startGovernanceBody.contains("authorization.allows(identity:"), "governance dispatch must use queue-owned authorization")
require(successBody.contains("activePersonaIdentity == item.expectedIdentity"), "governance response must recheck queue-owned identity")
require(merge.contains("func allows(identity: KBPersonaIdentity) -> Bool"), "account authorization scope must validate a persona identity")

require(contextStore.contains("KBLiteManager.shared.personaContextDidChange(to: identity)"), "context changes must rotate the extraction persona generation")
require(contextStore.contains("KnowledgeSyncCoordinator.shared.personaContextDidChange(to: identity)"), "context changes must update governance queue state")
require(familyRepository.contains("KBLiteManager.shared.familyAuthorizationGenerationDidChange"), "family refresh lifecycle must rotate extraction authorization")

print("Knowledge async authorization snapshot check passed")
