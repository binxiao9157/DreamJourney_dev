import Foundation

// MARK: - Lite 知识库数据模型

/// 知识库顶层容器 — 单文件持久化到 kb_graph.json
struct KBLiteGraph: Codable {
    var version: Int = 2
    var lastUpdated: Date = Date()
    var sessionCount: Int = 0        // 已处理的会话数
    var people: [KBPerson] = []
    var places: [KBPlace] = []
    var events: [KBEvent] = []
    var facts: [KBFact] = []

    init(
        version: Int = 2,
        lastUpdated: Date = Date(),
        sessionCount: Int = 0,
        people: [KBPerson] = [],
        places: [KBPlace] = [],
        events: [KBEvent] = [],
        facts: [KBFact] = []
    ) {
        self.version = max(version, 2)
        self.lastUpdated = lastUpdated
        self.sessionCount = sessionCount
        self.people = people
        self.places = places
        self.events = events
        self.facts = facts
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case lastUpdated
        case sessionCount
        case people
        case places
        case events
        case facts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = max(try container.decodeIfPresent(Int.self, forKey: .version) ?? 2, 2)
        lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated) ?? Date()
        sessionCount = try container.decodeIfPresent(Int.self, forKey: .sessionCount) ?? 0
        people = try container.decodeIfPresent([KBPerson].self, forKey: .people) ?? []
        places = try container.decodeIfPresent([KBPlace].self, forKey: .places) ?? []
        events = try container.decodeIfPresent([KBEvent].self, forKey: .events) ?? []
        facts = try container.decodeIfPresent([KBFact].self, forKey: .facts) ?? []
    }
}

// MARK: - 人物

struct KBPerson: Codable, Identifiable {
    let id: String              // UUID
    var name: String            // "爷爷", "张建国"
    var aliases: [String]       // ["老张", "建国"]
    var relation: String?       // "祖父"
    var traits: [String]        // ["军人", "手艺人"]
    var briefBio: String?       // AI 生成的一两句话简介
    var relatedPersonIds: [String] = []  // 关联人物 ID（双向关系）
    var sourceSessionIds: [Int] // 来源：第几次会话提到此人
    var createdAt: Date
    var updatedAt: Date
    var privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)

    init(
        id: String,
        name: String,
        aliases: [String],
        relation: String?,
        traits: [String],
        briefBio: String? = nil,
        relatedPersonIds: [String] = [],
        sourceSessionIds: [Int],
        createdAt: Date,
        updatedAt: Date,
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.relation = relation
        self.traits = traits
        self.briefBio = briefBio
        self.relatedPersonIds = relatedPersonIds
        self.sourceSessionIds = sourceSessionIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.privacyMetadata = privacyMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case aliases
        case relation
        case traits
        case briefBio
        case relatedPersonIds
        case sourceSessionIds
        case createdAt
        case updatedAt
        case privacyMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        relation = try container.decodeIfPresent(String.self, forKey: .relation)
        traits = try container.decodeIfPresent([String].self, forKey: .traits) ?? []
        briefBio = try container.decodeIfPresent(String.self, forKey: .briefBio)
        relatedPersonIds = try container.decodeIfPresent([String].self, forKey: .relatedPersonIds) ?? []
        sourceSessionIds = try container.decodeIfPresent([Int].self, forKey: .sourceSessionIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        privacyMetadata = try container.decodeIfPresent(MemoryPrivacyMetadata.self, forKey: .privacyMetadata)
            ?? MemoryPrivacyMetadata(scope: .localOnly)
    }

    /// 所有可用于搜索和匹配的文本
    var searchableText: String {
        ([name] + aliases + traits + [relation].compactMap { $0 } + [briefBio].compactMap { $0 })
            .joined(separator: " ")
    }
}

// MARK: - 地点

struct KBPlace: Codable, Identifiable {
    let id: String
    var name: String            // "上海外滩", "老家四川南充"
    var category: String?       // "hometown" | "lived" | "visited" | "worked"
    var latitude: Double?
    var longitude: Double?
    var description: String?
    var relatedPersonIds: [String] = []
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
    var privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)

    init(
        id: String,
        name: String,
        category: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        description: String? = nil,
        relatedPersonIds: [String] = [],
        sourceSessionIds: [Int] = [],
        createdAt: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.description = description
        self.relatedPersonIds = relatedPersonIds
        self.sourceSessionIds = sourceSessionIds
        self.createdAt = createdAt
        self.privacyMetadata = privacyMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case latitude
        case longitude
        case description
        case relatedPersonIds
        case sourceSessionIds
        case createdAt
        case privacyMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        relatedPersonIds = try container.decodeIfPresent([String].self, forKey: .relatedPersonIds) ?? []
        sourceSessionIds = try container.decodeIfPresent([Int].self, forKey: .sourceSessionIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        privacyMetadata = try container.decodeIfPresent(MemoryPrivacyMetadata.self, forKey: .privacyMetadata)
            ?? MemoryPrivacyMetadata(scope: .localOnly)
    }

    var searchableText: String {
        [name, category, description].compactMap { $0 }.joined(separator: " ")
    }
}

