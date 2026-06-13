import Foundation

enum MemoryArchiveItemKind: String, Codable {
    case photo
    case screenshot
    case voiceSample
    case textNote
    case personalityNote
    case catchphrase
}

enum MemoryArchiveAnalysisStatus: String, Codable {
    case manual
    case pending
    case analyzed
    case failed
}

struct MemoryArchiveImageAnalysis: Codable, Equatable {
    let summary: String
    let detectedPeople: [String]
    let scene: String?
    let occasion: String?
    let mood: String?
    let estimatedDecade: Int?
}

struct MemoryArchiveItem: Codable, Identifiable, Equatable, MemoryPrivacyScoped {
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
    var scene: String?
    var occasion: String?
    var mood: String?
    var estimatedDecade: Int?
    var tags: [String]
    var isPrivate: Bool
    var privacyMetadata: MemoryPrivacyMetadata
    var targetPersonId: String?
    var targetPersonName: String?
    var voiceProfileId: String?

    init(
        id: String,
        kind: MemoryArchiveItemKind,
        title: String,
        note: String,
        localPath: String?,
        createdAt: Date,
        updatedAt: Date,
        analysisStatus: MemoryArchiveAnalysisStatus,
        analysisSummary: String?,
        detectedPeople: [String],
        scene: String?,
        occasion: String?,
        mood: String?,
        estimatedDecade: Int?,
        tags: [String],
        isPrivate: Bool,
        privacyMetadata: MemoryPrivacyMetadata? = nil,
        targetPersonId: String? = nil,
        targetPersonName: String? = nil,
        voiceProfileId: String? = nil
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
        self.scene = scene
        self.occasion = occasion
        self.mood = mood
        self.estimatedDecade = estimatedDecade
        self.tags = tags
        self.isPrivate = isPrivate
        self.privacyMetadata = privacyMetadata
            ?? MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeFromLegacy(isPrivate: isPrivate))
        self.targetPersonId = targetPersonId
        self.targetPersonName = targetPersonName
        self.voiceProfileId = voiceProfileId
    }

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
        case scene
        case occasion
        case mood
        case estimatedDecade
        case tags
        case isPrivate
        case privacyMetadata
        case targetPersonId
        case targetPersonName
        case voiceProfileId
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
        scene = try container.decodeIfPresent(String.self, forKey: .scene)
        occasion = try container.decodeIfPresent(String.self, forKey: .occasion)
        mood = try container.decodeIfPresent(String.self, forKey: .mood)
        estimatedDecade = try container.decodeIfPresent(Int.self, forKey: .estimatedDecade)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? true
        privacyMetadata = try container.decodeIfPresent(MemoryPrivacyMetadata.self, forKey: .privacyMetadata)
            ?? MemoryPrivacyMetadata(scope: MemoryPrivacyMigration.scopeFromLegacy(isPrivate: isPrivate))
        targetPersonId = try container.decodeIfPresent(String.self, forKey: .targetPersonId)
        targetPersonName = try container.decodeIfPresent(String.self, forKey: .targetPersonName)
        voiceProfileId = try container.decodeIfPresent(String.self, forKey: .voiceProfileId)
    }
}

struct MemoryArchiveSummary: Equatable {
    let totalCount: Int
    let photoCount: Int
    let screenshotCount: Int
    let voiceSampleCount: Int
    let textCount: Int
    let analyzedPhotoCount: Int
}
