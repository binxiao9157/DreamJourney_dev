import Foundation
import CoreFoundation

// MARK: - Lite 知识库数据模型

/// 知识库顶层容器 — 单文件持久化到 kb_graph.json
struct KBLiteGraph: Codable {
    var version: Int = 1
    var lastUpdated: Date = Date()
    var sessionCount: Int = 0        // 已处理的会话数
    var lastBackendExtractionSessionId: Int? = nil
    var lastBackendExtractionAt: Date? = nil
    var people: [KBPerson] = []
    var places: [KBPlace] = []
    var events: [KBEvent] = []
    var facts: [KBFact] = []
}

struct KBSourceReference: Codable, Equatable {
    let kind: String
    let id: String
    let title: String
}

struct KBPrivacyMetadata: Codable {
    let scope: String
    var sourceRefs: [KBSourceReference]
    var widgetVisibility: String? = nil

    static func generationAllowed(kind: String, id: String, title: String) -> KBPrivacyMetadata {
        KBPrivacyMetadata(
            scope: "generationAllowed",
            sourceRefs: [KBSourceReference(kind: kind, id: id, title: title)]
        )
    }

    static func generationAllowed(sourceRefs: [KBSourceReference]) -> KBPrivacyMetadata {
        KBPrivacyMetadata(scope: "generationAllowed", sourceRefs: sourceRefs)
    }

    static func widgetSummaryAllowed(sourceRefs: [KBSourceReference]) -> KBPrivacyMetadata {
        KBPrivacyMetadata(
            scope: "generationAllowed",
            sourceRefs: sourceRefs,
            widgetVisibility: "summaryAllowed"
        )
    }
}

enum KBKnowledgeSourceAuditRecommendedAction: String, Equatable {
    case none
    case planLegacySourceRefMigration
    case reviewUnknownSourceRefs
}

struct KBKnowledgeSourceAuditCounts: Equatable {
    let total: Int
    let canonical: Int
    let legacy: Int
    let unknown: Int

    var recommendedAction: KBKnowledgeSourceAuditRecommendedAction {
        if unknown > 0 { return .reviewUnknownSourceRefs }
        if legacy > 0 { return .planLegacySourceRefMigration }
        return .none
    }
}

struct KBKnowledgeSourceRefEntityAuditCounts: Equatable {
    let total: Int
    let withSourceRefs: Int
    let withCanonicalRefs: Int
    let withLegacyRefs: Int
    let withUnknownRefs: Int
}

struct KBKnowledgeSourceRefAuditResponse: Equatable {
    let schemaVersion: Int
    let userId: String
    let revision: Int
    let entityCounts: KBKnowledgeSourceRefEntityAuditCounts
    let sourceRefCounts: KBKnowledgeSourceAuditCounts
    let recommendedAction: KBKnowledgeSourceAuditRecommendedAction

