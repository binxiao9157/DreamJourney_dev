import Foundation

enum OwnerTruthFormalMemoryContractError: LocalizedError, Equatable, Sendable {
    case invalidList(String)
    case invalidProfile(String)
    case invalidDetail(String)
    case invalidQuery(String)
    case invalidRevision(String)

    var errorDescription: String? {
        switch self {
        case .invalidList(let detail):
            return "正式记忆列表合同无效：\(detail)"
        case .invalidProfile(let detail):
            return "人物记忆归纳合同无效：\(detail)"
        case .invalidDetail(let detail):
            return "正式记忆详情合同无效：\(detail)"
        case .invalidQuery(let detail):
            return "正式记忆筛选条件无效：\(detail)"
        case .invalidRevision(let detail):
            return "正式记忆修订合同无效：\(detail)"
        }
    }
}

enum OwnerTruthFormalMemoryVersionStatus: String, Equatable, Sendable {
    case current
    case superseded
}

struct OwnerTruthFormalMemoryVersion: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let versionNumber: Int
    let status: OwnerTruthFormalMemoryVersionStatus
    let decision: OwnerTruthCandidateDecision
    let contentSchemaVersion: String
    let contentHash: String
    let content: [String: OwnerTruthJSONValue]
    let sourceCount: Int
    let createdAt: Date

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthFormalMemoryContract.recordID(object["versionId"]),
              let versionNumber = OwnerTruthFormalMemoryContract.positiveInt(object["versionNumber"]),
              let rawStatus = OwnerTruthFormalMemoryContract.requiredString(object["status"]),
              let status = OwnerTruthFormalMemoryVersionStatus(rawValue: rawStatus),
              let rawDecision = OwnerTruthFormalMemoryContract.requiredString(object["decision"]),
              let decision = OwnerTruthCandidateDecision(rawValue: rawDecision),
              decision == .accepted || decision == .corrected,
              let contentSchemaVersion = OwnerTruthFormalMemoryContract.requiredString(
                object["contentSchemaVersion"]
              ),
              let contentHash = OwnerTruthFormalMemoryContract.sha256(object["contentHash"]),
              let rawContent = object["content"] as? [String: Any],
              !rawContent.isEmpty,
              let sourceCount = OwnerTruthFormalMemoryContract.nonNegativeInt(object["sourceCount"]),
              sourceCount > 0,
              let createdAt = OwnerTruthFormalMemoryContract.date(object["createdAt"]) else {
            throw OwnerTruthFormalMemoryContractError.invalidDetail("版本字段缺失或越界")
        }
        var content: [String: OwnerTruthJSONValue] = [:]
        for (key, value) in rawContent {
            guard let parsed = OwnerTruthJSONValue(backendJSONObject: value) else {
                throw OwnerTruthFormalMemoryContractError.invalidDetail("版本内容不是有效 JSON")
            }
            content[key] = parsed
        }
        self.id = id
        self.versionNumber = versionNumber
        self.status = status
        self.decision = decision
        self.contentSchemaVersion = contentSchemaVersion
        self.contentHash = contentHash
        self.content = content
        self.sourceCount = sourceCount
        self.createdAt = createdAt
    }

    var summary: String {
        for key in ["event", "statement", "expression", "emotion", "summary", "title", "text", "claim", "label"] {
            guard case .string(let value)? = content[key] else { continue }
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty { return normalized }
        }
        return "正式记忆"
    }

    var editableTextKey: String {
        for key in ["event", "statement", "expression", "emotion", "summary", "title", "text", "claim", "label"] {
            if case .string = content[key] { return key }
        }
        return "summary"
    }

    func content(replacingEditableText value: String) -> [String: OwnerTruthJSONValue] {
        var replacement = content
        replacement[editableTextKey] = .string(value)
        return replacement
    }

    func facetValues(named name: String) -> [String] {
        guard case .object(let facets)? = content["facets"],
              case .array(let values)? = facets[name] else { return [] }
        return values.compactMap { value in
            guard case .object(let object) = value,
                  case .string(let label)? = object["value"] else { return nil }
            return label
        }
    }
}

struct OwnerTruthFormalMemoryListItem: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let memoryKind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let currentVersion: OwnerTruthFormalMemoryVersion

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthFormalMemoryContract.recordID(object["memoryId"]),
              let rawKind = OwnerTruthFormalMemoryContract.requiredString(object["memoryKind"]),
              let memoryKind = OwnerTruthMemoryKind(rawValue: rawKind),
              let rawPerspective = OwnerTruthFormalMemoryContract.requiredString(object["perspectiveType"]),
              let perspective = OwnerTruthPerspectiveType(rawValue: rawPerspective),
              let rawEpistemic = OwnerTruthFormalMemoryContract.requiredString(object["epistemicStatus"]),
              let epistemicStatus = OwnerTruthEpistemicStatus(rawValue: rawEpistemic),
              let rawSensitivity = OwnerTruthFormalMemoryContract.requiredString(object["sensitivity"]),
              let sensitivity = OwnerTruthSensitivityLevel(rawValue: rawSensitivity),
              let versionObject = object["currentVersion"] as? [String: Any] else {
            throw OwnerTruthFormalMemoryContractError.invalidList("记忆元数据缺失")
        }
        let currentVersion = try OwnerTruthFormalMemoryVersion(backendJSONObject: versionObject)
        guard currentVersion.status == .current else {
            throw OwnerTruthFormalMemoryContractError.invalidList("列表不得返回历史版本")
        }
        self.id = id
        self.memoryKind = memoryKind
        self.perspective = perspective
        self.epistemicStatus = epistemicStatus
        self.sensitivity = sensitivity
        self.currentVersion = currentVersion
    }
}

