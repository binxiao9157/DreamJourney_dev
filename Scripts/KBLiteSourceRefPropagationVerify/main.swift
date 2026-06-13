import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("KBLiteSourceRefPropagation verification failed: \(message)\n", stderr)
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
    let currentUser: UserModel? = UserModel(id: "kblite_source_ref_verify")
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
let verifyGraph = docs.appendingPathComponent("knowledge_base/kb_graph_kblite_source_ref_verify.json")
try? FileManager.default.removeItem(at: verifyGraph)

let now = Date(timeIntervalSince1970: 1_800_123_456)
KBLiteManager.shared.reset()

let conversationRef = MemorySourceRef(
    kind: .conversationTurn,
    id: "conversation-session-7",
    title: "真实对话第7轮",
    capturedAt: now
)
let conversationMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
    .appendingSourceRef(conversationRef)

let conversationCount = KBLiteManager.shared.verifyQuickExtract(
    turns: [
        ConversationTurn(
            role: "user",
            text: "我叫陈建国，1968年住在绍兴越城区仓桥直街。",
            timestamp: now,
            privacyMetadata: conversationMetadata
        )
    ],
    sessionId: 7,
    privacyMetadata: conversationMetadata
)
require(conversationCount > 0, "conversation quick extract should add knowledge")
require(
    KBLiteManager.shared.graph.people.contains {
        $0.name == "陈建国" &&
            $0.privacyMetadata.sourceRefs.contains(where: { $0.kind == .conversationTurn && $0.id == "conversation-session-7" })
    },
    "conversation person should keep conversationTurn sourceRef"
)

let archivePhotoRef = MemorySourceRef(
    kind: .memoryArchiveItem,
    id: "archive-photo-1",
    title: "西湖老照片",
    capturedAt: now
)
let archiveMetadata = MemoryPrivacyMetadata(scope: .generationAllowed)
    .appendingSourceRef(archivePhotoRef)
KBLiteManager.shared.ingestImageAnalysis(
    KBImageAnalysisResult(
        description: "西湖边一家人合影。",
        detectedPeople: ["林桂芳"],
        scene: "杭州西湖",
        occasion: "家庭合影",
        mood: "温馨",
        estimatedDecade: 1970
    ),
    sessionId: 8,
    privacyMetadata: archiveMetadata
)
require(
    KBLiteManager.shared.graph.places.contains {
        $0.name == "杭州西湖" &&
            $0.privacyMetadata.sourceRefs.contains(where: { $0.kind == .memoryArchiveItem && $0.id == "archive-photo-1" })
    },
    "archive photo place should keep memoryArchiveItem sourceRef"
)

let archiveVoiceRef = MemorySourceRef(
    kind: .memoryArchiveItem,
    id: "archive-voice-1",
    title: "西湖边聊天录音",
    capturedAt: now
)
let voiceCount = KBLiteManager.shared.ingestArchiveVoiceSampleMetadata(
    title: "西湖边聊天录音",
    note: "导入的语音样本，仅保存元信息。",
    sessionId: 9,
    privacyMetadata: MemoryPrivacyMetadata(scope: .generationAllowed).appendingSourceRef(archiveVoiceRef)
)
require(voiceCount == 1, "archive voice metadata should add one fact")
require(
    KBLiteManager.shared.graph.facts.contains {
        $0.statement.contains("语音样本") &&
            $0.privacyMetadata.sourceRefs.contains(where: { $0.kind == .memoryArchiveItem && $0.id == "archive-voice-1" })
    },
    "archive voice fact should keep memoryArchiveItem sourceRef"
)

let status = KBLiteDepositStatusBuilder.build(from: KBLiteManager.shared.graph)
require(status.conversationSourceCount > 0, "deposit status should count conversation source refs")
require(status.archiveSourceCount >= 2, "deposit status should count archive source refs")
require(status.untaggedSourceCount == 0, "newly deposited knowledge should not be untagged")

KBLiteManager.shared.reset()
try? FileManager.default.removeItem(at: verifyGraph)
print("KBLiteSourceRefPropagation verification passed")