    init?(json: [String: Any], expectedUserId: String) {
        guard let schemaVersion = Self.intValue(json["schemaVersion"]),
              schemaVersion == 1,
              let userId = json["userId"] as? String,
              userId == expectedUserId,
              let revision = Self.intValue(json["revision"]),
              revision >= 0,
              let counts = json["counts"] as? [String: Any],
              let entities = counts["entities"] as? [String: Any],
              let sourceRefs = counts["sourceRefs"] as? [String: Any],
              let totalEntities = Self.nonNegativeInt(entities["total"]),
              let withSourceRefs = Self.nonNegativeInt(entities["withSourceRefs"]),
              let withCanonicalRefs = Self.nonNegativeInt(entities["withCanonicalRefs"]),
              let withLegacyRefs = Self.nonNegativeInt(entities["withLegacyRefs"]),
              let withUnknownRefs = Self.nonNegativeInt(entities["withUnknownRefs"]),
              withSourceRefs <= totalEntities,
              withCanonicalRefs <= withSourceRefs,
              withLegacyRefs <= withSourceRefs,
              withUnknownRefs <= withSourceRefs,
              let totalRefs = Self.nonNegativeInt(sourceRefs["total"]),
              let canonicalRefs = Self.nonNegativeInt(sourceRefs["canonical"]),
              let legacyRefs = Self.nonNegativeInt(sourceRefs["legacy"]),
              let unknownRefs = Self.nonNegativeInt(sourceRefs["unknown"]),
              totalRefs == canonicalRefs + legacyRefs + unknownRefs,
              let actionRaw = json["recommendedAction"] as? String,
              let recommendedAction = KBKnowledgeSourceAuditRecommendedAction(rawValue: actionRaw) else {
            return nil
        }

        let sourceRefCounts = KBKnowledgeSourceAuditCounts(
            total: totalRefs,
            canonical: canonicalRefs,
            legacy: legacyRefs,
            unknown: unknownRefs
        )
        guard sourceRefCounts.recommendedAction == recommendedAction else { return nil }

        self.schemaVersion = schemaVersion
        self.userId = userId
        self.revision = revision
        self.entityCounts = KBKnowledgeSourceRefEntityAuditCounts(
            total: totalEntities,
            withSourceRefs: withSourceRefs,
            withCanonicalRefs: withCanonicalRefs,
            withLegacyRefs: withLegacyRefs,
            withUnknownRefs: withUnknownRefs
        )
        self.sourceRefCounts = sourceRefCounts
        self.recommendedAction = recommendedAction
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let value = intValue(value), value >= 0 else { return nil }
        return value
    }
}

enum KBKnowledgeSourceIdentityPolicy {
    static let sourceContractVersion = 1

    private static let canonicalKinds = Set([
        "conversationTurn",
        "conversationPhoto",
        "memoryArchiveItem",
        "timeMailboxLetter",
        "kbLiteEntity",
        "memoir",
        "importRecord",
        "userAuthorization",
    ])
    private static let legacyKinds = Set([
        "conversationSession",
        "archiveImageAnalysis",
    ])
    private static let photoAssetCharacters = CharacterSet.alphanumerics.union(
        CharacterSet(charactersIn: "-_.")
    )

    static func conversationTurnReferences(
        sessionId: Int,
        turnIndices: [Int]
    ) -> [KBSourceReference] {
        guard sessionId >= 0 else { return [] }
        var seen = Set<Int>()
        return turnIndices.compactMap { turnIndex in
            guard turnIndex >= 0, seen.insert(turnIndex).inserted else { return nil }
            return KBSourceReference(
                kind: "conversationTurn",
                id: "session-\(sessionId):turn-\(turnIndex)",
                title: title(for: "conversationTurn")
            )
        }
    }

    static func conversationPhotoReference(assetId: String) -> KBSourceReference? {
        let normalized = assetId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty,
              normalized.count <= 128,
              normalized.rangeOfCharacter(from: photoAssetCharacters.inverted) == nil else {
            return nil
        }
        return KBSourceReference(
            kind: "conversationPhoto",
            id: "photo-\(normalized)",
            title: title(for: "conversationPhoto")
        )
    }

    static func audit(sourceReferences: [KBSourceReference]) -> KBKnowledgeSourceAuditCounts {
        var canonical = 0
        var legacy = 0
        var unknown = 0
        for reference in sourceReferences {
            if canonicalKinds.contains(reference.kind) {
                canonical += 1
            } else if legacyKinds.contains(reference.kind) {
                legacy += 1
            } else {
                unknown += 1
            }
        }
        return KBKnowledgeSourceAuditCounts(
            total: sourceReferences.count,
            canonical: canonical,
            legacy: legacy,
            unknown: unknown
        )
    }

    static func title(for kind: String) -> String {
        switch kind {
        case "conversationTurn": return "对话来源"
        case "conversationPhoto": return "对话照片"
        case "memoryArchiveItem": return "档案素材"
        case "conversationSession": return "旧版对话会话来源"
        case "archiveImageAnalysis": return "旧版档案图像分析"
        case "timeMailboxLetter": return "时空信件"
        case "kbLiteEntity": return "知识条目"
        case "memoir": return "回忆录"
        case "importRecord": return "导入记录"
        case "userAuthorization": return "授权记录"
        default: return "来源记录"
        }
    }
}