// MARK: - 事件

struct KBEvent: Codable, Identifiable {
    let id: String
    var title: String           // "外滩全家合影"
    var description: String?
    var year: Int?
    var month: Int?
    var locationId: String?     // 关联 KBPlace.id
    var participantIds: [String] = [] // 关联 KBPerson.id
    var mediaIds: [String] = []
    var memoirId: String?       // 关联已有回忆录
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
    var privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)

    init(
        id: String,
        title: String,
        description: String? = nil,
        year: Int? = nil,
        month: Int? = nil,
        locationId: String? = nil,
        participantIds: [String] = [],
        mediaIds: [String] = [],
        memoirId: String? = nil,
        sourceSessionIds: [Int] = [],
        createdAt: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.year = year
        self.month = month
        self.locationId = locationId
        self.participantIds = participantIds
        self.mediaIds = mediaIds
        self.memoirId = memoirId
        self.sourceSessionIds = sourceSessionIds
        self.createdAt = createdAt
        self.privacyMetadata = privacyMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case year
        case month
        case locationId
        case participantIds
        case mediaIds
        case memoirId
        case sourceSessionIds
        case createdAt
        case privacyMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        month = try container.decodeIfPresent(Int.self, forKey: .month)
        locationId = try container.decodeIfPresent(String.self, forKey: .locationId)
        participantIds = try container.decodeIfPresent([String].self, forKey: .participantIds) ?? []
        mediaIds = try container.decodeIfPresent([String].self, forKey: .mediaIds) ?? []
        memoirId = try container.decodeIfPresent(String.self, forKey: .memoirId)
        sourceSessionIds = try container.decodeIfPresent([Int].self, forKey: .sourceSessionIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        privacyMetadata = try container.decodeIfPresent(MemoryPrivacyMetadata.self, forKey: .privacyMetadata)
            ?? MemoryPrivacyMetadata(scope: .localOnly)
    }

    var searchableText: String {
        [title, description].compactMap { $0 }.joined(separator: " ")
    }

    /// 格式化年份月份，如 "1975年7月"
    var formattedDate: String {
        var parts: [String] = []
        if let y = year { parts.append("\(y)年") }
        if let m = month { parts.append("\(m)月") }
        return parts.isEmpty ? "" : parts.joined()
    }
}

// MARK: - 事实

struct KBFact: Codable, Identifiable {
    let id: String
    var statement: String       // "爷爷1968年参军，在南京军区服役"
    var confidence: String      // "high" | "medium" | "low" | "confirmed"
    var relatedPersonIds: [String] = []
    var relatedPlaceIds: [String] = []
    var relatedEventIds: [String] = []
    var sourceSessionIds: [Int] = []
    var createdAt: Date = Date()
    var privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)

    init(
        id: String,
        statement: String,
        confidence: String,
        relatedPersonIds: [String] = [],
        relatedPlaceIds: [String] = [],
        relatedEventIds: [String] = [],
        sourceSessionIds: [Int] = [],
        createdAt: Date = Date(),
        privacyMetadata: MemoryPrivacyMetadata = MemoryPrivacyMetadata(scope: .localOnly)
    ) {
        self.id = id
        self.statement = statement
        self.confidence = confidence
        self.relatedPersonIds = relatedPersonIds
        self.relatedPlaceIds = relatedPlaceIds
        self.relatedEventIds = relatedEventIds
        self.sourceSessionIds = sourceSessionIds
        self.createdAt = createdAt
        self.privacyMetadata = privacyMetadata
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case statement
        case confidence
        case relatedPersonIds
        case relatedPlaceIds
        case relatedEventIds
        case sourceSessionIds
        case createdAt
        case privacyMetadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        statement = try container.decode(String.self, forKey: .statement)
        confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "high"
        relatedPersonIds = try container.decodeIfPresent([String].self, forKey: .relatedPersonIds) ?? []
        relatedPlaceIds = try container.decodeIfPresent([String].self, forKey: .relatedPlaceIds) ?? []
        relatedEventIds = try container.decodeIfPresent([String].self, forKey: .relatedEventIds) ?? []
        sourceSessionIds = try container.decodeIfPresent([Int].self, forKey: .sourceSessionIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        privacyMetadata = try container.decodeIfPresent(MemoryPrivacyMetadata.self, forKey: .privacyMetadata)
            ?? MemoryPrivacyMetadata(scope: .localOnly)
    }
}