struct OwnerTruthFormalMemoryPage: Equatable, Sendable {
    static let schemaVersion = "owner-truth-formal-memory-list-v1"

    let vaultID: OwnerTruthVaultID
    let memories: [OwnerTruthFormalMemoryListItem]
    let nextCursor: String?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let rows = object["memories"] as? [[String: Any]] else {
            throw OwnerTruthFormalMemoryContractError.invalidList("schemaVersion、vaultId 或列表无效")
        }
        let memories = try rows.map(OwnerTruthFormalMemoryListItem.init)
        guard Set(memories.map(\.id)).count == memories.count else {
            throw OwnerTruthFormalMemoryContractError.invalidList("列表包含重复记忆")
        }
        if let rawCursor = object["nextCursor"], !(rawCursor is NSNull),
           OwnerTruthFormalMemoryContract.requiredString(rawCursor) == nil {
            throw OwnerTruthFormalMemoryContractError.invalidList("分页游标无效")
        }
        vaultID = expectedVaultID
        self.memories = memories
        nextCursor = OwnerTruthFormalMemoryContract.requiredString(object["nextCursor"])
    }
}

enum OwnerTruthPersonMemoryDimensionKind: String, CaseIterable, Equatable, Sendable {
    case lifeEvent
    case knowledge
    case emotion
    case relationship
    case personality
    case value
    case habit
    case goal
    case identity
    case reflection
}

enum OwnerTruthPersonMemoryDimensionStatus: String, Equatable, Sendable {
    case ready
    case empty
}

struct OwnerTruthPersonMemoryDimension: Equatable, Sendable, Identifiable {
    var id: OwnerTruthPersonMemoryDimensionKind { kind }

    let kind: OwnerTruthPersonMemoryDimensionKind
    let title: String
    let status: OwnerTruthPersonMemoryDimensionStatus
    let narrative: String?
    let supportingMemoryIDs: [OwnerTruthRecordID]
    let supportingMemoryVersionIDs: [OwnerTruthRecordID]

    init(backendJSONObject object: [String: Any]) throws {
        guard let rawKind = OwnerTruthFormalMemoryContract.requiredString(object["dimension"]),
              let kind = OwnerTruthPersonMemoryDimensionKind(rawValue: rawKind),
              let title = OwnerTruthFormalMemoryContract.requiredString(object["title"]),
              let rawStatus = OwnerTruthFormalMemoryContract.requiredString(object["status"]),
              let status = OwnerTruthPersonMemoryDimensionStatus(rawValue: rawStatus),
              let supportingMemoryCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["supportingMemoryCount"]
              ),
              let rawSupportingMemoryIDs = object["supportingMemoryIds"] as? [String],
              let rawSupportingVersionIDs = object["supportingMemoryVersionIds"] as? [String] else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("维度字段缺失或越界")
        }
        let supportingMemoryIDs = rawSupportingMemoryIDs.compactMap {
            OwnerTruthFormalMemoryContract.recordID($0)
        }
        let supportingVersionIDs = rawSupportingVersionIDs.compactMap {
            OwnerTruthFormalMemoryContract.recordID($0)
        }
        guard supportingMemoryIDs.count == rawSupportingMemoryIDs.count,
              Set(supportingMemoryIDs).count == supportingMemoryIDs.count,
              supportingMemoryIDs.count == supportingMemoryCount,
              supportingVersionIDs.count == rawSupportingVersionIDs.count,
              Set(supportingVersionIDs).count == supportingVersionIDs.count,
              supportingVersionIDs.count == supportingMemoryCount else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("维度证据引用无效")
        }
        let narrative = OwnerTruthFormalMemoryContract.requiredString(object["narrative"])
        switch status {
        case .ready:
            guard narrative != nil, !supportingMemoryIDs.isEmpty else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("已归纳维度缺少正文或证据")
            }
        case .empty:
            guard narrative == nil, supportingMemoryIDs.isEmpty else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("空维度不得携带正文或证据")
            }
        }
        self.kind = kind
        self.title = title
        self.status = status
        self.narrative = narrative
        self.supportingMemoryIDs = supportingMemoryIDs
        self.supportingMemoryVersionIDs = supportingVersionIDs
    }
}

