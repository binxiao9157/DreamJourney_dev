import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("knowledge-governance-coordinator-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func position(_ needle: String, in source: String) -> String.Index {
    guard let range = source.range(of: needle) else {
        fputs("knowledge-governance-coordinator-check failed: missing \(needle)\n", stderr)
        exit(1)
    }
    return range.lowerBound
}

let coordinator = try read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")
let outbox = try read("DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift")

require(coordinator.contains("private let governanceOutboxStore = KnowledgeGovernanceOutboxStore()"),
        "coordinator must own the durable governance outbox")
require(coordinator.contains("func performGovernance("),
        "coordinator governance entry point is missing")
require(coordinator.contains("private func startNextGovernance("),
        "governance requests must share the serial sync coordinator")
require(coordinator.contains("guard isCurrent(context, at: .request), !isSyncing"),
        "governance must use the AccountLease context and single network owner gate")
require(coordinator.contains("let accountLease: AccountLease"),
        "governance context must carry the central AccountLease")
require(coordinator.contains("accountLeaseRuntime.validate(context.accountLease, at: checkpoint).allowed"),
        "governance callbacks and commits must validate their captured AccountLease")

let enqueuePosition = position("try self.governanceOutboxStore.enqueue(item, for: userId)", in: coordinator)
let requestPosition = position("DreamJourneyBackendClient.shared.governKnowledge(", in: coordinator)
require(enqueuePosition < requestPosition,
        "governance action must be persisted before the backend request")

require(coordinator.contains("$0.expectedIdentity == currentIdentity"),
        "pending action must match the current persona before dispatch")
require(coordinator.contains("private var activePersonaIdentity: KBPersonaIdentity?"),
        "governance must own an immutable queue persona snapshot")
require(coordinator.contains("authorization.allows(identity: currentIdentity)"),
        "pending action must be covered by the queue-owned account authorization")
require(coordinator.contains("activePersonaIdentity == item.expectedIdentity"),
        "persona identity must be checked again before applying the response")

require(coordinator.contains("if Self.isRevisionConflict(error)"),
        "revision conflicts must be handled explicitly")
require(coordinator.contains("enqueueSync(reason: \"governanceRevisionConflict\", context: context)"),
        "revision conflicts must refresh the remote base before retry")
require(coordinator.contains("operationId: item.operationId"),
        "retryable governance requests must preserve their operation ID")
require(coordinator.contains("if Self.isOperationPayloadConflict(error)"),
        "operation payload conflicts must have an explicit disposition")
require(coordinator.contains("private func handleGovernancePayloadConflict("),
        "governance payload conflict recovery must be centralized")
require(coordinator.contains("item.rotatingOperation(to: nextOperationId)"),
        "the first payload conflict must rotate the poisoned operation ID")
require(coordinator.contains("item.quarantined(reason: \"knowledgeOperationPayloadConflict\")"),
        "a repeated payload conflict must enter durable quarantine")
require(coordinator.contains("!$0.isQuarantined && $0.expectedIdentity == currentIdentity"),
        "quarantined actions must not block later dispatchable actions")
require(coordinator.contains("private func recoverPendingOperationConflict("),
        "ordinary pending mutations need a dedicated recovery path")
guard let recoveryRange = coordinator.range(of: "private func recoverPendingOperationConflict(") else {
    fputs("knowledge-governance-coordinator-check failed: missing pending recovery function\n", stderr)
    exit(1)
}
let recoverySource = String(coordinator[recoveryRange.lowerBound...])
let pendingRemoval = position("try pendingStore.remove(for: userId)", in: recoverySource)
let pendingRefresh = position("refreshAfterConflict(context: context)", in: recoverySource)
require(pendingRemoval < pendingRefresh,
        "the poisoned pending operation must be removed before authoritative refresh")

let applyPosition = position("guard applyAuthoritativeRemote(remote, previousBase: previousBase, context: context)", in: coordinator)
guard let removeRange = coordinator.range(
    of: "try governanceOutboxStore.remove(operationId: item.operationId, for: userId)",
    range: applyPosition..<coordinator.endIndex
) else {
    fputs("knowledge-governance-coordinator-check failed: missing post-apply outbox removal\n", stderr)
    exit(1)
}
let removePosition = removeRange.lowerBound
require(applyPosition < removePosition,
        "same-persona outbox item may only be removed after authoritative graph application")

require(coordinator.contains("let staleCompletions = Array(self.governanceCompletions.values)"),
        "user changes must invalidate governance callbacks")
require(coordinator.contains("KnowledgeGovernanceCoordinatorError.userChanged"),
        "invalidated callbacks need an explicit failure")
require(coordinator.contains("invalidGovernanceOutboxRemoved"),
        "corrupt outbox recovery must be observable without knowledge content")

for declaration in [
    "struct KnowledgeGovernanceOutboxItem: Codable, Equatable",
    "final class KnowledgeGovernanceOutboxStore",
    "func enqueue(_ item: KnowledgeGovernanceOutboxItem, for userId: String) throws",
    "func replace(",
    "func remove(operationId: String, for userId: String) throws",
    "let recoveryCount: Int",
    "let quarantineReason: String?",
    "func hasSameSemanticPayload(as other: KnowledgeGovernanceOutboxItem) -> Bool",
] {
    require(outbox.contains(declaration), "missing durable outbox contract \(declaration)")
}

print("Knowledge governance coordinator check passed")
