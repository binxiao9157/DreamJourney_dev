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

enum ArchiveBackendSyncState: String, Codable {
    case pending
    case synced
    case failed
}

enum ArchiveMediaUploadStatus: String, Codable {
    case localOnly
    case pending
    case uploaded
    case failed
}

enum ArchiveMediaTranscriptionStatus: String, Codable {
    case notRequested
    case pending
    case completed
    case failed
}

struct MemoryArchiveItem: Codable, Identifiable {
    static let legacyOwnerUserId = "legacy_unassigned"

    let id: String
    let ownerUserId: String
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
        case ownerUserId
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
        ownerUserId: String = MemoryArchiveItem.legacyOwnerUserId,
        analysisStatus: MemoryArchiveAnalysisStatus = .pending,
        analysisSummary: String? = nil,
        detectedPeople: [String] = [],
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = UUID().uuidString
        self.ownerUserId = ownerUserId
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
        ownerUserId: String = MemoryArchiveItem.legacyOwnerUserId,
        createdAt: Date,
        updatedAt: Date,
        analysisStatus: MemoryArchiveAnalysisStatus,
        analysisSummary: String? = nil,
        detectedPeople: [String] = [],
        tags: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
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

        var metadata = Self.stringDictionary(object["metadata"])
        if (kind == .photo || kind == .text),
           metadata[Self.backendSyncStateMetadataKey] == nil {
            metadata[Self.backendSyncStateMetadataKey] = ArchiveBackendSyncState.synced.rawValue
        }

        self.init(
            id: id,
            kind: kind,
            title: Self.stringValue(object["title"]) ?? kind.remoteDefaultTitle,
            note: Self.stringValue(object["note"]) ?? "",
            localPath: Self.stringValue(object["localPath"]),
            ownerUserId: Self.stringValue(object["ownerUserId"])
                ?? Self.stringValue(object["uploadedByUserId"])
                ?? Self.stringValue(object["uploaderUserId"])
                ?? Self.legacyOwnerUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            analysisStatus: status,
            analysisSummary: Self.stringValue(object["analysisSummary"]),
            detectedPeople: Self.stringArray(object["detectedPeople"]),
            tags: Self.stringArray(object["tags"]),
            metadata: metadata
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerUserId = try container.decodeIfPresent(String.self, forKey: .ownerUserId) ?? Self.legacyOwnerUserId
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
        try container.encode(ownerUserId, forKey: .ownerUserId)
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
    static let backendSyncStateMetadataKey = "backendSyncState"
    static let backendSyncErrorMetadataKey = "backendSyncError"
    static let backendSyncAttemptedAtMetadataKey = "backendSyncAttemptedAt"
    static let mediaUploadStatusMetadataKey = "uploadStatus"
    static let mediaTranscriptionStatusMetadataKey = "transcriptionStatus"
    static let mediaTranscriptTextMetadataKey = "transcriptText"
    static let mediaThumbnailPathMetadataKey = "thumbnailPath"
    static let mediaFileSizeBytesMetadataKey = "fileSizeBytes"
    static let mediaFileSizeLimitMBMetadataKey = "fileSizeLimitMB"
    static let analysisLocationCluesMetadataKey = "analysisLocationClues"
    static let analysisSceneCluesMetadataKey = "analysisSceneClues"
    static let analysisFailureReasonMetadataKey = "analysisFailureReason"

    var backendSyncState: ArchiveBackendSyncState {
        guard let rawValue = metadata[Self.backendSyncStateMetadataKey],
              let state = ArchiveBackendSyncState(rawValue: rawValue) else {
            return .pending
        }
        return state
    }

    var isPublicBackendSyncEligible: Bool {
        kind == .photo || kind == .text
    }

    var detectedLocationClues: [String] {
        Self.metadataList(metadata[Self.analysisLocationCluesMetadataKey])
    }

    var detectedSceneClues: [String] {
        Self.metadataList(metadata[Self.analysisSceneCluesMetadataKey])
    }

    func updatingBackendSyncState(
        _ state: ArchiveBackendSyncState,
        error: String? = nil,
        attemptedAt: Date = Date()
    ) -> MemoryArchiveItem {
        var updatedItem = self
        updatedItem.metadata[Self.backendSyncStateMetadataKey] = state.rawValue
        updatedItem.metadata[Self.backendSyncAttemptedAtMetadataKey] = "\(Int(attemptedAt.timeIntervalSince1970))"
        if let error, !error.isEmpty {
            updatedItem.metadata[Self.backendSyncErrorMetadataKey] = error
        } else {
            updatedItem.metadata.removeValue(forKey: Self.backendSyncErrorMetadataKey)
        }
        return updatedItem
    }

    func canManage(by userId: String) -> Bool {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedUserId.isEmpty,
              ownerUserId != Self.legacyOwnerUserId else {
            return false
        }
        return ownerUserId == normalizedUserId
    }

    func archiveBackendPayload(
        userId: String,
        viewerUserId: String,
        ownerId: String,
        personaScope: String,
        digitalHumanId: String,
        isoFormatter: ISO8601DateFormatter = ISO8601DateFormatter()
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "userId": userId,
            "viewerUserId": viewerUserId,
            "ownerId": ownerId,
            "id": id,
            "ownerUserId": ownerUserId,
            "uploadedByUserId": ownerUserId,
            "uploaderUserId": ownerUserId,
            "kind": kind.rawValue,
            "title": title,
            "note": note,
            "createdAt": isoFormatter.string(from: createdAt),
            "updatedAt": isoFormatter.string(from: updatedAt),
            "analysisStatus": analysisStatus.rawValue,
            "tags": tags,
            "detectedPeople": detectedPeople,
            "detectedLocations": detectedLocationClues,
            "detectedScenes": detectedSceneClues,
            "metadata": metadataForBackendContract,
            "personaScope": personaScope,
            "digitalHumanId": digitalHumanId,
        ]
        if let analysisSummary, !analysisSummary.isEmpty {
            payload["analysisSummary"] = analysisSummary
        }
        if let transcriptText = metadata[Self.mediaTranscriptTextMetadataKey], !transcriptText.isEmpty {
            payload["transcriptText"] = transcriptText
        }
        if let fileSizeBytes = metadata[Self.mediaFileSizeBytesMetadataKey], !fileSizeBytes.isEmpty {
            payload["fileSizeBytes"] = fileSizeBytes
        }
        if let fileSizeLimitMB = metadata[Self.mediaFileSizeLimitMBMetadataKey], !fileSizeLimitMB.isEmpty {
            payload["fileSizeLimitMB"] = fileSizeLimitMB
        }
        return payload
    }