enum OwnerTruthPersonMemoryProfileState: String, Equatable, Sendable {
    case ready
    case empty
}

struct OwnerTruthPersonLifeRecord: Equatable, Sendable {
    static let schemaVersion = "owner-truth-person-life-record-v2"
    static let algorithmVersion = "person-life-record-from-biography-v2"

    let state: OwnerTruthPersonMemoryProfileState
    let title: String
    let text: String?
    let paragraphs: [String]

    init(title: String, paragraphs: [String]) {
        self.state = paragraphs.isEmpty ? .empty : .ready
        self.title = title
        self.paragraphs = paragraphs
        self.text = paragraphs.isEmpty ? nil : paragraphs.joined(separator: "\n\n")
    }

    init(backendJSONObject object: [String: Any]) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["algorithmVersion"])
                == Self.algorithmVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["format"]) == "plainText",
              let rawState = OwnerTruthFormalMemoryContract.requiredString(object["state"]),
              let state = OwnerTruthPersonMemoryProfileState(rawValue: rawState),
              let title = OwnerTruthFormalMemoryContract.requiredString(object["title"]),
              let paragraphCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["paragraphCount"]
              ),
              let rawParagraphs = object["paragraphs"] as? [String] else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录字段缺失或越界")
        }
        let paragraphs = rawParagraphs.compactMap(OwnerTruthFormalMemoryContract.requiredString)
        let text = OwnerTruthFormalMemoryContract.requiredString(object["text"])
        guard paragraphs.count == rawParagraphs.count,
              paragraphs.count == paragraphCount else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录段落无效")
        }
        switch state {
        case .ready:
            guard !paragraphs.isEmpty,
                  text == paragraphs.joined(separator: "\n\n") else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录正文不完整")
            }
        case .empty:
            guard paragraphs.isEmpty, text == nil else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("空人生记录不得携带正文")
            }
        }
        self.state = state
        self.title = title
        self.text = text
        self.paragraphs = paragraphs
    }
}

struct OwnerTruthPersonLifeStoryChapter: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let text: String
    let paragraphs: [String]
    let supportingMemoryIDs: [OwnerTruthRecordID]
    let supportingMemoryVersionIDs: [OwnerTruthRecordID]
    let facets: [String]

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthFormalMemoryContract.requiredString(object["chapterId"]),
              let title = OwnerTruthFormalMemoryContract.requiredString(object["title"]),
              OwnerTruthFormalMemoryContract.requiredString(object["format"]) == "plainText",
              let paragraphCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["paragraphCount"]
              ),
              let rawParagraphs = object["paragraphs"] as? [String],
              let text = OwnerTruthFormalMemoryContract.requiredString(object["text"]),
              let supportingMemoryCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["supportingMemoryCount"]
              ),
              let rawMemoryIDs = object["supportingMemoryIds"] as? [String],
              let rawVersionIDs = object["supportingMemoryVersionIds"] as? [String],
              let facets = object["facets"] as? [String] else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生篇章字段缺失或越界")
        }
        let paragraphs = rawParagraphs.compactMap(OwnerTruthFormalMemoryContract.requiredString)
        let memoryIDs = rawMemoryIDs.compactMap(OwnerTruthFormalMemoryContract.recordID)
        let versionIDs = rawVersionIDs.compactMap(OwnerTruthFormalMemoryContract.recordID)
        guard !paragraphs.isEmpty,
              paragraphs.count == rawParagraphs.count,
              paragraphs.count == paragraphCount,
              text == paragraphs.joined(separator: "\n\n"),
              !memoryIDs.isEmpty,
              memoryIDs.count == rawMemoryIDs.count,
              memoryIDs.count == supportingMemoryCount,
              Set(memoryIDs).count == memoryIDs.count,
              versionIDs.count == rawVersionIDs.count,
              versionIDs.count == supportingMemoryCount,
              Set(versionIDs).count == versionIDs.count else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生篇章正文或来源引用无效")
        }
        self.id = id
        self.title = title
        self.text = text
        self.paragraphs = paragraphs
        self.supportingMemoryIDs = memoryIDs
        self.supportingMemoryVersionIDs = versionIDs
        self.facets = facets
    }
}

struct OwnerTruthPersonLifeStory: Equatable, Sendable {
    static let schemaVersion = "owner-truth-biography-projection-v1"
    static let algorithmVersion = "evidence-bound-person-model-v2"

    let state: OwnerTruthPersonMemoryProfileState
    let title: String
    let overview: String?
    let chapters: [OwnerTruthPersonLifeStoryChapter]
    let documentVersion: String?
    let sourceFingerprint: String?
    let isLegacyFallback: Bool

    init(legacyLifeRecord: OwnerTruthPersonLifeRecord) {
        state = legacyLifeRecord.state
        title = legacyLifeRecord.title
        overview = legacyLifeRecord.text
        chapters = []
        documentVersion = nil
        sourceFingerprint = nil
        isLegacyFallback = true
    }