// MARK: - Knowledge governance

enum KBKnowledgeEntityType: String, Codable, CaseIterable {
    case people
    case places
    case events
    case facts
}

struct KBKnowledgeEntityLink: Codable, Equatable {
    let entityType: KBKnowledgeEntityType
    let entityId: String
}

struct KBKnowledgeSourceIdentity: Codable, Equatable {
    let kind: String
    let id: String
}

enum KBKnowledgeGovernanceActionKind: String, Codable {
    case confirm
    case reject
    case correct
    case deleteSource
}

struct KBKnowledgeGovernanceMetadata: Codable, Equatable {
    let action: KBKnowledgeGovernanceActionKind
    let operationId: String
    let decidedAt: Date
    let target: KBKnowledgeEntityLink
    let replacement: KBKnowledgeEntityLink?
    let sourceRef: KBKnowledgeSourceIdentity?

    private enum CodingKeys: String, CodingKey {
        case action
        case operationId
        case decidedAt
        case target
        case replacement
        case sourceRef
    }

    init(
        action: KBKnowledgeGovernanceActionKind,
        operationId: String,
        decidedAt: Date,
        target: KBKnowledgeEntityLink,
        replacement: KBKnowledgeEntityLink? = nil,
        sourceRef: KBKnowledgeSourceIdentity? = nil
    ) {
        self.action = action
        self.operationId = operationId
        self.decidedAt = decidedAt
        self.target = target
        self.replacement = replacement
        self.sourceRef = sourceRef
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(KBKnowledgeGovernanceActionKind.self, forKey: .action)
        operationId = try container.decode(String.self, forKey: .operationId)
        decidedAt = try KBKnowledgeGovernanceDateCoding.decode(from: container, forKey: .decidedAt)
        target = try container.decode(KBKnowledgeEntityLink.self, forKey: .target)
        replacement = try container.decodeIfPresent(KBKnowledgeEntityLink.self, forKey: .replacement)
        sourceRef = try container.decodeIfPresent(KBKnowledgeSourceIdentity.self, forKey: .sourceRef)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(operationId, forKey: .operationId)
        try KBKnowledgeGovernanceDateCoding.encode(decidedAt, to: &container, forKey: .decidedAt)
        try container.encode(target, forKey: .target)
        try container.encodeIfPresent(replacement, forKey: .replacement)
        try container.encodeIfPresent(sourceRef, forKey: .sourceRef)
    }
}

struct KBPersonGovernanceCorrection: Codable, Equatable {
    var name: String? = nil
    var aliases: [String]? = nil
    var relation: String? = nil
    var traits: [String]? = nil
    var briefBio: String? = nil
    var relatedPersonIds: [String]? = nil

    fileprivate var hasChanges: Bool {
        name != nil || aliases != nil || relation != nil || traits != nil || briefBio != nil || relatedPersonIds != nil
    }
}

struct KBPlaceGovernanceCorrection: Codable, Equatable {
    var name: String? = nil
    var category: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var description: String? = nil
    var relatedPersonIds: [String]? = nil

    fileprivate var hasChanges: Bool {
        name != nil || category != nil || latitude != nil || longitude != nil || description != nil || relatedPersonIds != nil
    }
}

struct KBEventGovernanceCorrection: Codable, Equatable {
    var title: String? = nil
    var description: String? = nil
    var year: Int? = nil
    var month: Int? = nil
    var locationId: String? = nil
    var participantIds: [String]? = nil
    var mediaIds: [String]? = nil
    var memoirId: String? = nil

    fileprivate var hasChanges: Bool {
        title != nil || description != nil || year != nil || month != nil || locationId != nil ||
            participantIds != nil || mediaIds != nil || memoirId != nil
    }
}

