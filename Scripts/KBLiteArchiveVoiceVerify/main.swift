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
    let currentUser: UserModel? = UserModel(id: "kblite_archive_voice_verify")
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
let verifyGraph = docs.appendingPathComponent("knowledge_base/kb_graph_kblite_archive_voice_verify.json")
try? FileManager.default.removeItem(at: verifyGraph)

KBLiteManager.shared.reset()
let metadata = MemoryPrivacyMetadata(scope: .generationAllowed)
let addedCount = KBLiteManager.shared.ingestArchiveVoiceSampleMetadata(
    title: "1978 年西湖边聊天录音",
    note: "导入的长辈语音样本，用于后续声纹和语气参考。",
    sessionId: 42,
    privacyMetadata: metadata
)

let graph = KBLiteManager.shared.graph
let factText = graph.facts.map(\.statement).joined(separator: "\n")

assertCondition(addedCount == 1, "voice sample metadata should add one catalog fact")
assertCondition(graph.people.isEmpty, "voice sample metadata should not invent people")
assertCondition(graph.places.isEmpty, "voice sample metadata should not invent places")
assertCondition(graph.events.isEmpty, "voice sample metadata should not invent events")
assertCondition(factText.contains("1978 年西湖边聊天录音"), "voice sample fact should include title")
assertCondition(factText.contains("语音样本"), "voice sample fact should identify material type")
assertCondition(graph.facts.first?.confidence == "confirmed", "voice sample metadata should be confirmed")
assertCondition(graph.facts.first?.sourceSessionIds == [42], "voice sample fact should keep source session")
assertCondition(graph.facts.first?.privacyMetadata.scope == .generationAllowed, "voice sample fact should keep privacy scope")

let duplicateCount = KBLiteManager.shared.ingestArchiveVoiceSampleMetadata(
    title: "1978 年西湖边聊天录音",
    note: "重复导入不应重复入库。",
    sessionId: 43,
    privacyMetadata: metadata
)
assertCondition(duplicateCount == 0, "duplicate voice sample metadata should merge")
assertCondition(KBLiteManager.shared.graph.facts.count == 1, "duplicate voice sample should keep one fact")
assertCondition(KBLiteManager.shared.graph.facts.first?.sourceSessionIds == [42, 43], "duplicate should append source session")

KBLiteManager.shared.reset()
try? FileManager.default.removeItem(at: verifyGraph)
print("KBLiteArchiveVoice verification passed")