    init(backendJSONObject object: [String: Any]) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["algorithmVersion"])
                == Self.algorithmVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["format"]) == "plainText",
              let rawState = OwnerTruthFormalMemoryContract.requiredString(object["state"]),
              let state = OwnerTruthPersonMemoryProfileState(rawValue: rawState),
              let title = OwnerTruthFormalMemoryContract.requiredString(object["title"]),
              let chapterCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["chapterCount"]
              ),
              let supportingMemoryCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["supportingMemoryCount"]
              ),
              let rawChapters = object["chapters"] as? [[String: Any]] else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录篇章契约无效")
        }
        let overview = OwnerTruthFormalMemoryContract.requiredString(object["overview"])
        let documentVersion = OwnerTruthFormalMemoryContract.sha256(object["documentVersion"])
        let sourceFingerprint = OwnerTruthFormalMemoryContract.sha256(object["sourceFingerprint"])
        let chapters = try rawChapters.map(OwnerTruthPersonLifeStoryChapter.init)
        let memoryIDs = chapters.flatMap(\.supportingMemoryIDs)
        guard chapters.count == chapterCount,
              Set(chapters.map(\.id)).count == chapters.count,
              memoryIDs.count == supportingMemoryCount,
              Set(memoryIDs).count == memoryIDs.count else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录篇章或来源存在重复")
        }
        switch state {
        case .ready:
            guard overview != nil, !chapters.isEmpty, !memoryIDs.isEmpty,
                  documentVersion != nil, sourceFingerprint != nil else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录缺少总览或篇章")
            }
        case .empty:
            guard overview == nil, chapters.isEmpty, memoryIDs.isEmpty,
                  documentVersion != nil, sourceFingerprint != nil else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("空人生记录不得携带篇章")
            }
        }
        self.state = state
        self.title = title
        self.overview = overview
        self.chapters = chapters
        self.documentVersion = documentVersion
        self.sourceFingerprint = sourceFingerprint
        isLegacyFallback = false
    }
}

struct OwnerTruthPersonMemoryModelSummary: Equatable, Sendable {
    static let schemaVersion = "owner-truth-person-memory-model-v1"
    static let algorithmVersion = "evidence-bound-person-model-v2"

    let modelVersion: String
    let sourceFingerprint: String
    let memoryCount: Int
    let consolidatedMemoryCount: Int
    let unresolvedConflictCount: Int
    let cognitiveItemCount: Int
    let entityCount: Int
    let relationCount: Int
    let biographyDocumentVersion: String

    init(backendJSONObject object: [String: Any]) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["algorithmVersion"])
                == Self.algorithmVersion,
              let modelVersion = OwnerTruthFormalMemoryContract.sha256(object["modelVersion"]),
              let sourceFingerprint = OwnerTruthFormalMemoryContract.sha256(
                object["sourceFingerprint"]
              ),
              let memoryCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                  object["memoryCount"]
              ),
              let consolidatedMemoryCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                  object["consolidatedMemoryCount"]
              ),
              let unresolvedConflictCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                  object["unresolvedConflictCount"]
              ),
              let cognitiveItemCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["cognitiveItemCount"]
              ),
              let entityCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["entityCount"]
              ),
              let relationCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["relationCount"]
              ),
              let biographyDocumentVersion = OwnerTruthFormalMemoryContract.sha256(
                object["biographyDocumentVersion"]
              ) else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人物记忆模型摘要无效")
        }
        self.modelVersion = modelVersion
        self.sourceFingerprint = sourceFingerprint
        self.memoryCount = memoryCount
        self.consolidatedMemoryCount = consolidatedMemoryCount
        self.unresolvedConflictCount = unresolvedConflictCount
        self.cognitiveItemCount = cognitiveItemCount
        self.entityCount = entityCount
        self.relationCount = relationCount
        self.biographyDocumentVersion = biographyDocumentVersion
    }
}

