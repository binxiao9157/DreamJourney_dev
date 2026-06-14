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
    let currentUser: UserModel? = UserModel(id: "kblite_import_sanitizer_verify")
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
let verifyGraph = docs.appendingPathComponent("knowledge_base/kb_graph_kblite_import_sanitizer_verify.json")
try? FileManager.default.removeItem(at: verifyGraph)

let now = Date(timeIntervalSince1970: 1_800_345_678)
let metadata = MemoryPrivacyMetadata(scope: .familyCircle, createdAt: now)
let archivePhotoGenericMetadata = MemoryPrivacyMetadata(scope: .generationAllowed, createdAt: now).appendingSourceRef(
    MemorySourceRef(
        kind: .memoryArchiveItem,
        id: "archive-photo-generic",
        title: "老宅门口合影",
        capturedAt: now
    )
)
let importedGraph = KBLiteGraph(
    lastUpdated: now,
    sessionCount: 2,
    people: [
        KBPerson(
            id: "roadshow_person_grandpa",
            name: "陈树安",
            aliases: [],
            relation: "祖父",
            traits: ["路演样例"],
            sourceSessionIds: [1],
            createdAt: now,
            updatedAt: now,
            privacyMetadata: metadata
        ),
        KBPerson(
            id: "legacy_seed_grandma_without_roadshow_prefix",
            name: "陈静文",
            aliases: [],
            relation: "祖母",
            traits: ["喜欢整理老照片"],
            briefBio: "家人记忆中的温和长辈，常提醒晚辈慢慢来。",
            sourceSessionIds: [1],
            createdAt: now,
            updatedAt: now,
            privacyMetadata: metadata
        ),
        KBPerson(
            id: "generic_mother",
            name: "妈妈",
            aliases: [],
            relation: "母亲",
            traits: [],
            sourceSessionIds: [1],
            createdAt: now,
            updatedAt: now,
            privacyMetadata: metadata
        ),
        KBPerson(
            id: "real_person",
            name: "陈建国",
            aliases: [],
            relation: "本人",
            traits: ["喜欢整理老照片"],
            sourceSessionIds: [2],
            createdAt: now,
            updatedAt: now,
            privacyMetadata: metadata
        )
    ],
    places: [
        KBPlace(
            id: "roadshow_place_bund",
            name: "上海外滩",
            category: "visited",
            description: "路演样例中的家庭合影地点。",
            relatedPersonIds: ["roadshow_person_grandpa"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBPlace(
            id: "legacy_seed_bund_without_roadshow_prefix",
            name: "上海外滩",
            category: "visited",
            description: "路演样例中的家庭合影地点。",
            relatedPersonIds: ["legacy_seed_grandma_without_roadshow_prefix"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBPlace(
            id: "real_place",
            name: "绍兴越城区仓桥直街",
            category: "lived",
            description: "1968年居住地。",
            relatedPersonIds: ["real_person"],
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: metadata
        )
    ],
    events: [
        KBEvent(
            id: "roadshow_event_bund_photo",
            title: "外滩留下的合影记忆",
            description: "路演数据",
            year: 1975,
            locationId: "roadshow_place_bund",
            participantIds: ["roadshow_person_grandpa"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBEvent(
            id: "legacy_seed_photo_without_roadshow_prefix",
            title: "外滩全家合影",
            description: "1975 年 7 月家人在外滩留下的合影记忆。",
            year: 1975,
            month: 7,
            locationId: "legacy_seed_bund_without_roadshow_prefix",
            participantIds: ["legacy_seed_grandma_without_roadshow_prefix"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBEvent(
            id: "real_event",
            title: "在杭州西湖边开过小照相馆",
            description: "1978年的真实测试输入",
            year: 1978,
            locationId: "real_place",
            participantIds: ["real_person"],
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBEvent(
            id: "real_event_roadshow_story",
            title: "年轻时参加产品路演",
            description: "这是真实经历，不是演示 seed。",
            year: 2001,
            locationId: nil,
            participantIds: ["real_person"],
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: metadata
        )
    ],
    facts: [
        KBFact(
            id: "roadshow_fact_boundary",
            statement: "路演占位事实，不应进入真实测试知识库。",
            confidence: "confirmed",
            relatedPersonIds: ["roadshow_person_grandpa"],
            relatedEventIds: ["roadshow_event_bund_photo"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBFact(
            id: "legacy_seed_boundary_without_roadshow_prefix",
            statement: "时空信箱回声只基于保存记忆整理，不代表逝者真实回复。",
            confidence: "confirmed",
            relatedPersonIds: ["legacy_seed_grandma_without_roadshow_prefix"],
            relatedEventIds: ["legacy_seed_photo_without_roadshow_prefix"],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBFact(
            id: "real_fact",
            statement: "陈建国1968年住在绍兴越城区仓桥直街。",
            confidence: "confirmed",
            relatedPersonIds: ["real_person"],
            relatedEventIds: ["real_event"],
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBFact(
            id: "real_fact_roadshow_story",
            statement: "陈建国2001年参加过一次产品路演。",
            confidence: "confirmed",
            relatedPersonIds: ["real_person"],
            relatedEventIds: ["real_event_roadshow_story"],
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBFact(
            id: "generic_mother_fact",
            statement: "妈妈",
            confidence: "confirmed",
            relatedPersonIds: [],
            sourceSessionIds: [1],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBFact(
            id: "real_mother_memory_fact",
            statement: "妈妈喜欢做桂花糕。",
            confidence: "confirmed",
            relatedPersonIds: [],
            sourceSessionIds: [2],
            createdAt: now,
            privacyMetadata: metadata
        ),
        KBFact(
            id: "legacy_archive_photo_generic_fact",
            statement: "记忆档案馆照片《老宅门口合影》分析摘要：照片里妈妈和外婆在老宅门口合影。（场景：老宅；人物：妈妈、外婆）。",
            confidence: "confirmed",
            relatedPersonIds: [],
            sourceSessionIds: [3],
            createdAt: now,
            privacyMetadata: archivePhotoGenericMetadata
        )
    ]
)

KBLiteManager.shared.reset()
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try encoder.encode(importedGraph)
let json = String(data: data, encoding: .utf8)!
assertCondition(KBLiteManager.shared.importJSON(json), "import should parse mixed graph")

let graph = KBLiteManager.shared.graph
assertCondition(graph.people.map(\.name) == ["陈建国"], "import should keep only real person")
assertCondition(graph.places.map(\.name) == ["绍兴越城区仓桥直街"], "import should remove roadshow places")
assertCondition(
    Set(graph.events.map(\.title)) == Set(["在杭州西湖边开过小照相馆", "年轻时参加产品路演"]),
    "import should remove roadshow seed events without deleting real user roadshow stories"
)
assertCondition(
    Set(graph.facts.map(\.statement)) == Set([
        "陈建国1968年住在绍兴越城区仓桥直街。",
        "陈建国2001年参加过一次产品路演。"
    ]),
    "import should remove roadshow/generic kinship facts without deleting real user stories"
)

KBLiteManager.shared.writeGraph { graph in
    graph = importedGraph
}
let displayGraph = KBLiteManager.shared.displayGraphForLocalBrowsing()
assertCondition(displayGraph.people.map(\.name) == ["陈建国"], "display graph should hide generic and roadshow people")
assertCondition(displayGraph.places.map(\.name) == ["绍兴越城区仓桥直街"], "display graph should hide roadshow places")
assertCondition(
    Set(displayGraph.events.map(\.title)) == Set(["在杭州西湖边开过小照相馆", "年轻时参加产品路演"]),
    "display graph should hide roadshow events without deleting real roadshow-word stories"
)
assertCondition(
    displayGraph.events.allSatisfy { !$0.participantIds.contains("generic_mother") && !$0.participantIds.contains("roadshow_person_grandpa") },
    "display graph should prune event participant refs to hidden people"
)
assertCondition(
    Set(displayGraph.facts.map(\.statement)) == Set([
        "陈建国1968年住在绍兴越城区仓桥直街。",
        "陈建国2001年参加过一次产品路演。"
    ]),
    "display graph should hide roadshow/generic kinship facts without deleting real user facts"
)

KBLiteManager.shared.reset()
try? FileManager.default.removeItem(at: verifyGraph)
print("KBLiteImportSanitizer verification passed")
