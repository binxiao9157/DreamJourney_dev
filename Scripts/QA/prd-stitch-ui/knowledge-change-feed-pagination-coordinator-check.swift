import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("knowledge-change-feed-pagination-coordinator-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func position(_ needle: String, in source: String) -> String.Index {
    guard let range = source.range(of: needle) else {
        fputs("knowledge-change-feed-pagination-coordinator-check failed: missing \(needle)\n", stderr)
        exit(1)
    }
    return range.lowerBound
}

let client = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let coordinator = try read("DreamJourney/Sources/Services/KnowledgeSyncCoordinator.swift")
let merge = try read("DreamJourney/Sources/Services/KnowledgeThreeWayMerge.swift")
let manager = try read("DreamJourney/Sources/Services/KBLiteManager.swift")

for contract in [
    "struct KnowledgeSnapshotResponse",
    "struct KnowledgeChangePage",
    "struct KnowledgeChangeFeedReducer",
    "struct KnowledgeChangeFeedReduction",
    "enum KnowledgeChangeFeedRecoveryPolicy",
    "enum KnowledgeGraphCASPolicy",
] {
    require(merge.contains(contract), "missing pagination model \(contract)")
}
require(merge.contains("revision == previousRevision + 1"), "pages must require contiguous revisions")
require(merge.contains("pageCount < maxPageCount"), "page traversal must be bounded")
require(merge.contains("target revision changed during pull"), "target drift must be rejected")
require(merge.contains("statusCode == 410"), "compacted recovery must require HTTP 410")
require(merge.contains("detailCode == \"knowledgeChangeFeedCompacted\""),
        "compacted recovery must require the structured backend code")

require(client.contains("Result<KnowledgeChangePage, Error>"), "client must return a typed page")
require(client.contains("Result<KnowledgeSnapshotResponse, Error>"), "client must return a typed snapshot")
require(client.contains("func fetchKnowledgeSnapshot("), "client must expose snapshot fetch")
require(client.contains("/kb/snapshot/\\(pathComponent(userId))"), "snapshot fetch must use the user-scoped route")
require(client.contains("var components = URLComponents()"), "pagination query must use URLComponents")
require(client.contains("URLQueryItem(name: \"limit\""), "client must opt into bounded pagination")
require(client.contains("URLQueryItem(name: \"targetRevision\""), "later pages must pin targetRevision")

for stateContract in [
    "private var activePullSessionID: UUID?",
    "private var snapshotFallbackAttemptedPullSessionID: UUID?",
    "private func beginKnowledgePull(",
    "private func pullNextKnowledgePage(",
    "private func recoverCompactedKnowledgeFeed(",
    "private func commitKnowledgePull(",
    "private func isCurrentPull(",
] {
    require(coordinator.contains(stateContract), "missing pull state contract \(stateContract)")
}
require(coordinator.components(separatedBy: "beginKnowledgePull(").count >= 3,
        "normal sync and conflict refresh must share the paginated pull")
require(coordinator.contains("reducer: KnowledgeChangeFeedReducer(startRevision: startRevision)"),
        "each pull must own an isolated reducer")
require(coordinator.contains("targetRevision: reducer.targetRevision"),
        "later requests must carry the reducer target")
require(coordinator.contains("self.isCurrentPull("),
        "every page callback must validate user, generation and pull session")
require(coordinator.components(separatedBy: "fetchKnowledgeSnapshot(").count == 2,
        "the coordinator must have exactly one snapshot fallback request site")
require(coordinator.contains("snapshotFallbackAttemptedPullSessionID != pullSessionID"),
        "each pull session may attempt snapshot fallback only once")
require(coordinator.contains("KnowledgeChangeFeedRecoveryPolicy.shouldFetchSnapshot("),
        "snapshot fallback must use structured compacted classification")
require(coordinator.contains("previousBase: previousBase"),
        "snapshot fallback must reuse the authoritative apply path")
require(!coordinator.contains("didApplyChanges("),
        "the old one-shot side-effect parser must be removed")

let consume = position("let reduction = try nextReducer.consume(page)", in: coordinator)
let terminal = position("if !reduction.isTerminal", in: coordinator)
let commit = position("guard self.commitKnowledgePull(", in: coordinator)
let push = position("self.pushLocalGraph(", in: String(coordinator[commit...]))
require(consume < terminal && terminal < commit, "intermediate pages must reduce before terminal commit")
require(push > String(coordinator[commit...]).startIndex, "local push must follow terminal commit")

let recovery = position("private func recoverCompactedKnowledgeFeed(", in: coordinator)
let commitFunction = position("private func commitKnowledgePull(", in: coordinator)
let recoverySource = String(coordinator[recovery..<commitFunction])
let recoveryGuard = position("self.isCurrentPull(", in: recoverySource)
let recoveryApply = position("self.applyAuthoritativeRemote(", in: recoverySource)
let recoveryPush = position("self.pushLocalGraph(", in: recoverySource)
require(recoveryGuard < recoveryApply && recoveryApply < recoveryPush,
        "snapshot callback must reject stale sessions before apply, then push after apply")
require(recoverySource.contains(") else {\n            return\n        }\n        guard snapshotFallbackAttemptedPullSessionID"),
        "a stale recovery entry must return before mutating the active pull")
require(!recoverySource.contains("baseStore.save") && !recoverySource.contains("pendingStore.remove"),
        "snapshot recovery must not advance base or pending outside authoritative apply")

let pullFunction = position("private func pullNextKnowledgePage(", in: coordinator)
let pullSource = String(coordinator[pullFunction..<recovery])
let malformedPageCatch = position("} catch {", in: pullSource)
let compactedFailure = position("if Self.shouldRecoverCompactedChangeFeed(error)", in: pullSource)
require(malformedPageCatch < compactedFailure,
        "malformed gaps and target drift must terminate before HTTP compacted recovery classification")

let userChange = position("func userDidChange(to userId: String?)", in: coordinator)
let personaChange = position("func personaContextDidChange", in: coordinator)
let userChangeSource = String(coordinator[userChange..<personaChange])
require(userChangeSource.contains("self.activePullSessionID = nil")
        && userChangeSource.contains("self.snapshotFallbackAttemptedPullSessionID = nil"),
        "user switching must invalidate pull and snapshot fallback callbacks together")
require(coordinator.components(separatedBy: "Self.isUnsupportedEndpoint(error)").count >= 3,
        "legacy 404/405 endpoint fallback must remain available")

require(manager.contains("struct KBLiteGraphSnapshot"), "KBLite must expose a CAS snapshot")
require(manager.contains("func exportGraphSnapshot() -> KBLiteGraphSnapshot?"),
        "KBLite snapshot must include the mutation token")
require(manager.contains("func applySyncedGraphCAS("), "KBLite must expose CAS apply")
require(manager.contains("KnowledgeGraphCASPolicy.canApply("), "KBLite apply must enforce the CAS policy")
require(coordinator.contains("for attempt in 1...3"), "terminal CAS recomputation must be bounded")
require(coordinator.contains("case .staleLocalMutation:"), "local writes during paging must trigger recomputation")
require(coordinator.contains("activePullSessionID = nil"), "terminal/failure/user switch must invalidate pull state")

print("Knowledge change feed pagination coordinator check passed")