    func archiveMediaUploadIntentPayload(
        userId: String,
        personaScope: String,
        digitalHumanId: String,
        fileName: String,
        contentType: String,
        fileSizeBytes: Int64
    ) -> [String: Any] {
        [
            "userId": userId,
            "archiveItemId": id,
            "kind": kind.rawValue,
            "fileName": fileName,
            "contentType": contentType,
            "fileSizeBytes": fileSizeBytes,
            "personaScope": personaScope,
            "digitalHumanId": digitalHumanId,
            "ownerUserId": ownerUserId,
            "privacyMetadata": ["scope": "generationAllowed"],
        ]
    }

    private var metadataForBackendContract: [String: String] {
        var backendMetadata = metadata
        [
            Self.backendSyncStateMetadataKey,
            Self.backendSyncErrorMetadataKey,
            Self.backendSyncAttemptedAtMetadataKey,
            Self.mediaThumbnailPathMetadataKey,
            "localPath",
            "fileURL",
            "absolutePath",
            "rawAudioURL",
            "rawVideoURL",
            "localThumbnailPath",
        ].forEach {
            backendMetadata.removeValue(forKey: $0)
        }
        return backendMetadata
    }

    func assigningOwnerIfNeeded(_ ownerUserId: String) -> MemoryArchiveItem {
        let normalizedOwnerUserId = ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwnerUserId.isEmpty,
              self.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || self.ownerUserId == Self.legacyOwnerUserId else {
            return self
        }

        return MemoryArchiveItem(
            id: id,
            kind: kind,
            title: title,
            note: note,
            localPath: localPath,
            ownerUserId: normalizedOwnerUserId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            analysisStatus: analysisStatus,
            analysisSummary: analysisSummary,
            detectedPeople: detectedPeople,
            tags: tags,
            metadata: metadata
        )
    }

    mutating func applyLocalAnalysisResult(now: Date = Date()) {
        analysisStatus = .analyzed
        analysisSummary = localAnalysisSummary
        detectedPeople = Self.mergingUnique(detectedPeople, with: relationshipHints)
        tags = Self.mergingUnique(tags, with: localAnalysisTags)
        metadata["analysisSource"] = "local_rule"
        metadata["analysisUpdatedAt"] = "\(Int(now.timeIntervalSince1970))"
        metadata.removeValue(forKey: Self.analysisFailureReasonMetadataKey)
        storeMetadataList(extractLocationClues(), forKey: Self.analysisLocationCluesMetadataKey)
        storeMetadataList(extractSceneClues(), forKey: Self.analysisSceneCluesMetadataKey)
        updatedAt = now
    }

    mutating func markAnalysisFailed(reason: String, now: Date = Date()) {
        analysisStatus = .failed
        analysisSummary = "分析失败，可稍后重试。"
        metadata[Self.analysisFailureReasonMetadataKey] = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedAt = now
    }

    mutating func retryLocalAnalysis(now: Date = Date()) {
        analysisStatus = .pending
        analysisSummary = "正在重新整理人物、地点与场景线索。"
        metadata.removeValue(forKey: Self.analysisFailureReasonMetadataKey)
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

    private func extractLocationClues() -> [String] {
        let content = "\(title)\n\(note)"
        let candidates = [
            "上海",
            "外滩",
            "老家",
            "院子",
            "庭院",
            "公园",
            "学校",
            "医院",
            "厨房",
            "成都",
            "杭州",
            "北京",
        ]
        return candidates.filter { content.contains($0) }
    }

    private func extractSceneClues() -> [String] {
        let content = "\(title)\n\(note)"
        let candidates = [
            "合影",
            "聚会",
            "生日",
            "春节",
            "旅行",
            "散步",
            "吃饭",
            "聊天",
            "老照片",
            "相册",
            "录音",
        ]
        return candidates.filter { content.contains($0) }
    }

    private static func mergingUnique(_ base: [String], with additions: [String]) -> [String] {
        additions.reduce(into: base) { result, value in
            guard !value.isEmpty, !result.contains(value) else { return }
            result.append(value)
        }
    }

    private static func metadataList(_ rawValue: String?) -> [String] {
        guard let rawValue, !rawValue.isEmpty else { return [] }
        return rawValue
            .components(separatedBy: CharacterSet(charactersIn: "、,|"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private mutating func storeMetadataList(_ values: [String], forKey key: String) {
        let uniqueValues = Self.mergingUnique([], with: values)
        if uniqueValues.isEmpty {
            metadata.removeValue(forKey: key)
        } else {
            metadata[key] = uniqueValues.joined(separator: "、")
        }
    }
}