// MARK: - LLM 提取响应模型

/// DeepSeek LLM 返回的知识提取结果
struct KBExtractionResult: Codable {
    var people: [ExtractedPerson] = []
    var places: [ExtractedPlace] = []
    var events: [ExtractedEvent] = []
    var facts: [ExtractedFact] = []

    struct ExtractedPerson: Codable {
        var name: String
        var aliases: [String] = []
        var relation: String?
        var traits: [String] = []
        var briefBio: String?
        var sourceTurnIndices: [Int] = []
    }

    struct ExtractedPlace: Codable {
        var name: String
        var category: String?
        var latitude: Double?
        var longitude: Double?
        var description: String?
        var relatedPeople: [String] = []
        var sourceTurnIndices: [Int] = []
    }

    struct ExtractedEvent: Codable {
        var title: String
        var description: String?
        var year: Int?
        var month: Int?
        var location: String?
        var participants: [String] = []
        var sourceTurnIndices: [Int] = []
    }

    struct ExtractedFact: Codable {
        var statement: String
        var confidence: String?
        var relatedPeople: [String] = []
        var relatedPlaces: [String] = []
        var relatedEvents: [String] = []
        var sourceTurnIndices: [Int] = []
    }
}

// MARK: - 检索结果

/// 一次检索命中的所有实体
struct KBSearchResult {
    var people: [KBPerson] = []
    var places: [KBPlace] = []
    var events: [KBEvent] = []
    var facts: [KBFact] = []

    var isEmpty: Bool {
        people.isEmpty && places.isEmpty && events.isEmpty && facts.isEmpty
    }

    var totalCount: Int {
        people.count + places.count + events.count + facts.count
    }
}

// MARK: - 沉淀状态摘要

struct KBLiteDepositStatus: Equatable {
    let totalEntityCount: Int
    let sessionCount: Int
    let lastUpdated: Date
    let conversationSourceCount: Int
    let archiveSourceCount: Int
    let archiveStructuredKnowledgeSourceCount: Int
    let mailboxSourceCount: Int
    let importedSourceCount: Int
    let untaggedSourceCount: Int
    let localOnlyCount: Int
    let generationAllowedCount: Int
    let familyCircleCount: Int
    let privateOnlyCount: Int

    var sourceSummary: String {
        var parts = [
            "对话 \(conversationSourceCount)",
            "档案 \(archiveSourceCount)",
            "档案结构化 \(archiveStructuredKnowledgeSourceCount)",
            "信箱 \(mailboxSourceCount)"
        ]
        if importedSourceCount > 0 {
            parts.append("导入 \(importedSourceCount)")
        }
        if untaggedSourceCount > 0 {
            parts.append("未标记 \(untaggedSourceCount)")
        }
        return "来源：" + parts.joined(separator: " · ")
    }

    var privacySummary: String {
        var parts = [
            "本机 \(localOnlyCount)",
            "可生成 \(generationAllowedCount)",
            "亲友 \(familyCircleCount)"
        ]
        if privateOnlyCount > 0 {
            parts.append("私密 \(privateOnlyCount)")
        }
        return "隐私：" + parts.joined(separator: " · ")
    }
}

struct KBLiteExtractionSummary: Equatable {
    let deterministicAddedCount: Int
    let llmAddedCount: Int
    let didAttemptLLM: Bool
    let didSkipDueToFrequency: Bool
    let didSkipDueToNoRemoteContent: Bool
    let didSkipDueToInFlight: Bool
    let llmErrorDescription: String?

    var totalAddedCount: Int {
        deterministicAddedCount + llmAddedCount
    }

    var didFailLLM: Bool {
        llmErrorDescription?.isEmpty == false
    }

    static let empty = KBLiteExtractionSummary(
        deterministicAddedCount: 0,
        llmAddedCount: 0,
        didAttemptLLM: false,
        didSkipDueToFrequency: false,
        didSkipDueToNoRemoteContent: false,
        didSkipDueToInFlight: false,
        llmErrorDescription: nil
    )
}