struct OwnerTruthPersonMemoryProfile: Equatable, Sendable {
    static let schemaVersion = "owner-truth-person-memory-profile-v2"
    static let algorithmVersion = "evidence-bound-person-model-v2"

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthPersonMemoryProfileState
    let profileVersion: String
    let updatedAt: Date?
    let memoryCount: Int
    let lifeRecord: OwnerTruthPersonLifeRecord
    let lifeStory: OwnerTruthPersonLifeStory
    let dimensions: [OwnerTruthPersonMemoryDimension]
    let memoryModel: OwnerTruthPersonMemoryModelSummary

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["algorithmVersion"])
                == Self.algorithmVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let rawState = OwnerTruthFormalMemoryContract.requiredString(object["state"]),
              let state = OwnerTruthPersonMemoryProfileState(rawValue: rawState),
              let profileVersion = OwnerTruthFormalMemoryContract.sha256(object["profileVersion"]),
              let memoryCount = OwnerTruthFormalMemoryContract.nonNegativeInt(object["memoryCount"]),
              let rawDimensions = object["dimensions"] as? [[String: Any]],
              let rawMemoryModel = object["memoryModel"] as? [String: Any] else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile(
                "schemaVersion、vaultId 或画像字段无效"
            )
        }
        let dimensions = try rawDimensions.map(OwnerTruthPersonMemoryDimension.init)
        let memoryModel = try OwnerTruthPersonMemoryModelSummary(
            backendJSONObject: rawMemoryModel
        )
        guard dimensions.map(\.kind) == OwnerTruthPersonMemoryDimensionKind.allCases else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人物记忆维度缺失、重复或顺序错误")
        }
        let supportingMemoryIDs = Set(dimensions.flatMap(\.supportingMemoryIDs))
        guard supportingMemoryIDs.count == memoryCount,
              (state == .ready) == (memoryCount > 0) else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("画像状态与正式记忆数量不一致")
        }
        let lifeRecord = try Self.parseLifeRecord(
            from: object,
            dimensions: dimensions,
            expectedState: state
        )
        let lifeStory = try Self.parseLifeStory(
            from: object,
            legacyLifeRecord: lifeRecord,
            expectedState: state,
            expectedMemoryCount: memoryCount
        )
        guard memoryModel.modelVersion == profileVersion,
              memoryModel.memoryCount == memoryCount,
              memoryModel.biographyDocumentVersion == lifeStory.documentVersion else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile(
                "人物记忆模型、人生记录与正式记忆版本不一致"
            )
        }
        let updatedAt = try Self.parseUpdatedAt(from: object, expectedState: state)
        vaultID = expectedVaultID
        self.state = state
        self.profileVersion = profileVersion
        self.updatedAt = updatedAt
        self.memoryCount = memoryCount
        self.lifeRecord = lifeRecord
        self.lifeStory = lifeStory
        self.dimensions = dimensions
        self.memoryModel = memoryModel
    }

    private static func parseLifeRecord(
        from object: [String: Any],
        dimensions: [OwnerTruthPersonMemoryDimension],
        expectedState: OwnerTruthPersonMemoryProfileState
    ) throws -> OwnerTruthPersonLifeRecord {
        let lifeRecord: OwnerTruthPersonLifeRecord
        if let lifeRecordObject = object["lifeRecord"] as? [String: Any] {
            lifeRecord = try OwnerTruthPersonLifeRecord(backendJSONObject: lifeRecordObject)
        } else {
            lifeRecord = OwnerTruthPersonLifeRecord(
                title: "我的人生记录",
                paragraphs: dimensions.compactMap(\.narrative)
            )
        }
        guard lifeRecord.state == expectedState else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生记录状态与正式记忆不一致")
        }
        return lifeRecord
    }

    private static func parseLifeStory(
        from object: [String: Any],
        legacyLifeRecord: OwnerTruthPersonLifeRecord,
        expectedState: OwnerTruthPersonMemoryProfileState,
        expectedMemoryCount: Int
    ) throws -> OwnerTruthPersonLifeStory {
        let lifeStory: OwnerTruthPersonLifeStory
        if let lifeStoryObject = object["lifeStory"] as? [String: Any] {
            lifeStory = try OwnerTruthPersonLifeStory(backendJSONObject: lifeStoryObject)
            guard lifeStory.chapters.flatMap(\.supportingMemoryIDs).count == expectedMemoryCount else {
                throw OwnerTruthFormalMemoryContractError.invalidProfile("人生篇章未覆盖全部正式记忆")
            }
        } else {
            lifeStory = OwnerTruthPersonLifeStory(legacyLifeRecord: legacyLifeRecord)
        }
        guard lifeStory.state == expectedState else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("人生篇章状态与正式记忆不一致")
        }
        return lifeStory
    }

    private static func parseUpdatedAt(
        from object: [String: Any],
        expectedState: OwnerTruthPersonMemoryProfileState
    ) throws -> Date? {
        let updatedAt: Date?
        if object["updatedAt"] is NSNull || object["updatedAt"] == nil {
            updatedAt = nil
        } else if let parsed = OwnerTruthFormalMemoryContract.date(object["updatedAt"]) {
            updatedAt = parsed
        } else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("画像更新时间无效")
        }
        guard (expectedState == .empty && updatedAt == nil)
                || (expectedState == .ready && updatedAt != nil) else {
            throw OwnerTruthFormalMemoryContractError.invalidProfile("画像状态与更新时间不一致")
        }
        return updatedAt
    }
}

struct OwnerTruthFormalMemoryDetail: Equatable, Sendable {
    static let schemaVersion = "owner-truth-formal-memory-detail-v1"

