import Foundation

// MARK: - Lite 知识库数据模型

/// 知识库顶层容器 — 单文件持久化到 kb_graph.json
struct KBLiteGraph: Codable {
    var version: Int = 1
    var lastUpdated: Date = Date()
    var sessionCount: Int = 0        // 已处理的会话数
    var people: [KBPerson] = []
    var places: [KBPlace] = []
    var events: [KBEvent] = []
    var facts: [KBFact] = []
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

// MARK: - 图片分析响应

struct KBImageAnalysisResult: Codable {
    var description: String = ""
    var detectedPeople: [String] = []
    var scene: String = ""
    var occasion: String = ""
    var mood: String = ""
    var estimatedDecade: Int?
}