enum KBLiteDepositStatusBuilder {
    static func build(from graph: KBLiteGraph) -> KBLiteDepositStatus {
        let metadatas = graph.allPrivacyMetadata
        var sourceIDsByKind: [MemorySourceKind: Set<String>] = [:]
        var archiveStructuredSourceIDs = Set<String>()
        var untaggedCount = 0
        var privacyCounts: [MemoryPrivacyScope: Int] = [:]

        for metadata in metadatas {
            privacyCounts[metadata.scope, default: 0] += 1

            if metadata.sourceRefs.isEmpty {
                untaggedCount += 1
            } else {
                for sourceRef in metadata.sourceRefs {
                    sourceIDsByKind[sourceRef.kind, default: []].insert(sourceRef.id)
                }
            }
        }
        graph.people.forEach { entity in
            collectArchiveStructuredSourceIDs(from: entity.privacyMetadata, into: &archiveStructuredSourceIDs)
        }
        graph.places.forEach { entity in
            collectArchiveStructuredSourceIDs(from: entity.privacyMetadata, into: &archiveStructuredSourceIDs)
        }
        graph.events.forEach { entity in
            collectArchiveStructuredSourceIDs(from: entity.privacyMetadata, into: &archiveStructuredSourceIDs)
        }
        graph.facts.forEach { fact in
            guard !isArchiveMetadataOnlyFact(fact.statement) else { return }
            collectArchiveStructuredSourceIDs(from: fact.privacyMetadata, into: &archiveStructuredSourceIDs)
        }

        let importedCount =
            (sourceIDsByKind[.importRecord]?.count ?? 0) +
            (sourceIDsByKind[.kbLiteEntity]?.count ?? 0)

        return KBLiteDepositStatus(
            totalEntityCount: metadatas.count,
            sessionCount: graph.sessionCount,
            lastUpdated: graph.lastUpdated,
            conversationSourceCount: sourceIDsByKind[.conversationTurn]?.count ?? 0,
            archiveSourceCount: sourceIDsByKind[.memoryArchiveItem]?.count ?? 0,
            archiveStructuredKnowledgeSourceCount: archiveStructuredSourceIDs.count,
            mailboxSourceCount: sourceIDsByKind[.timeMailboxLetter]?.count ?? 0,
            importedSourceCount: importedCount,
            untaggedSourceCount: untaggedCount,
            localOnlyCount: privacyCounts[.localOnly] ?? 0,
            generationAllowedCount: privacyCounts[.generationAllowed] ?? 0,
            familyCircleCount: privacyCounts[.familyCircle] ?? 0,
            privateOnlyCount: privacyCounts[.privateOnly] ?? 0
        )
    }

    private static func collectArchiveStructuredSourceIDs(
        from metadata: MemoryPrivacyMetadata,
        into sourceIDs: inout Set<String>
    ) {
        for sourceRef in metadata.sourceRefs where sourceRef.kind == .memoryArchiveItem {
            sourceIDs.insert(sourceRef.id)
        }
    }

    private static func isArchiveMetadataOnlyFact(_ statement: String) -> Bool {
        let text = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.hasPrefix("记忆档案馆保存")
    }
}

private extension KBLiteGraph {
    var allPrivacyMetadata: [MemoryPrivacyMetadata] {
        people.map(\.privacyMetadata) +
            places.map(\.privacyMetadata) +
            events.map(\.privacyMetadata) +
            facts.map(\.privacyMetadata)
    }
}

// MARK: - 图片分析响应

struct KBImageAnalysisResult: Codable {
    var description: String = ""
    var detectedPeople: [String] = []
    var scene: String = ""
    var occasion: String = ""
    var mood: String = ""
    var estimatedDecade: Int?
}

struct KBLiteArchiveBackfillMaterial {
    enum Kind: String {
        case photo
        case screenshot
        case voiceSample
        case textNote
        case personalityNote
        case catchphrase

        var displayName: String {
            switch self {
            case .photo: return "旧照片"
            case .screenshot: return "聊天截图"
            case .voiceSample: return "语音样本"
            case .textNote: return "文字回忆"
            case .personalityNote: return "人格提示"
            case .catchphrase: return "口头禅"
            }
        }

        var isTextLike: Bool {
            switch self {
            case .textNote, .personalityNote, .catchphrase:
                return true
            case .photo, .screenshot, .voiceSample:
                return false
            }
        }

        var isImageLike: Bool {
            switch self {
            case .photo, .screenshot:
                return true
            case .voiceSample, .textNote, .personalityNote, .catchphrase:
                return false
            }
        }
    }

    let id: String
    let kind: Kind
    let title: String
    let note: String
    let createdAt: Date
    let analysisStatusRawValue: String?
    let analysisSummary: String?
    let detectedPeople: [String]
    let scene: String?
    let occasion: String?
    let mood: String?
    let estimatedDecade: Int?
    let privacyMetadata: MemoryPrivacyMetadata
    let targetPersonName: String?
    let targetPersonId: String?
}

// MARK: - Notifications

extension Notification.Name {
    static let kbLiteDidUpdate = Notification.Name("com.dreamjourney.kblite.didUpdate")
}