    let vaultID: OwnerTruthVaultID
    let memory: OwnerTruthFormalMemoryListItem
    let historyLimit: Int
    let historyTruncated: Bool
    let versions: [OwnerTruthFormalMemoryVersion]

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let memoryObject = object["memory"] as? [String: Any],
              let historyLimit = OwnerTruthFormalMemoryContract.nonNegativeInt(memoryObject["historyLimit"]),
              historyLimit == 3,
              let historyTruncated = memoryObject["historyTruncated"] as? Bool,
              let versionObjects = memoryObject["versions"] as? [[String: Any]],
              !versionObjects.isEmpty,
              versionObjects.count <= historyLimit + 1 else {
            throw OwnerTruthFormalMemoryContractError.invalidDetail("详情历史边界无效")
        }
        let memory = try OwnerTruthFormalMemoryListItem(backendJSONObject: memoryObject)
        let versions = try versionObjects.map(OwnerTruthFormalMemoryVersion.init)
        guard versions == versions.sorted(by: { $0.versionNumber > $1.versionNumber }),
              versions.first == memory.currentVersion,
              versions.filter({ $0.status == .current }).count == 1,
              Set(versions.map(\.id)).count == versions.count else {
            throw OwnerTruthFormalMemoryContractError.invalidDetail("版本顺序或当前指针无效")
        }
        vaultID = expectedVaultID
        self.memory = memory
        self.historyLimit = historyLimit
        self.historyTruncated = historyTruncated
        self.versions = versions
    }
}

struct OwnerTruthFormalMemoryFacetFilter: Equatable, Sendable {
    let name: String
    let value: String

    init(name: String, value: String) throws {
        let allowed = Set([
            "people", "time", "places", "relationships", "emotions", "values",
            "personality", "habits", "goals", "identity", "reflections"
        ])
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard allowed.contains(name), !normalizedValue.isEmpty else {
            throw OwnerTruthFormalMemoryContractError.invalidQuery("线索筛选无效")
        }
        self.name = name
        self.value = normalizedValue
    }
}

struct OwnerTruthFormalMemoryQuery: Equatable, Sendable {
    let kind: OwnerTruthMemoryKind?
    let text: String?
    let facets: [OwnerTruthFormalMemoryFacetFilter]
    let cursor: String?
    let limit: Int

    init(
        kind: OwnerTruthMemoryKind? = nil,
        text: String? = nil,
        facets: [OwnerTruthFormalMemoryFacetFilter] = [],
        cursor: String? = nil,
        limit: Int = 20
    ) throws {
        let normalizedText = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCursor = cursor?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (normalizedText?.count ?? 0) <= 256, (1...100).contains(limit) else {
            throw OwnerTruthFormalMemoryContractError.invalidQuery("关键词或分页大小越界")
        }
        self.kind = kind
        self.text = normalizedText?.isEmpty == false ? normalizedText : nil
        self.facets = facets
        self.cursor = normalizedCursor?.isEmpty == false ? normalizedCursor : nil
        self.limit = limit
    }
}

struct OwnerTruthFormalMemoryRevisionCommand: Equatable, Sendable {
    let commandID: String
    let expectedVersion: Int
    let expectedContentHash: String
    let expectedContentSchemaVersion: String
    let contentSchemaVersion: String
    let correctedContent: [String: OwnerTruthJSONValue]
    let reasonCode: String

    init(
        commandID: String = UUID().uuidString.lowercased(),
        expectedVersion: Int,
        expectedContentHash: String,
        expectedContentSchemaVersion: String,
        contentSchemaVersion: String,
        correctedContent: [String: OwnerTruthJSONValue],
        secondConfirmation: Bool,
        reasonCode: String = "ownerConfirmedFormalMemoryCorrection"
    ) throws {
        guard secondConfirmation,
              !commandID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              expectedVersion > 0,
              OwnerTruthFormalMemoryContract.isSHA256(expectedContentHash),
              !expectedContentSchemaVersion.isEmpty,
              !contentSchemaVersion.isEmpty,
              !correctedContent.isEmpty,
              !reasonCode.isEmpty else {
            throw OwnerTruthFormalMemoryContractError.invalidRevision("必须二次确认且版本字段完整")
        }
        self.commandID = commandID
        self.expectedVersion = expectedVersion
        self.expectedContentHash = expectedContentHash.lowercased()
        self.expectedContentSchemaVersion = expectedContentSchemaVersion
        self.contentSchemaVersion = contentSchemaVersion
        self.correctedContent = correctedContent
        self.reasonCode = reasonCode
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "expectedVersion": expectedVersion,
            "expectedContentHash": expectedContentHash,
            "expectedContentSchemaVersion": expectedContentSchemaVersion,
            "contentSchemaVersion": contentSchemaVersion,
            "correctedContent": correctedContent.mapValues(\.backendJSONObject),
            "secondConfirmation": true,
            "reasonCode": reasonCode,
        ]
    }
}

