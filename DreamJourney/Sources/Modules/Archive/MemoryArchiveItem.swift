import Foundation

enum MemoryArchiveItemKind: String, Codable {
    case photo
    case video
    case audio
    case text
    case timeLetter
}

enum MemoryArchiveAnalysisStatus: String, Codable {
    case manual
    case pending
    case analyzed
    case failed
}

struct MemoryArchiveItem: Codable, Identifiable {
    let id: String
    var kind: MemoryArchiveItemKind
    var title: String
    var note: String
    var localPath: String?
    var createdAt: Date
    var updatedAt: Date
    var analysisStatus: MemoryArchiveAnalysisStatus
    var analysisSummary: String?
    var detectedPeople: [String]
    var tags: [String]
    var metadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case note
        case localPath
        case createdAt
        case updatedAt
        case analysisStatus
        case analysisSummary
        case detectedPeople
        case tags
        case metadata
    }

    init(
        kind: MemoryArchiveItemKind,
        title: String,
        note: String,
        localPath: String? = nil,
        analysisStatus: MemoryArchiveAnalysisStatus = .pending,
        analysisSummary: String? = nil,
        detectedPeople: [String] = [],
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = UUID().uuidString
        self.kind = kind
        self.title = title
        self.note = note
        self.localPath = localPath
        self.createdAt = Date()
        self.updatedAt = Date()
        self.analysisStatus = analysisStatus
        self.analysisSummary = analysisSummary
        self.detectedPeople = detectedPeople
        self.tags = tags
        self.metadata = metadata
    }

    init(
        id: String,
        kind: MemoryArchiveItemKind,
        title: String,
        note: String,
        localPath: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        analysisStatus: MemoryArchiveAnalysisStatus,
        analysisSummary: String? = nil,
        detectedPeople: [String] = [],
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.note = note
        self.localPath = localPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.analysisStatus = analysisStatus
        self.analysisSummary = analysisSummary
        self.detectedPeople = detectedPeople
        self.tags = tags
        self.metadata = metadata
    }

    init?(remoteJSON object: [String: Any]) {
        guard let id = Self.stringValue(object["id"]),
              let kindRaw = Self.stringValue(object["kind"]),
              let kind = MemoryArchiveItemKind(remoteRawValue: kindRaw) else {
            return nil
        }

        let createdAt = Self.dateValue(object["createdAt"]) ?? Date()
        let updatedAt = Self.dateValue(object["updatedAt"]) ?? createdAt
        let statusRaw = Self.stringValue(object["analysisStatus"])
        let status: MemoryArchiveAnalysisStatus
        if let statusRaw,
           let parsedStatus = MemoryArchiveAnalysisStatus(remoteRawValue: statusRaw) {
            status = parsedStatus
        } else {
            status = .pending
        }

        self.init(
            id: id,
            kind: kind,
            title: Self.stringValue(object["title"]) ?? kind.remoteDefaultTitle,
            note: Self.stringValue(object["note"]) ?? "",
            localPath: Self.stringValue(object["localPath"]),
            createdAt: createdAt,
            updatedAt: updatedAt,
            analysisStatus: status,
            analysisSummary: Self.stringValue(object["analysisSummary"]),
            detectedPeople: Self.stringArray(object["detectedPeople"]),
            tags: Self.stringArray(object["tags"]),
            metadata: Self.stringDictionary(object["metadata"])
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(MemoryArchiveItemKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        localPath = try container.decodeIfPresent(String.self, forKey: .localPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        analysisStatus = try container.decode(MemoryArchiveAnalysisStatus.self, forKey: .analysisStatus)
        analysisSummary = try container.decodeIfPresent(String.self, forKey: .analysisSummary)
        detectedPeople = try container.decodeIfPresent([String].self, forKey: .detectedPeople) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(note, forKey: .note)
        try container.encodeIfPresent(localPath, forKey: .localPath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(analysisStatus, forKey: .analysisStatus)
        try container.encodeIfPresent(analysisSummary, forKey: .analysisSummary)
        try container.encode(detectedPeople, forKey: .detectedPeople)
        try container.encode(tags, forKey: .tags)
        try container.encode(metadata, forKey: .metadata)
    }
}

private extension MemoryArchiveItemKind {
    init?(remoteRawValue rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        switch normalized {
        case "photo":
            self = .photo
        case "video":
            self = .video
        case "audio":
            self = .audio
        case "text":
            self = .text
        case "timeletter":
            self = .timeLetter
        default:
            return nil
        }
    }

    var remoteDefaultTitle: String {
        switch self {
        case .photo:
            return "相册影像"
        case .video:
            return "视频片段"
        case .audio:
            return "语音档案"
        case .text:
            return "文字记忆"
        case .timeLetter:
            return "时间信件"
        }
    }
}

private extension MemoryArchiveAnalysisStatus {
    init?(remoteRawValue rawValue: String) {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .lowercased()

        switch normalized {
        case "manual":
            self = .manual
        case "pending":
            self = .pending
        case "analyzed", "analysed":
            self = .analyzed
        case "failed":
            self = .failed
        default:
            return nil
        }
    }
}

private extension MemoryArchiveItem {
    static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    static func dateValue(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }
        guard let string = stringValue(value) else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: string) {
            return date
        }
        if let timestamp = TimeInterval(string) {
            return Date(timeIntervalSince1970: timestamp)
        }
        return nil
    }

    static func stringArray(_ value: Any?) -> [String] {
        guard let array = value as? [Any] else {
            return []
        }
        return array.compactMap(stringValue)
    }

    static func stringDictionary(_ value: Any?) -> [String: String] {
        guard let dictionary = value as? [String: Any] else {
            return [:]
        }
        return dictionary.reduce(into: [String: String]()) { result, pair in
            if let string = stringValue(pair.value) {
                result[pair.key] = string
            }
        }
    }
}

extension MemoryArchiveItem {
    mutating func applyLocalAnalysisResult(now: Date = Date()) {
        analysisStatus = .analyzed
        analysisSummary = localAnalysisSummary
        detectedPeople = Self.mergingUnique(detectedPeople, with: relationshipHints)
        tags = Self.mergingUnique(tags, with: localAnalysisTags)
        metadata["analysisSource"] = "local_rule"
        metadata["analysisUpdatedAt"] = "\(Int(now.timeIntervalSince1970))"
        updatedAt = now
    }

    private var localAnalysisSummary: String {
        switch kind {
        case .photo:
            return "已记录照片说明，后续可继续补充人物、地点与场景线索。"
        case .video:
            return "已记录视频说明，后续可继续补充动态场景与人物线索。"
        case .audio:
            return "已根据声音说明整理语气、称呼与情绪线索。"
        case .text:
            return "已根据文字内容提取可用于后续回响的情绪与关系线索。"
        case .timeLetter:
            return "已将这封时间信件整理为未来回看时可使用的情感线索。"
        }
    }

    private var localAnalysisTags: [String] {
        switch kind {
        case .photo:
            return ["相册影像", "场景线索"]
        case .video:
            return ["视频片段", "场景线索"]
        case .audio:
            return ["语音档案", "语气线索"]
        case .text:
            return ["文字片段", "文字线索"]
        case .timeLetter:
            return ["时间信件", "情感线索"]
        }
    }

    private var relationshipHints: [String] {
        let content = "\(title)\n\(note)"
        let candidates = [
            "奶奶",
            "爷爷",
            "外婆",
            "外公",
            "妈妈",
            "爸爸",
            "母亲",
            "父亲",
            "祖母",
            "祖父",
            "家人",
            "孩子",
            "女儿",
            "儿子",
        ]
        return candidates.filter { content.contains($0) }
    }

    private static func mergingUnique(_ base: [String], with additions: [String]) -> [String] {
        additions.reduce(into: base) { result, value in
            guard !value.isEmpty, !result.contains(value) else { return }
            result.append(value)
        }
    }
}