struct KBFactGovernanceCorrection: Codable, Equatable {
    var statement: String? = nil
    var relatedPersonIds: [String]? = nil
    var relatedPlaceIds: [String]? = nil
    var relatedEventIds: [String]? = nil

    fileprivate var hasChanges: Bool {
        statement != nil || relatedPersonIds != nil || relatedPlaceIds != nil || relatedEventIds != nil
    }
}

enum KBKnowledgeGovernanceCorrection: Equatable {
    case person(KBPersonGovernanceCorrection)
    case place(KBPlaceGovernanceCorrection)
    case event(KBEventGovernanceCorrection)
    case fact(KBFactGovernanceCorrection)

    var entityType: KBKnowledgeEntityType {
        switch self {
        case .person: return .people
        case .place: return .places
        case .event: return .events
        case .fact: return .facts
        }
    }

    fileprivate var hasChanges: Bool {
        switch self {
        case .person(let correction): return correction.hasChanges
        case .place(let correction): return correction.hasChanges
        case .event(let correction): return correction.hasChanges
        case .fact(let correction): return correction.hasChanges
        }
    }
}

enum KBKnowledgeGovernanceAction: Codable, Equatable {
    case confirm(target: KBKnowledgeEntityLink, decidedAt: Date)
    case reject(target: KBKnowledgeEntityLink, decidedAt: Date)
    case correct(target: KBKnowledgeEntityLink, correction: KBKnowledgeGovernanceCorrection, decidedAt: Date)
    case deleteSource(sourceRef: KBKnowledgeSourceIdentity, decidedAt: Date)

    private enum CodingKeys: String, CodingKey {
        case kind
        case entityType
        case entityId
        case correction
        case sourceRef
        case decidedAt
    }

    var kind: KBKnowledgeGovernanceActionKind {
        switch self {
        case .confirm: return .confirm
        case .reject: return .reject
        case .correct: return .correct
        case .deleteSource: return .deleteSource
        }
    }

