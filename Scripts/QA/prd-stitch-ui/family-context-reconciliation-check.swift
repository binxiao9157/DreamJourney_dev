#!/usr/bin/env swift

import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func read(_ path: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Family context reconciliation check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(_ signature: String, in source: String) -> String {
    guard let signatureRange = source.range(of: signature),
          let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
        fputs("Family context reconciliation check failed: missing \(signature)\n", stderr)
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
    fputs("Family context reconciliation check failed: unterminated \(signature)\n", stderr)
    exit(1)
}

let policy = try read("DreamJourney/Sources/Services/FamilyRelationshipAuthorizationPolicy.swift")
let repository = try read("DreamJourney/Sources/Services/FamilyRepository.swift")
let store = try read("DreamJourney/Sources/App/DigitalHumanContextStore.swift")
let echo = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

require(policy.contains("enum FamilyContextReconciliationPolicy"), "a pure family context fallback policy is required")
let acceptedMember = functionBody("func acceptedMember(by id: String)", in: repository)
require(acceptedMember.contains("authorizationFreshness.allowsPreviouslyVerifiedUse"), "failed family freshness must deny old members")
require(repository.contains("DigitalHumanContextStore.shared.reconcileFamilyAuthorization()"), "family authority changes must reconcile persisted context")

let reconcileEntry = functionBody("func reconcileFamilyAuthorization()", in: store)
require(reconcileEntry.contains("guard Thread.isMainThread"), "reconciliation must serialize on the main thread")
require(reconcileEntry.contains("accountLeaseRuntime.capture"), "reconciliation must capture source account authority")
let reconcile = functionBody("private func reconcileFamilyAuthorization(", in: store)
require(reconcile.contains("FamilyContextReconciliationPolicy.shouldFallbackToSelf"), "reconciliation must use the explicit fallback policy")
require(reconcile.contains("applyCurrent("), "revoked family context must use the captured lease")
require(reconcile.contains(".defaultContext(userId: userId)"), "revoked family context must persist self")

let setter = functionBody("set {", in: store)
for required in [
    "let sourceUserId = normalizedUserId(UserManager.shared.currentUser?.id)",
    "accountLeaseRuntime.capture(forSubjectId: sourceUserId)",
    "applyCurrent(newValue, userId: sourceUserId, accountLease: accountLease)",
] {
    require(setter.contains(required), "context setter must include \(required)")
}
let applyCurrent = functionBody("private func applyCurrent(", in: store)
for required in [
    "UserDefaults.standard.set(data, forKey: key(for: userId))",
    "KBLiteManager.shared.personaContextDidChange(to: identity)",
    "KnowledgeSyncCoordinator.shared.personaContextDidChange(to: identity)",
    "guard previousContext != safeContext else { return }",
    "NotificationCenter.default.post(name: .djDigitalHumanContextDidChange",
] {
    require(applyCurrent.contains(required), "context apply must include \(required)")
}
require(applyCurrent.contains("at: .commit"), "context persistence must validate its AccountLease")
require(applyCurrent.contains("at: .ui"), "context notification must validate its AccountLease")

require(echo.contains("name: .djDigitalHumanContextDidChange"), "Echo must observe context changes")
let echoChange = functionBody("@objc private func digitalHumanContextDidChange()", in: echo)
require(echoChange.contains("reconcileDigitalHumanRuntimeWithCurrentContext"), "Echo must release stale family runtime")
require(echoChange.contains("prepareCloudDigitalHumanRuntimeIfNeeded"), "Echo must prepare the fallback self runtime")
require(echoChange.contains("viewModel.refreshArchiveContextStatus()"), "Echo must refresh persona-scoped context status")

print("Family context reconciliation check passed")
