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

enum MemoryArchiveBuildReadinessState: String, Equatable {
    case empty
    case collecting
    case materialReady
    case grounded
}

struct MemoryArchiveBuildReadiness: Equatable {
    static let requiredPhotoCount = 1
    static let requiredVoiceEvidenceCount = 3
    static let requiredPersonaHintCount = 1
    static let requiredArchiveKnowledgeSourceCount = 1

    let state: MemoryArchiveBuildReadinessState
    let completedStepCount: Int
    let totalStepCount: Int
    let usablePhotoCount: Int
    let usableVoiceEvidenceCount: Int
    let usablePersonaHintCount: Int
    let archiveKnowledgeSourceCount: Int
    let missingRequirements: [String]

    var titleText: String {
        "建库完成度 \(completedStepCount)/\(totalStepCount)"
    }

    var detailText: String {
        if missingRequirements.isEmpty {
            return "最小建库已成型：照片、语音材料、人格线索和结构化知识都已有真实来源。"
        }
        return "还需补充：" + missingRequirements.joined(separator: "、")
    }

    static func build(
        items: [MemoryArchiveItem],
        archiveKnowledgeSourceCount: Int
    ) -> MemoryArchiveBuildReadiness {
        let usableItems = items.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .prompt)
        }
        let usablePhotoCount = usableItems.filter(hasUsablePhotoEvidence).count
        let usableVoiceEvidenceCount = usableItems.filter(hasUsableVoiceOrScreenshotEvidence).count
        let usablePersonaHintCount = usableItems.filter {
            $0.kind == .personalityNote || $0.kind == .catchphrase
        }.count

        var completed = 0
        var missing: [String] = []
        if usablePhotoCount >= requiredPhotoCount {
            completed += 1
        } else {
            missing.append("1 张已分析的可生成旧照片")
        }
        if usableVoiceEvidenceCount >= requiredVoiceEvidenceCount {
            completed += 1
        } else {
            missing.append("\(requiredVoiceEvidenceCount) 份有真实转写或分析的可生成语音/截图材料")
        }
        if usablePersonaHintCount >= requiredPersonaHintCount {
            completed += 1
        } else {
            missing.append("1 条口头禅或性格描述")
        }
        if archiveKnowledgeSourceCount >= requiredArchiveKnowledgeSourceCount {
            completed += 1
        } else {
            missing.append("至少 1 条档案来源的结构化知识")
        }

        let total = 4
        let state: MemoryArchiveBuildReadinessState
        if completed == 0 {
            state = .empty
        } else if completed == total {
            state = .grounded
        } else if usablePhotoCount >= requiredPhotoCount
                    && usableVoiceEvidenceCount >= requiredVoiceEvidenceCount
                    && usablePersonaHintCount >= requiredPersonaHintCount {
            state = .materialReady
        } else {
            state = .collecting
        }

        return MemoryArchiveBuildReadiness(
            state: state,
            completedStepCount: completed,
            totalStepCount: total,
            usablePhotoCount: usablePhotoCount,
            usableVoiceEvidenceCount: usableVoiceEvidenceCount,
            usablePersonaHintCount: usablePersonaHintCount,
            archiveKnowledgeSourceCount: archiveKnowledgeSourceCount,
            missingRequirements: missing
        )
    }

    private static func hasUsablePhotoEvidence(_ item: MemoryArchiveItem) -> Bool {
        guard item.kind == .photo,
              item.analysisStatus == .analyzed else {
            return false
        }
        return hasText(item.analysisSummary) ||
            !item.detectedPeople.isEmpty ||
            hasText(item.scene) ||
            hasText(item.occasion) ||
            hasText(item.mood) ||
            item.estimatedDecade != nil
    }

    private static func hasUsableVoiceOrScreenshotEvidence(_ item: MemoryArchiveItem) -> Bool {
        switch item.kind {
        case .voiceSample:
            return voiceTranscriptText(in: item.note) != nil
        case .screenshot:
            guard item.analysisStatus == .analyzed else { return false }
            return hasText(item.analysisSummary) ||
                !item.detectedPeople.isEmpty ||
                hasText(item.scene) ||
                hasText(item.occasion) ||
                hasText(item.mood)
        case .photo, .textNote, .personalityNote, .catchphrase:
            return false
        }
    }

    private static func voiceTranscriptText(in note: String) -> String? {
        guard let range = note.range(of: "语音转写/摘要：") else {
            return nil
        }
        let text = note[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
