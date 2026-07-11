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
    "struct KnowledgeChangePage",
    "struct KnowledgeChangeFeedReducer",
    "struct KnowledgeChangeFeedReduction",
    "enum KnowledgeGraphCASPolicy",
] {
    require(merge.contains(contract), "missing pagination model \(contract)")
}
require(merge.contains("revision == previousRevision + 1"), "pages must require contiguous revisions")
require(merge.contains("pageCount < maxPageCount"), "page traversal must be bounded")
require(merge.contains("target revision changed during pull"), "target drift must be rejected")

require(client.contains("Result<KnowledgeChangePage, Error>"), "client must return a typed page")
require(client.contains("var components = URLComponents()"), "pagination query must use URLComponents")
require(client.contains("URLQueryItem(name: \"limit\""), "client must opt into bounded pagination")
require(client.contains("URLQueryItem(name: \"targetRevision\""), "later pages must pin targetRevision")

for stateContract in [
    "private var activePullSessionID: UUID?",
    "private func beginKnowledgePull(",
    "private func pullNextKnowledgePage(",
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
require(!coordinator.contains("didApplyChanges("),
        "the old one-shot side-effect parser must be removed")

let consume = position("let reduction = try nextReducer.consume(page)", in: coordinator)
let terminal = position("if !reduction.isTerminal", in: coordinator)
let commit = position("guard self.commitKnowledgePull(", in: coordinator)
let push = position("self.pushLocalGraph(", in: String(coordinator[commit...]))
require(consume < terminal && terminal < commit, "intermediate pages must reduce before terminal commit")
require(push > String(coordinator[commit...]).startIndex, "local push must follow terminal commit")

require(manager.contains("struct KBLiteGraphSnapshot"), "KBLite must expose a CAS snapshot")
require(manager.contains("func exportGraphSnapshot() -> KBLiteGraphSnapshot?"),
        "KBLite snapshot must include the mutation token")
require(manager.contains("func applySyncedGraphCAS("), "KBLite must expose CAS apply")
require(manager.contains("KnowledgeGraphCASPolicy.canApply("), "KBLite apply must enforce the CAS policy")
require(coordinator.contains("for attempt in 1...3"), "terminal CAS recomputation must be bounded")
require(coordinator.contains("case .staleLocalMutation:"), "local writes during paging must trigger recomputation")
require(coordinator.contains("activePullSessionID = nil"), "terminal/failure/user switch must invalidate pull state")

print("Knowledge change feed pagination coordinator check passed")