    func backendJSONObject() throws -> [String: Any] {
        try validateForBackend()
        let data = try JSONEncoder().encode(self)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw KBKnowledgeGovernanceModelError.invalidAction("action must encode as a JSON object")
        }
        return object
    }

    private func validateForBackend() throws {
        switch self {
        case .confirm(let target, _), .reject(let target, _):
            try Self.validate(target: target)
        case .correct(let target, let correction, _):
            try Self.validate(target: target)
            guard target.entityType == correction.entityType, correction.hasChanges else {
                throw KBKnowledgeGovernanceModelError.invalidAction(
                    "correction must be non-empty and match entityType"
                )
            }
        case .deleteSource(let sourceRef, _):
            guard !sourceRef.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !sourceRef.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw KBKnowledgeGovernanceModelError.invalidAction(
                    "sourceRef kind and id are required"
                )
            }
        }
    }

    private static func validate(target: KBKnowledgeEntityLink) throws {
        guard !target.entityId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw KBKnowledgeGovernanceModelError.invalidAction("entityId is required")
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(KBKnowledgeGovernanceActionKind.self, forKey: .kind)
        let decidedAt = try KBKnowledgeGovernanceDateCoding.decode(from: container, forKey: .decidedAt)

        switch kind {
        case .deleteSource:
            guard !container.contains(.entityType),
                  !container.contains(.entityId),
                  !container.contains(.correction) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sourceRef,
                    in: container,
                    debugDescription: "deleteSource cannot contain an entity target or correction"
                )
            }
            let sourceRef = try container.decode(KBKnowledgeSourceIdentity.self, forKey: .sourceRef)
            self = .deleteSource(sourceRef: sourceRef, decidedAt: decidedAt)
        case .confirm, .reject, .correct:
            guard !container.contains(.sourceRef) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sourceRef,
                    in: container,
                    debugDescription: "entity governance actions cannot contain sourceRef"
                )
            }
            let entityType = try container.decode(KBKnowledgeEntityType.self, forKey: .entityType)
            let entityId = try container.decode(String.self, forKey: .entityId)
            let target = KBKnowledgeEntityLink(entityType: entityType, entityId: entityId)
            if kind == .confirm || kind == .reject {
                guard !container.contains(.correction) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .correction,
                        in: container,
                        debugDescription: "only correct can contain correction"
                    )
                }
                self = kind == .confirm
                    ? .confirm(target: target, decidedAt: decidedAt)
                    : .reject(target: target, decidedAt: decidedAt)
                return
            }

            let correction = try Self.decodeCorrection(entityType: entityType, from: container)
            guard correction.hasChanges else {
                throw DecodingError.dataCorruptedError(
                    forKey: .correction,
                    in: container,
                    debugDescription: "correction must contain at least one supported field"
                )
            }
            self = .correct(target: target, correction: correction, decidedAt: decidedAt)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)

        switch self {
        case .confirm(let target, let decidedAt), .reject(let target, let decidedAt):
            try container.encode(target.entityType, forKey: .entityType)
            try container.encode(target.entityId, forKey: .entityId)
            try KBKnowledgeGovernanceDateCoding.encode(decidedAt, to: &container, forKey: .decidedAt)
        case .correct(let target, let correction, let decidedAt):
            guard target.entityType == correction.entityType else {
                throw EncodingError.invalidValue(
                    correction,
                    EncodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.correction],
                        debugDescription: "correction type must match entityType"
                    )
                )
            }
            guard correction.hasChanges else {
                throw EncodingError.invalidValue(
                    correction,
                    EncodingError.Context(
                        codingPath: container.codingPath + [CodingKeys.correction],
                        debugDescription: "correction must contain at least one supported field"
                    )
                )
            }
            try container.encode(target.entityType, forKey: .entityType)
            try container.encode(target.entityId, forKey: .entityId)
            try Self.encodeCorrection(correction, to: &container)
            try KBKnowledgeGovernanceDateCoding.encode(decidedAt, to: &container, forKey: .decidedAt)
        case .deleteSource(let sourceRef, let decidedAt):
            try container.encode(sourceRef, forKey: .sourceRef)
            try KBKnowledgeGovernanceDateCoding.encode(decidedAt, to: &container, forKey: .decidedAt)
        }
    }

    private static func decodeCorrection(
        entityType: KBKnowledgeEntityType,
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> KBKnowledgeGovernanceCorrection {
        let correctionContainer = try container.nestedContainer(
            keyedBy: KBKnowledgeGovernanceDynamicCodingKey.self,
            forKey: .correction
        )
        let presentFields = Set(correctionContainer.allKeys.map(\.stringValue))
        let allowedFields: Set<String>
        switch entityType {
        case .people:
            allowedFields = ["name", "aliases", "relation", "traits", "briefBio", "relatedPersonIds"]
        case .places:
            allowedFields = ["name", "category", "latitude", "longitude", "description", "relatedPersonIds"]
        case .events:
            allowedFields = [
                "title", "description", "year", "month", "locationId", "participantIds", "mediaIds", "memoirId",
            ]
        case .facts:
            allowedFields = ["statement", "relatedPersonIds", "relatedPlaceIds", "relatedEventIds"]
        }
        guard !presentFields.isEmpty, presentFields.isSubset(of: allowedFields) else {
            throw DecodingError.dataCorruptedError(
                forKey: .correction,
                in: container,
                debugDescription: "correction contains no fields or an unsupported field"
            )
        }

        switch entityType {
        case .people:
            return .person(try container.decode(KBPersonGovernanceCorrection.self, forKey: .correction))
        case .places:
            return .place(try container.decode(KBPlaceGovernanceCorrection.self, forKey: .correction))
        case .events:
            return .event(try container.decode(KBEventGovernanceCorrection.self, forKey: .correction))
        case .facts:
            return .fact(try container.decode(KBFactGovernanceCorrection.self, forKey: .correction))
        }
    }

    private static func encodeCorrection(
        _ correction: KBKnowledgeGovernanceCorrection,
        to container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        switch correction {
        case .person(let value): try container.encode(value, forKey: .correction)
        case .place(let value): try container.encode(value, forKey: .correction)
        case .event(let value): try container.encode(value, forKey: .correction)
        case .fact(let value): try container.encode(value, forKey: .correction)
        }
    }
}