struct OwnerTruthFormalMemoryRevisionReceipt: Equatable, Sendable {
    let status: String
    let memoryID: OwnerTruthRecordID
    let supersededVersionID: OwnerTruthRecordID
    let replacementVersionID: OwnerTruthRecordID
    let replacementVersion: Int
    let contentHash: String

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedMemoryID: OwnerTruthRecordID
    ) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let revision = object["revision"] as? [String: Any],
              OwnerTruthFormalMemoryContract.requiredString(revision["schemaVersion"])
                == "owner-truth-formal-memory-correction-v1",
              let status = OwnerTruthFormalMemoryContract.requiredString(revision["status"]),
              status == "created" || status == "deduplicated",
              OwnerTruthFormalMemoryContract.recordID(revision["memoryId"]) == expectedMemoryID,
              let supersededVersionID = OwnerTruthFormalMemoryContract.recordID(
                revision["supersededVersionId"]
              ),
              let replacementVersionID = OwnerTruthFormalMemoryContract.recordID(
                revision["replacementVersionId"]
              ),
              let replacementVersion = OwnerTruthFormalMemoryContract.positiveInt(
                revision["replacementVersion"]
              ),
              let contentHash = OwnerTruthFormalMemoryContract.sha256(revision["contentHash"]) else {
            throw OwnerTruthFormalMemoryContractError.invalidRevision("修订回执无效")
        }
        self.status = status
        memoryID = expectedMemoryID
        self.supersededVersionID = supersededVersionID
        self.replacementVersionID = replacementVersionID
        self.replacementVersion = replacementVersion
        self.contentHash = contentHash
    }
}

protocol OwnerTruthFormalMemoryClient: AnyObject {
    func fetchOwnerTruthFormalMemories(
        vaultID: OwnerTruthVaultID,
        query: OwnerTruthFormalMemoryQuery,
        completion: @escaping (Result<OwnerTruthFormalMemoryPage, Error>) -> Void
    )

    func fetchOwnerTruthFormalMemory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthFormalMemoryDetail, Error>) -> Void
    )

    func reviseOwnerTruthFormalMemory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        command: OwnerTruthFormalMemoryRevisionCommand,
        completion: @escaping (Result<OwnerTruthFormalMemoryRevisionReceipt, Error>) -> Void
    )
}

protocol OwnerTruthPersonMemoryProfileClient: AnyObject {
    func fetchOwnerTruthPersonMemoryProfile(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthPersonMemoryProfile, Error>) -> Void
    )
}

enum OwnerTruthSourceRecordContractError: LocalizedError, Equatable, Sendable {
    case invalidList(String)
    case invalidDetail(String)
    case invalidQuery(String)

    var errorDescription: String? {
        switch self {
        case .invalidList(let detail):
            return "内容记录列表合同无效：\(detail)"
        case .invalidDetail(let detail):
            return "内容记录详情合同无效：\(detail)"
        case .invalidQuery(let detail):
            return "内容记录分页条件无效：\(detail)"
        }
    }
}

enum OwnerTruthSourceRecordOrganizationStatus: String, Equatable, Sendable {
    case organizing
    case awaitingReview
    case confirmed
    case reviewed
    case failed
    case noMemoryFound

    var title: String {
        switch self {
        case .organizing: return "整理中"
        case .awaitingReview: return "待确认"
        case .confirmed: return "已写入正式记忆"
        case .reviewed: return "已完成审核"
        case .failed: return "整理失败"
        case .noMemoryFound: return "未整理出记忆"
        }
    }
}

struct OwnerTruthSourceRecord: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let sourceKind: String
    let sourceVersion: Int
    let state: String
    let textPreview: String
    let origin: String?
    let createdAt: Date
    let updatedAt: Date
    let organizationStatus: OwnerTruthSourceRecordOrganizationStatus
    let extractionStatus: String?
    let failureCode: String?
    let candidateCount: Int
    let pendingCount: Int
    let confirmedCount: Int
    let rejectedCount: Int

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthFormalMemoryContract.recordID(object["sourceId"]),
              let sourceKind = OwnerTruthFormalMemoryContract.requiredString(object["sourceKind"]),
              let sourceVersion = OwnerTruthFormalMemoryContract.positiveInt(object["sourceVersion"]),
              let state = OwnerTruthFormalMemoryContract.requiredString(object["state"]),
              let textPreview = object["textPreview"] as? String,
              let createdAt = OwnerTruthFormalMemoryContract.date(object["createdAt"]),
              let updatedAt = OwnerTruthFormalMemoryContract.date(object["updatedAt"]),
              let rawOrganizationStatus = OwnerTruthFormalMemoryContract.requiredString(
                object["organizationStatus"]
              ),
              let organizationStatus = OwnerTruthSourceRecordOrganizationStatus(
                rawValue: rawOrganizationStatus
              ),
              let candidateCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["candidateCount"]
              ),
              let pendingCount = OwnerTruthFormalMemoryContract.nonNegativeInt(object["pendingCount"]),
              let confirmedCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["confirmedCount"]
              ),
              let rejectedCount = OwnerTruthFormalMemoryContract.nonNegativeInt(
                object["rejectedCount"]
              ),
              pendingCount + confirmedCount + rejectedCount <= candidateCount else {
            throw OwnerTruthSourceRecordContractError.invalidList("记录字段缺失或计数越界")
        }
        if let value = object["origin"], !(value is NSNull),
           OwnerTruthFormalMemoryContract.requiredString(value) == nil {
            throw OwnerTruthSourceRecordContractError.invalidList("来源标识无效")
        }
        if let value = object["extractionStatus"], !(value is NSNull),
           OwnerTruthFormalMemoryContract.requiredString(value) == nil {
            throw OwnerTruthSourceRecordContractError.invalidList("整理状态无效")
        }
        if let value = object["failureCode"], !(value is NSNull),
           OwnerTruthFormalMemoryContract.requiredString(value) == nil {
            throw OwnerTruthSourceRecordContractError.invalidList("失败代码无效")
        }
        self.id = id
        self.sourceKind = sourceKind
        self.sourceVersion = sourceVersion
        self.state = state
        self.textPreview = textPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        self.origin = OwnerTruthFormalMemoryContract.requiredString(object["origin"])
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.organizationStatus = organizationStatus
        self.extractionStatus = OwnerTruthFormalMemoryContract.requiredString(object["extractionStatus"])
        self.failureCode = OwnerTruthFormalMemoryContract.requiredString(object["failureCode"])
        self.candidateCount = candidateCount
        self.pendingCount = pendingCount
        self.confirmedCount = confirmedCount
        self.rejectedCount = rejectedCount
    }

    var displayPreview: String {
        textPreview.isEmpty ? "该条记录不包含可显示的文字内容" : textPreview
    }
}

