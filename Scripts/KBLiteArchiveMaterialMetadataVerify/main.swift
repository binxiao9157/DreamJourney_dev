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
    let currentUser: UserModel? = UserModel(id: "kblite_archive_material_verify")
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
let verifyGraph = docs.appendingPathComponent("knowledge_base/kb_graph_kblite_archive_material_verify.json")
try? FileManager.default.removeItem(at: verifyGraph)

let now = Date(timeIntervalSince1970: 1_800_234_567)
KBLiteManager.shared.reset()

let textMetadata = MemoryPrivacyMetadata(scope: .generationAllowed).appendingSourceRef(
    MemorySourceRef(
        kind: .memoryArchiveItem,
        id: "archive-text-1",
        title: "林桂芳的口头禅",
        capturedAt: now
    )
)
let textCount = KBLiteManager.shared.ingestArchiveTextMaterialMetadata(
    archiveItemID: "archive-text-1",
    title: "林桂芳的口头禅",
    note: "她常说慢慢来，饭要趁热吃。",
    materialKind: "口头禅",
    capturedAt: now,
    sessionId: 11,
    privacyMetadata: textMetadata
)
assertCondition(textCount == 1, "archive text metadata should add one fact")
assertCondition(
    KBLiteManager.shared.graph.facts.contains {
        $0.statement.contains("林桂芳的口头禅") &&
            $0.statement.contains("口头禅") &&
            $0.statement.contains("慢慢来") &&
            $0.privacyMetadata.sourceRefs.contains(where: { $0.kind == .memoryArchiveItem && $0.id == "archive-text-1" })
    },
    "archive text fact should keep source ref and content summary"
)

let duplicateTextCount = KBLiteManager.shared.ingestArchiveTextMaterialMetadata(
    archiveItemID: "archive-text-1",
    title: "林桂芳的口头禅",
    note: "重复保存不应重复入库。",
    materialKind: "口头禅",
    capturedAt: now,
    sessionId: 12,
    privacyMetadata: textMetadata
)
assertCondition(duplicateTextCount == 0, "duplicate archive text metadata should merge")
assertCondition(
    KBLiteManager.shared.graph.facts.first(where: {
        $0.privacyMetadata.sourceRefs.contains(where: { $0.id == "archive-text-1" })
    })?.sourceSessionIds == [11, 12],
    "duplicate archive text metadata should append source session"
)

let photoMetadata = MemoryPrivacyMetadata(scope: .generationAllowed).appendingSourceRef(
    MemorySourceRef(
        kind: .memoryArchiveItem,
        id: "archive-photo-1",
        title: "西湖边合影",
        capturedAt: now
    )
)
let photoCount = KBLiteManager.shared.ingestArchivePhotoAnalysisMetadata(
    archiveItemID: "archive-photo-1",
    title: "西湖边合影",
    analysis: KBImageAnalysisResult(
        description: "照片里一家人在杭州西湖边合影。",
        detectedPeople: ["林桂芳"],
        scene: "杭州西湖",
        occasion: "家庭合影",
        mood: "温馨",
        estimatedDecade: 1970
    ),
    capturedAt: now,
    sessionId: 13,
    privacyMetadata: photoMetadata
)
assertCondition(photoCount == 1, "archive photo analysis metadata should add one fact")
assertCondition(
    KBLiteManager.shared.graph.facts.contains {
        $0.statement.contains("西湖边合影") &&
            $0.statement.contains("分析摘要") &&
            $0.statement.contains("杭州西湖") &&
            $0.privacyMetadata.sourceRefs.contains(where: { $0.kind == .memoryArchiveItem && $0.id == "archive-photo-1" })
    },
    "archive photo fact should keep source ref and analysis summary"
)

let privateCount = KBLiteManager.shared.ingestArchiveTextMaterialMetadata(
    archiveItemID: "archive-private",
    title: "私密素材",
    note: "不应进入知识库。",
    materialKind: "文字回忆",
    capturedAt: now,
    sessionId: 14,
    privacyMetadata: MemoryPrivacyMetadata(scope: .privateOnly)
)
assertCondition(privateCount == 0, "private archive metadata should not enter KBLite")

KBLiteManager.shared.reset()
try? FileManager.default.removeItem(at: verifyGraph)
print("KBLiteArchiveMaterialMetadata verification passed")
