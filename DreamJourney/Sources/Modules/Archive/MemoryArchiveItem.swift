import Foundation

struct TimeLetterRecipientSelection: Equatable {
    let id: String
    let name: String
}

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
    case analyzing
    case analyzed
    case failed
    case retryable
}

extension MemoryArchiveAnalysisStatus {
    var isRetryableFailureLike: Bool {
        switch self {
        case .manual:
            return false
        case .pending:
            return false
        case .analyzing:
            return false
        case .analyzed:
            return false
        case .failed:
            return true
        case .retryable:
            return true
        }
    }
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
        metadata = Self.metadataFromRemoteAnalysisContract(object, baseMetadata: metadata)
        metadata = Self.metadataFromRemoteTimeLetterContract(object, baseMetadata: metadata)
        if (kind == .photo || kind == .text || kind == .timeLetter),
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
        case "analyzing", "analysing":
            self = .analyzing
        case "analyzed", "analysed":
            self = .analyzed
        case "failed":
            self = .failed
        case "retryable":
            self = .retryable
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

    static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let bool as Bool:
            return bool
        case let number as NSNumber:
            return number.boolValue
        case let string as String:
            let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            switch normalized {
            case "true", "1", "yes", "y":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                return nil
            }
        default:
            return nil
        }
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

    static func metadataFromRemoteAnalysisContract(
        _ object: [String: Any],
        baseMetadata: [String: String]
    ) -> [String: String] {
        var metadata = baseMetadata
        mergeRemoteMetadataList(object["detectedLocations"], forKey: Self.analysisLocationCluesMetadataKey, into: &metadata)
        mergeRemoteMetadataList(object["detectedScenes"], forKey: Self.analysisSceneCluesMetadataKey, into: &metadata)
        if let failureReason = Self.stringValue(object["analysisFailureReason"]) {
            metadata[Self.analysisFailureReasonMetadataKey] = failureReason
        }
        if let provider = Self.stringValue(object["provider"]) {
            metadata[Self.analysisProviderMetadataKey] = provider
        }
        if let isRetryable = Self.boolValue(object["analysisRetryable"]) {
            metadata[Self.analysisRetryableMetadataKey] = isRetryable ? "true" : "false"
        }
        return metadata
    }

    static func mergeRemoteMetadataList(_ value: Any?, forKey key: String, into metadata: inout [String: String]) {
        let values = stringArray(value)
        guard !values.isEmpty else {
            return
        }
        metadata[key] = values.joined(separator: "、")
    }

    static func metadataFromRemoteTimeLetterContract(
        _ object: [String: Any],
        baseMetadata: [String: String]
    ) -> [String: String] {
        var metadata = baseMetadata
        for (remoteKey, metadataKey) in [
            ("deliveryState", "deliveryState"),
            ("timeLetterStatus", "timeLetterStatus"),
            ("deliveryPolicy", "deliveryPolicy"),
            ("openAt", MemoryArchiveItem.timeLetterOpenAtMetadataKey),
            ("sealedAt", MemoryArchiveItem.timeLetterSealedAtMetadataKey),
            ("deliveryStatus", MemoryArchiveItem.timeLetterDeliveryStatusMetadataKey),
            ("deliveryExecutionState", MemoryArchiveItem.timeLetterDeliveryExecutionStateMetadataKey),
            ("deliveryDecisionState", MemoryArchiveItem.timeLetterDeliveryDecisionStateMetadataKey),
            ("deliveryScheduleState", MemoryArchiveItem.timeLetterDeliveryScheduleStateMetadataKey),
            ("deliveryProviderState", MemoryArchiveItem.timeLetterDeliveryProviderStateMetadataKey),
        ] {
            if let value = stringValue(object[remoteKey]) {
                metadata[metadataKey] = value
            }
        }
        if let notificationScheduled = boolValue(object["deliveryNotificationScheduled"]) {
            metadata[MemoryArchiveItem.timeLetterNotificationScheduledMetadataKey] = notificationScheduled ? "true" : "false"
        }
        if let recipients = object["recipients"] as? [[String: Any]] {
            let ids = recipients.compactMap { stringValue($0["id"]) }
            let names = recipients.compactMap { stringValue($0["name"]) }
            if !ids.isEmpty {
                metadata[MemoryArchiveItem.timeLetterRecipientIdsMetadataKey] = ids.joined(separator: "|")
            }
            if !names.isEmpty {
                metadata[MemoryArchiveItem.timeLetterRecipientNamesMetadataKey] = names.joined(separator: "、")
            }
        }
        return metadata
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
    static let mediaUploadIntentIdMetadataKey = "uploadIntentId"
    static let mediaObjectKeyMetadataKey = "objectKey"
    static let mediaUploadProviderMetadataKey = "uploadProvider"
    static let mediaUploadURLMetadataKey = "uploadURL"
    static let mediaUploadErrorMetadataKey = "uploadError"
    static let analysisLocationCluesMetadataKey = "analysisLocationClues"
    static let analysisSceneCluesMetadataKey = "analysisSceneClues"
    static let analysisFailureReasonMetadataKey = "analysisFailureReason"
    static let analysisRetryableMetadataKey = "analysisRetryable"
    static let analysisProviderMetadataKey = "analysisProvider"
    static let analysisFallbackModeMetadataKey = "analysisFallbackMode"
    static let timeLetterDeliveryExecutionStateMetadataKey = "deliveryExecutionState"
    static let timeLetterDeliveryDecisionStateMetadataKey = "deliveryDecisionState"
    static let timeLetterDeliveryScheduleStateMetadataKey = "deliveryScheduleState"
    static let timeLetterDeliveryProviderStateMetadataKey = "deliveryProviderState"
    static let timeLetterNotificationScheduledMetadataKey = "deliveryNotificationScheduled"
    static let timeLetterOpenAtMetadataKey = "openAt"
    static let timeLetterRecipientIdsMetadataKey = "recipientIds"
    static let timeLetterRecipientNamesMetadataKey = "recipientNames"
    static let timeLetterSealedAtMetadataKey = "sealedAt"
    static let timeLetterDeliveryStatusMetadataKey = "deliveryStatus"
    static let timeLetterImageAttachmentCountMetadataKey = "imageAttachmentCount"
    static let timeLetterImageLocalPathMetadataKey = "imageLocalPath"

    var backendSyncState: ArchiveBackendSyncState {
        guard let rawValue = metadata[Self.backendSyncStateMetadataKey],
              let state = ArchiveBackendSyncState(rawValue: rawValue) else {
            return .pending
        }
        return state
    }

    var isPublicBackendSyncEligible: Bool {
        kind == .photo || kind == .text || kind == .timeLetter
    }

    var isMediaUploadIntentEligible: Bool {
        (kind == .audio || kind == .video) && resolvedLocalFilePath?.isEmpty == false
    }

    var resolvedLocalFilePath: String? {
        Self.resolvedLocalFilePath(localPath, candidateDirectoryNames: archiveLocalDirectoryNames)
    }

    var hasResolvedLocalFile: Bool {
        resolvedLocalFilePath != nil
    }

    var resolvedThumbnailPath: String? {
        Self.resolvedLocalFilePath(
            metadata[Self.mediaThumbnailPathMetadataKey],
            candidateDirectoryNames: ["archive-video-thumbnails"]
        )
    }

    var needsLocalPathRecovery: Bool {
        guard let localPath,
              let resolvedLocalFilePath else {
            return false
        }
        return localPath != resolvedLocalFilePath
    }

    func updatingRecoveredLocalPathIfNeeded() -> MemoryArchiveItem {
        var recovered = self
        if let resolvedLocalFilePath,
           localPath != resolvedLocalFilePath {
            recovered.localPath = resolvedLocalFilePath
        }
        if let resolvedThumbnailPath,
           metadata[Self.mediaThumbnailPathMetadataKey] != resolvedThumbnailPath {
            recovered.metadata[Self.mediaThumbnailPathMetadataKey] = resolvedThumbnailPath
        }
        return recovered
    }

    private var archiveLocalDirectoryNames: [String] {
        switch kind {
        case .photo:
            return ["archive-images"]
        case .audio:
            return ["archive-audio"]
        case .video:
            return ["archive-video", "archive-video-thumbnails"]
        case .timeLetter:
            return ["archive-time-letter-images"]
        case .text:
            return []
        }
    }

    private static func resolvedLocalFilePath(
        _ path: String?,
        candidateDirectoryNames: [String]
    ) -> String? {
        guard let path,
              !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        if FileManager.default.fileExists(atPath: path) {
            return path
        }

        let fileName = URL(fileURLWithPath: path).lastPathComponent
        guard !fileName.isEmpty,
              !candidateDirectoryNames.isEmpty,
              let documentsURL = try? FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              ) else {
            return nil
        }

        for directoryName in candidateDirectoryNames {
            let candidate = documentsURL
                .appendingPathComponent(directoryName, isDirectory: true)
                .appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }

        return nil
    }

    var mediaUploadContentType: String? {
        guard let localPath = resolvedLocalFilePath else { return nil }
        let fileExtension = URL(fileURLWithPath: localPath).pathExtension.lowercased()
        switch kind {
        case .audio:
            switch fileExtension {
            case "m4a":
                return "audio/mp4"
            case "wav":
                return "audio/wav"
            default:
                return "audio/mpeg"
            }
        case .video:
            switch fileExtension {
            case "mov":
                return "video/quicktime"
            case "mp4", "m4v":
                return "video/mp4"
            default:
                return "video/mp4"
            }
        case .photo, .text, .timeLetter:
            return nil
        }
    }

    var mediaUploadFileName: String? {
        guard let localPath = resolvedLocalFilePath else { return nil }
        let fileName = URL(fileURLWithPath: localPath).lastPathComponent
        return fileName.isEmpty ? nil : fileName
    }

    var mediaUploadFileSizeBytes: Int64? {
        if let rawValue = metadata[Self.mediaFileSizeBytesMetadataKey],
           let value = Int64(rawValue) {
            return value
        }
        guard let localPath = resolvedLocalFilePath,
              let attributes = try? FileManager.default.attributesOfItem(atPath: localPath),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }

    var isTimeLetterDraft: Bool {
        kind == .timeLetter && metadata["deliveryState"] == "draft"
    }

    var timeLetterOpenAt: Date? {
        Self.dateValue(metadata[Self.timeLetterOpenAtMetadataKey])
    }

    var timeLetterSealedAt: Date? {
        Self.dateValue(metadata[Self.timeLetterSealedAtMetadataKey])
    }

    var timeLetterRecipientIds: [String] {
        Self.metadataList(metadata[Self.timeLetterRecipientIdsMetadataKey], separator: "|")
    }

    var timeLetterRecipientNames: [String] {
        Self.metadataList(metadata[Self.timeLetterRecipientNamesMetadataKey])
    }

    var timeLetterRecipients: [TimeLetterRecipientSelection] {
        let ids = timeLetterRecipientIds
        let names = timeLetterRecipientNames
        guard !ids.isEmpty else {
            return [TimeLetterRecipientSelection(id: "self", name: "我")]
        }
        return ids.enumerated().map { index, id in
            let name = index < names.count ? names[index] : id
            return TimeLetterRecipientSelection(id: id, name: name)
        }
    }

    var timeLetterDeliveryStatus: String {
        if let status = metadata[Self.timeLetterDeliveryStatusMetadataKey],
           status == "delivered" {
            return status
        }
        if isTimeLetterDue {
            return "ready"
        }
        return metadata[Self.timeLetterDeliveryStatusMetadataKey] ?? (isTimeLetterDraft ? "draft" : "scheduled")
    }

    var isTimeLetterDelivered: Bool {
        timeLetterDeliveryStatus == "delivered"
    }

    var isTimeLetterDue: Bool {
        guard isSealedTimeLetter,
              let openAt = timeLetterOpenAt else {
            return false
        }
        return openAt <= Date()
    }

    var timeLetterDeliveryExecutionState: String {
        metadata[Self.timeLetterDeliveryExecutionStateMetadataKey] ?? (isTimeLetterDraft ? "draft" : "scheduled")
    }

    var timeLetterDeliveryDecisionState: String {
        metadata[Self.timeLetterDeliveryDecisionStateMetadataKey] ?? (isTimeLetterDraft ? "draft" : "confirmed")
    }

    var timeLetterDeliveryScheduleState: String {
        metadata[Self.timeLetterDeliveryScheduleStateMetadataKey] ?? (isTimeLetterDraft ? "not_scheduled" : "scheduled")
    }

    var timeLetterDeliveryProviderState: String {
        metadata[Self.timeLetterDeliveryProviderStateMetadataKey] ?? (isTimeLetterDraft ? "not_scheduled" : "local_notification_and_in_app")
    }

    var timeLetterNotificationScheduled: Bool {
        metadata[Self.timeLetterNotificationScheduledMetadataKey] == "true"
    }

    var isTimeLetterDeliveryDisabledUntilProductDecision: Bool {
        false
    }

    var detectedLocationClues: [String] {
        Self.metadataList(metadata[Self.analysisLocationCluesMetadataKey])
    }

    var detectedSceneClues: [String] {
        Self.metadataList(metadata[Self.analysisSceneCluesMetadataKey])
    }

    var analysisRetryableForBackend: Bool {
        if let retryable = metadata[Self.analysisRetryableMetadataKey],
           let parsedRetryable = Self.boolValue(retryable) {
            return parsedRetryable
        }
        return analysisStatus.isRetryableFailureLike
    }

    var metadataTranscriptTextForDisplay: String? {
        guard let transcriptText = metadata[Self.mediaTranscriptTextMetadataKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !transcriptText.isEmpty else {
            return nil
        }
        return transcriptText
    }

    var metadataFileSizeDisplayName: String? {
        guard let fileSizeText = metadata[Self.mediaFileSizeBytesMetadataKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let fileSizeBytes = Int64(fileSizeText),
              fileSizeBytes > 0 else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeBytes)
    }

    var videoAnalysisStatusDisplayName: String? {
        guard kind == .video else { return nil }
        switch analysisStatus {
        case .manual:
            return "手动说明"
        case .pending:
            return "等待视频分析"
        case .analyzing:
            return "视频分析中"
        case .analyzed:
            return "视频分析已生成"
        case .failed:
            return analysisRetryableForBackend ? "视频分析失败，可重试" : "视频分析失败"
        case .retryable:
            return "视频分析失败，可重试"
        }
    }

    var audioTranscriptionStatusDisplayName: String? {
        guard kind == .audio else { return nil }
        switch metadata[Self.mediaTranscriptionStatusMetadataKey] {
        case ArchiveMediaTranscriptionStatus.notRequested.rawValue:
            return "未转写"
        case ArchiveMediaTranscriptionStatus.pending.rawValue:
            return "转写中"
        case ArchiveMediaTranscriptionStatus.completed.rawValue:
            return "已转写"
        case ArchiveMediaTranscriptionStatus.failed.rawValue:
            return "转写失败，可重试"
        default:
            return nil
        }
    }

    var isSealedTimeLetter: Bool {
        kind == .timeLetter && metadata["deliveryState"] == "sealed"
    }

    var echoContextText: String? {
        let normalizedNote = Self.normalizedArchiveText(note)
        switch kind {
        case .audio:
            return metadataTranscriptTextForDisplay ?? (normalizedNote.isEmpty ? nil : normalizedNote)
        case .video:
            if analysisStatus == .analyzed {
                let normalizedSummary = Self.normalizedArchiveText(analysisSummary ?? "")
                if !normalizedSummary.isEmpty {
                    return normalizedSummary
                }
            }
            return normalizedNote.isEmpty ? nil : normalizedNote
        case .timeLetter:
            guard isSealedTimeLetter else { return nil }
            if analysisStatus.isRetryableFailureLike {
                return normalizedNote.isEmpty ? nil : normalizedNote
            }
            let normalizedSummary = Self.normalizedArchiveText(analysisSummary ?? "")
            return normalizedSummary.isEmpty ? (normalizedNote.isEmpty ? nil : normalizedNote) : normalizedSummary
        case .photo, .text:
            if analysisStatus.isRetryableFailureLike {
                return normalizedNote.isEmpty ? nil : normalizedNote
            }
            let normalizedSummary = Self.normalizedArchiveText(analysisSummary ?? "")
            return normalizedSummary.isEmpty ? (normalizedNote.isEmpty ? nil : normalizedNote) : normalizedSummary
        }
    }

    var echoContextAllowsClues: Bool {
        let statusAllowsClues: Bool
        switch analysisStatus {
        case .analyzed, .manual:
            statusAllowsClues = true
        case .pending, .analyzing, .failed, .retryable:
            statusAllowsClues = false
        }
        guard statusAllowsClues else {
            return false
        }
        switch kind {
        case .video:
            return analysisStatus == .analyzed
        case .audio:
            return metadataTranscriptTextForDisplay != nil || analysisStatus == .analyzed
        case .timeLetter:
            return isSealedTimeLetter
        case .photo, .text:
            return true
        }
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

    func markingMediaUploadPending() -> MemoryArchiveItem {
        markingMediaUploadPending(now: Date())
    }

    func markingMediaUploadPending(now: Date) -> MemoryArchiveItem {
        var updatedItem = self
        updatedItem.metadata[Self.mediaUploadStatusMetadataKey] = ArchiveMediaUploadStatus.pending.rawValue
        updatedItem.metadata.removeValue(forKey: Self.mediaUploadErrorMetadataKey)
        updatedItem.metadata["mediaUploadAttemptedAt"] = "\(Int(now.timeIntervalSince1970))"
        updatedItem.updatedAt = now
        return updatedItem
    }

    func markingMediaUploadUploaded(intent: ArchiveMediaUploadIntent) -> MemoryArchiveItem {
        markingMediaUploadUploaded(intent: intent, now: Date())
    }

    func markingMediaUploadUploaded(intent: ArchiveMediaUploadIntent, now: Date) -> MemoryArchiveItem {
        var updatedItem = self
        updatedItem.metadata[Self.mediaUploadStatusMetadataKey] = ArchiveMediaUploadStatus.uploaded.rawValue
        updatedItem.metadata[Self.mediaUploadIntentIdMetadataKey] = intent.uploadIntentId
        updatedItem.metadata[Self.mediaObjectKeyMetadataKey] = intent.objectKey
        updatedItem.metadata[Self.mediaUploadProviderMetadataKey] = intent.storageProvider
        updatedItem.metadata[Self.mediaUploadURLMetadataKey] = intent.uploadURL
        updatedItem.metadata.removeValue(forKey: Self.mediaUploadErrorMetadataKey)
        updatedItem.metadata["mediaUploadCompletedAt"] = "\(Int(now.timeIntervalSince1970))"
        updatedItem.updatedAt = now
        return updatedItem
    }

    func markingMediaUploadFailed(_ error: String) -> MemoryArchiveItem {
        markingMediaUploadFailed(error, now: Date())
    }

    func markingMediaUploadFailed(_ error: String, now: Date) -> MemoryArchiveItem {
        var updatedItem = self
        let normalizedError = error.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.metadata[Self.mediaUploadStatusMetadataKey] = ArchiveMediaUploadStatus.failed.rawValue
        updatedItem.metadata[Self.mediaUploadErrorMetadataKey] = String(
            (normalizedError.isEmpty ? "上传失败" : normalizedError).prefix(80)
        )
        updatedItem.metadata["mediaUploadAttemptedAt"] = "\(Int(now.timeIntervalSince1970))"
        updatedItem.updatedAt = now
        return updatedItem
    }

    func updatingTimeLetterDraft(note: String) -> MemoryArchiveItem {
        updatingTimeLetterDraft(
            note: note,
            openAt: timeLetterOpenAt ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            recipients: timeLetterRecipients,
            imageLocalPath: localPath,
            now: Date()
        )
    }

    func updatingTimeLetterDraft(note: String, now: Date) -> MemoryArchiveItem {
        updatingTimeLetterDraft(
            note: note,
            openAt: timeLetterOpenAt ?? Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now,
            recipients: timeLetterRecipients,
            imageLocalPath: localPath,
            now: now
        )
    }

    func updatingTimeLetterDraft(
        note: String,
        openAt: Date,
        recipients: [TimeLetterRecipientSelection],
        imageLocalPath: String?,
        now: Date = Date()
    ) -> MemoryArchiveItem {
        var updatedItem = self
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedItem.note = trimmedNote
        updatedItem.title = "时间信件草稿"
        updatedItem.localPath = imageLocalPath
        updatedItem.analysisSummary = "这封信暂存为草稿，可继续编辑打开时间、收件人和图片附件。"
        updatedItem.metadata["deliveryState"] = "draft"
        updatedItem.metadata["timeLetterStatus"] = "draft"
        updatedItem.metadata["deliveryPolicy"] = "draft"
        updatedItem.metadata[Self.timeLetterOpenAtMetadataKey] = Self.isoString(from: openAt)
        updatedItem.metadata[Self.timeLetterRecipientIdsMetadataKey] = recipients.map(\.id).joined(separator: "|")
        updatedItem.metadata[Self.timeLetterRecipientNamesMetadataKey] = recipients.map(\.name).joined(separator: "、")
        updatedItem.metadata[Self.timeLetterDeliveryStatusMetadataKey] = "draft"
        updatedItem.metadata[Self.timeLetterDeliveryExecutionStateMetadataKey] = "draft"
        updatedItem.metadata[Self.timeLetterDeliveryDecisionStateMetadataKey] = "draft"
        updatedItem.metadata[Self.timeLetterDeliveryScheduleStateMetadataKey] = "not_scheduled"
        updatedItem.metadata[Self.timeLetterDeliveryProviderStateMetadataKey] = "not_scheduled"
        updatedItem.metadata[Self.timeLetterNotificationScheduledMetadataKey] = "false"
        updatedItem.metadata.removeValue(forKey: Self.timeLetterSealedAtMetadataKey)
        if let imageLocalPath, !imageLocalPath.isEmpty {
            updatedItem.metadata[Self.timeLetterImageLocalPathMetadataKey] = imageLocalPath
            updatedItem.metadata[Self.timeLetterImageAttachmentCountMetadataKey] = "1"
        } else {
            updatedItem.metadata.removeValue(forKey: Self.timeLetterImageLocalPathMetadataKey)
            updatedItem.metadata[Self.timeLetterImageAttachmentCountMetadataKey] = "0"
        }
        updatedItem.metadata["characterCount"] = "\(trimmedNote.count)"
        updatedItem.updatedAt = now
        return updatedItem
    }

    func sealingTimeLetterDraft() -> MemoryArchiveItem {
        sealingTimeLetterDraft(now: Date())
    }

    func sealingTimeLetterDraft(now: Date) -> MemoryArchiveItem {
        sealingTimeLetter(
            openAt: timeLetterOpenAt ?? Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now,
            recipients: timeLetterRecipients,
            imageLocalPath: localPath,
            now: now
        )
    }

    func sealingTimeLetter(
        openAt: Date,
        recipients: [TimeLetterRecipientSelection],
        imageLocalPath: String?,
        now: Date = Date()
    ) -> MemoryArchiveItem {
        var updatedItem = self
        updatedItem.title = "时间信件"
        updatedItem.localPath = imageLocalPath
        updatedItem.analysisSummary = "这封信已封存，到达打开时间后会提醒本人和收件人查看。"
        updatedItem.tags = Self.mergingUnique(updatedItem.tags.filter { $0 != "草稿" }, with: ["时间信件"])
        updatedItem.metadata["deliveryState"] = "sealed"
        updatedItem.metadata["timeLetterStatus"] = "sealed"
        updatedItem.metadata["deliveryPolicy"] = "scheduled_local_and_in_app"
        updatedItem.metadata[Self.timeLetterOpenAtMetadataKey] = Self.isoString(from: openAt)
        updatedItem.metadata[Self.timeLetterRecipientIdsMetadataKey] = recipients.map(\.id).joined(separator: "|")
        updatedItem.metadata[Self.timeLetterRecipientNamesMetadataKey] = recipients.map(\.name).joined(separator: "、")
        updatedItem.metadata[Self.timeLetterSealedAtMetadataKey] = Self.isoString(from: now)
        updatedItem.metadata[Self.timeLetterDeliveryStatusMetadataKey] = openAt <= now ? "ready" : "scheduled"
        updatedItem.metadata[Self.timeLetterDeliveryExecutionStateMetadataKey] = openAt <= now ? "ready" : "scheduled"
        updatedItem.metadata[Self.timeLetterDeliveryDecisionStateMetadataKey] = "confirmed"
        updatedItem.metadata[Self.timeLetterDeliveryScheduleStateMetadataKey] = "scheduled"
        updatedItem.metadata[Self.timeLetterDeliveryProviderStateMetadataKey] = "local_notification_and_in_app"
        updatedItem.metadata[Self.timeLetterNotificationScheduledMetadataKey] = "true"
        if let imageLocalPath, !imageLocalPath.isEmpty {
            updatedItem.metadata[Self.timeLetterImageLocalPathMetadataKey] = imageLocalPath
            updatedItem.metadata[Self.timeLetterImageAttachmentCountMetadataKey] = "1"
        } else {
            updatedItem.metadata.removeValue(forKey: Self.timeLetterImageLocalPathMetadataKey)
            updatedItem.metadata[Self.timeLetterImageAttachmentCountMetadataKey] = "0"
        }
        updatedItem.updatedAt = now
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
            "analysisFailureReason": metadata[Self.analysisFailureReasonMetadataKey] ?? "",
            "analysisRetryable": analysisRetryableForBackend,
            "personaScope": personaScope,
            "digitalHumanId": digitalHumanId,
            "privacyMetadata": [
                "scope": "generationAllowed",
                "sourceRefs": [
                    [
                        "kind": "archiveItem",
                        "id": id,
                        "title": title,
                    ],
                ],
            ],
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
        if kind == .timeLetter {
            let deliveryState = metadata["deliveryState"] ?? (isTimeLetterDraft ? "draft" : "sealed")
            payload["deliveryState"] = deliveryState
            payload["timeLetterStatus"] = metadata["timeLetterStatus"] ?? deliveryState
            payload["deliveryPolicy"] = metadata["deliveryPolicy"] ?? (isTimeLetterDraft ? "draft" : "scheduled_local_and_in_app")
            payload["openAt"] = metadata[Self.timeLetterOpenAtMetadataKey] ?? ""
            payload["recipients"] = timeLetterRecipients.map {
                [
                    "id": $0.id,
                    "name": $0.name,
                    "type": $0.id == "self" ? "self" : "family",
                ]
            }
            payload["sealedAt"] = metadata[Self.timeLetterSealedAtMetadataKey] ?? ""
            payload["deliveryStatus"] = timeLetterDeliveryStatus
            payload["deliveryExecutionState"] = timeLetterDeliveryExecutionState
            payload["deliveryDecisionState"] = timeLetterDeliveryDecisionState
            payload["deliveryScheduleState"] = timeLetterDeliveryScheduleState
            payload["deliveryProviderState"] = timeLetterDeliveryProviderState
            payload["deliveryNotificationScheduled"] = timeLetterNotificationScheduled
            payload["metadataOnly"] = true
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
            Self.timeLetterImageLocalPathMetadataKey,
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
        metadata.removeValue(forKey: Self.analysisRetryableMetadataKey)
        storeMetadataList(extractLocationClues(), forKey: Self.analysisLocationCluesMetadataKey)
        storeMetadataList(extractSceneClues(), forKey: Self.analysisSceneCluesMetadataKey)
        updatedAt = now
    }

    mutating func markAnalysisFailed(reason: String, now: Date = Date()) {
        analysisStatus = .failed
        analysisSummary = "AI 分析暂不可用，可稍后重试。"
        metadata[Self.analysisFailureReasonMetadataKey] = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        metadata[Self.analysisRetryableMetadataKey] = "true"
        updatedAt = now
    }

    mutating func markAnalysisUnavailableFromRuntime(
        provider: String,
        fallbackMode: String,
        message: String,
        reason: String = "provider_unavailable",
        now: Date = Date()
    ) {
        analysisStatus = .failed
        analysisSummary = message
        metadata[Self.analysisFailureReasonMetadataKey] = reason
        metadata[Self.analysisRetryableMetadataKey] = "true"
        metadata[Self.analysisProviderMetadataKey] = provider
        metadata[Self.analysisFallbackModeMetadataKey] = fallbackMode
        metadata["analysisSource"] = "backend_runtime_config"
        metadata["analysisUpdatedAt"] = "\(Int(now.timeIntervalSince1970))"
        updatedAt = now
    }

    mutating func retryLocalAnalysis(now: Date = Date()) {
        analysisStatus = .pending
        analysisSummary = "正在重新整理人物、地点与场景线索。"
        metadata.removeValue(forKey: Self.analysisFailureReasonMetadataKey)
        metadata.removeValue(forKey: Self.analysisRetryableMetadataKey)
        metadata.removeValue(forKey: Self.analysisProviderMetadataKey)
        metadata.removeValue(forKey: Self.analysisFallbackModeMetadataKey)
        updatedAt = now
    }

    mutating func applyRemoteImageAnalysisResult(_ result: [String: Any], now: Date = Date()) {
        if let statusRaw = Self.stringValue(result["analysisStatus"]),
           let remoteStatus = MemoryArchiveAnalysisStatus(remoteRawValue: statusRaw) {
            analysisStatus = remoteStatus
        } else {
            analysisStatus = .analyzed
        }

        if let summary = Self.stringValue(result["analysisSummary"])
            ?? Self.stringValue(result["description"]) {
            analysisSummary = summary
        }
        detectedPeople = Self.mergingUnique(detectedPeople, with: Self.stringArray(result["detectedPeople"]))
        tags = Self.mergingUnique(tags, with: Self.stringArray(result["tags"]))
        metadata = Self.metadataFromRemoteAnalysisContract(result, baseMetadata: metadata)
        metadata["analysisSource"] = "backend_image_analysis"
        metadata["analysisUpdatedAt"] = "\(Int(now.timeIntervalSince1970))"
        if analysisStatus == .analyzed {
            metadata.removeValue(forKey: Self.analysisFailureReasonMetadataKey)
            metadata.removeValue(forKey: Self.analysisRetryableMetadataKey)
        } else if analysisStatus.isRetryableFailureLike,
                  Self.stringValue(result["analysisSummary"]) == nil,
                  Self.stringValue(result["description"]) == nil {
            analysisSummary = "AI 分析暂不可用，可稍后重试。"
        }
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

    private static func metadataList(_ rawValue: String?, separator: String? = nil) -> [String] {
        guard let rawValue, !rawValue.isEmpty else { return [] }
        let components = separator.map {
            rawValue.components(separatedBy: $0)
        } ?? rawValue.components(separatedBy: CharacterSet(charactersIn: "、,|"))
        return components
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func isoString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func normalizedArchiveText(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