struct OwnerTruthSourceRecordPage: Equatable, Sendable {
    static let schemaVersion = "owner-truth-source-record-list-v1"

    let vaultID: OwnerTruthVaultID
    let records: [OwnerTruthSourceRecord]
    let nextCursor: String?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let rows = object["records"] as? [[String: Any]] else {
            throw OwnerTruthSourceRecordContractError.invalidList("schemaVersion、vaultId 或列表无效")
        }
        let records = try rows.map(OwnerTruthSourceRecord.init)
        guard Set(records.map(\.id)).count == records.count else {
            throw OwnerTruthSourceRecordContractError.invalidList("列表包含重复记录")
        }
        if let rawCursor = object["nextCursor"], !(rawCursor is NSNull),
           OwnerTruthFormalMemoryContract.requiredString(rawCursor) == nil {
            throw OwnerTruthSourceRecordContractError.invalidList("分页游标无效")
        }
        vaultID = expectedVaultID
        self.records = records
        nextCursor = OwnerTruthFormalMemoryContract.requiredString(object["nextCursor"])
    }
}

struct OwnerTruthSourceRecordDetail: Equatable, Sendable {
    static let schemaVersion = "owner-truth-source-record-detail-v1"

    let vaultID: OwnerTruthVaultID
    let record: OwnerTruthSourceRecord
    let text: String

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard OwnerTruthFormalMemoryContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthFormalMemoryContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let recordObject = object["record"] as? [String: Any],
              let text = recordObject["text"] as? String else {
            throw OwnerTruthSourceRecordContractError.invalidDetail("schemaVersion、vaultId 或记录无效")
        }
        vaultID = expectedVaultID
        record = try OwnerTruthSourceRecord(backendJSONObject: recordObject)
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct OwnerTruthSourceRecordQuery: Equatable, Sendable {
    let cursor: String?
    let limit: Int

    init(cursor: String? = nil, limit: Int = 20) throws {
        let normalizedCursor = cursor?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...100).contains(limit) else {
            throw OwnerTruthSourceRecordContractError.invalidQuery("分页大小必须在 1 到 100 之间")
        }
        self.cursor = normalizedCursor?.isEmpty == false ? normalizedCursor : nil
        self.limit = limit
    }
}

protocol OwnerTruthSourceRecordClient: AnyObject {
    func fetchOwnerTruthSourceRecords(
        vaultID: OwnerTruthVaultID,
        query: OwnerTruthSourceRecordQuery,
        completion: @escaping (Result<OwnerTruthSourceRecordPage, Error>) -> Void
    )

    func fetchOwnerTruthSourceRecord(
        vaultID: OwnerTruthVaultID,
        sourceID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthSourceRecordDetail, Error>) -> Void
    )
}

private enum OwnerTruthFormalMemoryContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let raw = requiredString(value), let uuid = UUID(uuidString: raw) else { return nil }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              number.doubleValue.rounded(.towardZero) == number.doubleValue,
              number.doubleValue >= 0,
              number.doubleValue <= Double(Int.max) else {
            return nil
        }
        return number.intValue
    }

    static func positiveInt(_ value: Any?) -> Int? {
        guard let value = nonNegativeInt(value), value > 0 else { return nil }
        return value
    }

    static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit }
    }

    static func sha256(_ value: Any?) -> String? {
        guard let value = requiredString(value)?.lowercased(), isSHA256(value) else { return nil }
        return value
    }

    static func date(_ value: Any?) -> Date? {
        guard let value = requiredString(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}