struct KBKnowledgeGovernanceSummary: Codable, Equatable {
    let action: KBKnowledgeGovernanceActionKind
    let decidedAt: Date
    let affectedEntityCount: Int
    let target: KBKnowledgeEntityLink?
    let replacement: KBKnowledgeEntityLink?
    let sourceRef: KBKnowledgeSourceIdentity?
    let targets: [KBKnowledgeEntityLink]?

    private enum CodingKeys: String, CodingKey {
        case action
        case decidedAt
        case affectedEntityCount
        case target
        case replacement
        case sourceRef
        case targets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(KBKnowledgeGovernanceActionKind.self, forKey: .action)
        decidedAt = try KBKnowledgeGovernanceDateCoding.decode(from: container, forKey: .decidedAt)
        affectedEntityCount = try container.decode(Int.self, forKey: .affectedEntityCount)
        target = try container.decodeIfPresent(KBKnowledgeEntityLink.self, forKey: .target)
        replacement = try container.decodeIfPresent(KBKnowledgeEntityLink.self, forKey: .replacement)
        sourceRef = try container.decodeIfPresent(KBKnowledgeSourceIdentity.self, forKey: .sourceRef)
        targets = try container.decodeIfPresent([KBKnowledgeEntityLink].self, forKey: .targets)

        guard affectedEntityCount > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .affectedEntityCount,
                in: container,
                debugDescription: "affectedEntityCount must be positive"
            )
        }
        switch action {
        case .deleteSource:
            guard sourceRef != nil,
                  let targets,
                  !targets.isEmpty,
                  affectedEntityCount == targets.count,
                  target == nil,
                  replacement == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .sourceRef,
                    in: container,
                    debugDescription: "deleteSource summary requires sourceRef and targets"
                )
            }
        case .correct:
            guard affectedEntityCount == 2,
                  target != nil,
                  replacement != nil,
                  sourceRef == nil,
                  targets == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .replacement,
                    in: container,
                    debugDescription: "correct summary requires target and replacement"
                )
            }
        case .confirm, .reject:
            guard affectedEntityCount == 1,
                  target != nil,
                  replacement == nil,
                  sourceRef == nil,
                  targets == nil else {
                throw DecodingError.dataCorruptedError(
                    forKey: .target,
                    in: container,
                    debugDescription: "entity summary requires only a target"
                )
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try KBKnowledgeGovernanceDateCoding.encode(decidedAt, to: &container, forKey: .decidedAt)
        try container.encode(affectedEntityCount, forKey: .affectedEntityCount)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encodeIfPresent(replacement, forKey: .replacement)
        try container.encodeIfPresent(sourceRef, forKey: .sourceRef)
        try container.encodeIfPresent(targets, forKey: .targets)
    }
}

struct KBKnowledgeGovernanceResponse {
    let governanceSchemaVersion: Int
    let mutationSchemaVersion: Int
    let userId: String
    let operationId: String
    let revision: Int
    let duplicate: Bool
    let summary: KBKnowledgeGovernanceSummary
    let graph: [String: Any]

