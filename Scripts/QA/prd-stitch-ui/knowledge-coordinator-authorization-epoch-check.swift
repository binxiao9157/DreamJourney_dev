#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Knowledge coordinator authorization epoch check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(_ signature: String, in source: String) -> String {
    guard let signatureRange = source.range(of: signature),
          let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
        fputs("Knowledge coordinator authorization epoch check failed: missing \(signature)\n", stderr)
        exit(1)
    }
    var depth = 0
    var cursor = openingBrace
    while cursor < source.endIndex {
        if source[cursor] == "{" { depth += 1 }
        if source[cursor] == "}" {
            depth -= 1
            if depth == 0 { return String(source[openingBrace...cursor]) }
        }
        cursor = source.index(after: cursor)
    }
    fputs("Knowledge coordinator authorization epoch check failed: unterminated \(signature)\n", stderr)
    exit(1)
}

let policy = try read("DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift")
let coordinator = try read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")

for required in [
    "struct KnowledgeAuthorizationEpochState: Equatable",
    "mutating func rotate() -> UUID",
    "func accepts(boundEpoch: UUID?) -> Bool",
] {
    require(policy.contains(required), "epoch model must include \(required)")
}

for required in [
    "private var activeAuthorizationEpoch: UUID?",
    "private var authorizationEpochState = KnowledgeAuthorizationEpochState()",
    "private let authorizationEpochLock = NSLock()",
    "private let queueIdentityKey = DispatchSpecificKey<UInt8>()",
    "private func rotateAuthorizationEpoch(",
    "private func rotateAuthorizationEpochForPersonaChange(",
    "private func rotateAuthorizationEpochForFamilyRefresh(ownerUserId:",
    "private func performSynchronouslyOnQueue(_ block: () -> Void)",
] {
    require(coordinator.contains(required), "coordinator must include \(required)")
}

for (signature, rotation) in [
    ("func userDidChange(to userId: String?)", "rotateAuthorizationEpoch("),
    ("func personaContextDidChange(to identity: KBPersonaIdentity?)", "rotateAuthorizationEpochForPersonaChange("),
    ("func familyAuthorizationRefreshStarted(ownerUserId: String)", "rotateAuthorizationEpochForFamilyRefresh("),
] {
    let body = functionBody(signature, in: coordinator)
    require(body.contains(rotation), "\(signature) must rotate epoch before queue invalidation")
    require(body.contains("performSynchronouslyOnQueue"), "\(signature) must finish queue invalidation before returning")
    require(body.contains("activeAuthorizationEpoch = authorizationEpoch"), "\(signature) must bind the new queue generation")
    require(!body.contains("queue.async"), "\(signature) must not defer invalidation asynchronously")
}

let isCurrent = functionBody("private func isCurrent(userId: String, generation: UUID)", in: coordinator)
require(isCurrent.contains("authorizationEpochState.accepts(boundEpoch: activeAuthorizationEpoch)"), "every callback guard must validate its bound authorization epoch")
let syncBody = functionBody("func synchronizeCurrentUser(reason: String)", in: coordinator)
require(syncBody.contains("activeAuthorizationEpoch = authorizationEpoch"), "a new account sync generation must bind the current epoch")
require(!coordinator.contains("DispatchQueue.main.sync"), "synchronous invalidation must not create a queue-to-main deadlock")

print("Knowledge coordinator authorization epoch check passed")
