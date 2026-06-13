import Foundation

private func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

struct UserModel: Codable {
    let id: String
}

struct ConversationTurn: Codable, MemoryPrivacyScoped {
    let role: String
    let text: String
    let timestamp: Date
    let privacyMetadata: MemoryPrivacyMetadata
}

final class UserManager {
    static let shared = UserManager()
    let currentUser: UserModel? = UserModel(id: "kblite_time_mailbox_verify")
}

final class KBLiteSemanticSearch {
    static let shared = KBLiteSemanticSearch()
    var isAvailable: Bool { false }

    func warmCache(people: [KBPerson], places: [KBPlace], events: [KBEvent], facts: [KBFact]) {}

    func semanticSearch(
        query: String,
        people: [KBPerson],
        places: [KBPlace],
        events: [KBEvent],
        facts: [KBFact],
        topK: Int = 5
    ) -> KBSearchResult {
        KBSearchResult()
    }
}

final class DeepSeekService {
    static let shared = DeepSeekService()

    enum StubError: LocalizedError {
        case unavailable
    }

    func extractKnowledge(prompt: String, completion: @escaping (Result<KBExtractionResult, StubError>) -> Void) {
        completion(.failure(.unavailable))
    }
}

let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let verifyGraph = docs.appendingPathComponent("knowledge_base/kb_graph_kblite_time_mailbox_verify.json")
try? FileManager.default.removeItem(at: verifyGraph)

KBLiteManager.shared.reset()
let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
let deliverAt = createdAt.addingTimeInterval(86_400)
let metadata = MemoryPrivacyMetadata(scope: .generationAllowed)
let addedCount = KBLiteManager.shared.ingestTimeMailboxLetterMetadata(
    letterId: "letter-001",
    recipientName: "林桂芳",
    title: "西湖边的小照相馆",
    deliverAt: deliverAt,
    createdAt: createdAt,
    privacyMetadata: metadata
)

let graph = KBLiteManager.shared.graph
let factText = graph.facts.map(\.statement).joined(separator: "\n")

assertCondition(addedCount == 1, "time mailbox metadata should add one catalog fact")
assertCondition(graph.people.isEmpty, "time mailbox metadata should not invent people")
assertCondition(graph.places.isEmpty, "time mailbox metadata should not invent places")
assertCondition(graph.events.isEmpty, "time mailbox metadata should not invent events")
assertCondition(factText.contains("林桂芳"), "fact should include recipient")
assertCondition(factText.contains("西湖边的小照相馆"), "fact should include title")
assertCondition(factText.contains("时空信箱"), "fact should identify mailbox material")
assertCondition(!factText.contains("我今天路过老房子"), "fact must not include private body text")
assertCondition(graph.facts.first?.confidence == "confirmed", "time mailbox metadata should be confirmed")
assertCondition(graph.facts.first?.privacyMetadata.scope == .generationAllowed, "time mailbox fact should keep privacy scope")

let duplicateCount = KBLiteManager.shared.ingestTimeMailboxLetterMetadata(
    letterId: "letter-001",
    recipientName: "林桂芳",
    title: "重复封存",
    deliverAt: deliverAt,
    createdAt: createdAt,
    privacyMetadata: metadata
)
assertCondition(duplicateCount == 0, "duplicate mailbox metadata should merge by letter id")
assertCondition(KBLiteManager.shared.graph.facts.count == 1, "duplicate mailbox metadata should keep one fact")

KBLiteManager.shared.reset()
try? FileManager.default.removeItem(at: verifyGraph)
print("KBLiteTimeMailbox verification passed")