    init(json: [String: Any]) throws {
        guard let governanceSchemaVersion = Self.strictInt(json["governanceSchemaVersion"]),
              governanceSchemaVersion == 1 else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("governanceSchemaVersion must be 1")
        }
        guard let mutationSchemaVersion = Self.strictInt(json["mutationSchemaVersion"]),
              mutationSchemaVersion == 2 else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("mutationSchemaVersion must be 2")
        }
        guard let userId = json["userId"] as? String, !userId.isEmpty else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("userId is required")
        }
        guard let operationId = json["operationId"] as? String, !operationId.isEmpty else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("operationId is required")
        }
        guard let revision = Self.strictInt(json["revision"]), revision >= 0 else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("revision must be a non-negative integer")
        }
        guard let duplicate = Self.strictBool(json["duplicate"]) else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("duplicate must be a boolean")
        }
        guard let graph = json["graph"] as? [String: Any], JSONSerialization.isValidJSONObject(graph) else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("graph must be a JSON object")
        }
        guard let summaryObject = json["summary"] as? [String: Any],
              JSONSerialization.isValidJSONObject(summaryObject) else {
            throw KBKnowledgeGovernanceModelError.invalidResponse("summary must be a JSON object")
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: summaryObject)
            summary = try JSONDecoder().decode(KBKnowledgeGovernanceSummary.self, from: data)
        } catch {
            throw KBKnowledgeGovernanceModelError.invalidResponse("summary is invalid")
        }

        self.governanceSchemaVersion = governanceSchemaVersion
        self.mutationSchemaVersion = mutationSchemaVersion
        self.userId = userId
        self.operationId = operationId
        self.revision = revision
        self.duplicate = duplicate
        self.graph = graph
    }

    private static func strictInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              ["c", "C", "s", "S", "i", "I", "l", "L", "q", "Q"].contains(String(cString: number.objCType)) else {
            return nil
        }
        return number.intValue
    }

    private static func strictBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return nil
        }
        return number.boolValue
    }
}

enum KBKnowledgeGovernanceModelError: LocalizedError {
    case invalidAction(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidAction(let detail): return "Invalid knowledge governance action: \(detail)"
        case .invalidResponse(let detail): return "Invalid knowledge governance response: \(detail)"
        }
    }
}

private enum KBKnowledgeGovernanceDateCoding {
    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date {
        let value = try container.decode(String.self, forKey: key)
        guard let date = date(from: value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Expected an ISO-8601 timestamp"
            )
        }
        return date
    }

    static func encode<Key: CodingKey>(
        _ date: Date,
        to container: inout KeyedEncodingContainer<Key>,
        forKey key: Key
    ) throws {
        try container.encode(string(from: date), forKey: key)
    }

    private static func date(from value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

private struct KBKnowledgeGovernanceDynamicCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
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
    var privacyMetadata: KBPrivacyMetadata? = nil
    var ownerUserId: String? = nil
    var personaScope: String? = nil
    var digitalHumanId: String? = nil
    var evidenceStatus: String? = nil
    var sourceTurnIndices: [Int]? = nil
    var governanceMetadata: KBKnowledgeGovernanceMetadata? = nil

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
    var privacyMetadata: KBPrivacyMetadata? = nil
    var ownerUserId: String? = nil
    var personaScope: String? = nil
    var digitalHumanId: String? = nil
    var evidenceStatus: String? = nil
    var sourceTurnIndices: [Int]? = nil
    var governanceMetadata: KBKnowledgeGovernanceMetadata? = nil

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
    var privacyMetadata: KBPrivacyMetadata? = nil
    var ownerUserId: String? = nil
    var personaScope: String? = nil
    var digitalHumanId: String? = nil
    var evidenceStatus: String? = nil
    var sourceTurnIndices: [Int]? = nil
    var governanceMetadata: KBKnowledgeGovernanceMetadata? = nil

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
    var privacyMetadata: KBPrivacyMetadata? = nil
    var ownerUserId: String? = nil
    var personaScope: String? = nil
    var digitalHumanId: String? = nil
    var evidenceStatus: String? = nil
    var sourceTurnIndices: [Int]? = nil
    var governanceMetadata: KBKnowledgeGovernanceMetadata? = nil
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

// MARK: - Backend knowledge mutation proposal

struct KBKnowledgeMutationProposal: Codable {
    let proposalSchemaVersion: Int
    let mutationSchemaVersion: Int
    let baseRevision: Int
    let ownerUserId: String
    let personaScope: String
    let digitalHumanId: String
    let upserts: KBKnowledgeProposalUpserts
    let tombstones: [KBKnowledgeProposalTombstone]
    let proposalPolicy: KBKnowledgeProposalPolicy
}

struct KBKnowledgeProposalUpserts: Codable {
    let people: [KBKnowledgeProposalPerson]
    let places: [KBKnowledgeProposalPlace]
    let events: [KBKnowledgeProposalEvent]
    let facts: [KBKnowledgeProposalFact]
}

struct KBKnowledgeProposalPerson: Codable, Identifiable {
    let id: String
    let name: String
    let aliases: [String]
    let relation: String?
    let traits: [String]
    let briefBio: String?
    let relatedPersonIds: [String]
    let sourceSessionIds: [Int]
    let sourceTurnIndices: [Int]
    let privacyMetadata: KBPrivacyMetadata
    let ownerUserId: String
    let personaScope: String
    let digitalHumanId: String
    let evidenceStatus: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct KBKnowledgeProposalPlace: Codable, Identifiable {
    let id: String
    let name: String
    let category: String?
    let latitude: Double?
    let longitude: Double?
    let description: String?
    let relatedPersonIds: [String]
    let sourceSessionIds: [Int]
    let sourceTurnIndices: [Int]
    let privacyMetadata: KBPrivacyMetadata
    let ownerUserId: String
    let personaScope: String
    let digitalHumanId: String
    let evidenceStatus: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct KBKnowledgeProposalEvent: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let year: Int?
    let month: Int?
    let locationId: String?
    let participantIds: [String]
    let mediaIds: [String]
    let memoirId: String?
    let sourceSessionIds: [Int]
    let sourceTurnIndices: [Int]
    let privacyMetadata: KBPrivacyMetadata
    let ownerUserId: String
    let personaScope: String
    let digitalHumanId: String
    let evidenceStatus: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct KBKnowledgeProposalFact: Codable, Identifiable {
    let id: String
    let statement: String
    let confidence: String
    let relatedPersonIds: [String]
    let relatedPlaceIds: [String]
    let relatedEventIds: [String]
    let sourceSessionIds: [Int]
    let sourceTurnIndices: [Int]
    let privacyMetadata: KBPrivacyMetadata
    let ownerUserId: String
    let personaScope: String
    let digitalHumanId: String
    let evidenceStatus: String
    let createdAt: Date?
    let updatedAt: Date?
}

struct KBKnowledgeProposalTombstone: Codable {
    let entityType: String
    let entityId: String
    let deletedAt: Date
}

struct KBKnowledgeProposalPolicy: Codable {
    let version: Int
    let snapshotEntityCount: Int
    let eligibleSnapshotEntityCount: Int
    let upsertEntityCount: Int
    let upsertCounts: KBKnowledgeProposalEntityCounts
    let reusedEntityCount: Int
    let generatedEntityCount: Int
    let duplicateEntityCount: Int
    let skippedEntityCount: Int
    let resolvedRelationCount: Int
    let unresolvedRelationCount: Int
}

struct KBKnowledgeProposalEntityCounts: Codable {
    let people: Int
    let places: Int
    let events: Int
    let facts: Int
}

struct KBKnowledgeExtractionEnvelope: Codable {
    let extraction: KBExtractionResult
    let proposal: KBKnowledgeMutationProposal?

    private enum CodingKeys: String, CodingKey {
        case extraction
        case proposal = "mutationProposal"
    }

    init(extraction: KBExtractionResult, proposal: KBKnowledgeMutationProposal?) {
        self.extraction = extraction
        self.proposal = proposal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extraction = try container.decode(KBExtractionResult.self, forKey: .extraction)
        proposal = container.contains(.proposal)
            ? try container.decode(KBKnowledgeMutationProposal.self, forKey: .proposal)
            : nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(extraction, forKey: .extraction)
        if let proposal {
            try container.encode(proposal, forKey: .proposal)
        }
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

// MARK: - Notifications

extension Notification.Name {
    static let kbLiteDidUpdate = Notification.Name("com.dreamjourney.kblite.didUpdate")
}
