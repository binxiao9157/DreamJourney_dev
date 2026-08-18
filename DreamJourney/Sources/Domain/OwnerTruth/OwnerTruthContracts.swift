import CryptoKit
import Foundation

// Owner Truth V1 remains a pure domain boundary until the gated CreateSource
// facade is introduced. Legacy Archive and KBLite models are not authority.

struct OwnerTruthVaultID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init?(_ rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        self.rawValue = normalized
    }

    init?(rawValue: String) {
        self.init(rawValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let value = Self(try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Owner Truth vault ID must be non-empty"
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct OwnerTruthRecordID: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UUID.self)
        self.init(rawValue: rawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum OwnerTruthSourceKind: String, CaseIterable, Codable, Sendable {
    case text
    case archiveItem
    case conversation
    case `import`
}

enum OwnerTruthSourceState: String, CaseIterable, Codable, Sendable {
    case active
    case redacted
    case deleted
}

enum OwnerTruthMemoryKind: String, CaseIterable, Codable, Sendable {
    case experience
    case knowledge
    case emotion
}

enum OwnerTruthPerspectiveType: String, CaseIterable, Codable, Sendable {
    case firstPerson
    case reported
    case inferred
}

enum OwnerTruthEpistemicStatus: String, CaseIterable, Codable, Sendable {
    case observed
    case recalled
    case reported
    case inferred
    case uncertain
}

enum OwnerTruthSensitivityLevel: String, CaseIterable, Codable, Sendable {
    case standard
    case sensitive
    case restricted
}

enum OwnerTruthCandidateDecision: String, CaseIterable, Codable, Sendable {
    case pending
    case accepted
    case rejected
    case corrected
    case invalidated

    var isTerminal: Bool {
        self != .pending
    }
}

/// The command action accepted by the QA-only review API. It intentionally
/// differs from the persisted terminal decision names returned by the API.
enum OwnerTruthCandidateReviewAction: String, CaseIterable, Codable, Sendable {
    case accept
    case correct
    case reject

    var terminalDecision: OwnerTruthCandidateDecision {
        switch self {
        case .accept:
            return .accepted
        case .correct:
            return .corrected
        case .reject:
            return .rejected
        }
    }
}

enum OwnerTruthContractError: Error, Equatable, Sendable {
    case terminalDecisionImmutable
}

enum OwnerTruthRemoteContractError: LocalizedError, Equatable, Sendable {
    case invalidInbox(String)
    case invalidDecision(String)
    case invalidCommand(String)
    case invalidTextSourceCapture(String)
    case invalidMediaCapture(String)
    case invalidInterviewCandidateReview(String)
    case invalidInterviewCandidateConfirmationInbox(String)
    case invalidInterviewCandidateMemoryActivationInbox(String)
    case invalidInterviewCandidateMemoryProjectionRecoveryInbox(String)
    case invalidInterviewCandidateConfirmation(String)
    case invalidInterviewCandidateProposalStatus(String)
    case invalidInterviewCandidateProposalAdmission(String)
    case invalidInterviewCandidateDecision(String)
    case invalidInterviewSessionState(String)
    case invalidInterviewOrchestration(String)
    case invalidInterviewNaturalInput(String)
    case invalidInterviewPendingReviewBatchInbox(String)
    case invalidInterviewReviewBatchAcknowledgement(String)
    case invalidKnowledgeDimensionConfirmation(String)
    case invalidKnowledgeRecommendationPlan(String)
    case invalidGuidedRecommendationPresentation(String)
    case invalidGuidedRecommendationFeedback(String)
    case invalidGuidedRecommendationActivation(String)
    case invalidLifeMapPresentation(String)
    case invalidMemorySearchPresentation(String)
    case invalidInterviewOutcomePresentation(String)
    case invalidKBLiteCompatibilityReadEnvelope(String)
    case invalidContextCitationShadowBuild(String)
    case invalidContextCitationShadowCompare(String)
    case invalidAnswerCitationReceipt(String)
    case invalidCorrectionRequestCommand(String)
    case invalidCorrectionRequestReceipt(String)
    case invalidCorrectionResolutionCommand(String)
    case invalidCorrectionResolutionReceipt(String)

    var errorDescription: String? {
        switch self {
        case .invalidInbox(let detail):
            return "候选收件箱合同无效：\(detail)"
        case .invalidDecision(let detail):
            return "候选审核回执合同无效：\(detail)"
        case .invalidCommand(let detail):
            return "候选审核命令无效：\(detail)"
        case .invalidTextSourceCapture(let detail):
            return "文字记忆采集合同无效：\(detail)"
        case .invalidMediaCapture(let detail):
            return "媒体记忆采集合同无效：\(detail)"
        case .invalidInterviewCandidateReview(let detail):
            return "访谈候选审核合同无效：\(detail)"
        case .invalidInterviewCandidateConfirmationInbox(let detail):
            return "访谈候选确认待办合同无效：\(detail)"
        case .invalidInterviewCandidateMemoryActivationInbox(let detail):
            return "访谈正式记忆待办合同无效：\(detail)"
        case .invalidInterviewCandidateMemoryProjectionRecoveryInbox(let detail):
            return "访谈正式记忆整理状态合同无效：\(detail)"
        case .invalidInterviewCandidateConfirmation(let detail):
            return "访谈候选确认合同无效：\(detail)"
        case .invalidInterviewCandidateProposalStatus(let detail):
            return "访谈候选提议状态合同无效：\(detail)"
        case .invalidInterviewCandidateProposalAdmission(let detail):
            return "访谈候选整理准入合同无效：\(detail)"
        case .invalidInterviewCandidateDecision(let detail):
            return "访谈候选审核回执合同无效：\(detail)"
        case .invalidInterviewSessionState(let detail):
            return "访谈会话状态合同无效：\(detail)"
        case .invalidInterviewOrchestration(let detail):
            return "访谈编排合同无效：\(detail)"
        case .invalidInterviewNaturalInput(let detail):
            return "访谈自然输入合同无效：\(detail)"
        case .invalidInterviewPendingReviewBatchInbox(let detail):
            return "访谈待整理批次合同无效：\(detail)"
        case .invalidInterviewReviewBatchAcknowledgement(let detail):
            return "访谈整理确认合同无效：\(detail)"
        case .invalidKnowledgeDimensionConfirmation(let detail):
            return "知识维度确认合同无效：\(detail)"
        case .invalidKnowledgeRecommendationPlan(let detail):
            return "知识推荐合同无效：\(detail)"
        case .invalidGuidedRecommendationPresentation(let detail):
            return "引导问题合同无效：\(detail)"
        case .invalidGuidedRecommendationFeedback(let detail):
            return "引导问题反馈合同无效：\(detail)"
        case .invalidGuidedRecommendationActivation(let detail):
            return "引导问题启用合同无效：\(detail)"
        case .invalidLifeMapPresentation(let detail):
            return "人生地图合同无效：\(detail)"
        case .invalidMemorySearchPresentation(let detail):
            return "回顾检索合同无效：\(detail)"
        case .invalidInterviewOutcomePresentation(let detail):
            return "本次回顾合同无效：\(detail)"
        case .invalidKBLiteCompatibilityReadEnvelope(let detail):
            return "兼容读取合同无效：\(detail)"
        case .invalidContextCitationShadowBuild(let detail):
            return "上下文引用合同无效：\(detail)"
        case .invalidContextCitationShadowCompare(let detail):
            return "上下文对照合同无效：\(detail)"
        case .invalidAnswerCitationReceipt(let detail):
            return "回答引用回执合同无效：\(detail)"
        case .invalidCorrectionRequestCommand(let detail):
            return "回答纠错请求命令无效：\(detail)"
        case .invalidCorrectionRequestReceipt(let detail):
            return "回答纠错请求回执合同无效：\(detail)"
        case .invalidCorrectionResolutionCommand(let detail):
            return "回答纠错处理命令无效：\(detail)"
        case .invalidCorrectionResolutionReceipt(let detail):
            return "回答纠错处理回执合同无效：\(detail)"
        }
    }
}

/// Minimal transport error information consumed by the pure Owner Truth domain.
/// The app client conforms in its own target, so this domain remains portable
/// for Mac-based contract tests without losing typed failure behavior in iOS.
protocol OwnerTruthBackendFailureClassifying: Error {
    var ownerTruthBackendStatusCode: Int? { get }
    var ownerTruthBackendErrorCode: String? { get }
    var ownerTruthFeaturePolicyDenied: Bool { get }
}

func advanceOwnerTruthCandidateDecision(
    current: OwnerTruthCandidateDecision,
    requested: OwnerTruthCandidateDecision
) throws -> OwnerTruthCandidateDecision {
    guard !current.isTerminal || current == requested else {
        throw OwnerTruthContractError.terminalDecisionImmutable
    }
    return requested == .pending ? current : requested
}

/// JSON-only value type used by the typed candidate contract. Keeping raw
/// proposal values out of `[String: Any]` avoids a second loosely typed client
/// authority before the hidden review UI is introduced.
indirect enum OwnerTruthJSONValue: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([OwnerTruthJSONValue])
    case object([String: OwnerTruthJSONValue])

    init?(backendJSONObject value: Any) {
        if value is NSNull {
            self = .null
        } else if let value = value as? Bool {
            self = .bool(value)
        } else if let value = value as? NSNumber {
            guard value.doubleValue.isFinite else { return nil }
            self = .number(value.doubleValue)
        } else if let value = value as? String {
            self = .string(value)
        } else if let value = value as? [Any] {
            var values: [OwnerTruthJSONValue] = []
            values.reserveCapacity(value.count)
            for item in value {
                guard let parsed = OwnerTruthJSONValue(backendJSONObject: item) else {
                    return nil
                }
                values.append(parsed)
            }
            self = .array(values)
        } else if let value = value as? [String: Any] {
            var values: [String: OwnerTruthJSONValue] = [:]
            values.reserveCapacity(value.count)
            for (key, item) in value {
                guard let parsed = OwnerTruthJSONValue(backendJSONObject: item) else {
                    return nil
                }
                values[key] = parsed
            }
            self = .object(values)
        } else {
            return nil
        }
    }

    var backendJSONObject: Any {
        switch self {
        case .null:
            return NSNull()
        case .bool(let value):
            return value
        case .number(let value):
            return value
        case .string(let value):
            return value
        case .array(let values):
            return values.map(\.backendJSONObject)
        case .object(let values):
            return values.mapValues(\.backendJSONObject)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            guard value.isFinite else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Owner Truth JSON number must be finite"
                )
            }
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([OwnerTruthJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: OwnerTruthJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported Owner Truth JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let values):
            try container.encode(values)
        }
    }
}

enum OwnerTruthMemoryFacetKind: String, CaseIterable, Codable, Equatable, Sendable {
    case people
    case time
    case places
    case relationships
    case emotions
    case values
    case personality

    var title: String {
        switch self {
        case .people: return "人物"
        case .time: return "时间"
        case .places: return "地点"
        case .relationships: return "关系"
        case .emotions: return "情绪"
        case .values: return "价值观"
        case .personality: return "性格"
        }
    }
}

enum OwnerTruthFacetEvidenceMode: String, Codable, Equatable, Sendable {
    case ownerStated
    case inferred

    var title: String {
        switch self {
        case .ownerStated: return "本人表达"
        case .inferred: return "系统推断"
        }
    }
}

struct OwnerTruthMemoryFacetValue: Equatable, Sendable {
    let value: String
    let evidenceMode: OwnerTruthFacetEvidenceMode
    let confidence: Double
    fileprivate let rawObject: [String: OwnerTruthJSONValue]

    fileprivate init?(jsonValue: OwnerTruthJSONValue) {
        guard case .object(let object) = jsonValue,
              case .string(let rawValue)? = object["value"],
              case .string(let rawEvidenceMode)? = object["evidenceMode"],
              let evidenceMode = OwnerTruthFacetEvidenceMode(rawValue: rawEvidenceMode),
              case .number(let confidence)? = object["confidence"],
              confidence.isFinite,
              (0...1).contains(confidence) else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.value = value
        self.evidenceMode = evidenceMode
        self.confidence = confidence
        rawObject = object
    }

    fileprivate func ownerCorrectedJSONValue(value: String) -> OwnerTruthJSONValue {
        var object = rawObject
        object["value"] = .string(value)
        object["evidenceMode"] = .string(OwnerTruthFacetEvidenceMode.ownerStated.rawValue)
        object["confidence"] = .number(1.0)
        return .object(object)
    }
}

struct OwnerTruthMemoryFacets: Equatable, Sendable {
    let valuesByKind: [OwnerTruthMemoryFacetKind: [OwnerTruthMemoryFacetValue]]
    let confidence: Double
    private let rawObject: [String: OwnerTruthJSONValue]

    init?(jsonValue: OwnerTruthJSONValue) {
        guard case .object(let object) = jsonValue,
              case .number(let confidence)? = object["confidence"],
              confidence.isFinite,
              (0...1).contains(confidence) else {
            return nil
        }
        var valuesByKind: [OwnerTruthMemoryFacetKind: [OwnerTruthMemoryFacetValue]] = [:]
        for kind in OwnerTruthMemoryFacetKind.allCases {
            guard case .array(let values)? = object[kind.rawValue] else {
                return nil
            }
            var parsed: [OwnerTruthMemoryFacetValue] = []
            parsed.reserveCapacity(values.count)
            for value in values {
                guard let item = OwnerTruthMemoryFacetValue(jsonValue: value) else {
                    return nil
                }
                parsed.append(item)
            }
            valuesByKind[kind] = parsed
        }
        self.valuesByKind = valuesByKind
        self.confidence = confidence
        rawObject = object
    }

    func values(for kind: OwnerTruthMemoryFacetKind) -> [OwnerTruthMemoryFacetValue] {
        valuesByKind[kind] ?? []
    }

    var isEmpty: Bool {
        OwnerTruthMemoryFacetKind.allCases.allSatisfy { values(for: $0).isEmpty }
    }

    /// Rebuilds only known facet arrays. Unknown provider fields remain in the
    /// raw object, while every value explicitly submitted by the Owner becomes
    /// owner-stated evidence.
    func ownerCorrectedJSONValue(
        valuesByKind correctedValues: [OwnerTruthMemoryFacetKind: [String]]
    ) -> OwnerTruthJSONValue {
        var object = rawObject
        for kind in OwnerTruthMemoryFacetKind.allCases {
            var currentValues: [String: OwnerTruthMemoryFacetValue] = [:]
            for value in values(for: kind) {
                currentValues[Self.comparisonKey(value.value)] = value
            }
            var seen: Set<String> = []
            let normalizedValues = (correctedValues[kind] ?? []).compactMap { rawValue -> String? in
                let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = Self.comparisonKey(value)
                guard !value.isEmpty, seen.insert(key).inserted else { return nil }
                return value
            }
            object[kind.rawValue] = .array(normalizedValues.map { value in
                let existing = currentValues[Self.comparisonKey(value)]
                return existing?.ownerCorrectedJSONValue(value: value)
                    ?? .object([
                        "value": .string(value),
                        "evidenceMode": .string(OwnerTruthFacetEvidenceMode.ownerStated.rawValue),
                        "confidence": .number(1.0),
                    ])
            })
        }
        object["confidence"] = .number(1.0)
        return .object(object)
    }

    private static func comparisonKey(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

enum OwnerTruthMemoryFacetsState: Equatable, Sendable {
    case available(OwnerTruthMemoryFacets)
    case legacyNotAvailable
    case invalid
    case unsupportedSchema(String)

    static func resolve(
        contentSchemaVersion: String,
        content: [String: OwnerTruthJSONValue]
    ) -> OwnerTruthMemoryFacetsState {
        switch contentSchemaVersion {
        case "owner-truth-v2":
            guard let rawFacets = content["facets"],
                  let facets = OwnerTruthMemoryFacets(jsonValue: rawFacets) else {
                return .invalid
            }
            return .available(facets)
        case "owner-truth-v1", "owner-truth-candidate-content-v1":
            return .legacyNotAvailable
        default:
            return .unsupportedSchema(contentSchemaVersion)
        }
    }
}

struct OwnerTruthEvidenceSpan: Codable, Equatable, Sendable {
    let start: Int
    let end: Int

    init?(backendJSONObject value: Any?) {
        guard let object = value as? [String: Any],
              let start = Self.intValue(object["start"]),
              let end = Self.intValue(object["end"]),
              start >= 0,
              end >= start else {
            return nil
        }
        self.start = start
        self.end = end
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }
}

struct OwnerTruthCandidateEvidenceReference: Codable, Equatable, Sendable {
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int
    let span: OwnerTruthEvidenceSpan?

    init(backendJSONObject object: [String: Any]) throws {
        guard let sourceID = Self.recordID(object["sourceId"]),
              let sourceVersion = Self.positiveInt(object["sourceVersion"]) else {
            throw OwnerTruthRemoteContractError.invalidInbox("sourceRefs requires sourceId and positive sourceVersion")
        }
        self.sourceID = sourceID
        self.sourceVersion = sourceVersion
        if object["span"] != nil {
            guard let span = OwnerTruthEvidenceSpan(backendJSONObject: object["span"]) else {
                throw OwnerTruthRemoteContractError.invalidInbox("sourceRefs span is invalid")
            }
            self.span = span
        } else {
            self.span = nil
        }
    }

    fileprivate static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let rawValue = value as? String,
              let uuid = UUID(uuidString: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    fileprivate static func positiveInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value > 0 {
            return value
        }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue,
           value.intValue > 0 {
            return value.intValue
        }
        if let value = value as? String,
           let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
           parsed > 0 {
            return parsed
        }
        return nil
    }
}

enum OwnerTruthCandidatePrimaryField: String, Codable, Equatable, Sendable {
    case summary
    case claim
    case label

    init(memoryKind: OwnerTruthMemoryKind) {
        switch memoryKind {
        case .experience:
            self = .summary
        case .knowledge:
            self = .claim
        case .emotion:
            self = .label
        }
    }

    var title: String {
        switch self {
        case .summary: return "记忆描述"
        case .claim: return "观点内容"
        case .label: return "感受标签"
        }
    }
}

struct OwnerTruthCandidateInboxItem: Codable, Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let vaultID: OwnerTruthVaultID
    let sourceID: OwnerTruthRecordID
    let memoryKind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let contentSchemaVersion: String
    let content: [String: OwnerTruthJSONValue]
    let contentHash: String
    let sourceReferences: [OwnerTruthCandidateEvidenceReference]
    let reviewMode: String
    let candidateVersion: Int
    let createdAt: Date?

    init(backendJSONObject object: [String: Any], vaultID: OwnerTruthVaultID) throws {
        guard let id = OwnerTruthCandidateEvidenceReference.recordID(object["candidateId"]),
              let sourceID = OwnerTruthCandidateEvidenceReference.recordID(object["sourceId"]),
              let memoryKind = Self.enumValue(OwnerTruthMemoryKind.self, object["memoryKind"]),
              let perspective = Self.enumValue(OwnerTruthPerspectiveType.self, object["perspectiveType"]),
              let epistemicStatus = Self.enumValue(OwnerTruthEpistemicStatus.self, object["epistemicStatus"]),
              let sensitivity = Self.enumValue(OwnerTruthSensitivityLevel.self, object["sensitivity"]),
              let contentSchemaVersion = Self.nonEmptyString(object["contentSchemaVersion"]),
              let contentObject = object["content"] as? [String: Any],
              !contentObject.isEmpty,
              let contentHash = Self.nonEmptyString(object["contentHash"]),
              let sourceReferenceObjects = object["sourceRefs"] as? [[String: Any]],
              !sourceReferenceObjects.isEmpty,
              let reviewMode = Self.nonEmptyString(object["reviewMode"]),
              let candidateVersion = OwnerTruthCandidateEvidenceReference.positiveInt(object["candidateVersion"]) else {
            throw OwnerTruthRemoteContractError.invalidInbox("candidate item misses a required typed field")
        }

        var content: [String: OwnerTruthJSONValue] = [:]
        content.reserveCapacity(contentObject.count)
        for (key, value) in contentObject {
            guard let parsed = OwnerTruthJSONValue(backendJSONObject: value) else {
                throw OwnerTruthRemoteContractError.invalidInbox("candidate content contains an unsupported JSON value")
            }
            content[key] = parsed
        }

        let primaryField = OwnerTruthCandidatePrimaryField(memoryKind: memoryKind)
        guard case .string(let rawPrimaryValue)? = content[primaryField.rawValue],
              !rawPrimaryValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "candidate content misses the required \(primaryField.rawValue) field"
            )
        }

        let sourceReferences = try sourceReferenceObjects.map(OwnerTruthCandidateEvidenceReference.init(backendJSONObject:))
        guard sourceReferences.contains(where: { $0.sourceID == sourceID }) else {
            throw OwnerTruthRemoteContractError.invalidInbox("candidate sourceId is absent from sourceRefs")
        }

        self.id = id
        self.vaultID = vaultID
        self.sourceID = sourceID
        self.memoryKind = memoryKind
        self.perspective = perspective
        self.epistemicStatus = epistemicStatus
        self.sensitivity = sensitivity
        self.contentSchemaVersion = contentSchemaVersion
        self.content = content
        self.contentHash = contentHash
        self.sourceReferences = sourceReferences
        self.reviewMode = reviewMode
        self.candidateVersion = candidateVersion
        self.createdAt = try Self.date(object["createdAt"])
    }

    var primaryField: OwnerTruthCandidatePrimaryField {
        OwnerTruthCandidatePrimaryField(memoryKind: memoryKind)
    }

    var facetsState: OwnerTruthMemoryFacetsState {
        OwnerTruthMemoryFacetsState.resolve(
            contentSchemaVersion: contentSchemaVersion,
            content: content
        )
    }

    var primaryValue: String {
        guard case .string(let rawValue)? = content[primaryField.rawValue] else {
            return ""
        }
        return rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func enumValue<Value: RawRepresentable>(
        _ type: Value.Type,
        _ value: Any?
    ) -> Value? where Value.RawValue == String {
        guard let rawValue = nonEmptyString(value) else { return nil }
        return Value(rawValue: rawValue)
    }

    private static func date(_ value: Any?) throws -> Date? {
        guard let value else { return nil }
        guard let rawValue = nonEmptyString(value) else {
            throw OwnerTruthRemoteContractError.invalidInbox("createdAt must be an ISO-8601 value or null")
        }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        guard let date = fractionalFormatter.date(from: rawValue)
            ?? standardFormatter.date(from: rawValue) else {
            throw OwnerTruthRemoteContractError.invalidInbox("createdAt is not valid ISO-8601")
        }
        return date
    }
}

struct OwnerTruthCandidateInbox: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-candidate-inbox-v1"

    let vaultID: OwnerTruthVaultID
    let candidates: [OwnerTruthCandidateInboxItem]

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard Self.nonEmptyString(object["schemaVersion"]) == Self.schemaVersion,
              let responseVaultID = Self.nonEmptyString(object["vaultId"]),
              responseVaultID == expectedVaultID.rawValue,
              let candidateObjects = object["candidates"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidInbox("schemaVersion, vaultId or candidates does not match the contract")
        }
        vaultID = expectedVaultID
        candidates = try candidateObjects.map {
            try OwnerTruthCandidateInboxItem(backendJSONObject: $0, vaultID: expectedVaultID)
        }
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

enum OwnerTruthCandidateMemoryActivationStatus: String, Codable, Equatable, Sendable {
    case current
    case superseded
    case pending
    case notApplicable
}

struct OwnerTruthCandidateReviewHistoryMemoryActivation: Codable, Equatable, Sendable {
    let status: OwnerTruthCandidateMemoryActivationStatus
    let memoryID: OwnerTruthRecordID?
    let memoryVersionID: OwnerTruthRecordID?
    let memoryVersion: Int?

    init(backendJSONObject object: [String: Any]) throws {
        guard let rawStatus = Self.nonEmptyString(object["status"]),
              let status = OwnerTruthCandidateMemoryActivationStatus(rawValue: rawStatus) else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "review history memoryActivation.status is invalid"
            )
        }
        let memoryID = try Self.optionalRecordID(object["memoryId"], field: "memoryId")
        let memoryVersionID = try Self.optionalRecordID(
            object["memoryVersionId"],
            field: "memoryVersionId"
        )
        let memoryVersion: Int?
        if object["memoryVersion"] == nil || object["memoryVersion"] is NSNull {
            memoryVersion = nil
        } else {
            guard let parsed = OwnerTruthCandidateEvidenceReference.positiveInt(
                object["memoryVersion"]
            ) else {
                throw OwnerTruthRemoteContractError.invalidInbox(
                    "review history memoryVersion must be positive or null"
                )
            }
            memoryVersion = parsed
        }
        switch status {
        case .current, .superseded:
            guard memoryID != nil, memoryVersionID != nil, memoryVersion != nil else {
                throw OwnerTruthRemoteContractError.invalidInbox(
                    "current or superseded review history requires a MemoryVersion"
                )
            }
        case .pending, .notApplicable:
            guard memoryID == nil, memoryVersionID == nil, memoryVersion == nil else {
                throw OwnerTruthRemoteContractError.invalidInbox(
                    "pending or notApplicable review history cannot claim a MemoryVersion"
                )
            }
        }
        self.status = status
        self.memoryID = memoryID
        self.memoryVersionID = memoryVersionID
        self.memoryVersion = memoryVersion
    }

    private static func optionalRecordID(
        _ value: Any?,
        field: String
    ) throws -> OwnerTruthRecordID? {
        guard let value, !(value is NSNull) else { return nil }
        guard let parsed = OwnerTruthCandidateEvidenceReference.recordID(value) else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "review history \(field) must be a UUID or null"
            )
        }
        return parsed
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

struct OwnerTruthCandidateReviewHistoryItem: Codable, Equatable, Sendable, Identifiable {
    let candidate: OwnerTruthCandidateInboxItem
    let decision: OwnerTruthCandidateDecision
    let decidedAt: Date
    let memoryActivation: OwnerTruthCandidateReviewHistoryMemoryActivation

    var id: OwnerTruthRecordID { candidate.id }

    init(backendJSONObject object: [String: Any], vaultID: OwnerTruthVaultID) throws {
        guard let candidateObject = object["candidate"] as? [String: Any],
              let rawDecision = Self.nonEmptyString(object["decision"]),
              let decision = OwnerTruthCandidateDecision(rawValue: rawDecision),
              decision.isTerminal,
              let rawDecidedAt = Self.nonEmptyString(object["decidedAt"]),
              let decidedAt = Self.date(rawDecidedAt),
              let activationObject = object["memoryActivation"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "review history item misses a required typed field"
            )
        }
        let candidate = try OwnerTruthCandidateInboxItem(
            backendJSONObject: candidateObject,
            vaultID: vaultID
        )
        let activation = try OwnerTruthCandidateReviewHistoryMemoryActivation(
            backendJSONObject: activationObject
        )
        switch decision {
        case .accepted, .corrected:
            guard activation.status != .notApplicable else {
                throw OwnerTruthRemoteContractError.invalidInbox(
                    "accepted or corrected review cannot be notApplicable"
                )
            }
        case .rejected, .invalidated:
            guard activation.status == .notApplicable else {
                throw OwnerTruthRemoteContractError.invalidInbox(
                    "rejected or invalidated review cannot activate memory"
                )
            }
        case .pending:
            throw OwnerTruthRemoteContractError.invalidInbox(
                "pending is not a review history decision"
            )
        }
        self.candidate = candidate
        self.decision = decision
        self.decidedAt = decidedAt
        self.memoryActivation = activation
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func date(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }
}

struct OwnerTruthCandidateReviewHistory: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-candidate-review-history-v1"

    let vaultID: OwnerTruthVaultID
    let reviews: [OwnerTruthCandidateReviewHistoryItem]

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard Self.nonEmptyString(object["schemaVersion"]) == Self.schemaVersion,
              Self.nonEmptyString(object["vaultId"]) == expectedVaultID.rawValue,
              let reviewObjects = object["reviews"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "review history schemaVersion, vaultId or reviews is invalid"
            )
        }
        let reviews = try reviewObjects.map {
            try OwnerTruthCandidateReviewHistoryItem(
                backendJSONObject: $0,
                vaultID: expectedVaultID
            )
        }
        guard Set(reviews.map(\.id)).count == reviews.count else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "review history contains duplicate candidates"
            )
        }
        vaultID = expectedVaultID
        self.reviews = reviews
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

enum OwnerTruthMemoryVersionHistoryStatus: String, Codable, Equatable, Sendable {
    case current
    case superseded
}

struct OwnerTruthMemoryVersionHistoryItem: Codable, Equatable, Sendable, Identifiable {
    let versionNumber: Int
    let status: OwnerTruthMemoryVersionHistoryStatus
    let decision: OwnerTruthCandidateDecision
    let contentSchemaVersion: String
    let content: [String: OwnerTruthJSONValue]
    let sourceCount: Int
    let createdAt: Date

    var id: Int { versionNumber }

    init(backendJSONObject object: [String: Any]) throws {
        let forbiddenKeys: Set<String> = [
            "memoryId",
            "memoryVersionId",
            "contentHash",
            "actorSubjectId",
            "decisionReceiptId",
        ]
        guard forbiddenKeys.isDisjoint(with: object.keys),
              let versionNumber = OwnerTruthCandidateEvidenceReference.positiveInt(
                object["versionNumber"]
              ),
              let rawStatus = Self.nonEmptyString(object["status"]),
              let status = OwnerTruthMemoryVersionHistoryStatus(rawValue: rawStatus),
              let rawDecision = Self.nonEmptyString(object["decision"]),
              let decision = OwnerTruthCandidateDecision(rawValue: rawDecision),
              decision == .accepted || decision == .corrected,
              let contentSchemaVersion = Self.nonEmptyString(object["contentSchemaVersion"]),
              let contentObject = object["content"] as? [String: Any],
              !contentObject.isEmpty,
              let sourceCount = OwnerTruthCandidateEvidenceReference.positiveInt(
                object["sourceCount"]
              ),
              let rawCreatedAt = Self.nonEmptyString(object["createdAt"]),
              let createdAt = Self.date(rawCreatedAt) else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "MemoryVersion history item is invalid or leaks internal metadata"
            )
        }
        var content: [String: OwnerTruthJSONValue] = [:]
        for (key, value) in contentObject {
            guard let parsed = OwnerTruthJSONValue(backendJSONObject: value) else {
                throw OwnerTruthRemoteContractError.invalidInbox(
                    "MemoryVersion history content is invalid"
                )
            }
            content[key] = parsed
        }
        self.versionNumber = versionNumber
        self.status = status
        self.decision = decision
        self.contentSchemaVersion = contentSchemaVersion
        self.content = content
        self.sourceCount = sourceCount
        self.createdAt = createdAt
    }

    var facetsState: OwnerTruthMemoryFacetsState {
        OwnerTruthMemoryFacetsState.resolve(
            contentSchemaVersion: contentSchemaVersion,
            content: content
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func date(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
    }
}

struct OwnerTruthMemoryVersionHistory: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-memory-version-history-v1"

    let vaultID: OwnerTruthVaultID
    let memoryKind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let memoryStatus: String
    let versions: [OwnerTruthMemoryVersionHistoryItem]

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        guard Self.nonEmptyString(object["schemaVersion"]) == Self.schemaVersion,
              Self.nonEmptyString(object["vaultId"]) == expectedVaultID.rawValue,
              let rawMemoryKind = Self.nonEmptyString(object["memoryKind"]),
              let memoryKind = OwnerTruthMemoryKind(rawValue: rawMemoryKind),
              let rawPerspective = Self.nonEmptyString(object["perspectiveType"]),
              let perspective = OwnerTruthPerspectiveType(rawValue: rawPerspective),
              let rawEpistemicStatus = Self.nonEmptyString(object["epistemicStatus"]),
              let epistemicStatus = OwnerTruthEpistemicStatus(rawValue: rawEpistemicStatus),
              let rawSensitivity = Self.nonEmptyString(object["sensitivity"]),
              let sensitivity = OwnerTruthSensitivityLevel(rawValue: rawSensitivity),
              Self.nonEmptyString(object["memoryStatus"]) == "active",
              let versionObjects = object["versions"] as? [[String: Any]],
              !versionObjects.isEmpty else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "MemoryVersion history metadata is invalid"
            )
        }
        let versions = try versionObjects.map(OwnerTruthMemoryVersionHistoryItem.init)
        guard Set(versions.map(\.versionNumber)).count == versions.count,
              versions == versions.sorted(by: { $0.versionNumber > $1.versionNumber }),
              versions.filter({ $0.status == .current }).count == 1,
              versions.first?.status == .current else {
            throw OwnerTruthRemoteContractError.invalidInbox(
                "MemoryVersion history ordering or current state is invalid"
            )
        }
        vaultID = expectedVaultID
        self.memoryKind = memoryKind
        self.perspective = perspective
        self.epistemicStatus = epistemicStatus
        self.sensitivity = sensitivity
        memoryStatus = "active"
        self.versions = versions
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

struct OwnerTruthCandidateReviewCommand: Equatable, Sendable {
    let commandID: String
    let expectedCandidateVersion: Int
    let action: OwnerTruthCandidateReviewAction
    let correctedValue: [String: OwnerTruthJSONValue]?
    let correctedValueSchemaVersion: String?
    let reasonCode: String

    init(
        commandID: String,
        expectedCandidateVersion: Int,
        action: OwnerTruthCandidateReviewAction,
        correctedValue: [String: OwnerTruthJSONValue]? = nil,
        correctedValueSchemaVersion: String? = nil,
        reasonCode: String
    ) throws {
        let normalizedCommandID = commandID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReasonCode = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSchemaVersion = correctedValueSchemaVersion?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCommandID.isEmpty else {
            throw OwnerTruthRemoteContractError.invalidCommand("commandId is required")
        }
        guard expectedCandidateVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidCommand("expectedCandidateVersion must be positive")
        }
        guard !normalizedReasonCode.isEmpty else {
            throw OwnerTruthRemoteContractError.invalidCommand("reasonCode is required")
        }
        switch action {
        case .correct:
            guard let correctedValue, !correctedValue.isEmpty,
                  let normalizedSchemaVersion, !normalizedSchemaVersion.isEmpty else {
                throw OwnerTruthRemoteContractError.invalidCommand("correct requires correctedValue and correctedValueSchemaVersion")
            }
            self.correctedValue = correctedValue
            self.correctedValueSchemaVersion = normalizedSchemaVersion
        case .accept, .reject:
            guard correctedValue == nil, correctedValueSchemaVersion == nil else {
                throw OwnerTruthRemoteContractError.invalidCommand("only correct may carry a corrected value")
            }
            self.correctedValue = nil
            self.correctedValueSchemaVersion = nil
        }
        self.commandID = normalizedCommandID
        self.expectedCandidateVersion = expectedCandidateVersion
        self.action = action
        self.reasonCode = normalizedReasonCode
    }

    var backendPayload: [String: Any] {
        var payload: [String: Any] = [
            "commandId": commandID,
            "expectedCandidateVersion": expectedCandidateVersion,
            "action": action.rawValue,
            "reasonCode": reasonCode,
        ]
        if let correctedValue, let correctedValueSchemaVersion {
            payload["correctedValue"] = correctedValue.mapValues(\.backendJSONObject)
            payload["correctedValueSchemaVersion"] = correctedValueSchemaVersion
        }
        return payload
    }
}

enum OwnerTruthCommandOutcome: String, Codable, Equatable, Sendable {
    case created
    case deduplicated
}

enum OwnerTruthMemoryActivationOutcome: String, Codable, Equatable, Sendable {
    case created
    case deduplicated
    case notApplicable
}

struct OwnerTruthCandidateDecisionReceipt: Codable, Equatable, Sendable {
    let id: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let candidateVersion: Int
    let candidateBeforeHash: String
    let candidateAfterHash: String
    let correctedValueID: OwnerTruthRecordID?
}

struct OwnerTruthCandidateMemoryActivation: Codable, Equatable, Sendable {
    let outcome: OwnerTruthMemoryActivationOutcome
    let memoryID: OwnerTruthRecordID?
    let memoryVersionID: OwnerTruthRecordID?
    let contentHash: String?
}

struct OwnerTruthCandidateDecisionResult: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-candidate-decision-memory-v1"

    let outcome: OwnerTruthCommandOutcome
    let receipt: OwnerTruthCandidateDecisionReceipt
    let memoryActivation: OwnerTruthCandidateMemoryActivation

    init(backendJSONObject object: [String: Any], expectedCandidateID: OwnerTruthRecordID) throws {
        guard Self.nonEmptyString(object["schemaVersion"]) == Self.schemaVersion,
              let outcome = OwnerTruthCommandOutcome(rawValue: Self.nonEmptyString(object["status"]) ?? ""),
              let receiptObject = object["receipt"] as? [String: Any],
              let receiptID = OwnerTruthCandidateEvidenceReference.recordID(receiptObject["receiptId"]),
              let candidateID = OwnerTruthCandidateEvidenceReference.recordID(receiptObject["candidateId"]),
              candidateID == expectedCandidateID,
              let decision = OwnerTruthCandidateDecision(rawValue: Self.nonEmptyString(receiptObject["decision"]) ?? ""),
              decision.isTerminal,
              let candidateVersion = OwnerTruthCandidateEvidenceReference.positiveInt(receiptObject["candidateVersion"]),
              let candidateBeforeHash = Self.nonEmptyString(receiptObject["candidateBeforeHash"]),
              let candidateAfterHash = Self.nonEmptyString(receiptObject["candidateAfterHash"]),
              let activationObject = object["memoryActivation"] as? [String: Any],
              let activationOutcome = OwnerTruthMemoryActivationOutcome(rawValue: Self.nonEmptyString(activationObject["status"]) ?? "") else {
            throw OwnerTruthRemoteContractError.invalidDecision("response misses a required typed field")
        }

        let correctedValueID: OwnerTruthRecordID?
        if let rawValue = receiptObject["correctedValueId"], !(rawValue is NSNull) {
            guard let parsed = OwnerTruthCandidateEvidenceReference.recordID(rawValue) else {
                throw OwnerTruthRemoteContractError.invalidDecision("correctedValueId must be a UUID or null")
            }
            correctedValueID = parsed
        } else {
            correctedValueID = nil
        }

        let memoryID = try Self.optionalRecordID(activationObject["memoryId"], field: "memoryId")
        let memoryVersionID = try Self.optionalRecordID(
            activationObject["memoryVersionId"],
            field: "memoryVersionId"
        )
        let contentHash = try Self.optionalString(activationObject["contentHash"], field: "contentHash")
        switch decision {
        case .accepted, .corrected:
            guard activationOutcome != .notApplicable,
                  memoryID != nil,
                  memoryVersionID != nil,
                  contentHash != nil else {
                throw OwnerTruthRemoteContractError.invalidDecision("accepted or corrected decisions require a MemoryVersion activation")
            }
        case .rejected, .invalidated:
            guard activationOutcome == .notApplicable,
                  memoryID == nil,
                  memoryVersionID == nil else {
                throw OwnerTruthRemoteContractError.invalidDecision("rejected or invalidated decisions must not activate memory")
            }
        case .pending:
            throw OwnerTruthRemoteContractError.invalidDecision("pending is not a terminal review result")
        }

        self.outcome = outcome
        self.receipt = OwnerTruthCandidateDecisionReceipt(
            id: receiptID,
            candidateID: candidateID,
            decision: decision,
            candidateVersion: candidateVersion,
            candidateBeforeHash: candidateBeforeHash,
            candidateAfterHash: candidateAfterHash,
            correctedValueID: correctedValueID
        )
        self.memoryActivation = OwnerTruthCandidateMemoryActivation(
            outcome: activationOutcome,
            memoryID: memoryID,
            memoryVersionID: memoryVersionID,
            contentHash: contentHash
        )
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func optionalString(_ value: Any?, field: String) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        guard let value = nonEmptyString(value) else {
            throw OwnerTruthRemoteContractError.invalidDecision("\(field) must be a non-empty string or null")
        }
        return value
    }

    private static func optionalRecordID(_ value: Any?, field: String) throws -> OwnerTruthRecordID? {
        guard let value, !(value is NSNull) else { return nil }
        guard let value = OwnerTruthCandidateEvidenceReference.recordID(value) else {
            throw OwnerTruthRemoteContractError.invalidDecision("\(field) must be a UUID or null")
        }
        return value
    }
}

// MARK: - Closed-pilot owner-authored text Source capture

/// The only client-authored write admitted by the first Owner Truth pilot.
/// The server derives the Source identifier from `commandID`; callers must
/// retain the command for retry instead of creating another original.
struct OwnerTruthTextSourceCaptureCommand: Equatable, Sendable {
    static let maximumCharacterCount = 20_000
    static let defaultPurpose = "memoryCapture"

    let commandID: UUID
    let expectedAuthorityEpoch: Int
    let text: String
    let purpose: String
    let clientCreatedAt: Date

    init(
        commandID: UUID = UUID(),
        expectedAuthorityEpoch: Int,
        text: String,
        purpose: String = Self.defaultPurpose,
        clientCreatedAt: Date = Date()
    ) throws {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard expectedAuthorityEpoch >= 0,
              !normalizedText.isEmpty,
              normalizedText.count <= Self.maximumCharacterCount,
              Self.isValidPurpose(normalizedPurpose) else {
            throw OwnerTruthRemoteContractError.invalidTextSourceCapture(
                "command requires bounded text, a non-negative authority epoch and a valid purpose"
            )
        }

        self.commandID = commandID
        self.expectedAuthorityEpoch = expectedAuthorityEpoch
        self.text = normalizedText
        self.purpose = normalizedPurpose
        self.clientCreatedAt = clientCreatedAt
    }

    /// Exactly mirrors the server's closed-pilot request schema. Owner,
    /// vault, Source ID, receipt and extraction effect are all server-owned.
    var backendPayload: [String: Any] {
        [
            "commandId": commandID.uuidString.lowercased(),
            "expectedAuthorityEpoch": expectedAuthorityEpoch,
            "kind": "text",
            "content": text,
            "purpose": purpose,
            "clientCreatedAt": Self.iso8601String(clientCreatedAt),
        ]
    }

    private static func isValidPurpose(_ purpose: String) -> Bool {
        guard !purpose.isEmpty, purpose.utf8.count <= 80 else { return false }
        return purpose.range(
            of: "^[A-Za-z0-9._-]+$",
            options: .regularExpression
        ) != nil
    }

    private static func iso8601String(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

enum OwnerTruthTextSourceCaptureOutcome: String, Equatable, Sendable {
    case created
    case deduplicated
}

/// The only read needed before issuing the next owner-authored Source command.
/// It is deliberately value-minimized: no owner, Source, Candidate or memory
/// material crosses this boundary.
struct OwnerTruthTextSourceCaptureState: Equatable, Sendable {
    static let schemaVersion = "owner-truth-text-capture-state-v1"

    let vaultID: OwnerTruthVaultID
    let authorityEpoch: Int

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        let responseKeys: Set<String> = [
            "schemaVersion",
            "vaultId",
            "authorityEpoch",
        ]
        guard Set(object.keys) == responseKeys,
              OwnerTruthTextSourceCaptureContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthTextSourceCaptureContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let authorityEpoch = OwnerTruthTextSourceCaptureContract.nonNegativeInt(
                object["authorityEpoch"]
              ) else {
            throw OwnerTruthRemoteContractError.invalidTextSourceCapture(
                "response does not match the value-minimized Source capture state contract"
            )
        }

        vaultID = expectedVaultID
        self.authorityEpoch = authorityEpoch
    }
}

/// Value-minimized receipt for an admitted owner-authored Source. It never
/// retains the submitted text, Source payload or Candidate payload.
struct OwnerTruthTextSourceCaptureReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-text-capture-response-v1"
    static let sourceReceiptSchemaVersion = "owner-truth-create-source-v1"

    let vaultID: OwnerTruthVaultID
    let outcome: OwnerTruthTextSourceCaptureOutcome
    let receiptID: OwnerTruthRecordID
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int
    let authorityEpoch: Int
    let acceptedAt: Date

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        let responseKeys: Set<String> = [
            "schemaVersion",
            "vaultId",
            "source",
            "candidateExtraction",
            "acceptedAt",
        ]
        let sourceKeys: Set<String> = [
            "schemaVersion",
            "status",
            "receiptId",
            "sourceId",
            "sourceVersion",
            "authorityEpoch",
        ]
        guard Set(object.keys) == responseKeys,
              OwnerTruthTextSourceCaptureContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthTextSourceCaptureContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let source = object["source"] as? [String: Any],
              Set(source.keys) == sourceKeys,
              OwnerTruthTextSourceCaptureContract.requiredString(source["schemaVersion"])
                == Self.sourceReceiptSchemaVersion,
              let outcomeRaw = OwnerTruthTextSourceCaptureContract.requiredString(source["status"]),
              let outcome = OwnerTruthTextSourceCaptureOutcome(rawValue: outcomeRaw),
              let receiptID = OwnerTruthTextSourceCaptureContract.recordID(source["receiptId"]),
              let sourceID = OwnerTruthTextSourceCaptureContract.recordID(source["sourceId"]),
              let sourceVersion = OwnerTruthTextSourceCaptureContract.positiveInt(source["sourceVersion"]),
              let authorityEpoch = OwnerTruthTextSourceCaptureContract.nonNegativeInt(source["authorityEpoch"]),
              let candidateExtraction = object["candidateExtraction"] as? [String: Any],
              Set(candidateExtraction.keys) == ["status"],
              OwnerTruthTextSourceCaptureContract.requiredString(candidateExtraction["status"])
                == "requested",
              let acceptedAt = OwnerTruthTextSourceCaptureContract.iso8601Date(object["acceptedAt"]) else {
            throw OwnerTruthRemoteContractError.invalidTextSourceCapture(
                "response does not match the value-minimized Source receipt contract"
            )
        }

        vaultID = expectedVaultID
        self.outcome = outcome
        self.receiptID = receiptID
        self.sourceID = sourceID
        self.sourceVersion = sourceVersion
        self.authorityEpoch = authorityEpoch
        self.acceptedAt = acceptedAt
    }
}

/// The transport keeps authentication, AccountLease and captured release-policy
/// headers inside the backend client. It intentionally has no QA-header path.
protocol OwnerTruthTextSourceCaptureClient: AnyObject {
    func fetchOwnerTruthTextSourceCaptureState(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthTextSourceCaptureState, Error>) -> Void
    )

    func captureOwnerTruthTextSource(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthTextSourceCaptureCommand,
        completion: @escaping (Result<OwnerTruthTextSourceCaptureReceipt, Error>) -> Void
    )
}

// MARK: - Closed-pilot private media SourceObject capture

enum OwnerTruthMediaKind: String, CaseIterable, Codable, Sendable {
    case image
    case audio
    case video
    case document

    var allowsExternalProcessing: Bool {
        self == .image || self == .document
    }

    fileprivate var supportedContentTypes: Set<String> {
        switch self {
        case .image:
            return ["image/jpeg", "image/png", "image/webp"]
        case .audio:
            return ["audio/mpeg", "audio/wav", "audio/x-wav", "audio/mp4", "audio/m4a"]
        case .video:
            return ["video/mp4", "video/quicktime"]
        case .document:
            return [
                "text/plain",
                "application/pdf",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ]
        }
    }
}

enum OwnerTruthMediaSourceObjectState: String, CaseIterable, Codable, Sendable {
    case uploadPending
    case verified
    case quarantined
    case processing
    case processed
    case failed
    case deleted
}

enum OwnerTruthMediaSafetyStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case clean
    case blocked
    case unavailable
}

enum OwnerTruthMediaProcessingStatus: String, CaseIterable, Codable, Sendable {
    case notQueued
    case queued
    case processing
    case succeeded
    case retryableFailed
    case failed
    case notApplicable
    case blocked
}

enum OwnerTruthMediaUploadIntentOutcome: String, Equatable, Sendable {
    case created
    case deduplicated
}

enum OwnerTruthMediaUploadIntentState: String, Equatable, Sendable {
    case pending
    case uploaded
    case rejected
    case expired
}

enum OwnerTruthMediaSourceObjectResponseStatus: String, Equatable, Sendable {
    case uploaded
    case deduplicated
    case quarantined
    case processingRequested
}

enum OwnerTruthMediaAccessState: String, Codable, Equatable, Sendable {
    case available
    case accessRevoked
}

enum OwnerTruthMediaDeletionStatus: String, Codable, Equatable, Sendable {
    case notRequested
    case pending
    case partial
    case unsupported
    case completed
}

enum OwnerTruthMediaDeletionOutcome: String, Equatable, Sendable {
    case deletionRequested
    case deletionRetryRequested
    case deletionDeduplicated
}

/// One-time bearer secret returned only when an upload intent is first
/// created. It deliberately is not Codable so a generic receipt cache cannot
/// persist it accidentally.
struct OwnerTruthMediaUploadToken: Equatable, Sendable {
    let rawValue: String

    init?(_ rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 32, normalized.count <= 512 else { return nil }
        self.rawValue = normalized
    }
}

struct OwnerTruthMediaUploadIntentCommand: Equatable, Sendable {
    static let defaultPurpose = "memoryCapture"

    let commandID: UUID
    let expectedAuthorityEpoch: Int
    let mediaKind: OwnerTruthMediaKind
    let fileName: String
    let contentType: String
    let fileSizeBytes: Int
    let contentSHA256: String
    let purpose: String
    let clientCreatedAt: Date
    let allowExternalProcessing: Bool

    init(
        commandID: UUID = UUID(),
        expectedAuthorityEpoch: Int,
        mediaKind: OwnerTruthMediaKind,
        fileName: String,
        contentType: String,
        fileSizeBytes: Int,
        contentSHA256: String,
        purpose: String = Self.defaultPurpose,
        clientCreatedAt: Date = Date(),
        allowExternalProcessing: Bool = false
    ) throws {
        let normalizedFileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContentType = contentType
            .lowercased()
            .split(separator: ";", maxSplits: 1)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedSHA256 = contentSHA256
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        guard expectedAuthorityEpoch >= 0,
              Self.isValidFileName(normalizedFileName),
              mediaKind.supportedContentTypes.contains(normalizedContentType),
              fileSizeBytes > 0,
              Self.isSHA256(normalizedSHA256),
              Self.isValidPurpose(normalizedPurpose),
              !allowExternalProcessing || mediaKind.allowsExternalProcessing else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "upload intent requires valid authority, media metadata and processing consent"
            )
        }

        self.commandID = commandID
        self.expectedAuthorityEpoch = expectedAuthorityEpoch
        self.mediaKind = mediaKind
        self.fileName = normalizedFileName
        self.contentType = normalizedContentType
        self.fileSizeBytes = fileSizeBytes
        self.contentSHA256 = normalizedSHA256
        self.purpose = normalizedPurpose
        self.clientCreatedAt = clientCreatedAt
        self.allowExternalProcessing = allowExternalProcessing
    }

    init(
        commandID: UUID = UUID(),
        expectedAuthorityEpoch: Int,
        mediaKind: OwnerTruthMediaKind,
        fileName: String,
        contentType: String,
        content: Data,
        purpose: String = Self.defaultPurpose,
        clientCreatedAt: Date = Date(),
        allowExternalProcessing: Bool = false
    ) throws {
        try self.init(
            commandID: commandID,
            expectedAuthorityEpoch: expectedAuthorityEpoch,
            mediaKind: mediaKind,
            fileName: fileName,
            contentType: contentType,
            fileSizeBytes: content.count,
            contentSHA256: SHA256.hash(data: content)
                .map { String(format: "%02x", $0) }
                .joined(),
            purpose: purpose,
            clientCreatedAt: clientCreatedAt,
            allowExternalProcessing: allowExternalProcessing
        )
    }

    var backendPayload: [String: Any] {
        var payload: [String: Any] = [
            "commandId": commandID.uuidString.lowercased(),
            "expectedAuthorityEpoch": expectedAuthorityEpoch,
            "mediaKind": mediaKind.rawValue,
            "fileName": fileName,
            "contentType": contentType,
            "fileSizeBytes": fileSizeBytes,
            "contentSha256": contentSHA256,
            "purpose": purpose,
            "clientCreatedAt": OwnerTruthMediaCaptureContract.iso8601String(clientCreatedAt),
        ]
        if allowExternalProcessing {
            payload["allowExternalProcessing"] = true
        }
        return payload
    }

    private static func isValidFileName(_ value: String) -> Bool {
        !value.isEmpty
            && value.utf8.count <= 255
            && value != "."
            && value != ".."
            && !value.contains("/")
            && !value.contains("\\")
            && !value.contains("\0")
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil
    }

    private static func isValidPurpose(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z][A-Za-z0-9._-]{0,79}$", options: .regularExpression) != nil
    }
}

/// Idempotent owner command for revocation-first private-media deletion.
/// It intentionally carries no storage key, provider identifier or delete mode.
struct OwnerTruthMediaDeletionCommand: Equatable, Sendable {
    let commandID: UUID
    let expectedAuthorityEpoch: Int
    let clientRequestedAt: Date

    init(
        commandID: UUID = UUID(),
        expectedAuthorityEpoch: Int,
        clientRequestedAt: Date = Date()
    ) throws {
        guard expectedAuthorityEpoch >= 0 else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "media deletion requires a non-negative authority epoch"
            )
        }
        self.commandID = commandID
        self.expectedAuthorityEpoch = expectedAuthorityEpoch
        self.clientRequestedAt = clientRequestedAt
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID.uuidString.lowercased(),
            "expectedAuthorityEpoch": expectedAuthorityEpoch,
            "clientRequestedAt": OwnerTruthMediaCaptureContract.iso8601String(clientRequestedAt),
        ]
    }
}

struct OwnerTruthMediaSourceObjectReceipt: Equatable, Sendable {
    let sourceObjectID: OwnerTruthRecordID
    let mediaKind: OwnerTruthMediaKind
    let state: OwnerTruthMediaSourceObjectState
    let contentType: String
    let magicMime: String?
    let fileName: String
    let fileSizeBytes: Int
    let contentSHA256: String
    let safetyStatus: OwnerTruthMediaSafetyStatus
    let safetyProvider: String?
    let processingStatus: OwnerTruthMediaProcessingStatus
    let processingGeneration: Int
    let externalProcessingAllowed: Bool
    let retryable: Bool
    let failureCode: String?
    let derivedSourceID: OwnerTruthRecordID?
    let updatedAt: Date

    init(backendJSONObject object: [String: Any]) throws {
        guard Set(object.keys) == OwnerTruthMediaCaptureContract.sourceObjectKeys else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "SourceObject response contains unexpected or private fields"
            )
        }
        guard let sourceObjectID = OwnerTruthMediaCaptureContract.recordID(object["sourceObjectId"]),
              let mediaKindRaw = OwnerTruthMediaCaptureContract.requiredString(object["mediaKind"]),
              let mediaKind = OwnerTruthMediaKind(rawValue: mediaKindRaw),
              let stateRaw = OwnerTruthMediaCaptureContract.requiredString(object["state"]),
              let state = OwnerTruthMediaSourceObjectState(rawValue: stateRaw),
              let contentType = OwnerTruthMediaCaptureContract.requiredString(object["contentType"]),
              OwnerTruthMediaCaptureContract.optionalStringIsValid(object["magicMime"]),
              let fileName = OwnerTruthMediaCaptureContract.requiredString(object["fileName"]),
              let fileSizeBytes = OwnerTruthMediaCaptureContract.positiveInt(object["fileSizeBytes"]),
              let contentSHA256 = OwnerTruthMediaCaptureContract.sha256(object["contentSha256"]),
              let safetyRaw = OwnerTruthMediaCaptureContract.requiredString(object["safetyStatus"]),
              let safetyStatus = OwnerTruthMediaSafetyStatus(rawValue: safetyRaw),
              OwnerTruthMediaCaptureContract.optionalStringIsValid(object["safetyProvider"]),
              let processingRaw = OwnerTruthMediaCaptureContract.requiredString(object["processingStatus"]),
              let processingStatus = OwnerTruthMediaProcessingStatus(rawValue: processingRaw),
              let processingGeneration = OwnerTruthMediaCaptureContract.nonNegativeInt(
                  object["processingGeneration"]
              ),
              let externalProcessingAllowed = OwnerTruthMediaCaptureContract.strictBool(
                  object["externalProcessingAllowed"]
              ),
              let retryable = OwnerTruthMediaCaptureContract.strictBool(object["retryable"]),
              OwnerTruthMediaCaptureContract.optionalStringIsValid(object["failureCode"]),
              OwnerTruthMediaCaptureContract.optionalRecordIDIsValid(object["derivedSourceId"]),
              let updatedAt = OwnerTruthMediaCaptureContract.iso8601Date(object["updatedAt"]) else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "SourceObject response contains invalid fields: "
                    + OwnerTruthMediaCaptureContract.invalidSourceObjectFields(in: object).joined(separator: ",")
            )
        }
        let magicMime = OwnerTruthMediaCaptureContract.optionalString(object["magicMime"])
        let safetyProvider = OwnerTruthMediaCaptureContract.optionalString(object["safetyProvider"])
        let failureCode = OwnerTruthMediaCaptureContract.optionalString(object["failureCode"])
        let derivedSourceID = OwnerTruthMediaCaptureContract.optionalRecordID(
            object["derivedSourceId"]
        )
        guard mediaKind.supportedContentTypes.contains(contentType),
              processingStatus != .succeeded || state == .processed,
              state != .processed || derivedSourceID != nil else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "SourceObject response state is internally inconsistent"
            )
        }

        self.sourceObjectID = sourceObjectID
        self.mediaKind = mediaKind
        self.state = state
        self.contentType = contentType
        self.magicMime = magicMime
        self.fileName = fileName
        self.fileSizeBytes = fileSizeBytes
        self.contentSHA256 = contentSHA256
        self.safetyStatus = safetyStatus
        self.safetyProvider = safetyProvider
        self.processingStatus = processingStatus
        self.processingGeneration = processingGeneration
        self.externalProcessingAllowed = externalProcessingAllowed
        self.retryable = retryable
        self.failureCode = failureCode
        self.derivedSourceID = derivedSourceID
        self.updatedAt = updatedAt
    }
}

struct OwnerTruthMediaUploadIntentReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-media-upload-intent-v1"

    struct UploadIntent: Equatable, Sendable {
        let uploadIntentID: OwnerTruthRecordID
        let state: OwnerTruthMediaUploadIntentState
        let expiresAt: Date
        let requiresClientUpload: Bool
        let uploadToken: OwnerTruthMediaUploadToken?
    }

    let vaultID: OwnerTruthVaultID
    let outcome: OwnerTruthMediaUploadIntentOutcome
    let sourceObject: OwnerTruthMediaSourceObjectReceipt
    let uploadIntent: UploadIntent

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == [
            "schemaVersion", "status", "vaultId", "sourceObject", "uploadIntent",
        ],
        OwnerTruthMediaCaptureContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
        OwnerTruthMediaCaptureContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
        let outcomeRaw = OwnerTruthMediaCaptureContract.requiredString(object["status"]),
        let outcome = OwnerTruthMediaUploadIntentOutcome(rawValue: outcomeRaw),
        let sourceObjectJSON = object["sourceObject"] as? [String: Any],
        let uploadIntentJSON = object["uploadIntent"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture("upload intent envelope is invalid")
        }
        let expectedIntentKeys = OwnerTruthMediaCaptureContract.uploadIntentKeys.union(
            uploadIntentJSON["uploadToken"] == nil ? [] : ["uploadToken"]
        )
        guard Set(uploadIntentJSON.keys) == expectedIntentKeys,
              let uploadIntentID = OwnerTruthMediaCaptureContract.recordID(
                uploadIntentJSON["uploadIntentId"]
              ),
              let stateRaw = OwnerTruthMediaCaptureContract.requiredString(uploadIntentJSON["state"]),
              let state = OwnerTruthMediaUploadIntentState(rawValue: stateRaw),
              let expiresAt = OwnerTruthMediaCaptureContract.iso8601Date(uploadIntentJSON["expiresAt"]),
              OwnerTruthMediaCaptureContract.requiredString(uploadIntentJSON["transport"])
                == "authenticatedDirectUpload",
              OwnerTruthMediaCaptureContract.requiredString(uploadIntentJSON["uploadMethod"]) == "PUT",
              OwnerTruthMediaCaptureContract.requiredString(uploadIntentJSON["uploadTokenHeader"])
                == "X-DreamJourney-Upload-Token",
              let requiresClientUpload = OwnerTruthMediaCaptureContract.strictBool(
                  uploadIntentJSON["requiresClientUpload"]
              ) else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture("upload intent receipt is invalid")
        }
        let token = (uploadIntentJSON["uploadToken"] as? String)
            .flatMap(OwnerTruthMediaUploadToken.init)
        guard (uploadIntentJSON["uploadToken"] == nil || token != nil),
              (outcome != .created || !requiresClientUpload || token != nil),
              (outcome != .deduplicated || token == nil),
              (state == .pending) == requiresClientUpload else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "upload token or upload state does not match the intent outcome"
            )
        }

        vaultID = expectedVaultID
        self.outcome = outcome
        sourceObject = try OwnerTruthMediaSourceObjectReceipt(backendJSONObject: sourceObjectJSON)
        uploadIntent = UploadIntent(
            uploadIntentID: uploadIntentID,
            state: state,
            expiresAt: expiresAt,
            requiresClientUpload: requiresClientUpload,
            uploadToken: token
        )
    }
}

struct OwnerTruthMediaSourceObjectResponse: Equatable, Sendable {
    static let schemaVersion = "owner-truth-media-source-object-v1"

    let vaultID: OwnerTruthVaultID
    let status: OwnerTruthMediaSourceObjectResponseStatus?
    let sourceObject: OwnerTruthMediaSourceObjectReceipt

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedSourceObjectID: OwnerTruthRecordID? = nil
    ) throws {
        let expectedKeys: Set<String> = object["status"] == nil
            ? ["schemaVersion", "vaultId", "sourceObject"]
            : ["schemaVersion", "vaultId", "sourceObject", "status"]
        guard Set(object.keys) == expectedKeys,
              OwnerTruthMediaCaptureContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthMediaCaptureContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let sourceObjectJSON = object["sourceObject"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture("SourceObject envelope is invalid")
        }
        let status: OwnerTruthMediaSourceObjectResponseStatus?
        if object["status"] == nil {
            status = nil
        } else {
            guard let rawStatus = OwnerTruthMediaCaptureContract.requiredString(object["status"]),
                  let parsed = OwnerTruthMediaSourceObjectResponseStatus(rawValue: rawStatus) else {
                throw OwnerTruthRemoteContractError.invalidMediaCapture("SourceObject outcome is invalid")
            }
            status = parsed
        }
        let sourceObject = try OwnerTruthMediaSourceObjectReceipt(
            backendJSONObject: sourceObjectJSON
        )
        guard expectedSourceObjectID == nil || expectedSourceObjectID == sourceObject.sourceObjectID else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture("SourceObject identity changed")
        }

        vaultID = expectedVaultID
        self.status = status
        self.sourceObject = sourceObject
    }
}

/// Value-minimized receipt for an accepted SourceObject deletion. `pending`
/// means access has already been revoked while server-owned physical cleanup is
/// still outstanding; it never means the client may retry processing or read
/// the object again.
struct OwnerTruthMediaDeletionReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-media-deletion-response-v1"

    let vaultID: OwnerTruthVaultID
    let outcome: OwnerTruthMediaDeletionOutcome
    let sourceObject: OwnerTruthMediaSourceObjectReceipt
    let accessState: OwnerTruthMediaAccessState
    let deletionStatus: OwnerTruthMediaDeletionStatus
    let retryable: Bool
    let failureCode: String?
    let updatedAt: Date

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedSourceObjectID: OwnerTruthRecordID
    ) throws {
        guard Set(object.keys) == [
            "schemaVersion", "status", "vaultId", "sourceObject", "deletion",
        ],
        OwnerTruthMediaCaptureContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
        OwnerTruthMediaCaptureContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
        let outcomeRaw = OwnerTruthMediaCaptureContract.requiredString(object["status"]),
        let outcome = OwnerTruthMediaDeletionOutcome(rawValue: outcomeRaw),
        let sourceObjectJSON = object["sourceObject"] as? [String: Any],
        let deletionJSON = object["deletion"] as? [String: Any],
        Set(deletionJSON.keys) == OwnerTruthMediaCaptureContract.deletionReceiptKeys,
        let accessStateRaw = OwnerTruthMediaCaptureContract.requiredString(deletionJSON["accessState"]),
        let accessState = OwnerTruthMediaAccessState(rawValue: accessStateRaw),
        let deletionStatusRaw = OwnerTruthMediaCaptureContract.requiredString(deletionJSON["deletionStatus"]),
        let deletionStatus = OwnerTruthMediaDeletionStatus(rawValue: deletionStatusRaw),
        let retryable = OwnerTruthMediaCaptureContract.strictBool(deletionJSON["retryable"]),
        OwnerTruthMediaCaptureContract.optionalStringIsValid(deletionJSON["failureCode"]),
        let updatedAt = OwnerTruthMediaCaptureContract.iso8601Date(deletionJSON["updatedAt"]) else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "media deletion receipt is invalid"
            )
        }

        let sourceObject = try OwnerTruthMediaSourceObjectReceipt(backendJSONObject: sourceObjectJSON)
        let failureCode = OwnerTruthMediaCaptureContract.optionalString(deletionJSON["failureCode"])
        guard sourceObject.sourceObjectID == expectedSourceObjectID,
              sourceObject.state == .deleted,
              sourceObject.processingStatus == .blocked,
              accessState == .accessRevoked,
              deletionStatus != .notRequested,
              !(deletionStatus == .completed && (retryable || failureCode != nil)),
              !((deletionStatus == .partial || deletionStatus == .unsupported) && failureCode == nil) else {
            throw OwnerTruthRemoteContractError.invalidMediaCapture(
                "media deletion receipt is internally inconsistent"
            )
        }

        vaultID = expectedVaultID
        self.outcome = outcome
        self.sourceObject = sourceObject
        self.accessState = accessState
        self.deletionStatus = deletionStatus
        self.retryable = retryable
        self.failureCode = failureCode
        self.updatedAt = updatedAt
    }
}

protocol OwnerTruthMediaCaptureClient: AnyObject {
    func createOwnerTruthMediaUploadIntent(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthMediaUploadIntentCommand,
        completion: @escaping (Result<OwnerTruthMediaUploadIntentReceipt, Error>) -> Void
    )

    func uploadOwnerTruthMediaContent(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        uploadIntentID: OwnerTruthRecordID,
        uploadToken: OwnerTruthMediaUploadToken,
        contentType: String,
        content: Data,
        completion: @escaping (Result<OwnerTruthMediaSourceObjectResponse, Error>) -> Void
    )

    func fetchOwnerTruthMediaSourceObject(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        sourceObjectID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthMediaSourceObjectResponse, Error>) -> Void
    )

    func retryOwnerTruthMediaProcessing(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        sourceObjectID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthMediaSourceObjectResponse, Error>) -> Void
    )

    func requestOwnerTruthMediaDeletion(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        sourceObjectID: OwnerTruthRecordID,
        command: OwnerTruthMediaDeletionCommand,
        completion: @escaping (Result<OwnerTruthMediaDeletionReceipt, Error>) -> Void
    )

    func retryOwnerTruthMediaDeletion(
        accountLease: AccountLease,
        vaultID: OwnerTruthVaultID,
        sourceObjectID: OwnerTruthRecordID,
        command: OwnerTruthMediaDeletionCommand,
        completion: @escaping (Result<OwnerTruthMediaDeletionReceipt, Error>) -> Void
    )
}

private enum OwnerTruthMediaCaptureContract {
    static let sourceObjectKeys: Set<String> = [
        "sourceObjectId", "mediaKind", "state", "contentType", "magicMime",
        "fileName", "fileSizeBytes", "contentSha256", "safetyStatus", "safetyProvider",
        "processingStatus", "processingGeneration", "externalProcessingAllowed", "retryable",
        "failureCode", "derivedSourceId", "updatedAt",
    ]
    static let uploadIntentKeys: Set<String> = [
        "uploadIntentId", "state", "expiresAt", "transport", "uploadMethod",
        "uploadTokenHeader", "requiresClientUpload",
    ]
    static let deletionReceiptKeys: Set<String> = [
        "accessState", "deletionStatus", "retryable", "failureCode", "updatedAt",
    ]

    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func optionalString(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return requiredString(value)
    }

    static func optionalStringIsValid(_ value: Any?) -> Bool {
        guard let value, !(value is NSNull) else { return true }
        return requiredString(value) != nil
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let rawValue = requiredString(value), let uuid = UUID(uuidString: rawValue) else {
            return nil
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func optionalRecordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let value, !(value is NSNull) else { return nil }
        return recordID(value)
    }

    static func optionalRecordIDIsValid(_ value: Any?) -> Bool {
        guard let value, !(value is NSNull) else { return true }
        return recordID(value) != nil
    }

    static func positiveInt(_ value: Any?) -> Int? {
        guard !isJSONBoolean(value), let value = value as? Int, value > 0 else { return nil }
        return value
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard !isJSONBoolean(value), let value = value as? Int, value >= 0 else { return nil }
        return value
    }

    static func strictBool(_ value: Any?) -> Bool? {
        guard isJSONBoolean(value), let value = value as? Bool else { return nil }
        return value
    }

    private static func isJSONBoolean(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    static func sha256(_ value: Any?) -> String? {
        guard let value = requiredString(value)?.lowercased(),
              value.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    static func iso8601Date(_ value: Any?) -> Date? {
        guard let rawValue = requiredString(value) else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: rawValue) ?? ISO8601DateFormatter().date(from: rawValue)
    }

    static func iso8601String(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }

    static func invalidSourceObjectFields(in object: [String: Any]) -> [String] {
        var invalid: [String] = []
        if recordID(object["sourceObjectId"]) == nil { invalid.append("sourceObjectId") }
        if requiredString(object["mediaKind"]).flatMap(OwnerTruthMediaKind.init(rawValue:)) == nil {
            invalid.append("mediaKind")
        }
        if requiredString(object["state"]).flatMap(OwnerTruthMediaSourceObjectState.init(rawValue:)) == nil {
            invalid.append("state")
        }
        if requiredString(object["contentType"]) == nil { invalid.append("contentType") }
        if !optionalStringIsValid(object["magicMime"]) { invalid.append("magicMime") }
        if requiredString(object["fileName"]) == nil { invalid.append("fileName") }
        if positiveInt(object["fileSizeBytes"]) == nil { invalid.append("fileSizeBytes") }
        if sha256(object["contentSha256"]) == nil { invalid.append("contentSha256") }
        if requiredString(object["safetyStatus"]).flatMap(OwnerTruthMediaSafetyStatus.init(rawValue:)) == nil {
            invalid.append("safetyStatus")
        }
        if !optionalStringIsValid(object["safetyProvider"]) { invalid.append("safetyProvider") }
        if requiredString(object["processingStatus"])
            .flatMap(OwnerTruthMediaProcessingStatus.init(rawValue:)) == nil {
            invalid.append("processingStatus")
        }
        if nonNegativeInt(object["processingGeneration"]) == nil {
            invalid.append("processingGeneration")
        }
        if strictBool(object["externalProcessingAllowed"]) == nil {
            invalid.append("externalProcessingAllowed")
        }
        if strictBool(object["retryable"]) == nil { invalid.append("retryable") }
        if !optionalStringIsValid(object["failureCode"]) { invalid.append("failureCode") }
        if !optionalRecordIDIsValid(object["derivedSourceId"]) { invalid.append("derivedSourceId") }
        if iso8601Date(object["updatedAt"]) == nil { invalid.append("updatedAt") }
        return invalid.sorted()
    }
}

enum OwnerTruthTextSourceCapturePhase: Equatable, Sendable {
    case idle
    case readingAuthority
    case submitting
    case accepted
    case unavailable
    case failed
}

enum OwnerTruthTextSourceCaptureNotice: Equatable, Sendable {
    case releasePolicyUnavailable
    case accountUnavailable
    case staleAccountLease
    case invalidVault
    case invalidText
    case authorityReadFailed
    case receiptMismatch
    case captureFailed
    case submissionInProgress
}

enum OwnerTruthTextSourceCaptureUseCaseError: LocalizedError, Equatable, Sendable {
    case unavailable(OwnerTruthTextSourceCaptureNotice)
    case failed(OwnerTruthTextSourceCaptureNotice)

    var errorDescription: String? {
        switch self {
        case .unavailable(.releasePolicyUnavailable):
            return "当前账号暂未开通待确认记忆"
        case .unavailable(.accountUnavailable), .unavailable(.staleAccountLease):
            return "账号已变化，请重新进入后再提交"
        case .unavailable(.invalidVault):
            return "当前档案空间暂不可提交待确认记忆"
        case .failed(.invalidText):
            return "请先写下一段记忆"
        case .failed(.authorityReadFailed):
            return "暂时无法确认记忆提交状态，请稍后重试"
        case .failed(.receiptMismatch):
            return "提交结果不完整，请稍后重试"
        case .failed(.captureFailed):
            return "暂时无法提交待确认记忆，请保持内容后重试"
        case .failed(.submissionInProgress):
            return "正在提交待确认记忆"
        case .unavailable, .failed:
            return "待确认记忆暂不可提交"
        }
    }
}

struct OwnerTruthTextSourceCaptureViewState: Equatable, Sendable {
    let phase: OwnerTruthTextSourceCapturePhase
    let notice: OwnerTruthTextSourceCaptureNotice?
    let receipt: OwnerTruthTextSourceCaptureReceipt?

    static let idle = OwnerTruthTextSourceCaptureViewState(
        phase: .idle,
        notice: nil,
        receipt: nil
    )
}

/// Lease-fenced client workflow for the closed-pilot text Source entry.
///
/// The pending command stays in memory only while the entry sheet is open. A
/// retry reuses the exact same command ID and payload, so a lost response
/// cannot create a second Source. A transient delivery failure keeps the raw
/// text only in this live sheet so the user can retry; acceptance, policy or
/// account changes clear it. It is never written to a local retry queue.
final class OwnerTruthTextSourceCaptureUseCase {
    typealias CommandIDFactory = () -> UUID
    typealias Completion = (Result<OwnerTruthTextSourceCaptureReceipt, OwnerTruthTextSourceCaptureUseCaseError>) -> Void

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthTextSourceCaptureClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let commandIDFactory: CommandIDFactory

    private var pendingText: String?
    private var pendingCommandID: UUID?
    private var preparedCommand: OwnerTruthTextSourceCaptureCommand?
    private var pendingCompletion: Completion?
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthTextSourceCaptureViewState = .idle {
        didSet {
            onViewStateChange?(viewState)
        }
    }

    var onViewStateChange: ((OwnerTruthTextSourceCaptureViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthTextSourceCaptureClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool,
        commandIDFactory: @escaping CommandIDFactory = UUID.init
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.commandIDFactory = commandIDFactory
    }

    func submit(_ text: String, completion: @escaping Completion) {
        guard !isInFlight else {
            completion(.failure(.failed(.submissionInProgress)))
            return
        }

        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            transitionFailure(.invalidText, completion: completion)
            return
        }

        pendingCompletion = completion
        if pendingText != normalizedText {
            clearPendingCommand()
            pendingText = normalizedText
            pendingCommandID = commandIDFactory()
        }

        if preparedCommand != nil {
            submitPreparedCommand()
        } else {
            readAuthorityState()
        }
    }

    private var isInFlight: Bool {
        switch viewState.phase {
        case .readingAuthority, .submitting:
            return true
        case .idle, .accepted, .unavailable, .failed:
            return false
        }
    }

    private func readAuthorityState() {
        guard validateRequestBoundary() else { return }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthTextSourceCaptureViewState(
            phase: .readingAuthority,
            notice: nil,
            receipt: nil
        )
        client.fetchOwnerTruthTextSourceCaptureState(vaultID: vaultID) { [weak self] result in
            self?.receiveAuthorityState(result, vaultID: vaultID, generation: generation)
        }
    }

    private func receiveAuthorityState(
        _ result: Result<OwnerTruthTextSourceCaptureState, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard validateCommitBoundary() else { return }

        switch result {
        case .success(let state):
            guard state.vaultID == vaultID,
                  state.vaultID.rawValue == accountLease.vaultId,
                  let text = pendingText,
                  let commandID = pendingCommandID else {
                transitionFailure(.receiptMismatch)
                return
            }
            do {
                preparedCommand = try OwnerTruthTextSourceCaptureCommand(
                    commandID: commandID,
                    expectedAuthorityEpoch: state.authorityEpoch,
                    text: text
                )
            } catch {
                clearPendingCommand()
                transitionFailure(.invalidText)
                return
            }
            submitPreparedCommand()
        case .failure:
            transitionFailure(.authorityReadFailed)
        }
    }

    private func submitPreparedCommand() {
        guard validateRequestBoundary() else { return }
        guard let vaultID,
              let command = preparedCommand else {
            transitionFailure(.captureFailed)
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthTextSourceCaptureViewState(
            phase: .submitting,
            notice: nil,
            receipt: nil
        )
        client.captureOwnerTruthTextSource(vaultID: vaultID, command: command) { [weak self] result in
            self?.receiveCaptureReceipt(
                result,
                vaultID: vaultID,
                command: command,
                generation: generation
            )
        }
    }

    private func receiveCaptureReceipt(
        _ result: Result<OwnerTruthTextSourceCaptureReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthTextSourceCaptureCommand,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard validateCommitBoundary() else { return }

        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID,
                  receipt.authorityEpoch == command.expectedAuthorityEpoch else {
                transitionFailure(.receiptMismatch)
                return
            }
            viewState = OwnerTruthTextSourceCaptureViewState(
                phase: .accepted,
                notice: nil,
                receipt: receipt
            )
            clearPendingCommand()
            finish(.success(receipt))
        case .failure:
            // Keep the exact command in memory for an idempotent retry.
            transitionFailure(.captureFailed)
        }
    }

    @discardableResult
    private func validateRequestBoundary() -> Bool {
        guard releasePolicyAvailable() else {
            transitionUnavailable(.releasePolicyUnavailable)
            return false
        }
        guard vaultID != nil else {
            transitionUnavailable(.invalidVault)
            return false
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return false
        }
        return true
    }

    @discardableResult
    private func validateCommitBoundary() -> Bool {
        guard releasePolicyAvailable() else {
            transitionUnavailable(.releasePolicyUnavailable)
            return false
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            transitionUnavailable(.staleAccountLease)
            return false
        }
        return true
    }

    private func transitionUnavailable(_ notice: OwnerTruthTextSourceCaptureNotice) {
        operationGeneration &+= 1
        clearPendingCommand()
        viewState = OwnerTruthTextSourceCaptureViewState(
            phase: .unavailable,
            notice: notice,
            receipt: nil
        )
        finish(.failure(.unavailable(notice)))
    }

    private func transitionFailure(
        _ notice: OwnerTruthTextSourceCaptureNotice,
        completion: Completion? = nil
    ) {
        viewState = OwnerTruthTextSourceCaptureViewState(
            phase: .failed,
            notice: notice,
            receipt: nil
        )
        if let completion {
            completion(.failure(.failed(notice)))
        } else {
            finish(.failure(.failed(notice)))
        }
    }

    private func clearPendingCommand() {
        pendingText = nil
        pendingCommandID = nil
        preparedCommand = nil
    }

    private func finish(_ result: Result<OwnerTruthTextSourceCaptureReceipt, OwnerTruthTextSourceCaptureUseCaseError>) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result)
    }
}

private enum OwnerTruthTextSourceCaptureContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let value = requiredString(value), let uuid = UUID(uuidString: value) else {
            return nil
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func positiveInt(_ value: Any?) -> Int? {
        guard !(value is Bool), let value = value as? Int, value > 0 else { return nil }
        return value
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard !(value is Bool), let value = value as? Int, value >= 0 else { return nil }
        return value
    }

    static func iso8601Date(_ value: Any?) -> Date? {
        guard let rawValue = requiredString(value) else { return nil }
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardFormatter = ISO8601DateFormatter()
        return fractionalFormatter.date(from: rawValue) ?? standardFormatter.date(from: rawValue)
    }
}

enum OwnerTruthCandidateReviewQAGate {
    static let launchArgument = "DJEnableOwnerTruthCandidateReviewQA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        return false
        #endif
    }
}

/// Narrow port consumed by the hidden Archive review use case. The concrete
/// backend client owns transport, authentication and QA headers; the use case
/// owns lease checks, intent mapping and ViewState only.
protocol OwnerTruthCandidateReviewClient: AnyObject {
    func fetchOwnerTruthCandidateInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthCandidateInbox, Error>) -> Void
    )

    func reviewOwnerTruthCandidate(
        vaultID: OwnerTruthVaultID,
        candidateID: OwnerTruthRecordID,
        command: OwnerTruthCandidateReviewCommand,
        completion: @escaping (Result<OwnerTruthCandidateDecisionResult, Error>) -> Void
    )

    func fetchOwnerTruthCandidateReviewHistory(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthCandidateReviewHistory, Error>) -> Void
    )

    func fetchOwnerTruthMemoryVersionHistory(
        vaultID: OwnerTruthVaultID,
        memoryID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthMemoryVersionHistory, Error>) -> Void
    )
}

// MARK: - Default-off interview Candidate review

/// The private interview lane has its own review contract. It must not reuse
/// the generic Candidate Inbox because the generic route may activate a
/// MemoryVersion, while this lane deliberately stops at a DecisionReceipt.
enum OwnerTruthInterviewCandidateReviewReadiness: String, Codable, Equatable, Sendable {
    case awaitingExtraction
    case reviewReady
    case noCandidates
    case extractionFailed
    case extractionQuarantined
}

enum OwnerTruthInterviewCandidateReviewPath: String, Codable, Equatable, Sendable {
    case batch
    case single
}

struct OwnerTruthInterviewCandidateReviewItem: Equatable, Sendable, Identifiable {
    let candidate: OwnerTruthCandidateInboxItem
    let extractionID: OwnerTruthRecordID
    let reviewPath: OwnerTruthInterviewCandidateReviewPath

    var id: OwnerTruthRecordID { candidate.id }

    init(
        backendJSONObject object: [String: Any],
        vaultID: OwnerTruthVaultID,
        expectedPath: OwnerTruthInterviewCandidateReviewPath
    ) throws {
        guard let extractionID = OwnerTruthCandidateEvidenceReference.recordID(object["extractionId"]),
              let rawPath = OwnerTruthInterviewCandidateContract.requiredString(object["reviewPath"]),
              let reviewPath = OwnerTruthInterviewCandidateReviewPath(rawValue: rawPath),
              reviewPath == expectedPath else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateReview(
                "review item has an invalid path or extraction reference"
            )
        }
        self.candidate = try OwnerTruthCandidateInboxItem(
            backendJSONObject: object,
            vaultID: vaultID
        )
        self.extractionID = extractionID
        self.reviewPath = reviewPath
    }
}

struct OwnerTruthInterviewCandidateReviewBatch: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-review-read-v1"
    static let compositionSchemaVersion = "owner-truth-interview-candidate-review-v1"

    let vaultID: OwnerTruthVaultID
    let reviewBatchID: OwnerTruthRecordID
    let admissionID: OwnerTruthRecordID
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int
    let authorityEpoch: Int
    let readiness: OwnerTruthInterviewCandidateReviewReadiness
    let latestExtractionStatus: String?
    let selectedExtractionID: OwnerTruthRecordID?
    let batchCandidates: [OwnerTruthInterviewCandidateReviewItem]
    let singleCandidates: [OwnerTruthInterviewCandidateReviewItem]

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedReviewBatchID: OwnerTruthRecordID
    ) throws {
        guard OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewCandidateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let review = object["review"] as? [String: Any],
              OwnerTruthInterviewCandidateContract.requiredString(review["schemaVersion"])
                == Self.compositionSchemaVersion,
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(review["reviewBatchId"]),
              reviewBatchID == expectedReviewBatchID,
              let admissionID = OwnerTruthCandidateEvidenceReference.recordID(review["admissionId"]),
              let sourceID = OwnerTruthCandidateEvidenceReference.recordID(review["sourceId"]),
              let sourceVersion = OwnerTruthCandidateEvidenceReference.positiveInt(review["sourceVersion"]),
              let authorityEpoch = OwnerTruthInterviewCandidateContract.nonNegativeInt(review["authorityEpoch"]),
              let readinessRaw = OwnerTruthInterviewCandidateContract.requiredString(review["readiness"]),
              let readiness = OwnerTruthInterviewCandidateReviewReadiness(rawValue: readinessRaw),
              let batchObjects = object["batchCandidates"] as? [[String: Any]],
              let singleObjects = object["singleCandidates"] as? [[String: Any]],
              let batchCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(review["batchCandidateCount"]),
              let singleCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(review["singleCandidateCount"]),
              batchCount == batchObjects.count,
              singleCount == singleObjects.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateReview(
                "review batch response misses a required typed field"
            )
        }

        let batchCandidates = try batchObjects.map {
            try OwnerTruthInterviewCandidateReviewItem(
                backendJSONObject: $0,
                vaultID: expectedVaultID,
                expectedPath: .batch
            )
        }
        let singleCandidates = try singleObjects.map {
            try OwnerTruthInterviewCandidateReviewItem(
                backendJSONObject: $0,
                vaultID: expectedVaultID,
                expectedPath: .single
            )
        }
        let identifiers = batchCandidates.map(\.id) + singleCandidates.map(\.id)
        guard Set(identifiers).count == identifiers.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateReview(
                "review batch contains the same Candidate more than once"
            )
        }
        if readiness == .reviewReady {
            guard !identifiers.isEmpty else {
                throw OwnerTruthRemoteContractError.invalidInterviewCandidateReview(
                    "reviewReady response must contain at least one pending Candidate"
                )
            }
        } else if !identifiers.isEmpty {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateReview(
                "non-ready response must not expose pending Candidates"
            )
        }
        let selectedExtractionID = try Self.resolveSelectedExtractionID(
            composition: review,
            candidates: batchCandidates + singleCandidates,
            error: OwnerTruthRemoteContractError.invalidInterviewCandidateReview
        )

        vaultID = expectedVaultID
        self.reviewBatchID = reviewBatchID
        self.admissionID = admissionID
        self.sourceID = sourceID
        self.sourceVersion = sourceVersion
        self.authorityEpoch = authorityEpoch
        self.readiness = readiness
        self.latestExtractionStatus = try OwnerTruthInterviewCandidateContract.optionalString(
            review["latestExtractionStatus"],
            field: "latestExtractionStatus"
        )
        self.selectedExtractionID = selectedExtractionID
        self.batchCandidates = batchCandidates
        self.singleCandidates = singleCandidates
    }

    static func resolveSelectedExtractionID(
        composition: [String: Any],
        candidates: [OwnerTruthInterviewCandidateReviewItem],
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> OwnerTruthRecordID? {
        let candidateExtractionIDs = Set(candidates.map(\.extractionID))
        let explicitSelectedExtractionID: OwnerTruthRecordID?
        if let rawValue = composition["selectedExtractionId"], !(rawValue is NSNull) {
            guard let selected = OwnerTruthCandidateEvidenceReference.recordID(rawValue) else {
                throw error("selectedExtractionId must be a UUID or null")
            }
            explicitSelectedExtractionID = selected
        } else {
            explicitSelectedExtractionID = nil
        }

        if let explicitSelectedExtractionID {
            guard candidateExtractionIDs.isEmpty
                || candidateExtractionIDs == Set([explicitSelectedExtractionID]) else {
                throw error("review candidates do not match selectedExtractionId")
            }
            return explicitSelectedExtractionID
        }
        guard candidateExtractionIDs.count <= 1 else {
            throw error("review response mixes Candidate ExtractionResult baselines")
        }
        return candidateExtractionIDs.first
    }
}

/// In-memory binding added only after a confirmation projection has passed a
/// request/commit AccountLease validation. It is deliberately not Codable and
/// never crosses the backend boundary.
private struct OwnerTruthInterviewCandidateConfirmationLeaseBinding: Equatable, Sendable {
    let accountLease: AccountLease

    func matches(_ accountLease: AccountLease) -> Bool {
        self.accountLease == accountLease
    }
}

/// A confirmation inbox is only a content-free batch discovery projection. It
/// receives its own binding type so it cannot accidentally be treated as a
/// per-batch confirmation with Candidate material.
private struct OwnerTruthInterviewCandidateConfirmationInboxLeaseBinding: Equatable, Sendable {
    let accountLease: AccountLease

    func matches(_ accountLease: AccountLease) -> Bool {
        self.accountLease == accountLease
    }
}

/// Opaque, content-free metadata used to discover one formal confirmation
/// batch. A caller must perform the separately governed per-batch read before
/// it can receive Candidate, Source, admission, or receipt data.
struct OwnerTruthInterviewCandidateConfirmationInboxItem: Equatable, Sendable, Identifiable {
    let reviewBatchID: OwnerTruthRecordID
    let readiness: OwnerTruthInterviewCandidateReviewReadiness
    let batchCandidateCount: Int
    let singleCandidateCount: Int

    var id: OwnerTruthRecordID { reviewBatchID }

    init(backendJSONObject object: [String: Any]) throws {
        let allowedKeys: Set<String> = [
            "reviewBatchId",
            "readiness",
            "batchCandidateCount",
            "singleCandidateCount",
        ]
        guard Set(object.keys).isSubset(of: allowedKeys),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              let readinessRaw = OwnerTruthInterviewCandidateContract.requiredString(object["readiness"]),
              let readiness = OwnerTruthInterviewCandidateReviewReadiness(rawValue: readinessRaw),
              let batchCandidateCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(object["batchCandidateCount"]),
              let singleCandidateCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(object["singleCandidateCount"]) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmationInbox(
                "confirmation inbox item misses a required content-free field"
            )
        }

        self.reviewBatchID = reviewBatchID
        self.readiness = readiness
        self.batchCandidateCount = batchCandidateCount
        self.singleCandidateCount = singleCandidateCount
    }
}

/// Formal confirmation batch discovery. This is intentionally not Codable and
/// rejects unexpected fields, so future product code cannot silently turn the
/// discovery endpoint into a Candidate content transport.
struct OwnerTruthInterviewCandidateConfirmationInbox: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-confirmation-inbox-v1"

    let vaultID: OwnerTruthVaultID
    let items: [OwnerTruthInterviewCandidateConfirmationInboxItem]
    private var leaseBinding: OwnerTruthInterviewCandidateConfirmationInboxLeaseBinding?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        let allowedKeys: Set<String> = ["schemaVersion", "vaultId", "confirmations"]
        guard Set(object.keys).isSubset(of: allowedKeys),
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewCandidateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let itemObjects = object["confirmations"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmationInbox(
                "schemaVersion, vaultId or confirmations does not match the contract"
            )
        }

        let items = try itemObjects.map(OwnerTruthInterviewCandidateConfirmationInboxItem.init)
        guard Set(items.map(\.reviewBatchID)).count == items.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmationInbox(
                "confirmation inbox repeats a review batch"
            )
        }

        vaultID = expectedVaultID
        self.items = items
        leaseBinding = nil
    }

    /// A remote discovery payload becomes usable only after the AccountLease
    /// that passed the completion fence binds it in memory.
    func bound(to accountLease: AccountLease) -> Self {
        var copy = self
        copy.leaseBinding = OwnerTruthInterviewCandidateConfirmationInboxLeaseBinding(
            accountLease: accountLease
        )
        return copy
    }

    func isBound(to accountLease: AccountLease) -> Bool {
        leaseBinding?.matches(accountLease) == true
    }
}

/// Separate lease binding for the value-minimized activation inbox. A pending
/// activation is not a pending Candidate and must not inherit the confirmation
/// inbox binding by accident.
private struct OwnerTruthInterviewCandidateMemoryActivationInboxLeaseBinding: Equatable, Sendable {
    let accountLease: AccountLease

    func matches(_ accountLease: AccountLease) -> Bool {
        self.accountLease == accountLease
    }
}

/// One value-free handle for a formally confirmed Candidate whose
/// MemoryVersion has not been created yet. It intentionally contains no
/// Candidate text, DecisionReceipt, or MemoryVersion identifier.
struct OwnerTruthInterviewCandidateMemoryActivationInboxItem: Equatable, Sendable, Identifiable {
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID

    var id: OwnerTruthRecordID { candidateID }

    init(backendJSONObject object: [String: Any]) throws {
        let allowedKeys: Set<String> = ["reviewBatchId", "candidateId"]
        guard Set(object.keys).isSubset(of: allowedKeys),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              let candidateID = OwnerTruthCandidateEvidenceReference.recordID(object["candidateId"]) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateMemoryActivationInbox(
                "activation inbox item must contain only reviewBatchId and candidateId"
            )
        }
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
    }
}

/// Formal, default-off recovery projection for explicit MemoryVersion
/// activation. It is deliberately content-free, strict about schema fields,
/// and bound in memory after the same account lease used for the request has
/// passed its completion fence.
struct OwnerTruthInterviewCandidateMemoryActivationInbox: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-memory-activation-inbox-v1"

    let vaultID: OwnerTruthVaultID
    let items: [OwnerTruthInterviewCandidateMemoryActivationInboxItem]
    private var leaseBinding: OwnerTruthInterviewCandidateMemoryActivationInboxLeaseBinding?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        let allowedKeys: Set<String> = ["schemaVersion", "vaultId", "items"]
        guard Set(object.keys).isSubset(of: allowedKeys),
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewCandidateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let itemObjects = object["items"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateMemoryActivationInbox(
                "schemaVersion, vaultId or items does not match the contract"
            )
        }

        let items = try itemObjects.map(OwnerTruthInterviewCandidateMemoryActivationInboxItem.init)
        let activationKeys = items.map {
            "\($0.reviewBatchID.rawValue.uuidString.lowercased()):\($0.candidateID.rawValue.uuidString.lowercased())"
        }
        guard Set(activationKeys).count == activationKeys.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateMemoryActivationInbox(
                "activation inbox repeats a review batch Candidate handle"
            )
        }

        vaultID = expectedVaultID
        self.items = items
        leaseBinding = nil
    }

    func bound(to accountLease: AccountLease) -> Self {
        var copy = self
        copy.leaseBinding = OwnerTruthInterviewCandidateMemoryActivationInboxLeaseBinding(
            accountLease: accountLease
        )
        return copy
    }

    func isBound(to accountLease: AccountLease) -> Bool {
        leaseBinding?.matches(accountLease) == true
    }
}

/// Separate lease binding for the value-minimized projection recovery inbox.
/// It must not be reusable as either a confirmation or activation capability.
private struct OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxLeaseBinding: Equatable, Sendable {
    let accountLease: AccountLease

    func matches(_ accountLease: AccountLease) -> Bool {
        self.accountLease == accountLease
    }
}

/// The only recovery state exposed to the client. Worker attempts, effect
/// identifiers, MemoryVersion identifiers, and record content remain server-side.
enum OwnerTruthInterviewCandidateMemoryProjectionRecoveryState: String, Equatable, Sendable {
    case rebuilding
}

/// One opaque handle for a formal MemoryVersion whose compatibility projection
/// is still being rebuilt. It is informational only and cannot trigger a
/// rebuild from the client.
struct OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxItem: Equatable, Sendable, Identifiable {
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let state: OwnerTruthInterviewCandidateMemoryProjectionRecoveryState

    var id: OwnerTruthRecordID { candidateID }

    init(backendJSONObject object: [String: Any]) throws {
        let allowedKeys: Set<String> = ["reviewBatchId", "candidateId", "state"]
        guard Set(object.keys).isSubset(of: allowedKeys),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              let candidateID = OwnerTruthCandidateEvidenceReference.recordID(object["candidateId"]),
              OwnerTruthInterviewCandidateMemoryProjectionRecoveryState(
                  rawValue: OwnerTruthInterviewCandidateContract.requiredString(object["state"]) ?? ""
              ) == .rebuilding else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateMemoryProjectionRecoveryInbox(
                "projection recovery item must contain only rebuilding state and opaque handles"
            )
        }
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
        state = .rebuilding
    }
}

/// Read-only, value-minimized discovery for an already activated formal memory
/// that is not materialized yet. The existing durable worker owns retry; this
/// contract deliberately provides no retry, rebuild, or detail command.
struct OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-memory-projection-recovery-inbox-v1"

    let vaultID: OwnerTruthVaultID
    let items: [OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxItem]
    private var leaseBinding: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxLeaseBinding?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        let allowedKeys: Set<String> = ["schemaVersion", "vaultId", "items"]
        guard Set(object.keys).isSubset(of: allowedKeys),
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewCandidateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let itemObjects = object["items"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateMemoryProjectionRecoveryInbox(
                "schemaVersion, vaultId or items does not match the contract"
            )
        }

        let items = try itemObjects.map(OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxItem.init)
        let recoveryKeys = items.map {
            "\($0.reviewBatchID.rawValue.uuidString.lowercased()):\($0.candidateID.rawValue.uuidString.lowercased())"
        }
        guard Set(recoveryKeys).count == recoveryKeys.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateMemoryProjectionRecoveryInbox(
                "projection recovery inbox repeats a review batch Candidate handle"
            )
        }

        vaultID = expectedVaultID
        self.items = items
        leaseBinding = nil
    }

    func bound(to accountLease: AccountLease) -> Self {
        var copy = self
        copy.leaseBinding = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxLeaseBinding(
            accountLease: accountLease
        )
        return copy
    }

    func isBound(to accountLease: AccountLease) -> Bool {
        leaseBinding?.matches(accountLease) == true
    }
}

/// Read-only confirmation material behind the separately captured product
/// policy. It deliberately has a distinct schema from the QA review route so
/// a future product surface cannot accidentally reuse a QA-only transport.
struct OwnerTruthInterviewCandidateConfirmation: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-confirmation-read-v1"
    static let compositionSchemaVersion = OwnerTruthInterviewCandidateReviewBatch.compositionSchemaVersion

    let vaultID: OwnerTruthVaultID
    let reviewBatchID: OwnerTruthRecordID
    let admissionID: OwnerTruthRecordID
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int
    let authorityEpoch: Int
    let readiness: OwnerTruthInterviewCandidateReviewReadiness
    let latestExtractionStatus: String?
    let selectedExtractionID: OwnerTruthRecordID?
    let batchCandidates: [OwnerTruthInterviewCandidateReviewItem]
    let singleCandidates: [OwnerTruthInterviewCandidateReviewItem]
    private var leaseBinding: OwnerTruthInterviewCandidateConfirmationLeaseBinding?

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedReviewBatchID: OwnerTruthRecordID
    ) throws {
        guard OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewCandidateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let confirmation = object["confirmation"] as? [String: Any],
              OwnerTruthInterviewCandidateContract.requiredString(confirmation["schemaVersion"])
                == Self.compositionSchemaVersion,
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(confirmation["reviewBatchId"]),
              reviewBatchID == expectedReviewBatchID,
              let admissionID = OwnerTruthCandidateEvidenceReference.recordID(confirmation["admissionId"]),
              let sourceID = OwnerTruthCandidateEvidenceReference.recordID(confirmation["sourceId"]),
              let sourceVersion = OwnerTruthCandidateEvidenceReference.positiveInt(confirmation["sourceVersion"]),
              let authorityEpoch = OwnerTruthInterviewCandidateContract.nonNegativeInt(confirmation["authorityEpoch"]),
              let readinessRaw = OwnerTruthInterviewCandidateContract.requiredString(confirmation["readiness"]),
              let readiness = OwnerTruthInterviewCandidateReviewReadiness(rawValue: readinessRaw),
              let batchObjects = object["batchCandidates"] as? [[String: Any]],
              let singleObjects = object["singleCandidates"] as? [[String: Any]],
              let batchCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(confirmation["batchCandidateCount"]),
              let singleCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(confirmation["singleCandidateCount"]),
              batchCount == batchObjects.count,
              singleCount == singleObjects.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmation(
                "confirmation response misses a required typed field"
            )
        }

        let batchCandidates: [OwnerTruthInterviewCandidateReviewItem]
        let singleCandidates: [OwnerTruthInterviewCandidateReviewItem]
        do {
            batchCandidates = try batchObjects.map {
                try OwnerTruthInterviewCandidateReviewItem(
                    backendJSONObject: $0,
                    vaultID: expectedVaultID,
                    expectedPath: .batch
                )
            }
            singleCandidates = try singleObjects.map {
                try OwnerTruthInterviewCandidateReviewItem(
                    backendJSONObject: $0,
                    vaultID: expectedVaultID,
                    expectedPath: .single
                )
            }
        } catch {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmation(
                "confirmation candidate item does not match the typed review contract"
            )
        }

        let identifiers = batchCandidates.map(\.id) + singleCandidates.map(\.id)
        guard Set(identifiers).count == identifiers.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmation(
                "confirmation contains the same Candidate more than once"
            )
        }
        if readiness == .reviewReady {
            guard !identifiers.isEmpty else {
                throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmation(
                    "reviewReady confirmation must contain at least one pending Candidate"
                )
            }
        } else if !identifiers.isEmpty {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmation(
                "non-ready confirmation must not expose pending Candidates"
            )
        }

        let selectedExtractionID = try OwnerTruthInterviewCandidateReviewBatch.resolveSelectedExtractionID(
            composition: confirmation,
            candidates: batchCandidates + singleCandidates,
            error: OwnerTruthRemoteContractError.invalidInterviewCandidateConfirmation
        )

        vaultID = expectedVaultID
        self.reviewBatchID = reviewBatchID
        self.admissionID = admissionID
        self.sourceID = sourceID
        self.sourceVersion = sourceVersion
        self.authorityEpoch = authorityEpoch
        self.readiness = readiness
        self.latestExtractionStatus = try OwnerTruthInterviewCandidateContract.optionalString(
            confirmation["latestExtractionStatus"],
            field: "latestExtractionStatus"
        )
        self.selectedExtractionID = selectedExtractionID
        self.batchCandidates = batchCandidates
        self.singleCandidates = singleCandidates
        self.leaseBinding = nil
    }

    /// A decoded remote projection is not actionable until the reader binds it
    /// to the AccountLease that passed the read completion fence.
    func bound(to accountLease: AccountLease) -> Self {
        var copy = self
        copy.leaseBinding = OwnerTruthInterviewCandidateConfirmationLeaseBinding(
            accountLease: accountLease
        )
        return copy
    }

    func isBound(to accountLease: AccountLease) -> Bool {
        leaseBinding?.matches(accountLease) == true
    }

    /// Candidate membership legitimately changes after a decision. The
    /// surrounding admission/source/epoch identity must not drift while the
    /// action is being reconciled.
    func hasSameAuthorityComposition(
        as other: OwnerTruthInterviewCandidateConfirmation
    ) -> Bool {
        vaultID == other.vaultID
            && reviewBatchID == other.reviewBatchID
            && admissionID == other.admissionID
            && sourceID == other.sourceID
            && sourceVersion == other.sourceVersion
            && authorityEpoch == other.authorityEpoch
    }
}

/// Value-free staging state for a formally acknowledged interview review
/// batch. This is intentionally distinct from the confirmation projection: it
/// contains no Source, Candidate, extraction, effect or Provider identifier.
enum OwnerTruthInterviewCandidateProposalReviewBatchState: String, Equatable, Sendable {
    case pendingAcknowledgement
    case acknowledged
}

enum OwnerTruthInterviewCandidateProposalAdmissionState: String, Equatable, Sendable {
    case pendingAcknowledgement
    case readyForAdmission
    case admitted
    case invalidated
}

enum OwnerTruthInterviewCandidateProposalSourceState: String, Equatable, Sendable {
    case notAdmitted
    case admitted
    case inactive
}

enum OwnerTruthInterviewCandidateProposalExtractionState: String, Equatable, Sendable {
    case notRequested
    case requested
    case blocked
    case succeeded
    case failed
    case quarantined
}

enum OwnerTruthInterviewCandidateProposalEffectState: String, Equatable, Sendable {
    case disabled
}

enum OwnerTruthInterviewCandidateProposalReviewState: String, Equatable, Sendable {
    case notReady
    case reviewReady
    case noCandidates
    case extractionFailed
    case extractionQuarantined
}

/// In-memory binding added only after the value-free staging response passes
/// the AccountLease request/commit fence. It never crosses the backend
/// boundary and carries no archive content.
private struct OwnerTruthInterviewCandidateProposalStatusLeaseBinding: Equatable, Sendable {
    let accountLease: AccountLease

    func matches(_ accountLease: AccountLease) -> Bool {
        self.accountLease == accountLease
    }
}

struct OwnerTruthInterviewCandidateProposalStatus: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-proposal-status-v1"

    let vaultID: OwnerTruthVaultID
    let reviewBatchID: OwnerTruthRecordID
    let reviewBatchState: OwnerTruthInterviewCandidateProposalReviewBatchState
    let candidateProposalState: OwnerTruthInterviewCandidateProposalAdmissionState
    let sourceState: OwnerTruthInterviewCandidateProposalSourceState
    let candidateExtractionState: OwnerTruthInterviewCandidateProposalExtractionState
    let effectExecutionState: OwnerTruthInterviewCandidateProposalEffectState
    let candidateReviewState: OwnerTruthInterviewCandidateProposalReviewState
    private var leaseBinding: OwnerTruthInterviewCandidateProposalStatusLeaseBinding?

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedReviewBatchID: OwnerTruthRecordID
    ) throws {
        guard Set(object.keys) == Set([
            "schemaVersion",
            "vaultId",
            "reviewBatch",
            "candidateProposal",
            "source",
            "candidateExtraction",
            "effectExecution",
            "candidateReview",
        ]),
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewCandidateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let reviewBatch = object["reviewBatch"] as? [String: Any],
              let candidateProposal = object["candidateProposal"] as? [String: Any],
              let source = object["source"] as? [String: Any],
              let candidateExtraction = object["candidateExtraction"] as? [String: Any],
              let effectExecution = object["effectExecution"] as? [String: Any],
              let candidateReview = object["candidateReview"] as? [String: Any],
              Set(reviewBatch.keys) == Set(["reviewBatchId", "state"]),
              Set(candidateProposal.keys) == Set(["status"]),
              Set(source.keys) == Set(["status"]),
              Set(candidateExtraction.keys) == Set(["status"]),
              Set(effectExecution.keys) == Set(["status"]),
              Set(candidateReview.keys) == Set(["status"]),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(reviewBatch["reviewBatchId"]),
              reviewBatchID == expectedReviewBatchID,
              let reviewBatchRaw = OwnerTruthInterviewCandidateContract.requiredString(reviewBatch["state"]),
              let reviewBatchState = OwnerTruthInterviewCandidateProposalReviewBatchState(rawValue: reviewBatchRaw),
              let proposalRaw = OwnerTruthInterviewCandidateContract.requiredString(candidateProposal["status"]),
              let candidateProposalState = OwnerTruthInterviewCandidateProposalAdmissionState(rawValue: proposalRaw),
              let sourceRaw = OwnerTruthInterviewCandidateContract.requiredString(source["status"]),
              let sourceState = OwnerTruthInterviewCandidateProposalSourceState(rawValue: sourceRaw),
              let extractionRaw = OwnerTruthInterviewCandidateContract.requiredString(candidateExtraction["status"]),
              let candidateExtractionState = OwnerTruthInterviewCandidateProposalExtractionState(rawValue: extractionRaw),
              let effectRaw = OwnerTruthInterviewCandidateContract.requiredString(effectExecution["status"]),
              let effectExecutionState = OwnerTruthInterviewCandidateProposalEffectState(rawValue: effectRaw),
              let reviewRaw = OwnerTruthInterviewCandidateContract.requiredString(candidateReview["status"]),
              let candidateReviewState = OwnerTruthInterviewCandidateProposalReviewState(rawValue: reviewRaw),
              Self.isCoherent(
                reviewBatchState: reviewBatchState,
                candidateProposalState: candidateProposalState,
                sourceState: sourceState,
                candidateExtractionState: candidateExtractionState,
                effectExecutionState: effectExecutionState,
                candidateReviewState: candidateReviewState
              ) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateProposalStatus(
                "status response misses a required typed field or has an unsupported state combination"
            )
        }

        vaultID = expectedVaultID
        self.reviewBatchID = reviewBatchID
        self.reviewBatchState = reviewBatchState
        self.candidateProposalState = candidateProposalState
        self.sourceState = sourceState
        self.candidateExtractionState = candidateExtractionState
        self.effectExecutionState = effectExecutionState
        self.candidateReviewState = candidateReviewState
        leaseBinding = nil
    }

    func bound(to accountLease: AccountLease) -> Self {
        var copy = self
        copy.leaseBinding = OwnerTruthInterviewCandidateProposalStatusLeaseBinding(
            accountLease: accountLease
        )
        return copy
    }

    func isBound(to accountLease: AccountLease) -> Bool {
        leaseBinding?.matches(accountLease) == true
    }

    var isTerminallyUnavailable: Bool {
        candidateProposalState == .invalidated || sourceState == .inactive
    }

    private static func isCoherent(
        reviewBatchState: OwnerTruthInterviewCandidateProposalReviewBatchState,
        candidateProposalState: OwnerTruthInterviewCandidateProposalAdmissionState,
        sourceState: OwnerTruthInterviewCandidateProposalSourceState,
        candidateExtractionState: OwnerTruthInterviewCandidateProposalExtractionState,
        effectExecutionState: OwnerTruthInterviewCandidateProposalEffectState,
        candidateReviewState: OwnerTruthInterviewCandidateProposalReviewState
    ) -> Bool {
        guard effectExecutionState == .disabled else { return false }
        switch (reviewBatchState, candidateProposalState) {
        case (.pendingAcknowledgement, .pendingAcknowledgement):
            return sourceState == .notAdmitted
                && candidateExtractionState == .notRequested
                && candidateReviewState == .notReady
        case (.acknowledged, .readyForAdmission):
            return sourceState == .notAdmitted
                && candidateExtractionState == .notRequested
                && candidateReviewState == .notReady
        case (.acknowledged, .invalidated):
            return sourceState == .inactive
                && candidateExtractionState == .blocked
                && candidateReviewState == .notReady
        case (.acknowledged, .admitted):
            guard sourceState == .admitted else { return false }
            switch candidateExtractionState {
            case .requested:
                return candidateReviewState == .notReady
            case .succeeded:
                return candidateReviewState == .reviewReady || candidateReviewState == .noCandidates
            case .failed:
                return candidateReviewState == .extractionFailed
            case .quarantined:
                return candidateReviewState == .extractionQuarantined
            case .notRequested, .blocked:
                return false
            }
        case (.pendingAcknowledgement, .readyForAdmission),
             (.pendingAcknowledgement, .admitted),
             (.pendingAcknowledgement, .invalidated),
             (.acknowledged, .pendingAcknowledgement):
            return false
        }
    }
}

struct OwnerTruthInterviewCandidateBatchSelection: Equatable, Sendable {
    let candidateID: OwnerTruthRecordID
    let expectedCandidateVersion: Int

    init(candidateID: OwnerTruthRecordID, expectedCandidateVersion: Int) throws {
        guard expectedCandidateVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidCommand(
                "expectedCandidateVersion must be positive"
            )
        }
        self.candidateID = candidateID
        self.expectedCandidateVersion = expectedCandidateVersion
    }

    var backendJSONObject: [String: Any] {
        [
            "candidateId": candidateID.rawValue.uuidString.lowercased(),
            "expectedCandidateVersion": expectedCandidateVersion,
        ]
    }
}

struct OwnerTruthInterviewCandidateBatchAcceptCommand: Equatable, Sendable {
    let commandID: String
    let reviewBatchID: OwnerTruthRecordID
    let selections: [OwnerTruthInterviewCandidateBatchSelection]
    let reasonCode: String

    init(
        commandID: String,
        reviewBatchID: OwnerTruthRecordID,
        selections: [OwnerTruthInterviewCandidateBatchSelection],
        reasonCode: String
    ) throws {
        let normalizedCommandID = commandID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedReasonCode = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCommandID.isEmpty,
              !normalizedReasonCode.isEmpty,
              !selections.isEmpty,
              Set(selections.map(\.candidateID)).count == selections.count else {
            throw OwnerTruthRemoteContractError.invalidCommand(
                "batch acceptance requires a unique non-empty selection and command metadata"
            )
        }
        self.commandID = normalizedCommandID
        self.reviewBatchID = reviewBatchID
        self.selections = selections
        self.reasonCode = normalizedReasonCode
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "selections": selections.map(\.backendJSONObject),
            "reasonCode": reasonCode,
        ]
    }
}

struct OwnerTruthInterviewCandidateSingleReviewCommand: Equatable, Sendable {
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let review: OwnerTruthCandidateReviewCommand

    init(
        reviewBatchID: OwnerTruthRecordID,
        candidateID: OwnerTruthRecordID,
        review: OwnerTruthCandidateReviewCommand
    ) {
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
        self.review = review
    }

    var backendPayload: [String: Any] { review.backendPayload }
}

struct OwnerTruthInterviewCandidateReviewReceipt: Equatable, Sendable {
    let id: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let candidateVersion: Int
    let correctedValueID: OwnerTruthRecordID?

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = OwnerTruthCandidateEvidenceReference.recordID(object["receiptId"]),
              let candidateID = OwnerTruthCandidateEvidenceReference.recordID(object["candidateId"]),
              let decisionRaw = OwnerTruthInterviewCandidateContract.requiredString(object["decision"]),
              let decision = OwnerTruthCandidateDecision(rawValue: decisionRaw),
              decision.isTerminal,
              let candidateVersion = OwnerTruthCandidateEvidenceReference.positiveInt(object["candidateVersion"]) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "review receipt misses a required typed field"
            )
        }
        self.id = id
        self.candidateID = candidateID
        self.decision = decision
        self.candidateVersion = candidateVersion
        self.correctedValueID = try OwnerTruthInterviewCandidateContract.optionalRecordID(
            object["correctedValueId"],
            field: "correctedValueId"
        )
    }
}

struct OwnerTruthInterviewCandidateBatchAcceptResult: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-batch-decision-response-v1"

    let outcome: OwnerTruthCommandOutcome
    let batchDecisionID: OwnerTruthRecordID
    let reviewBatchID: OwnerTruthRecordID
    let receipts: [OwnerTruthInterviewCandidateReviewReceipt]
    let memoryVersionCreated: Bool

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthInterviewCandidateBatchAcceptCommand
    ) throws {
        guard OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              let outcomeRaw = OwnerTruthInterviewCandidateContract.requiredString(object["status"]),
              let outcome = OwnerTruthCommandOutcome(rawValue: outcomeRaw),
              let batchDecisionID = OwnerTruthCandidateEvidenceReference.recordID(object["batchDecisionId"]),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              reviewBatchID == expectedCommand.reviewBatchID,
              let receiptObjects = object["receipts"] as? [[String: Any]],
              let acceptedCount = OwnerTruthCandidateEvidenceReference.positiveInt(object["acceptedCandidateCount"]),
              acceptedCount == receiptObjects.count,
              acceptedCount == expectedCommand.selections.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "batch decision response does not match the requested selection"
            )
        }
        let receipts = try receiptObjects.map(OwnerTruthInterviewCandidateReviewReceipt.init(backendJSONObject:))
        let expectedIDs = Set(expectedCommand.selections.map(\.candidateID))
        guard Set(receipts.map(\.candidateID)) == expectedIDs,
              receipts.allSatisfy({ $0.decision == .accepted }) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "batch decision receipt does not match the accepted Candidates"
            )
        }
        try OwnerTruthInterviewCandidateContract.assertNoMemoryActivation(
            object["memoryActivation"]
        )
        self.outcome = outcome
        self.batchDecisionID = batchDecisionID
        self.reviewBatchID = reviewBatchID
        self.receipts = receipts
        self.memoryVersionCreated = false
    }
}

struct OwnerTruthInterviewCandidateSingleReviewResult: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-single-review-response-v1"

    let outcome: OwnerTruthCommandOutcome
    let batchDecisionID: OwnerTruthRecordID
    let reviewBatchID: OwnerTruthRecordID
    let receipt: OwnerTruthInterviewCandidateReviewReceipt
    let memoryVersionCreated: Bool

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthInterviewCandidateSingleReviewCommand
    ) throws {
        guard OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              let outcomeRaw = OwnerTruthInterviewCandidateContract.requiredString(object["status"]),
              let outcome = OwnerTruthCommandOutcome(rawValue: outcomeRaw),
              let batchDecisionID = OwnerTruthCandidateEvidenceReference.recordID(object["batchDecisionId"]),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              reviewBatchID == expectedCommand.reviewBatchID,
              let receiptObject = object["receipt"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "single decision response misses a required typed field"
            )
        }
        let receipt = try OwnerTruthInterviewCandidateReviewReceipt(
            backendJSONObject: receiptObject
        )
        guard receipt.candidateID == expectedCommand.candidateID,
              receipt.decision == expectedCommand.review.action.terminalDecision else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "single decision receipt does not match the requested Candidate"
            )
        }
        try OwnerTruthInterviewCandidateContract.assertNoMemoryActivation(
            object["memoryActivation"]
        )
        self.outcome = outcome
        self.batchDecisionID = batchDecisionID
        self.reviewBatchID = reviewBatchID
        self.receipt = receipt
        self.memoryVersionCreated = false
    }
}

/// Narrow port for the QA-only M0-A interview review surface. Its return types
/// intentionally do not expose generic MemoryVersion activation information.
protocol OwnerTruthInterviewCandidateReviewClient: AnyObject {
    func fetchOwnerTruthInterviewCandidateReview(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateReviewBatch, Error>) -> Void
    )

    func acceptOwnerTruthInterviewCandidateBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateBatchAcceptCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateBatchAcceptResult, Error>) -> Void
    )

    func reviewOwnerTruthInterviewCandidateSingle(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateSingleReviewCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateSingleReviewResult, Error>) -> Void
    )
}

/// Narrow read-only port for the default-off product confirmation contract.
/// It intentionally has no decision/activation methods.
protocol OwnerTruthInterviewCandidateConfirmationClient: AnyObject {
    func fetchOwnerTruthInterviewCandidateConfirmation(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmation, Error>) -> Void
    )
}

/// Narrow read-only port for the formal value-free candidate-proposal staging
/// status. It has no admission, extraction, Candidate or Memory action.
protocol OwnerTruthInterviewCandidateProposalStatusClient: AnyObject {
    func fetchOwnerTruthInterviewCandidateProposalStatus(
        vaultID: OwnerTruthVaultID,
        reviewBatchID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateProposalStatus, Error>) -> Void
    )
}

/// Content-free discovery port for formal confirmation batches. It has no
/// Candidate detail or decision method; those remain behind the separately
/// captured per-batch confirmation contracts.
protocol OwnerTruthInterviewCandidateConfirmationInboxClient: AnyObject {
    func fetchOwnerTruthInterviewCandidateConfirmationInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>) -> Void
    )
}

/// Content-free recovery port for formally confirmed Candidates that need a
/// separate explicit MemoryVersion activation. It cannot be used to discover
/// arbitrary Candidate material or DecisionReceipt identifiers.
protocol OwnerTruthInterviewCandidateMemoryActivationInboxClient: AnyObject {
    func fetchOwnerTruthInterviewCandidateMemoryActivationInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateMemoryActivationInbox, Error>) -> Void
    )
}

/// Read-only discovery for formal memories that are already activated but are
/// still being materialized by the server-side projection worker. No client
/// action is available through this port.
protocol OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxClient: AnyObject {
    func fetchOwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox, Error>) -> Void
    )
}

/// A product confirmation command is intentionally distinct from the QA review
/// command. The server fixes the acceptance reason at the policy boundary, so
/// callers cannot supply or vary it.
struct OwnerTruthInterviewCandidateConfirmationBatchCommand: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-confirmation-batch-command-v1"

    let commandID: String
    let reviewBatchID: OwnerTruthRecordID
    let selections: [OwnerTruthInterviewCandidateBatchSelection]

    init(
        commandID: String,
        reviewBatchID: OwnerTruthRecordID,
        selections: [OwnerTruthInterviewCandidateBatchSelection]
    ) throws {
        let normalizedCommandID = commandID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCommandID.isEmpty,
              !selections.isEmpty,
              Set(selections.map(\.candidateID)).count == selections.count else {
            throw OwnerTruthRemoteContractError.invalidCommand(
                "confirmation batch action requires a unique non-empty selection and command id"
            )
        }
        self.commandID = normalizedCommandID
        self.reviewBatchID = reviewBatchID
        self.selections = selections
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "selections": selections.map(\.backendJSONObject),
        ]
    }
}

/// Value-minimized result for a product confirmation action. It must never
/// deserialize the QA receipt envelope or any candidate content.
struct OwnerTruthInterviewCandidateConfirmationBatchResult: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-confirmation-batch-decision-response-v1"

    let outcome: OwnerTruthCommandOutcome
    let batchDecisionID: OwnerTruthRecordID
    let reviewBatchID: OwnerTruthRecordID
    let acceptedCandidateIDs: [OwnerTruthRecordID]
    let memoryVersionCreated: Bool

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthInterviewCandidateConfirmationBatchCommand
    ) throws {
        guard object["receipts"] == nil,
              object["review"] == nil,
              object["content"] == nil,
              object["confirmation"] == nil,
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              let outcomeRaw = OwnerTruthInterviewCandidateContract.requiredString(object["status"]),
              let outcome = OwnerTruthCommandOutcome(rawValue: outcomeRaw),
              let batchDecisionID = OwnerTruthCandidateEvidenceReference.recordID(object["batchDecisionId"]),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              reviewBatchID == expectedCommand.reviewBatchID,
              let acceptedCount = OwnerTruthInterviewCandidateContract.nonNegativeInt(object["acceptedCandidateCount"]),
              let acceptedValues = object["acceptedCandidateIds"] as? [Any],
              acceptedCount == acceptedValues.count,
              acceptedCount == expectedCommand.selections.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "confirmation action response does not match the typed contract"
            )
        }
        let acceptedCandidateIDs = acceptedValues.compactMap(OwnerTruthCandidateEvidenceReference.recordID)
        let expectedIDs = Set(expectedCommand.selections.map(\.candidateID))
        guard acceptedCandidateIDs.count == acceptedValues.count,
              Set(acceptedCandidateIDs) == expectedIDs,
              Set(acceptedCandidateIDs).count == acceptedCandidateIDs.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "confirmation action result does not match the requested Candidates"
            )
        }
        try OwnerTruthInterviewCandidateContract.assertNoMemoryActivation(object["memoryActivation"])
        self.outcome = outcome
        self.batchDecisionID = batchDecisionID
        self.reviewBatchID = reviewBatchID
        self.acceptedCandidateIDs = acceptedCandidateIDs
        self.memoryVersionCreated = false
    }
}

/// Narrow write port for the default-off product confirmation route. It does
/// not share the QA review transport or its receipt model.
protocol OwnerTruthInterviewCandidateConfirmationActionClient: AnyObject {
    func confirmOwnerTruthInterviewCandidateBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateConfirmationBatchCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>) -> Void
    )
}

/// A formal product command for one sensitive or explicitly single-review
/// Candidate. It intentionally does not reuse the QA receipt envelope.
struct OwnerTruthInterviewCandidateConfirmationSingleCommand: Equatable, Sendable {
    let commandID: String
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let expectedCandidateVersion: Int
    let action: OwnerTruthCandidateReviewAction
    let correctedValue: [String: OwnerTruthJSONValue]?
    let correctedValueSchemaVersion: String?

    init(
        commandID: String,
        reviewBatchID: OwnerTruthRecordID,
        candidateID: OwnerTruthRecordID,
        expectedCandidateVersion: Int,
        action: OwnerTruthCandidateReviewAction,
        correctedValue: [String: OwnerTruthJSONValue]? = nil,
        correctedValueSchemaVersion: String? = nil
    ) throws {
        let normalizedCommandID = commandID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSchemaVersion = correctedValueSchemaVersion?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCommandID.isEmpty, expectedCandidateVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidCommand(
                "confirmation single action requires a command id and candidate version"
            )
        }
        switch action {
        case .correct:
            guard let correctedValue, !correctedValue.isEmpty,
                  let normalizedSchemaVersion, !normalizedSchemaVersion.isEmpty else {
                throw OwnerTruthRemoteContractError.invalidCommand(
                    "confirmation correct requires correctedValue and correctedValueSchemaVersion"
                )
            }
            self.correctedValue = correctedValue
            self.correctedValueSchemaVersion = normalizedSchemaVersion
        case .accept, .reject:
            guard correctedValue == nil, correctedValueSchemaVersion == nil else {
                throw OwnerTruthRemoteContractError.invalidCommand(
                    "only confirmation correct may carry a corrected value"
                )
            }
            self.correctedValue = nil
            self.correctedValueSchemaVersion = nil
        }
        self.commandID = normalizedCommandID
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
        self.expectedCandidateVersion = expectedCandidateVersion
        self.action = action
    }

    var backendPayload: [String: Any] {
        var payload: [String: Any] = [
            "commandId": commandID,
            "expectedCandidateVersion": expectedCandidateVersion,
            "action": action.rawValue,
        ]
        if let correctedValue, let correctedValueSchemaVersion {
            payload["correctedValue"] = correctedValue.mapValues(\.backendJSONObject)
            payload["correctedValueSchemaVersion"] = correctedValueSchemaVersion
        }
        return payload
    }
}

/// Value-minimized product result for a single Candidate decision. Receipt
/// identifiers and any Candidate content are deliberately excluded.
struct OwnerTruthInterviewCandidateConfirmationSingleResult: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-confirmation-single-decision-response-v1"

    let outcome: OwnerTruthCommandOutcome
    let batchDecisionID: OwnerTruthRecordID
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let memoryVersionCreated: Bool

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthInterviewCandidateConfirmationSingleCommand
    ) throws {
        guard object["receipt"] == nil,
              object["review"] == nil,
              object["confirmation"] == nil,
              object["content"] == nil,
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              let outcomeRaw = OwnerTruthInterviewCandidateContract.requiredString(object["status"]),
              let outcome = OwnerTruthCommandOutcome(rawValue: outcomeRaw),
              let batchDecisionID = OwnerTruthCandidateEvidenceReference.recordID(object["batchDecisionId"]),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              reviewBatchID == expectedCommand.reviewBatchID,
              let candidateID = OwnerTruthCandidateEvidenceReference.recordID(object["candidateId"]),
              candidateID == expectedCommand.candidateID,
              let decisionRaw = OwnerTruthInterviewCandidateContract.requiredString(object["decision"]),
              let decision = OwnerTruthCandidateDecision(rawValue: decisionRaw),
              decision == expectedCommand.action.terminalDecision else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "confirmation single action result does not match the typed command"
            )
        }
        try OwnerTruthInterviewCandidateContract.assertNoMemoryActivation(object["memoryActivation"])
        self.outcome = outcome
        self.batchDecisionID = batchDecisionID
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
        self.decision = decision
        self.memoryVersionCreated = false
    }
}

/// Narrow write port for a formal sensitive/single Candidate decision. It is
/// separate from QA review so the client cannot accidentally use QA headers.
protocol OwnerTruthInterviewCandidateConfirmationSingleActionClient: AnyObject {
    func confirmOwnerTruthInterviewCandidateSingle(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateConfirmationSingleCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateConfirmationSingleResult, Error>) -> Void
    )
}

private enum OwnerTruthInterviewCandidateContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func optionalString(_ value: Any?, field: String) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        guard let normalized = requiredString(value) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateReview(
                "\(field) must be a non-empty string or null"
            )
        }
        return normalized
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value >= 0 {
            return value
        }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue,
           value.intValue >= 0 {
            return value.intValue
        }
        if let value = value as? String,
           let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
           parsed >= 0 {
            return parsed
        }
        return nil
    }

    static func optionalRecordID(_ value: Any?, field: String) throws -> OwnerTruthRecordID? {
        guard let value, !(value is NSNull) else { return nil }
        guard let identifier = OwnerTruthCandidateEvidenceReference.recordID(value) else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "\(field) must be a UUID or null"
            )
        }
        return identifier
    }

    static func assertNoMemoryActivation(_ value: Any?) throws {
        guard let activation = value as? [String: Any],
              requiredString(activation["status"]) == OwnerTruthMemoryActivationOutcome.notApplicable.rawValue,
              let memoryVersionCreated = activation["memoryVersionCreated"] as? Bool,
              !memoryVersionCreated else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "interview review must not activate a MemoryVersion"
            )
        }
    }
}

/// Intent and ViewState boundary for the private M0-A interview review surface.
/// It is deliberately separate from `OwnerTruthCandidateReviewUseCase`: a
/// terminal interview review creates only a DecisionReceipt, never a
/// MemoryVersion or a legacy Archive/KBLite write.
enum OwnerTruthInterviewCandidateReviewIntent: Equatable, Sendable {
    case refresh
    case acceptBatch(candidateIDs: [OwnerTruthRecordID])
    case acceptSingle(candidateID: OwnerTruthRecordID)
    case correctSingle(candidateID: OwnerTruthRecordID, correctedSummary: String)
    case rejectSingle(candidateID: OwnerTruthRecordID)
}

enum OwnerTruthInterviewCandidateReviewPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case submitting
    case empty
    case failed
}

enum OwnerTruthInterviewCandidateReviewNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case accountUnavailable
    case staleAccountLease
    case invalidVault
    case invalidSelection
    case candidateUnavailable
    case correctionRequired
    case reviewResultMismatch
    case requestFailed
    case batchAccepted
    case singleAccepted
    case singleCorrected
    case singleRejected
}

struct OwnerTruthInterviewCandidateReviewItemViewState: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let reviewPath: OwnerTruthInterviewCandidateReviewPath
    let proposalPreview: String
    let memoryKind: OwnerTruthMemoryKind
    let sensitivity: OwnerTruthSensitivityLevel
    let evidenceCount: Int
    let candidateVersion: Int
    let supportsCorrection: Bool
}

struct OwnerTruthInterviewCandidateReviewReceiptViewState: Equatable, Sendable {
    let candidateIDs: [OwnerTruthRecordID]
    let decisions: [OwnerTruthCandidateDecision]
    let memoryVersionCreated: Bool
}

struct OwnerTruthInterviewCandidateReviewViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateReviewPhase
    let readiness: OwnerTruthInterviewCandidateReviewReadiness?
    let batchItems: [OwnerTruthInterviewCandidateReviewItemViewState]
    let singleItems: [OwnerTruthInterviewCandidateReviewItemViewState]
    let notice: OwnerTruthInterviewCandidateReviewNotice?
    let latestReceipt: OwnerTruthInterviewCandidateReviewReceiptViewState?

    static let idle = OwnerTruthInterviewCandidateReviewViewState(
        phase: .idle,
        readiness: nil,
        batchItems: [],
        singleItems: [],
        notice: nil,
        latestReceipt: nil
    )
}

/// Lease-fenced client adapter for M0-A review composition.  The use case is
/// QA-only and intentionally cannot reach the generic Candidate inbox route.
final class OwnerTruthInterviewCandidateReviewUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let reviewBatchID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewCandidateReviewClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private let commandIDFactory: CommandIDFactory

    private var batchCandidatesByID: [OwnerTruthRecordID: OwnerTruthInterviewCandidateReviewItem] = [:]
    private var batchCandidateIDs: [OwnerTruthRecordID] = []
    private var singleCandidatesByID: [OwnerTruthRecordID: OwnerTruthInterviewCandidateReviewItem] = [:]
    private var singleCandidateIDs: [OwnerTruthRecordID] = []
    private var readiness: OwnerTruthInterviewCandidateReviewReadiness?
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateReviewViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateReviewViewState) -> Void)?

    init(
        accountLease: AccountLease,
        reviewBatchID: OwnerTruthRecordID,
        client: OwnerTruthInterviewCandidateReviewClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled },
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.reviewBatchID = reviewBatchID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthInterviewCandidateReviewIntent) {
        switch intent {
        case .refresh:
            refresh()
        case .acceptBatch(let candidateIDs):
            submitBatch(candidateIDs: candidateIDs)
        case .acceptSingle(let candidateID):
            submitSingle(candidateID: candidateID, action: .accept, correctedSummary: nil)
        case .correctSingle(let candidateID, let correctedSummary):
            submitSingle(candidateID: candidateID, action: .correct, correctedSummary: correctedSummary)
        case .rejectSingle(let candidateID):
            submitSingle(candidateID: candidateID, action: .reject, correctedSummary: nil)
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = state(phase: .loading, notice: nil, latestReceipt: nil)
        client.fetchOwnerTruthInterviewCandidateReview(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID
        ) { [weak self] result in
            self?.receiveReviewBatch(result, vaultID: vaultID, generation: generation)
        }
    }

    private func submitBatch(candidateIDs: [OwnerTruthRecordID]) {
        guard let vaultID = beginRequestOrFail() else { return }
        let uniqueCandidateIDs = Array(Set(candidateIDs))
        guard !uniqueCandidateIDs.isEmpty,
              uniqueCandidateIDs.count == candidateIDs.count,
              uniqueCandidateIDs.allSatisfy({ batchCandidatesByID[$0] != nil }) else {
            transitionFailure(.invalidSelection)
            return
        }
        let selections: [OwnerTruthInterviewCandidateBatchSelection]
        do {
            selections = try uniqueCandidateIDs.compactMap { candidateID in
                guard let candidate = batchCandidatesByID[candidateID] else { return nil }
                return try OwnerTruthInterviewCandidateBatchSelection(
                    candidateID: candidateID,
                    expectedCandidateVersion: candidate.candidate.candidateVersion
                )
            }
            guard selections.count == uniqueCandidateIDs.count else {
                transitionFailure(.invalidSelection)
                return
            }
            let command = try OwnerTruthInterviewCandidateBatchAcceptCommand(
                commandID: commandIDFactory(),
                reviewBatchID: reviewBatchID,
                selections: selections,
                reasonCode: "ownerReviewed"
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = state(phase: .submitting, notice: nil, latestReceipt: nil)
            client.acceptOwnerTruthInterviewCandidateBatch(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveBatchDecision(
                    result,
                    expectedCandidateIDs: uniqueCandidateIDs,
                    generation: generation
                )
            }
        } catch {
            transitionFailure(.requestFailed)
        }
    }

    private func submitSingle(
        candidateID: OwnerTruthRecordID,
        action: OwnerTruthCandidateReviewAction,
        correctedSummary: String?
    ) {
        guard let vaultID = beginRequestOrFail() else { return }
        guard let candidate = singleCandidatesByID[candidateID] else {
            transitionFailure(.candidateUnavailable)
            return
        }
        guard let review = makeSingleReview(
            candidate: candidate,
            action: action,
            correctedSummary: correctedSummary
        ) else { return }
        let command = OwnerTruthInterviewCandidateSingleReviewCommand(
            reviewBatchID: reviewBatchID,
            candidateID: candidateID,
            review: review
        )
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = state(phase: .submitting, notice: nil, latestReceipt: nil)
        client.reviewOwnerTruthInterviewCandidateSingle(vaultID: vaultID, command: command) { [weak self] result in
            self?.receiveSingleDecision(
                result,
                expectedCandidateID: candidateID,
                expectedAction: action,
                generation: generation
            )
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func makeSingleReview(
        candidate: OwnerTruthInterviewCandidateReviewItem,
        action: OwnerTruthCandidateReviewAction,
        correctedSummary: String?
    ) -> OwnerTruthCandidateReviewCommand? {
        do {
            switch action {
            case .accept:
                return try OwnerTruthCandidateReviewCommand(
                    commandID: commandIDFactory(),
                    expectedCandidateVersion: candidate.candidate.candidateVersion,
                    action: .accept,
                    reasonCode: "ownerReviewed"
                )
            case .reject:
                return try OwnerTruthCandidateReviewCommand(
                    commandID: commandIDFactory(),
                    expectedCandidateVersion: candidate.candidate.candidateVersion,
                    action: .reject,
                    reasonCode: "ownerReviewed"
                )
            case .correct:
                let normalizedSummary = correctedSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !normalizedSummary.isEmpty else {
                    transitionFailure(.correctionRequired)
                    return nil
                }
                var correctedValue = candidate.candidate.content
                correctedValue[Self.correctionTextKey(for: candidate.candidate)] = .string(normalizedSummary)
                return try OwnerTruthCandidateReviewCommand(
                    commandID: commandIDFactory(),
                    expectedCandidateVersion: candidate.candidate.candidateVersion,
                    action: .correct,
                    correctedValue: correctedValue,
                    correctedValueSchemaVersion: candidate.candidate.contentSchemaVersion,
                    reasonCode: "ownerCorrected"
                )
            }
        } catch {
            transitionFailure(.requestFailed)
            return nil
        }
    }

    private func receiveReviewBatch(
        _ result: Result<OwnerTruthInterviewCandidateReviewBatch, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let batch):
            guard batch.vaultID == vaultID,
                  batch.vaultID.rawValue == accountLease.vaultId,
                  batch.reviewBatchID == reviewBatchID else {
                transitionFailure(.requestFailed)
                return
            }
            batchCandidatesByID = Dictionary(uniqueKeysWithValues: batch.batchCandidates.map { ($0.id, $0) })
            batchCandidateIDs = batch.batchCandidates.map(\.id)
            singleCandidatesByID = Dictionary(uniqueKeysWithValues: batch.singleCandidates.map { ($0.id, $0) })
            singleCandidateIDs = batch.singleCandidates.map(\.id)
            readiness = batch.readiness
            viewState = state(
                phase: batch.batchCandidates.isEmpty && batch.singleCandidates.isEmpty ? .empty : .ready,
                notice: nil,
                latestReceipt: nil
            )
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveBatchDecision(
        _ result: Result<OwnerTruthInterviewCandidateBatchAcceptResult, Error>,
        expectedCandidateIDs: [OwnerTruthRecordID],
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let decision):
            let receiptIDs = decision.receipts.map(\.candidateID)
            guard !decision.memoryVersionCreated,
                  Set(receiptIDs) == Set(expectedCandidateIDs),
                  decision.receipts.allSatisfy({ $0.decision == .accepted }) else {
                transitionFailure(.reviewResultMismatch)
                return
            }
            for candidateID in expectedCandidateIDs {
                batchCandidatesByID.removeValue(forKey: candidateID)
            }
            batchCandidateIDs.removeAll { expectedCandidateIDs.contains($0) }
            let receipt = OwnerTruthInterviewCandidateReviewReceiptViewState(
                candidateIDs: receiptIDs,
                decisions: decision.receipts.map(\.decision),
                memoryVersionCreated: false
            )
            viewState = state(
                phase: remainingCandidateCount == 0 ? .empty : .ready,
                notice: .batchAccepted,
                latestReceipt: receipt
            )
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveSingleDecision(
        _ result: Result<OwnerTruthInterviewCandidateSingleReviewResult, Error>,
        expectedCandidateID: OwnerTruthRecordID,
        expectedAction: OwnerTruthCandidateReviewAction,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let decision):
            guard !decision.memoryVersionCreated,
                  decision.receipt.candidateID == expectedCandidateID,
                  decision.receipt.decision == expectedAction.terminalDecision else {
                transitionFailure(.reviewResultMismatch)
                return
            }
            singleCandidatesByID.removeValue(forKey: expectedCandidateID)
            singleCandidateIDs.removeAll { $0 == expectedCandidateID }
            let notice: OwnerTruthInterviewCandidateReviewNotice
            switch expectedAction {
            case .accept: notice = .singleAccepted
            case .correct: notice = .singleCorrected
            case .reject: notice = .singleRejected
            }
            let receipt = OwnerTruthInterviewCandidateReviewReceiptViewState(
                candidateIDs: [decision.receipt.candidateID],
                decisions: [decision.receipt.decision],
                memoryVersionCreated: false
            )
            viewState = state(
                phase: remainingCandidateCount == 0 ? .empty : .ready,
                notice: notice,
                latestReceipt: receipt
            )
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private var remainingCandidateCount: Int {
        batchCandidateIDs.count + singleCandidateIDs.count
    }

    private func state(
        phase: OwnerTruthInterviewCandidateReviewPhase,
        notice: OwnerTruthInterviewCandidateReviewNotice?,
        latestReceipt: OwnerTruthInterviewCandidateReviewReceiptViewState?
    ) -> OwnerTruthInterviewCandidateReviewViewState {
        OwnerTruthInterviewCandidateReviewViewState(
            phase: phase,
            readiness: readiness,
            batchItems: batchCandidateIDs.compactMap { itemViewState(for: batchCandidatesByID[$0]) },
            singleItems: singleCandidateIDs.compactMap { itemViewState(for: singleCandidatesByID[$0]) },
            notice: notice,
            latestReceipt: latestReceipt
        )
    }

    private func itemViewState(
        for item: OwnerTruthInterviewCandidateReviewItem?
    ) -> OwnerTruthInterviewCandidateReviewItemViewState? {
        guard let item else { return nil }
        return OwnerTruthInterviewCandidateReviewItemViewState(
            id: item.id,
            reviewPath: item.reviewPath,
            proposalPreview: Self.proposalPreview(for: item.candidate),
            memoryKind: item.candidate.memoryKind,
            sensitivity: item.candidate.sensitivity,
            evidenceCount: item.candidate.sourceReferences.count,
            candidateVersion: item.candidate.candidateVersion,
            supportsCorrection: item.reviewPath == .single
        )
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateReviewNotice) {
        operationGeneration &+= 1
        batchCandidatesByID.removeAll()
        batchCandidateIDs.removeAll()
        singleCandidatesByID.removeAll()
        singleCandidateIDs.removeAll()
        readiness = nil
        viewState = state(phase: .unavailable, notice: notice, latestReceipt: nil)
    }

    private func transitionFailure(_ notice: OwnerTruthInterviewCandidateReviewNotice) {
        viewState = state(phase: .failed, notice: notice, latestReceipt: nil)
    }

    private static func proposalPreview(for candidate: OwnerTruthCandidateInboxItem) -> String {
        for key in ["summary", "claim", "label", "title", "text"] {
            guard case .string(let rawValue)? = candidate.content[key] else { continue }
            let normalized = rawValue
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return String(normalized.prefix(160))
            }
        }
        return "待确认访谈线索"
    }

    private static func correctionTextKey(for candidate: OwnerTruthCandidateInboxItem) -> String {
        for key in ["summary", "claim", "label", "title", "text"] where candidate.content[key] != nil {
            return key
        }
        return "summary"
    }
}

// MARK: - Default-off product confirmation inbox

enum OwnerTruthInterviewCandidateConfirmationInboxIntent: Equatable, Sendable {
    case refresh
}

enum OwnerTruthInterviewCandidateConfirmationInboxPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case failed
}

enum OwnerTruthInterviewCandidateConfirmationInboxNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contentUnavailable
    case contextChanged
    case requestFailed
}

struct OwnerTruthInterviewCandidateConfirmationInboxViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateConfirmationInboxPhase
    let inbox: OwnerTruthInterviewCandidateConfirmationInbox?
    let notice: OwnerTruthInterviewCandidateConfirmationInboxNotice?

    static let idle = OwnerTruthInterviewCandidateConfirmationInboxViewState(
        phase: .idle,
        inbox: nil,
        notice: nil
    )
}

/// Lease-fenced, default-off discovery consumer for formal confirmation
/// batches. It does not automatically read an item or expose Candidate content;
/// a future UI must explicitly select an opaque `reviewBatchID` and invoke the
/// existing per-batch confirmation reader.
final class OwnerTruthInterviewCandidateConfirmationInboxUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let focusedReviewBatchID: OwnerTruthRecordID?
    private let client: OwnerTruthInterviewCandidateConfirmationInboxClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateConfirmationInboxViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateConfirmationInboxViewState) -> Void)?

    init(
        accountLease: AccountLease,
        focusedReviewBatchID: OwnerTruthRecordID? = nil,
        client: OwnerTruthInterviewCandidateConfirmationInboxClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.focusedReviewBatchID = focusedReviewBatchID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func send(_ intent: OwnerTruthInterviewCandidateConfirmationInboxIntent) {
        switch intent {
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateConfirmationInboxViewState(
            phase: .loading,
            inbox: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewCandidateConfirmationInbox(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateConfirmationInbox, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let inbox):
            guard inbox.vaultID == vaultID,
                  inbox.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure()
                return
            }
            let boundInbox = inbox.bound(to: accountLease)
            if let focusedReviewBatchID,
               !boundInbox.items.contains(where: {
                   $0.reviewBatchID == focusedReviewBatchID && $0.readiness == .reviewReady
               }) {
                resetForUnavailable(.contentUnavailable)
                return
            }
            viewState = OwnerTruthInterviewCandidateConfirmationInboxViewState(
                phase: boundInbox.items.isEmpty ? .empty : .ready,
                inbox: boundInbox,
                notice: nil
            )
        case .failure(let error):
            transitionFailure(for: error)
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateConfirmationInboxNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateConfirmationInboxViewState(
            phase: .unavailable,
            inbox: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewCandidateConfirmationInboxViewState(
            phase: .failed,
            inbox: nil,
            notice: .requestFailed
        )
    }

    private func transitionFailure(for error: Error) {
        switch OwnerTruthInterviewCandidateReviewReadFailureDisposition(error: error) {
        case .releasePolicyDisabled:
            resetForUnavailable(.releasePolicyDisabled)
        case .contentUnavailable:
            resetForUnavailable(.contentUnavailable)
        case .contextChanged:
            resetForUnavailable(.contextChanged)
        case .retryable:
            transitionFailure()
        }
    }
}

// MARK: - Default-off formal MemoryVersion activation inbox

enum OwnerTruthInterviewCandidateMemoryActivationInboxIntent: Equatable, Sendable {
    case refresh
}

enum OwnerTruthInterviewCandidateMemoryActivationInboxPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case failed
}

enum OwnerTruthInterviewCandidateMemoryActivationInboxNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case requestFailed
}

struct OwnerTruthInterviewCandidateMemoryActivationInboxViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateMemoryActivationInboxPhase
    let inbox: OwnerTruthInterviewCandidateMemoryActivationInbox?
    let notice: OwnerTruthInterviewCandidateMemoryActivationInboxNotice?

    static let idle = OwnerTruthInterviewCandidateMemoryActivationInboxViewState(
        phase: .idle,
        inbox: nil,
        notice: nil
    )
}

/// Lease-fenced recovery reader for the second Authority transition. It only
/// receives opaque handles that the server has already tied to a formal Owner
/// confirmation; any later activation still goes through its own typed write
/// command and server-side admission checks.
final class OwnerTruthInterviewCandidateMemoryActivationInboxUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthInterviewCandidateMemoryActivationInboxClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateMemoryActivationInboxViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateMemoryActivationInboxViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthInterviewCandidateMemoryActivationInboxClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func send(_ intent: OwnerTruthInterviewCandidateMemoryActivationInboxIntent) {
        switch intent {
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateMemoryActivationInboxViewState(
            phase: .loading,
            inbox: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewCandidateMemoryActivationInbox(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateMemoryActivationInbox, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let inbox):
            guard inbox.vaultID == vaultID,
                  inbox.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure()
                return
            }
            let boundInbox = inbox.bound(to: accountLease)
            viewState = OwnerTruthInterviewCandidateMemoryActivationInboxViewState(
                phase: boundInbox.items.isEmpty ? .empty : .ready,
                inbox: boundInbox,
                notice: nil
            )
        case .failure:
            transitionFailure()
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateMemoryActivationInboxNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateMemoryActivationInboxViewState(
            phase: .unavailable,
            inbox: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewCandidateMemoryActivationInboxViewState(
            phase: .failed,
            inbox: nil,
            notice: .requestFailed
        )
    }
}

// MARK: - Default-off formal MemoryVersion projection recovery inbox

enum OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxIntent: Equatable, Sendable {
    case refresh
}

enum OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case failed
}

enum OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case requestFailed
}

struct OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxPhase
    let inbox: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox?
    let notice: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxNotice?

    static let idle = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState(
        phase: .idle,
        inbox: nil,
        notice: nil
    )
}

/// Lease-fenced read-only visibility for server-managed projection recovery.
/// A failed summary read cannot change the independent activation inbox state.
final class OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func send(_ intent: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxIntent) {
        switch intent {
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState(
            phase: .loading,
            inbox: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateMemoryProjectionRecoveryInbox, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let inbox):
            guard inbox.vaultID == vaultID,
                  inbox.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure()
                return
            }
            let boundInbox = inbox.bound(to: accountLease)
            viewState = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState(
                phase: boundInbox.items.isEmpty ? .empty : .ready,
                inbox: boundInbox,
                notice: nil
            )
        case .failure:
            transitionFailure()
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState(
            phase: .unavailable,
            inbox: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewCandidateMemoryProjectionRecoveryInboxViewState(
            phase: .failed,
            inbox: nil,
            notice: .requestFailed
        )
    }
}

// MARK: - Default-off product confirmation read

/// A read-only, lease-fenced consumer for the future product confirmation
/// route. The default closure is fail-closed; a caller must explicitly supply
/// a captured release-policy decision before any real backend request occurs.
enum OwnerTruthInterviewCandidateConfirmationIntent: Equatable, Sendable {
    case refresh
}

enum OwnerTruthInterviewCandidateConfirmationPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case failed
}

enum OwnerTruthInterviewCandidateConfirmationNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contentUnavailable
    case contextChanged
    case requestFailed
}

struct OwnerTruthInterviewCandidateConfirmationViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateConfirmationPhase
    let confirmation: OwnerTruthInterviewCandidateConfirmation?
    let notice: OwnerTruthInterviewCandidateConfirmationNotice?

    static let idle = OwnerTruthInterviewCandidateConfirmationViewState(
        phase: .idle,
        confirmation: nil,
        notice: nil
    )
}

final class OwnerTruthInterviewCandidateConfirmationUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let reviewBatchID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewCandidateConfirmationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateConfirmationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateConfirmationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        reviewBatchID: OwnerTruthRecordID,
        client: OwnerTruthInterviewCandidateConfirmationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.reviewBatchID = reviewBatchID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func send(_ intent: OwnerTruthInterviewCandidateConfirmationIntent) {
        switch intent {
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateConfirmationViewState(
            phase: .loading,
            confirmation: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewCandidateConfirmation(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateConfirmation, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let confirmation):
            guard confirmation.vaultID == vaultID,
                  confirmation.vaultID.rawValue == accountLease.vaultId,
                  confirmation.reviewBatchID == reviewBatchID else {
                transitionFailure()
                return
            }
            let boundConfirmation = confirmation.bound(to: accountLease)
            let phase: OwnerTruthInterviewCandidateConfirmationPhase =
                boundConfirmation.batchCandidates.isEmpty && boundConfirmation.singleCandidates.isEmpty
                ? .empty
                : .ready
            viewState = OwnerTruthInterviewCandidateConfirmationViewState(
                phase: phase,
                confirmation: boundConfirmation,
                notice: nil
            )
        case .failure(let error):
            transitionFailure(for: error)
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateConfirmationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateConfirmationViewState(
            phase: .unavailable,
            confirmation: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewCandidateConfirmationViewState(
            phase: .failed,
            confirmation: nil,
            notice: .requestFailed
        )
    }

    private func transitionFailure(for error: Error) {
        switch OwnerTruthInterviewCandidateReviewReadFailureDisposition(error: error) {
        case .releasePolicyDisabled:
            resetForUnavailable(.releasePolicyDisabled)
        case .contentUnavailable:
            resetForUnavailable(.contentUnavailable)
        case .contextChanged:
            resetForUnavailable(.contextChanged)
        case .retryable:
            transitionFailure()
        }
    }
}

// MARK: - Default-off formal candidate-proposal staging status

enum OwnerTruthInterviewCandidateProposalStatusIntent: Equatable, Sendable {
    case refresh
}

enum OwnerTruthInterviewCandidateProposalStatusPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case failed
}

enum OwnerTruthInterviewCandidateProposalStatusNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contentUnavailable
    case contextChanged
    case requestFailed
}

struct OwnerTruthInterviewCandidateProposalStatusViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateProposalStatusPhase
    let status: OwnerTruthInterviewCandidateProposalStatus?
    let notice: OwnerTruthInterviewCandidateProposalStatusNotice?

    static let idle = OwnerTruthInterviewCandidateProposalStatusViewState(
        phase: .idle,
        status: nil,
        notice: nil
    )
}

/// Lease-fenced, read-only consumer for the formal staging status route. The
/// default policy is fail-closed and this use case intentionally has no UI
/// attachment yet; it exists to keep transport/authority semantics stable.
final class OwnerTruthInterviewCandidateProposalStatusUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let reviewBatchID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewCandidateProposalStatusClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateProposalStatusViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateProposalStatusViewState) -> Void)?

    init(
        accountLease: AccountLease,
        reviewBatchID: OwnerTruthRecordID,
        client: OwnerTruthInterviewCandidateProposalStatusClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.reviewBatchID = reviewBatchID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func send(_ intent: OwnerTruthInterviewCandidateProposalStatusIntent) {
        switch intent {
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateProposalStatusViewState(
            phase: .loading,
            status: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewCandidateProposalStatus(
            vaultID: vaultID,
            reviewBatchID: reviewBatchID
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateProposalStatus, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let status):
            guard status.vaultID == vaultID,
                  status.vaultID.rawValue == accountLease.vaultId,
                  status.reviewBatchID == reviewBatchID else {
                transitionFailure()
                return
            }
            guard !status.isTerminallyUnavailable else {
                resetForUnavailable(.contentUnavailable)
                return
            }
            viewState = OwnerTruthInterviewCandidateProposalStatusViewState(
                phase: .ready,
                status: status.bound(to: accountLease),
                notice: nil
            )
        case .failure(let error):
            transitionFailure(for: error)
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateProposalStatusNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateProposalStatusViewState(
            phase: .unavailable,
            status: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewCandidateProposalStatusViewState(
            phase: .failed,
            status: nil,
            notice: .requestFailed
        )
    }

    private func transitionFailure(for error: Error) {
        switch OwnerTruthInterviewCandidateReviewReadFailureDisposition(error: error) {
        case .releasePolicyDisabled:
            resetForUnavailable(.releasePolicyDisabled)
        case .contentUnavailable:
            resetForUnavailable(.contentUnavailable)
        case .contextChanged:
            resetForUnavailable(.contextChanged)
        case .retryable:
            transitionFailure()
        }
    }
}

private enum OwnerTruthInterviewCandidateReviewReadFailureDisposition {
    case releasePolicyDisabled
    case contentUnavailable
    case contextChanged
    case retryable

    init(error: Error) {
        guard let clientError = error as? any OwnerTruthBackendFailureClassifying else {
            self = .retryable
            return
        }

        if clientError.ownerTruthFeaturePolicyDenied {
            self = .releasePolicyDisabled
        } else if clientError.ownerTruthBackendErrorCode == "release_policy_denied"
                    || clientError.ownerTruthBackendErrorCode == "ownerTruthCandidateReviewUnavailable" {
            self = .releasePolicyDisabled
        } else if clientError.ownerTruthBackendErrorCode == "ownerTruthCandidateSourceInactive" {
            self = .contentUnavailable
        } else if clientError.ownerTruthBackendStatusCode == 409 {
            self = .contextChanged
        } else if clientError.ownerTruthBackendStatusCode == 403
                    || clientError.ownerTruthBackendStatusCode == 404
                    || clientError.ownerTruthBackendStatusCode == 410 {
            // The current backend normally expresses a stale proposal as a
            // typed success state, 403, 409, or a missing focused inbox item.
            // Treat future 404/410 responses conservatively.
            self = .contentUnavailable
        } else {
            self = .retryable
        }
    }
}

// MARK: - Default-off product confirmation action

enum OwnerTruthInterviewCandidateConfirmationActionIntent: Equatable, Sendable {
    case confirmBatch(candidateIDs: [OwnerTruthRecordID])
}

enum OwnerTruthInterviewCandidateConfirmationActionPhase: Equatable, Sendable {
    case idle
    case unavailable
    case submitting
    case reconciling
    case confirmed
    case failed
}

enum OwnerTruthInterviewCandidateConfirmationActionNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contentUnavailable
    case contextChanged
    case invalidSelection
    case responseMismatch
    case reconciliationFailed
    case requestFailed
    case batchConfirmed
}

struct OwnerTruthInterviewCandidateConfirmationActionViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateConfirmationActionPhase
    let latestResult: OwnerTruthInterviewCandidateConfirmationBatchResult?
    let notice: OwnerTruthInterviewCandidateConfirmationActionNotice?

    static let idle = OwnerTruthInterviewCandidateConfirmationActionViewState(
        phase: .idle,
        latestResult: nil,
        notice: nil
    )
}

/// Lease-fenced product confirmation writer. It accepts only ordinary batch
/// candidates present in the confirmation projection, remains default-off,
/// and keeps the same command id when retrying an unchanged selection.
final class OwnerTruthInterviewCandidateConfirmationActionUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let confirmation: OwnerTruthInterviewCandidateConfirmation
    private let client: OwnerTruthInterviewCandidateConfirmationActionClient
    private let confirmationReader: OwnerTruthInterviewCandidateConfirmationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let commandIDFactory: CommandIDFactory
    private var commandIDsBySelectionSignature: [String: String] = [:]
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateConfirmationActionViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateConfirmationActionViewState) -> Void)?

    init(
        accountLease: AccountLease,
        confirmation: OwnerTruthInterviewCandidateConfirmation,
        client: OwnerTruthInterviewCandidateConfirmationActionClient,
        confirmationReader: OwnerTruthInterviewCandidateConfirmationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false },
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.confirmation = confirmation
        self.client = client
        self.confirmationReader = confirmationReader
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthInterviewCandidateConfirmationActionIntent) {
        switch intent {
        case .confirmBatch(let candidateIDs):
            confirmBatch(candidateIDs: candidateIDs)
        }
    }

    private func confirmBatch(candidateIDs: [OwnerTruthRecordID]) {
        guard let vaultID = beginRequestOrFail(),
              let command = makeCommand(candidateIDs: candidateIDs) else {
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateConfirmationActionViewState(
            phase: .submitting,
            latestResult: nil,
            notice: nil
        )
        client.confirmOwnerTruthInterviewCandidateBatch(vaultID: vaultID, command: command) { [weak self] result in
            self?.receive(result, expectedCommand: command, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID,
              confirmation.vaultID == vaultID,
              confirmation.vaultID.rawValue == accountLease.vaultId else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard confirmation.isBound(to: accountLease) else {
            resetForUnavailable(.staleAccountLease)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func makeCommand(
        candidateIDs: [OwnerTruthRecordID]
    ) -> OwnerTruthInterviewCandidateConfirmationBatchCommand? {
        guard !candidateIDs.isEmpty,
              Set(candidateIDs).count == candidateIDs.count else {
            transitionFailure(.invalidSelection)
            return nil
        }
        let candidatesByID = Dictionary(
            uniqueKeysWithValues: confirmation.batchCandidates.map { ($0.id, $0) }
        )
        let selectedCandidates = candidateIDs.compactMap { candidatesByID[$0] }
        guard selectedCandidates.count == candidateIDs.count,
              selectedCandidates.allSatisfy({
                  $0.reviewPath == .batch && $0.candidate.sensitivity == .standard
              }) else {
            transitionFailure(.invalidSelection)
            return nil
        }
        let signature = candidateIDs
            .map { $0.rawValue.uuidString.lowercased() }
            .sorted()
            .joined(separator: ",")
        let commandID = commandIDsBySelectionSignature[signature] ?? commandIDFactory()
        commandIDsBySelectionSignature[signature] = commandID
        do {
            return try OwnerTruthInterviewCandidateConfirmationBatchCommand(
                commandID: commandID,
                reviewBatchID: confirmation.reviewBatchID,
                selections: try selectedCandidates.map {
                    try OwnerTruthInterviewCandidateBatchSelection(
                        candidateID: $0.id,
                        expectedCandidateVersion: $0.candidate.candidateVersion
                    )
                }
            )
        } catch {
            transitionFailure(.invalidSelection)
            return nil
        }
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateConfirmationBatchResult, Error>,
        expectedCommand: OwnerTruthInterviewCandidateConfirmationBatchCommand,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let actionResult):
            let expectedIDs = Set(expectedCommand.selections.map(\.candidateID))
            guard confirmation.vaultID == vaultID,
                  actionResult.reviewBatchID == confirmation.reviewBatchID,
                  Set(actionResult.acceptedCandidateIDs) == expectedIDs,
                  !actionResult.memoryVersionCreated else {
                transitionFailure(.responseMismatch)
                return
            }
            viewState = OwnerTruthInterviewCandidateConfirmationActionViewState(
                phase: .reconciling,
                latestResult: actionResult,
                notice: nil
            )
            confirmationReader.fetchOwnerTruthInterviewCandidateConfirmation(
                vaultID: vaultID,
                reviewBatchID: confirmation.reviewBatchID
            ) { [weak self] readResult in
                self?.receiveReconciliation(
                    readResult,
                    actionResult: actionResult,
                    expectedCandidateIDs: expectedIDs,
                    vaultID: vaultID,
                    generation: generation
                )
            }
        case .failure(let error):
            transitionFailure(for: error)
        }
    }

    private func receiveReconciliation(
        _ result: Result<OwnerTruthInterviewCandidateConfirmation, Error>,
        actionResult: OwnerTruthInterviewCandidateConfirmationBatchResult,
        expectedCandidateIDs: Set<OwnerTruthRecordID>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let reconciledConfirmation):
            let remainingCandidateIDs = Set(
                reconciledConfirmation.batchCandidates.map(\.id) +
                    reconciledConfirmation.singleCandidates.map(\.id)
            )
            guard reconciledConfirmation.vaultID == vaultID,
                  reconciledConfirmation.vaultID.rawValue == accountLease.vaultId,
                  reconciledConfirmation.reviewBatchID == confirmation.reviewBatchID,
                  reconciledConfirmation.hasSameAuthorityComposition(as: confirmation),
                  remainingCandidateIDs.isDisjoint(with: expectedCandidateIDs) else {
                transitionFailure(.reconciliationFailed, latestResult: actionResult)
                return
            }
            viewState = OwnerTruthInterviewCandidateConfirmationActionViewState(
                phase: .confirmed,
                latestResult: actionResult,
                notice: .batchConfirmed
            )
        case .failure(let error):
            transitionFailure(for: error, latestResult: actionResult)
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewCandidateConfirmationActionNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateConfirmationActionViewState(
            phase: .unavailable,
            latestResult: nil,
            notice: notice
        )
    }

    private func transitionFailure(
        for error: Error,
        latestResult: OwnerTruthInterviewCandidateConfirmationBatchResult? = nil
    ) {
        switch OwnerTruthInterviewCandidateReviewReadFailureDisposition(error: error) {
        case .releasePolicyDisabled:
            resetForUnavailable(.releasePolicyDisabled)
        case .contentUnavailable:
            resetForUnavailable(.contentUnavailable)
        case .contextChanged:
            resetForUnavailable(.contextChanged)
        case .retryable:
            transitionFailure(.requestFailed, latestResult: latestResult)
        }
    }

    private func transitionFailure(
        _ notice: OwnerTruthInterviewCandidateConfirmationActionNotice,
        latestResult: OwnerTruthInterviewCandidateConfirmationBatchResult? = nil
    ) {
        viewState = OwnerTruthInterviewCandidateConfirmationActionViewState(
            phase: .failed,
            latestResult: latestResult,
            notice: notice
        )
    }
}

// MARK: - Default-off product single confirmation action

enum OwnerTruthInterviewCandidateConfirmationSingleActionIntent: Equatable, Sendable {
    case accept(candidateID: OwnerTruthRecordID)
    case correct(candidateID: OwnerTruthRecordID, correctedSummary: String)
    case reject(candidateID: OwnerTruthRecordID)
}

enum OwnerTruthInterviewCandidateConfirmationSingleActionPhase: Equatable, Sendable {
    case idle
    case unavailable
    case submitting
    case reconciling
    case confirmed
    case failed
}

enum OwnerTruthInterviewCandidateConfirmationSingleActionNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contentUnavailable
    case contextChanged
    case invalidSelection
    case correctionRequired
    case responseMismatch
    case reconciliationFailed
    case requestFailed
    case singleAccepted
    case singleCorrected
    case singleRejected
}

struct OwnerTruthInterviewCandidateConfirmationSingleActionViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateConfirmationSingleActionPhase
    let latestResult: OwnerTruthInterviewCandidateConfirmationSingleResult?
    let notice: OwnerTruthInterviewCandidateConfirmationSingleActionNotice?

    static let idle = OwnerTruthInterviewCandidateConfirmationSingleActionViewState(
        phase: .idle,
        latestResult: nil,
        notice: nil
    )
}

/// Lease-fenced formal product action for a sensitive or explicitly
/// single-review Candidate. Like the batch path, it records a terminal receipt
/// only and reconciles the same authority composition before reporting success.
final class OwnerTruthInterviewCandidateConfirmationSingleActionUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let confirmation: OwnerTruthInterviewCandidateConfirmation
    private let client: OwnerTruthInterviewCandidateConfirmationSingleActionClient
    private let confirmationReader: OwnerTruthInterviewCandidateConfirmationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let commandIDFactory: CommandIDFactory
    private var commandIDsByActionSignature: [String: String] = [:]
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateConfirmationSingleActionViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateConfirmationSingleActionViewState) -> Void)?

    init(
        accountLease: AccountLease,
        confirmation: OwnerTruthInterviewCandidateConfirmation,
        client: OwnerTruthInterviewCandidateConfirmationSingleActionClient,
        confirmationReader: OwnerTruthInterviewCandidateConfirmationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false },
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.confirmation = confirmation
        self.client = client
        self.confirmationReader = confirmationReader
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthInterviewCandidateConfirmationSingleActionIntent) {
        switch intent {
        case .accept(let candidateID):
            submit(candidateID: candidateID, action: .accept, correctedSummary: nil)
        case .correct(let candidateID, let correctedSummary):
            submit(candidateID: candidateID, action: .correct, correctedSummary: correctedSummary)
        case .reject(let candidateID):
            submit(candidateID: candidateID, action: .reject, correctedSummary: nil)
        }
    }

    private func submit(
        candidateID: OwnerTruthRecordID,
        action: OwnerTruthCandidateReviewAction,
        correctedSummary: String?
    ) {
        guard let vaultID = beginRequestOrFail(),
              let command = makeCommand(
                  candidateID: candidateID,
                  action: action,
                  correctedSummary: correctedSummary
              ) else {
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateConfirmationSingleActionViewState(
            phase: .submitting,
            latestResult: nil,
            notice: nil
        )
        client.confirmOwnerTruthInterviewCandidateSingle(vaultID: vaultID, command: command) { [weak self] result in
            self?.receive(result, expectedCommand: command, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID,
              confirmation.vaultID == vaultID,
              confirmation.vaultID.rawValue == accountLease.vaultId else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard confirmation.isBound(to: accountLease) else {
            resetForUnavailable(.staleAccountLease)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func makeCommand(
        candidateID: OwnerTruthRecordID,
        action: OwnerTruthCandidateReviewAction,
        correctedSummary: String?
    ) -> OwnerTruthInterviewCandidateConfirmationSingleCommand? {
        guard let candidate = confirmation.singleCandidates.first(where: { $0.id == candidateID }),
              candidate.reviewPath == .single else {
            transitionFailure(.invalidSelection)
            return nil
        }

        let normalizedSummary = correctedSummary?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if action == .correct, normalizedSummary.isEmpty {
            transitionFailure(.correctionRequired)
            return nil
        }
        let signature = [
            candidateID.rawValue.uuidString.lowercased(),
            action.rawValue,
            normalizedSummary,
        ].joined(separator: "|")
        let commandID = commandIDsByActionSignature[signature] ?? commandIDFactory()
        commandIDsByActionSignature[signature] = commandID

        do {
            switch action {
            case .accept, .reject:
                return try OwnerTruthInterviewCandidateConfirmationSingleCommand(
                    commandID: commandID,
                    reviewBatchID: confirmation.reviewBatchID,
                    candidateID: candidateID,
                    expectedCandidateVersion: candidate.candidate.candidateVersion,
                    action: action
                )
            case .correct:
                var correctedValue = candidate.candidate.content
                correctedValue[Self.correctionTextKey(for: candidate.candidate)] = .string(normalizedSummary)
                return try OwnerTruthInterviewCandidateConfirmationSingleCommand(
                    commandID: commandID,
                    reviewBatchID: confirmation.reviewBatchID,
                    candidateID: candidateID,
                    expectedCandidateVersion: candidate.candidate.candidateVersion,
                    action: .correct,
                    correctedValue: correctedValue,
                    correctedValueSchemaVersion: candidate.candidate.contentSchemaVersion
                )
            }
        } catch {
            transitionFailure(.requestFailed)
            return nil
        }
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateConfirmationSingleResult, Error>,
        expectedCommand: OwnerTruthInterviewCandidateConfirmationSingleCommand,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let actionResult):
            guard confirmation.vaultID == vaultID,
                  actionResult.reviewBatchID == confirmation.reviewBatchID,
                  actionResult.candidateID == expectedCommand.candidateID,
                  actionResult.decision == expectedCommand.action.terminalDecision,
                  !actionResult.memoryVersionCreated else {
                transitionFailure(.responseMismatch)
                return
            }
            viewState = OwnerTruthInterviewCandidateConfirmationSingleActionViewState(
                phase: .reconciling,
                latestResult: actionResult,
                notice: nil
            )
            confirmationReader.fetchOwnerTruthInterviewCandidateConfirmation(
                vaultID: vaultID,
                reviewBatchID: confirmation.reviewBatchID
            ) { [weak self] readResult in
                self?.receiveReconciliation(
                    readResult,
                    actionResult: actionResult,
                    expectedCandidateID: expectedCommand.candidateID,
                    expectedAction: expectedCommand.action,
                    vaultID: vaultID,
                    generation: generation
                )
            }
        case .failure(let error):
            transitionFailure(for: error)
        }
    }

    private func receiveReconciliation(
        _ result: Result<OwnerTruthInterviewCandidateConfirmation, Error>,
        actionResult: OwnerTruthInterviewCandidateConfirmationSingleResult,
        expectedCandidateID: OwnerTruthRecordID,
        expectedAction: OwnerTruthCandidateReviewAction,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let reconciledConfirmation):
            let remainingCandidateIDs = Set(
                reconciledConfirmation.batchCandidates.map(\.id) +
                    reconciledConfirmation.singleCandidates.map(\.id)
            )
            guard reconciledConfirmation.vaultID == vaultID,
                  reconciledConfirmation.vaultID.rawValue == accountLease.vaultId,
                  reconciledConfirmation.reviewBatchID == confirmation.reviewBatchID,
                  reconciledConfirmation.hasSameAuthorityComposition(as: confirmation),
                  !remainingCandidateIDs.contains(expectedCandidateID) else {
                transitionFailure(.reconciliationFailed, latestResult: actionResult)
                return
            }
            let notice: OwnerTruthInterviewCandidateConfirmationSingleActionNotice
            switch expectedAction {
            case .accept: notice = .singleAccepted
            case .correct: notice = .singleCorrected
            case .reject: notice = .singleRejected
            }
            viewState = OwnerTruthInterviewCandidateConfirmationSingleActionViewState(
                phase: .confirmed,
                latestResult: actionResult,
                notice: notice
            )
        case .failure(let error):
            transitionFailure(for: error, latestResult: actionResult)
        }
    }

    private func resetForUnavailable(
        _ notice: OwnerTruthInterviewCandidateConfirmationSingleActionNotice
    ) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateConfirmationSingleActionViewState(
            phase: .unavailable,
            latestResult: nil,
            notice: notice
        )
    }

    private func transitionFailure(
        for error: Error,
        latestResult: OwnerTruthInterviewCandidateConfirmationSingleResult? = nil
    ) {
        switch OwnerTruthInterviewCandidateReviewReadFailureDisposition(error: error) {
        case .releasePolicyDisabled:
            resetForUnavailable(.releasePolicyDisabled)
        case .contentUnavailable:
            resetForUnavailable(.contentUnavailable)
        case .contextChanged:
            resetForUnavailable(.contextChanged)
        case .retryable:
            transitionFailure(.requestFailed, latestResult: latestResult)
        }
    }

    private func transitionFailure(
        _ notice: OwnerTruthInterviewCandidateConfirmationSingleActionNotice,
        latestResult: OwnerTruthInterviewCandidateConfirmationSingleResult? = nil
    ) {
        viewState = OwnerTruthInterviewCandidateConfirmationSingleActionViewState(
            phase: .failed,
            latestResult: latestResult,
            notice: notice
        )
    }

private static func correctionTextKey(for candidate: OwnerTruthCandidateInboxItem) -> String {
        for key in ["summary", "claim", "label", "title", "text"] where candidate.content[key] != nil {
            return key
        }
        return "summary"
    }
}

// MARK: - Default-off formal Candidate MemoryVersion activation

/// A value-free, explicit follow-up command that promotes one already formal
/// confirmed Candidate to the current MemoryVersion. Candidate text, receipt
/// identifiers, and version identifiers stay on the server side.
struct OwnerTruthInterviewCandidateMemoryActivationCommand: Equatable, Sendable {
    let commandID: String
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID

    init(
        commandID: String,
        reviewBatchID: OwnerTruthRecordID,
        candidateID: OwnerTruthRecordID
    ) throws {
        let normalizedCommandID = commandID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCommandID.isEmpty, normalizedCommandID.count <= 128 else {
            throw OwnerTruthRemoteContractError.invalidCommand(
                "memory activation requires a command id no longer than 128 characters"
            )
        }
        self.commandID = normalizedCommandID
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
    }

    var backendPayload: [String: Any] {
        ["commandId": commandID]
    }
}

/// Value-minimized terminal response for the explicit MemoryVersion activation
/// boundary. The server must not return private Candidate content, receipt IDs,
/// Memory IDs, or MemoryVersion IDs to this presentation client.
struct OwnerTruthInterviewCandidateMemoryActivationResult: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-confirmation-memory-activation-response-v1"

    let outcome: OwnerTruthCommandOutcome
    let reviewBatchID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let memoryActivationOutcome: OwnerTruthMemoryActivationOutcome
    let projectionRebuildRequested: Bool

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthInterviewCandidateMemoryActivationCommand
    ) throws {
        let allowedKeys: Set<String> = [
            "schemaVersion",
            "status",
            "reviewBatchId",
            "candidateId",
            "memoryActivation",
            "projectionRebuildRequested",
        ]
        guard Set(object.keys).isSubset(of: allowedKeys),
              OwnerTruthInterviewCandidateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              let outcomeRaw = OwnerTruthInterviewCandidateContract.requiredString(object["status"]),
              let outcome = OwnerTruthCommandOutcome(rawValue: outcomeRaw),
              let reviewBatchID = OwnerTruthCandidateEvidenceReference.recordID(object["reviewBatchId"]),
              reviewBatchID == expectedCommand.reviewBatchID,
              let candidateID = OwnerTruthCandidateEvidenceReference.recordID(object["candidateId"]),
              candidateID == expectedCommand.candidateID,
              let activation = object["memoryActivation"] as? [String: Any],
              Set(activation.keys).isSubset(of: ["status", "memoryVersionCreated"]),
              let activationRaw = OwnerTruthInterviewCandidateContract.requiredString(activation["status"]),
              let memoryActivationOutcome = OwnerTruthMemoryActivationOutcome(rawValue: activationRaw),
              memoryActivationOutcome != .notApplicable,
              memoryActivationOutcome.rawValue == outcome.rawValue,
              let memoryVersionCreated = activation["memoryVersionCreated"] as? Bool,
              memoryVersionCreated,
              let projectionRebuildRequested = object["projectionRebuildRequested"] as? Bool else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateDecision(
                "memory activation response does not match the value-minimized typed command"
            )
        }
        self.outcome = outcome
        self.reviewBatchID = reviewBatchID
        self.candidateID = candidateID
        self.memoryActivationOutcome = memoryActivationOutcome
        self.projectionRebuildRequested = projectionRebuildRequested
    }
}

/// Prevents a formal activation use case from being initialized by an arbitrary
/// pending Candidate. Only a fresh terminal formal confirmation result can make
/// a Candidate eligible for the next authority boundary.
enum OwnerTruthInterviewCandidateMemoryActivationEligibility: Equatable, Sendable {
    case batchConfirmation(OwnerTruthInterviewCandidateConfirmationBatchResult)
    case singleConfirmation(OwnerTruthInterviewCandidateConfirmationSingleResult)

    var reviewBatchID: OwnerTruthRecordID {
        switch self {
        case .batchConfirmation(let result): return result.reviewBatchID
        case .singleConfirmation(let result): return result.reviewBatchID
        }
    }

    var eligibleCandidateIDs: Set<OwnerTruthRecordID> {
        switch self {
        case .batchConfirmation(let result):
            return Set(result.acceptedCandidateIDs)
        case .singleConfirmation(let result):
            switch result.decision {
            case .accepted, .corrected:
                return [result.candidateID]
            case .pending, .rejected, .invalidated:
                return []
            }
        }
    }
}

/// Separate from both the QA Candidate review transport and the formal decision
/// transport. The activation route has its own policy evidence and must never
/// receive the QA header.
protocol OwnerTruthInterviewCandidateMemoryActivationClient: AnyObject {
    func activateOwnerTruthInterviewCandidateMemory(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateMemoryActivationCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateMemoryActivationResult, Error>) -> Void
    )
}

enum OwnerTruthInterviewCandidateMemoryActivationIntent: Equatable, Sendable {
    case activate
}

enum OwnerTruthInterviewCandidateMemoryActivationPhase: Equatable, Sendable {
    case idle
    case unavailable
    case activating
    case activated
    case failed
}

enum OwnerTruthInterviewCandidateMemoryActivationNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case invalidEligibility
    case responseMismatch
    case requestFailed
    case activated
}

struct OwnerTruthInterviewCandidateMemoryActivationViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateMemoryActivationPhase
    let latestResult: OwnerTruthInterviewCandidateMemoryActivationResult?
    let notice: OwnerTruthInterviewCandidateMemoryActivationNotice?

    static let idle = OwnerTruthInterviewCandidateMemoryActivationViewState(
        phase: .idle,
        latestResult: nil,
        notice: nil
    )
}

/// Lease-fenced client-side boundary for the explicit promotion step. It is
/// intentionally not rendered in public UI until the corresponding Release
/// Policy allows it; this use case only establishes the formal contract.
final class OwnerTruthInterviewCandidateMemoryActivationUseCase {
    typealias CommandIDFactory = () -> String

    private enum EligibilitySource: Equatable, Sendable {
        case freshConfirmation(
            confirmation: OwnerTruthInterviewCandidateConfirmation,
            eligibility: OwnerTruthInterviewCandidateMemoryActivationEligibility
        )
        case activationInbox(OwnerTruthInterviewCandidateMemoryActivationInbox)
    }

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let eligibilitySource: EligibilitySource
    private let reviewBatchID: OwnerTruthRecordID
    private let candidateID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewCandidateMemoryActivationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let commandIDFactory: CommandIDFactory
    private var commandID: String?
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateMemoryActivationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateMemoryActivationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        confirmation: OwnerTruthInterviewCandidateConfirmation,
        eligibility: OwnerTruthInterviewCandidateMemoryActivationEligibility,
        candidateID: OwnerTruthRecordID,
        client: OwnerTruthInterviewCandidateMemoryActivationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false },
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        eligibilitySource = .freshConfirmation(
            confirmation: confirmation,
            eligibility: eligibility
        )
        reviewBatchID = confirmation.reviewBatchID
        self.candidateID = candidateID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.commandIDFactory = commandIDFactory
    }

    /// Replays a server-discovered, value-free pending activation after the
    /// original confirmation screen has gone away. The inbox must already be
    /// bound to the active AccountLease; arbitrary UUIDs cannot be promoted by
    /// this overload.
    init(
        accountLease: AccountLease,
        activationInbox: OwnerTruthInterviewCandidateMemoryActivationInbox,
        item: OwnerTruthInterviewCandidateMemoryActivationInboxItem,
        client: OwnerTruthInterviewCandidateMemoryActivationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false },
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        eligibilitySource = .activationInbox(activationInbox)
        reviewBatchID = item.reviewBatchID
        candidateID = item.candidateID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthInterviewCandidateMemoryActivationIntent) {
        switch intent {
        case .activate:
            activate()
        }
    }

    private func activate() {
        guard let vaultID = beginRequestOrFail(),
              let command = makeCommandOrFail() else {
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewCandidateMemoryActivationViewState(
            phase: .activating,
            latestResult: nil,
            notice: nil
        )
        client.activateOwnerTruthInterviewCandidateMemory(vaultID: vaultID, command: command) { [weak self] result in
            self?.receive(result, expectedCommand: command, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID,
              vaultID.rawValue == accountLease.vaultId else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        guard isEligible(for: vaultID) else {
            transitionFailure(.invalidEligibility)
            return nil
        }
        return vaultID
    }

    private func isEligible(for vaultID: OwnerTruthVaultID) -> Bool {
        switch eligibilitySource {
        case .freshConfirmation(let confirmation, let eligibility):
            return confirmation.vaultID == vaultID
                && confirmation.vaultID.rawValue == accountLease.vaultId
                && confirmation.isBound(to: accountLease)
                && eligibility.reviewBatchID == confirmation.reviewBatchID
                && reviewBatchID == confirmation.reviewBatchID
                && eligibility.eligibleCandidateIDs.contains(candidateID)
                && (confirmation.batchCandidates.contains(where: { $0.id == candidateID })
                    || confirmation.singleCandidates.contains(where: { $0.id == candidateID }))
        case .activationInbox(let inbox):
            return inbox.vaultID == vaultID
                && inbox.vaultID.rawValue == accountLease.vaultId
                && inbox.isBound(to: accountLease)
                && inbox.items.contains(where: {
                    $0.reviewBatchID == reviewBatchID && $0.candidateID == candidateID
                })
        }
    }

    private func makeCommandOrFail() -> OwnerTruthInterviewCandidateMemoryActivationCommand? {
        let stableCommandID = commandID ?? commandIDFactory()
        commandID = stableCommandID
        do {
            return try OwnerTruthInterviewCandidateMemoryActivationCommand(
                commandID: stableCommandID,
                reviewBatchID: reviewBatchID,
                candidateID: candidateID
            )
        } catch {
            transitionFailure(.requestFailed)
            return nil
        }
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateMemoryActivationResult, Error>,
        expectedCommand: OwnerTruthInterviewCandidateMemoryActivationCommand,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let activation):
            guard activation.reviewBatchID == expectedCommand.reviewBatchID,
                  activation.candidateID == expectedCommand.candidateID else {
                transitionFailure(.responseMismatch)
                return
            }
            viewState = OwnerTruthInterviewCandidateMemoryActivationViewState(
                phase: .activated,
                latestResult: activation,
                notice: .activated
            )
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func resetForUnavailable(
        _ notice: OwnerTruthInterviewCandidateMemoryActivationNotice
    ) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateMemoryActivationViewState(
            phase: .unavailable,
            latestResult: nil,
            notice: notice
        )
    }

    private func transitionFailure(
        _ notice: OwnerTruthInterviewCandidateMemoryActivationNotice
    ) {
        viewState = OwnerTruthInterviewCandidateMemoryActivationViewState(
            phase: .failed,
            latestResult: nil,
            notice: notice
        )
    }
}

// MARK: - Default-off interview session state read

/// This is a narrow QA-only read model for the persisted interview session.
/// It intentionally excludes conversation text, identifiers that are not
/// required by the UI, and every owner-truth artifact payload.
enum OwnerTruthInterviewSessionLifecycle: String, Codable, Equatable, Sendable {
    case active
    case paused
    case ended
}

enum OwnerTruthInterviewSessionBoundary: String, Codable, Equatable, Sendable {
    case open
    case skipOnce
    case cooldown
    case doNotAsk
}

enum OwnerTruthInterviewSessionFatigue: String, Codable, Equatable, Sendable {
    case normal
    case guarded
    case exhausted
}

struct OwnerTruthInterviewSessionState: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-session-state-read-v1"

    let vaultID: OwnerTruthVaultID
    let lifecycle: OwnerTruthInterviewSessionLifecycle
    let boundary: OwnerTruthInterviewSessionBoundary
    let rowVersion: Int
    let threadVersion: Int
    let ownerTurnCount: Int
    let deepeningTurnCount: Int
    let candidateBatchTurnCount: Int
    let fatigue: OwnerTruthInterviewSessionFatigue
    let hasPendingReviewBatch: Bool
    let authorityEpoch: Int

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard OwnerTruthInterviewSessionStateContract.requiredString(object["schemaVersion"]) == Self.schemaVersion,
              OwnerTruthInterviewSessionStateContract.requiredString(object["vaultId"]) == expectedVaultID.rawValue,
              let session = object["session"] as? [String: Any],
              let lifecycleRaw = OwnerTruthInterviewSessionStateContract.requiredString(session["state"]),
              let lifecycle = OwnerTruthInterviewSessionLifecycle(rawValue: lifecycleRaw),
              let boundaryRaw = OwnerTruthInterviewSessionStateContract.requiredString(session["boundary"]),
              let boundary = OwnerTruthInterviewSessionBoundary(rawValue: boundaryRaw),
              let rowVersion = OwnerTruthInterviewSessionStateContract.positiveInt(session["rowVersion"]),
              let threadVersion = OwnerTruthInterviewSessionStateContract.positiveInt(session["threadVersion"]),
              let ownerTurnCount = OwnerTruthInterviewSessionStateContract.nonNegativeInt(session["ownerTurnCount"]),
              let deepeningTurnCount = OwnerTruthInterviewSessionStateContract.nonNegativeInt(session["deepeningTurnCount"]),
              let candidateBatchTurnCount = OwnerTruthInterviewSessionStateContract.nonNegativeInt(session["candidateBatchTurnCount"]),
              let fatigueRaw = OwnerTruthInterviewSessionStateContract.requiredString(session["fatigue"]),
              let fatigue = OwnerTruthInterviewSessionFatigue(rawValue: fatigueRaw),
              let hasPendingReviewBatch = session["hasPendingReviewBatch"] as? Bool,
              let authorityEpoch = OwnerTruthInterviewSessionStateContract.nonNegativeInt(session["authorityEpoch"]) else {
            throw OwnerTruthRemoteContractError.invalidInterviewSessionState(
                "state response misses a required value-minimized field"
            )
        }

        vaultID = expectedVaultID
        self.lifecycle = lifecycle
        self.boundary = boundary
        self.rowVersion = rowVersion
        self.threadVersion = threadVersion
        self.ownerTurnCount = ownerTurnCount
        self.deepeningTurnCount = deepeningTurnCount
        self.candidateBatchTurnCount = candidateBatchTurnCount
        self.fatigue = fatigue
        self.hasPendingReviewBatch = hasPendingReviewBatch
        self.authorityEpoch = authorityEpoch
    }
}

/// Transport is kept separate from the use case so the QA view can use a
/// deterministic mock without opening a public network or Echo path.
protocol OwnerTruthInterviewSessionStateClient: AnyObject {
    func fetchOwnerTruthInterviewSessionState(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewSessionState, Error>) -> Void
    )
}

enum OwnerTruthInterviewSessionStateIntent: Equatable, Sendable {
    case refresh
}

enum OwnerTruthInterviewSessionStatePhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case unavailable
    case failed
}

enum OwnerTruthInterviewSessionStateNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case requestFailed
}

struct OwnerTruthInterviewSessionStateViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewSessionStatePhase
    let session: OwnerTruthInterviewSessionState?
    let notice: OwnerTruthInterviewSessionStateNotice?

    static let idle = OwnerTruthInterviewSessionStateViewState(
        phase: .idle,
        session: nil,
        notice: nil
    )
}

/// Owns only the QA read lifecycle. Account lease checks fence both request
/// submission and asynchronous commit so a previous account cannot paint a
/// later account's diagnostic screen.
final class OwnerTruthInterviewSessionStateUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let sessionID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewSessionStateClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewSessionStateViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewSessionStateViewState) -> Void)?

    init(
        accountLease: AccountLease,
        sessionID: OwnerTruthRecordID,
        client: OwnerTruthInterviewSessionStateClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.sessionID = sessionID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    func send(_ intent: OwnerTruthInterviewSessionStateIntent) {
        switch intent {
        case .refresh:
            refresh()
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewSessionStateViewState(
            phase: .loading,
            session: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewSessionState(
            vaultID: vaultID,
            sessionID: sessionID
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewSessionState, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            transitionUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let session):
            guard session.vaultID == vaultID,
                  session.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure()
                return
            }
            viewState = OwnerTruthInterviewSessionStateViewState(
                phase: .ready,
                session: session,
                notice: nil
            )
        case .failure:
            transitionFailure()
        }
    }

    private func transitionUnavailable(_ notice: OwnerTruthInterviewSessionStateNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewSessionStateViewState(
            phase: .unavailable,
            session: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewSessionStateViewState(
            phase: .failed,
            session: nil,
            notice: .requestFailed
        )
    }
}

private enum OwnerTruthInterviewSessionStateContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func positiveInt(_ value: Any?) -> Int? {
        guard let value = value as? Int, value > 0 else { return nil }
        return value
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? Int, value >= 0 else { return nil }
        return value
    }
}

// MARK: - Default-off interview orchestration read

/// These are policy decisions, not generated responses. They remain distinct
/// from product-facing Echo copy and cannot carry user message content.
enum OwnerTruthInterviewOrchestrationAction: String, Equatable, Sendable {
    case listen
    case deepen
    case clarify
    case broaden
    case summarize
    case pause
}

enum OwnerTruthInterviewOrchestrationNextSessionState: String, Equatable, Sendable {
    case active
    case paused
    case ending
    case ended
    case invalid
}

/// The six transient hints are the complete client payload. In particular,
/// callers cannot pass topic text, a topic identifier, or an authorization
/// assertion to the QA policy endpoint.
struct OwnerTruthInterviewOrchestrationSignals: Equatable, Sendable {
    let topicIncomplete: Bool
    let needsClarification: Bool
    let userChangedTopic: Bool
    let userReopenedDoNotAskTopic: Bool
    let isSensitive: Bool
    let acceptedBroadenRecommendation: Bool

    init(
        topicIncomplete: Bool = false,
        needsClarification: Bool = false,
        userChangedTopic: Bool = false,
        userReopenedDoNotAskTopic: Bool = false,
        isSensitive: Bool = false,
        acceptedBroadenRecommendation: Bool = false
    ) {
        self.topicIncomplete = topicIncomplete
        self.needsClarification = needsClarification
        self.userChangedTopic = userChangedTopic
        self.userReopenedDoNotAskTopic = userReopenedDoNotAskTopic
        self.isSensitive = isSensitive
        self.acceptedBroadenRecommendation = acceptedBroadenRecommendation
    }

    var backendPayload: [String: Any] {
        [
            "topicIncomplete": topicIncomplete,
            "needsClarification": needsClarification,
            "userChangedTopic": userChangedTopic,
            "userReopenedDoNotAskTopic": userReopenedDoNotAskTopic,
            "isSensitive": isSensitive,
            "acceptedBroadenRecommendation": acceptedBroadenRecommendation,
        ]
    }
}

struct OwnerTruthInterviewOrchestrationDecision: Equatable, Sendable {
    let action: OwnerTruthInterviewOrchestrationAction
    let reasonCode: String
    let maxFollowupsRemaining: Int
    let reviewBatchDue: Bool
    let nextSessionState: OwnerTruthInterviewOrchestrationNextSessionState
    let consumesOneShotBoundary: Bool
}

struct OwnerTruthInterviewOrchestrationPersistedSession: Equatable, Sendable {
    let boundary: OwnerTruthInterviewSessionBoundary
    let candidateBatchTurnCount: Int
    let deepeningTurnCount: Int
    let fatigue: OwnerTruthInterviewSessionFatigue
    let ownerTurnCount: Int
    let lifecycle: OwnerTruthInterviewSessionLifecycle
}

/// Value-free policy read used only by the hidden QA lane. The initializer
/// checks every envelope key so a future backend expansion cannot quietly put
/// a transcript, topic or Owner Truth identifier into this diagnostic path.
struct OwnerTruthInterviewOrchestrationRead: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-session-orchestration-read-response-v1"
    static let orchestrationSchemaVersion = "owner-truth-interview-session-orchestration-v1"
    static let policySchemaVersion = "owner-truth-interview-orchestration-v1"
    static let transientSignalsDescriptor = "opaqueTopicAndBooleanPolicySignalsOnly"

    let vaultID: OwnerTruthVaultID
    let decision: OwnerTruthInterviewOrchestrationDecision
    let persistedSession: OwnerTruthInterviewOrchestrationPersistedSession

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == ["schemaVersion", "vaultId", "orchestration"],
              OwnerTruthInterviewOrchestrationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewOrchestrationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let orchestration = object["orchestration"] as? [String: Any],
              Set(orchestration.keys) == [
                "schemaVersion",
                "policySchemaVersion",
                "decision",
                "persistedSession",
                "transientSignals",
              ],
              OwnerTruthInterviewOrchestrationContract.requiredString(
                orchestration["schemaVersion"]
              ) == Self.orchestrationSchemaVersion,
              OwnerTruthInterviewOrchestrationContract.requiredString(
                orchestration["policySchemaVersion"]
              ) == Self.policySchemaVersion,
              OwnerTruthInterviewOrchestrationContract.requiredString(
                orchestration["transientSignals"]
              ) == Self.transientSignalsDescriptor,
              let decisionObject = orchestration["decision"] as? [String: Any],
              let persistedSessionObject = orchestration["persistedSession"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidInterviewOrchestration(
                "response does not match the value-free envelope"
            )
        }

        decision = try Self.decodeDecision(decisionObject)
        persistedSession = try Self.decodePersistedSession(persistedSessionObject)
        vaultID = expectedVaultID
    }

    private static func decodeDecision(
        _ object: [String: Any]
    ) throws -> OwnerTruthInterviewOrchestrationDecision {
        guard Set(object.keys) == [
            "action",
            "consumesOneShotBoundary",
            "maxFollowupsRemaining",
            "nextSessionState",
            "reasonCode",
            "reviewBatchDue",
            "schemaVersion",
        ],
              OwnerTruthInterviewOrchestrationContract.requiredString(object["schemaVersion"])
                == policySchemaVersion,
              let actionRaw = OwnerTruthInterviewOrchestrationContract.requiredString(object["action"]),
              let action = OwnerTruthInterviewOrchestrationAction(rawValue: actionRaw),
              let reasonCode = OwnerTruthInterviewOrchestrationContract.opaqueIdentifier(
                object["reasonCode"]
              ),
              let maxFollowupsRemaining = OwnerTruthInterviewOrchestrationContract.boundedInt(
                object["maxFollowupsRemaining"],
                range: 0...4
              ),
              let reviewBatchDue = object["reviewBatchDue"] as? Bool,
              let nextStateRaw = OwnerTruthInterviewOrchestrationContract.requiredString(
                object["nextSessionState"]
              ),
              let nextSessionState = OwnerTruthInterviewOrchestrationNextSessionState(
                rawValue: nextStateRaw
              ),
              let consumesOneShotBoundary = object["consumesOneShotBoundary"] as? Bool else {
            throw OwnerTruthRemoteContractError.invalidInterviewOrchestration(
                "decision does not match the bounded policy contract"
            )
        }
        return OwnerTruthInterviewOrchestrationDecision(
            action: action,
            reasonCode: reasonCode,
            maxFollowupsRemaining: maxFollowupsRemaining,
            reviewBatchDue: reviewBatchDue,
            nextSessionState: nextSessionState,
            consumesOneShotBoundary: consumesOneShotBoundary
        )
    }

    private static func decodePersistedSession(
        _ object: [String: Any]
    ) throws -> OwnerTruthInterviewOrchestrationPersistedSession {
        guard Set(object.keys) == [
            "boundary",
            "candidateBatchTurnCount",
            "deepeningTurnCount",
            "fatigue",
            "ownerTurnCount",
            "state",
        ],
              let boundaryRaw = OwnerTruthInterviewOrchestrationContract.requiredString(
                object["boundary"]
              ),
              let boundary = OwnerTruthInterviewSessionBoundary(rawValue: boundaryRaw),
              let candidateBatchTurnCount = OwnerTruthInterviewOrchestrationContract.nonNegativeInt(
                object["candidateBatchTurnCount"]
              ),
              let deepeningTurnCount = OwnerTruthInterviewOrchestrationContract.nonNegativeInt(
                object["deepeningTurnCount"]
              ),
              let fatigueRaw = OwnerTruthInterviewOrchestrationContract.requiredString(
                object["fatigue"]
              ),
              let fatigue = OwnerTruthInterviewSessionFatigue(rawValue: fatigueRaw),
              let ownerTurnCount = OwnerTruthInterviewOrchestrationContract.nonNegativeInt(
                object["ownerTurnCount"]
              ),
              let lifecycleRaw = OwnerTruthInterviewOrchestrationContract.requiredString(
                object["state"]
              ),
              let lifecycle = OwnerTruthInterviewSessionLifecycle(rawValue: lifecycleRaw) else {
            throw OwnerTruthRemoteContractError.invalidInterviewOrchestration(
                "persisted session does not match the value-free contract"
            )
        }
        return OwnerTruthInterviewOrchestrationPersistedSession(
            boundary: boundary,
            candidateBatchTurnCount: candidateBatchTurnCount,
            deepeningTurnCount: deepeningTurnCount,
            fatigue: fatigue,
            ownerTurnCount: ownerTurnCount,
            lifecycle: lifecycle
        )
    }
}

protocol OwnerTruthInterviewOrchestrationClient: AnyObject {
    func fetchOwnerTruthInterviewOrchestration(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        signals: OwnerTruthInterviewOrchestrationSignals,
        completion: @escaping (Result<OwnerTruthInterviewOrchestrationRead, Error>) -> Void
    )
}

enum OwnerTruthInterviewOrchestrationIntent: Equatable, Sendable {
    case refresh(OwnerTruthInterviewOrchestrationSignals)
}

enum OwnerTruthInterviewOrchestrationPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case unavailable
    case failed
}

enum OwnerTruthInterviewOrchestrationNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case requestFailed
}

struct OwnerTruthInterviewOrchestrationViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewOrchestrationPhase
    let orchestration: OwnerTruthInterviewOrchestrationRead?
    let notice: OwnerTruthInterviewOrchestrationNotice?

    static let idle = OwnerTruthInterviewOrchestrationViewState(
        phase: .idle,
        orchestration: nil,
        notice: nil
    )
}

/// This lifecycle protects the QA diagnostic read from account switching. It
/// deliberately has no UI ownership and cannot change the interview state.
final class OwnerTruthInterviewOrchestrationUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let sessionID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewOrchestrationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewOrchestrationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewOrchestrationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        sessionID: OwnerTruthRecordID,
        client: OwnerTruthInterviewOrchestrationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.sessionID = sessionID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    func send(_ intent: OwnerTruthInterviewOrchestrationIntent) {
        switch intent {
        case .refresh(let signals):
            refresh(signals: signals)
        }
    }

    private func refresh(signals: OwnerTruthInterviewOrchestrationSignals) {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewOrchestrationViewState(
            phase: .loading,
            orchestration: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewOrchestration(
            vaultID: vaultID,
            sessionID: sessionID,
            signals: signals
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewOrchestrationRead, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            transitionUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let orchestration):
            guard orchestration.vaultID == vaultID,
                  orchestration.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure()
                return
            }
            viewState = OwnerTruthInterviewOrchestrationViewState(
                phase: .ready,
                orchestration: orchestration,
                notice: nil
            )
        case .failure:
            transitionFailure()
        }
    }

    private func transitionUnavailable(_ notice: OwnerTruthInterviewOrchestrationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewOrchestrationViewState(
            phase: .unavailable,
            orchestration: nil,
            notice: notice
        )
    }

    private func transitionFailure() {
        viewState = OwnerTruthInterviewOrchestrationViewState(
            phase: .failed,
            orchestration: nil,
            notice: .requestFailed
        )
    }
}

private enum OwnerTruthInterviewOrchestrationContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? Int, value >= 0 else { return nil }
        return value
    }

    static func boundedInt(_ value: Any?, range: ClosedRange<Int>) -> Int? {
        guard let value = nonNegativeInt(value), range.contains(value) else { return nil }
        return value
    }

    static func opaqueIdentifier(_ value: Any?) -> String? {
        guard let value = requiredString(value), value.utf8.count <= 128 else { return nil }
        let scalars = Array(value.unicodeScalars)
        guard let first = scalars.first, isASCIILetter(first) else { return nil }
        guard scalars.dropFirst().allSatisfy(isAllowedOpaqueIdentifierScalar) else { return nil }
        return value
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    private static func isAllowedOpaqueIdentifierScalar(_ scalar: Unicode.Scalar) -> Bool {
        isASCIILetter(scalar)
            || (48...57).contains(scalar.value)
            || scalar == "."
            || scalar == "_"
            || scalar == ":"
            || scalar == "-"
    }
}

// MARK: - Default-off interview natural-input command

/// A write or explicit resume handle intentionally has no conversation text.
/// It is sufficient to preserve optimistic version fences without turning the
/// private interview record into a visible transcript.
enum OwnerTruthInterviewNaturalInputReceiptOutcome: String, Equatable, Sendable {
    case created
    case deduplicated
    case resumed
}

struct OwnerTruthInterviewNaturalInputReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-session-command-v1"

    let vaultID: OwnerTruthVaultID
    let outcome: OwnerTruthInterviewNaturalInputReceiptOutcome
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let threadVersion: Int
    let sessionVersion: Int
    let lifecycle: OwnerTruthInterviewSessionLifecycle
    let boundary: OwnerTruthInterviewSessionBoundary
    let messageID: OwnerTruthRecordID?
    let messageSequence: Int?

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard OwnerTruthInterviewNaturalInputContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewNaturalInputContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let receipt = object["receipt"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "command receipt misses a required value-minimized field"
            )
        }
        try self.init(receiptJSONObject: receipt, expectedVaultID: expectedVaultID)
    }

    fileprivate init(
        receiptJSONObject receipt: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard let outcomeRaw = OwnerTruthInterviewNaturalInputContract.requiredString(receipt["status"]),
              let outcome = OwnerTruthInterviewNaturalInputReceiptOutcome(rawValue: outcomeRaw),
              let threadID = OwnerTruthInterviewNaturalInputContract.recordID(receipt["threadId"]),
              let sessionID = OwnerTruthInterviewNaturalInputContract.recordID(receipt["sessionId"]),
              let threadVersion = OwnerTruthInterviewNaturalInputContract.positiveInt(receipt["threadVersion"]),
              let sessionVersion = OwnerTruthInterviewNaturalInputContract.positiveInt(receipt["sessionVersion"]),
              let lifecycleRaw = OwnerTruthInterviewNaturalInputContract.requiredString(receipt["state"]),
              let lifecycle = OwnerTruthInterviewSessionLifecycle(rawValue: lifecycleRaw),
              let boundaryRaw = OwnerTruthInterviewNaturalInputContract.requiredString(receipt["boundary"]),
              let boundary = OwnerTruthInterviewSessionBoundary(rawValue: boundaryRaw) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "command receipt misses a required value-minimized field"
            )
        }

        let messageID = try OwnerTruthInterviewNaturalInputContract.optionalRecordID(
            receipt["messageId"],
            field: "messageId"
        )
        let messageSequence = try OwnerTruthInterviewNaturalInputContract.optionalPositiveInt(
            receipt["messageSequence"],
            field: "messageSequence"
        )
        guard (messageID == nil) == (messageSequence == nil) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "message metadata must be present together or absent together"
            )
        }
        guard outcome != .resumed || (messageID == nil && messageSequence == nil) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "resumed session handle must not include message metadata"
            )
        }

        vaultID = expectedVaultID
        self.outcome = outcome
        self.threadID = threadID
        self.sessionID = sessionID
        self.threadVersion = threadVersion
        self.sessionVersion = sessionVersion
        self.lifecycle = lifecycle
        self.boundary = boundary
        self.messageID = messageID
        self.messageSequence = messageSequence
    }

    func matches(_ command: OwnerTruthInterviewNaturalInputStartCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && messageID == nil
            && messageSequence == nil
    }

    func matches(_ command: OwnerTruthInterviewNaturalInputAppendCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && messageID == command.messageID
            && messageSequence != nil
            && threadVersion > command.expectedThreadVersion
            && sessionVersion > command.expectedSessionVersion
    }

    func matches(_ command: OwnerTruthInterviewEndCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && lifecycle == .ended
            && boundary == .open
            && messageID == nil
            && messageSequence == nil
            && threadVersion > command.expectedThreadVersion
            && sessionVersion > command.expectedSessionVersion
    }

    func matches(_ command: OwnerTruthInterviewBoundaryCommand) -> Bool {
        let expectedLifecycle: OwnerTruthInterviewSessionLifecycle =
            command.boundary == .skipOnce ? .active : .paused
        return threadID == command.threadID
            && sessionID == command.sessionID
            && boundary == command.boundary
            && lifecycle == expectedLifecycle
            && messageID == nil
            && messageSequence == nil
            && sessionVersion > command.expectedSessionVersion
    }

    func matches(_ command: OwnerTruthInterviewPacingCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && lifecycle == .active
            && boundary == .open
            && messageID == nil
            && messageSequence == nil
            && sessionVersion > command.expectedSessionVersion
    }

    func matches(_ command: OwnerTruthInterviewPauseForTopicSwitchCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && lifecycle == .paused
            && messageID == nil
            && messageSequence == nil
            && threadVersion > command.expectedThreadVersion
            && sessionVersion > command.expectedSessionVersion
    }

    func matches(_ command: OwnerTruthInterviewRestoreDoNotAskCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && lifecycle == .active
            && boundary == .open
            && messageID == nil
            && messageSequence == nil
            && sessionVersion > command.expectedSessionVersion
    }

    func matches(_ command: OwnerTruthInterviewRestoreCooldownCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && lifecycle == .active
            && boundary == .open
            && messageID == nil
            && messageSequence == nil
            && sessionVersion > command.expectedSessionVersion
    }
}

/// The current-session read either gives the authenticated owner a stable
/// handle for the one active interview, or explicitly confirms that a new
/// session may be created. It never returns transcript, review or pacing data.
struct OwnerTruthInterviewNaturalInputCurrentSession: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-current-session-v1"

    let vaultID: OwnerTruthVaultID
    let receipt: OwnerTruthInterviewNaturalInputReceipt?
    let entryMode: OwnerTruthInterviewEntryMode?

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard OwnerTruthInterviewNaturalInputContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewNaturalInputContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "current session response misses a required value-minimized field"
            )
        }

        if let value = object["currentSession"], !(value is NSNull) {
            guard let currentSession = value as? [String: Any] else {
                throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                    "currentSession must be an object or null"
                )
            }
            let parsedReceipt = try OwnerTruthInterviewNaturalInputReceipt(
                receiptJSONObject: currentSession,
                expectedVaultID: expectedVaultID
            )
            guard parsedReceipt.outcome == .resumed,
                  parsedReceipt.lifecycle == .active,
                  parsedReceipt.messageID == nil,
                  parsedReceipt.messageSequence == nil else {
                throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                    "currentSession must contain an active resumed session handle"
                )
            }
            guard let parsedEntryMode = OwnerTruthInterviewEntryMode(
                rawValue: OwnerTruthInterviewNaturalInputContract.requiredString(
                    currentSession["entryMode"]
                ) ?? OwnerTruthInterviewEntryMode.naturalInput.rawValue
            ) else {
                throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                    "currentSession contains an unsupported entry mode"
                )
            }
            receipt = parsedReceipt
            entryMode = parsedEntryMode
        } else {
            receipt = nil
            entryMode = nil
        }
        vaultID = expectedVaultID
    }
}

enum OwnerTruthInterviewEntryMode: String, Equatable, Sendable {
    case naturalInput
    case live
    case recommendation
    case resume
}

/// A product-safe projection of one private interview session. It intentionally
/// contains no transcript text, Candidate content, review IDs, pacing counters
/// or internal fatigue state. The UI maps this bounded state to natural copy.
enum OwnerTruthInterviewNaturalInputContinuationState: String, Equatable, Sendable {
    case readyForNarrative
    case narrativeRecorded
    case reviewPending
    case paused
    case ended
}

struct OwnerTruthInterviewNaturalInputContinuation: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-session-presentation-v1"

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthInterviewNaturalInputContinuationState
    let canContinue: Bool
    let canContinueLater: Bool

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard OwnerTruthInterviewNaturalInputContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewNaturalInputContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let presentation = object["presentation"] as? [String: Any],
              let stateRaw = OwnerTruthInterviewNaturalInputContract.requiredString(
                presentation["state"]
              ),
              let state = OwnerTruthInterviewNaturalInputContinuationState(rawValue: stateRaw),
              let canContinue = OwnerTruthInterviewNaturalInputContract.requiredBool(
                presentation["canContinue"]
              ),
              let canContinueLater = OwnerTruthInterviewNaturalInputContract.requiredBool(
                presentation["canContinueLater"]
              ) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "session presentation misses a required value-minimized field"
            )
        }

        vaultID = expectedVaultID
        self.state = state
        self.canContinue = canContinue
        self.canContinueLater = canContinueLater
    }
}

struct OwnerTruthInterviewNaturalInputStartCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let entryMode: OwnerTruthInterviewEntryMode

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        entryMode: OwnerTruthInterviewEntryMode = .naturalInput
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "start command id must be non-empty"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.entryMode = entryMode
    }

    var backendPayload: [String: Any] {
        var payload: [String: Any] = [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "sessionId": sessionID.rawValue.uuidString.lowercased(),
        ]
        if entryMode != .naturalInput {
            payload["entryMode"] = entryMode.rawValue
        }
        return payload
    }
}

enum OwnerTruthInterviewNaturalInputMessageRole: String, Equatable, Sendable {
    case owner
    case assistant
}

enum OwnerTruthInterviewNaturalInputCaptureMode: String, Equatable, Sendable {
    case naturalInput
    case live
}

struct OwnerTruthInterviewNaturalInputAppendCommand: Equatable, Sendable {
    static let maximumCharacterCount = 20_000

    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let messageID: OwnerTruthRecordID
    let expectedThreadVersion: Int
    let expectedSessionVersion: Int
    let text: String
    let role: OwnerTruthInterviewNaturalInputMessageRole
    let captureMode: OwnerTruthInterviewNaturalInputCaptureMode

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        messageID: OwnerTruthRecordID,
        expectedThreadVersion: Int,
        expectedSessionVersion: Int,
        text: String,
        role: OwnerTruthInterviewNaturalInputMessageRole = .owner,
        captureMode: OwnerTruthInterviewNaturalInputCaptureMode = .naturalInput
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              let text = OwnerTruthInterviewNaturalInputContract.nonEmptyString(text),
              text.count <= Self.maximumCharacterCount,
              expectedThreadVersion > 0,
              expectedSessionVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "append command requires non-empty bounded text and positive versions"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.messageID = messageID
        self.expectedThreadVersion = expectedThreadVersion
        self.expectedSessionVersion = expectedSessionVersion
        self.text = text
        self.role = role
        self.captureMode = captureMode
    }

    var backendPayload: [String: Any] {
        var payload: [String: Any] = [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "messageId": messageID.rawValue.uuidString.lowercased(),
            "expectedThreadVersion": expectedThreadVersion,
            "expectedSessionVersion": expectedSessionVersion,
            "text": text,
        ]
        if role != .owner {
            payload["role"] = role.rawValue
        }
        if captureMode != .naturalInput {
            payload["captureMode"] = captureMode.rawValue
        }
        return payload
    }
}

/// An explicit end for one persisted private interview. It carries no reason,
/// transcript, Candidate identifier, or client-selected review-batch state.
/// The server decides whether a hidden session-exit batch is due.
struct OwnerTruthInterviewEndCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedThreadVersion: Int
    let expectedSessionVersion: Int

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedThreadVersion: Int,
        expectedSessionVersion: Int
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              expectedThreadVersion > 0,
              expectedSessionVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "end command requires a non-empty command id and positive versions"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedThreadVersion = expectedThreadVersion
        self.expectedSessionVersion = expectedSessionVersion
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "expectedThreadVersion": expectedThreadVersion,
            "expectedSessionVersion": expectedSessionVersion,
        ]
    }
}

/// An explicit private-interview boundary. This command deliberately has no
/// free-form reason, transcript text or reopen operation: product policy must
/// introduce any reactivation flow as a separate reviewed contract.
struct OwnerTruthInterviewBoundaryCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedSessionVersion: Int
    let boundary: OwnerTruthInterviewSessionBoundary

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedSessionVersion: Int,
        boundary: OwnerTruthInterviewSessionBoundary
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              expectedSessionVersion > 0,
              boundary != .open else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "boundary command requires a positive version and a supported owner control"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedSessionVersion = expectedSessionVersion
        self.boundary = boundary
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "expectedSessionVersion": expectedSessionVersion,
            "boundary": boundary.rawValue,
        ]
    }
}

/// A QA-only pacing fact for the private interview orchestrator. It carries
/// no transcript text, topic identifier, candidate, or client-owned policy.
/// The server owns the allowed sequence and follow-up budget.
enum OwnerTruthInterviewPacingEvent: String, Equatable, Sendable {
    case deepeningCompleted
    case summaryCompleted
}

struct OwnerTruthInterviewPacingCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedSessionVersion: Int
    let event: OwnerTruthInterviewPacingEvent

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedSessionVersion: Int,
        event: OwnerTruthInterviewPacingEvent
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              expectedSessionVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "pacing command requires a non-empty command id and positive session version"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedSessionVersion = expectedSessionVersion
        self.event = event
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "expectedSessionVersion": expectedSessionVersion,
            "event": event.rawValue,
        ]
    }
}

/// A QA-only lifecycle fence for an explicit owner topic switch. It carries
/// no topic text, topic identifier, classifier result, or next-session id;
/// the next session is created by the existing start command after this pause
/// receipt has been accepted.
struct OwnerTruthInterviewPauseForTopicSwitchCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedThreadVersion: Int
    let expectedSessionVersion: Int

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedThreadVersion: Int,
        expectedSessionVersion: Int
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              expectedThreadVersion > 0,
              expectedSessionVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "topic switch requires a non-empty command id and positive versions"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedThreadVersion = expectedThreadVersion
        self.expectedSessionVersion = expectedSessionVersion
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "expectedThreadVersion": expectedThreadVersion,
            "expectedSessionVersion": expectedSessionVersion,
        ]
    }
}

/// A separately named, explicitly confirmed action that can reopen only a
/// persisted `doNotAsk` boundary. It is not a generic `boundary=open` write.
struct OwnerTruthInterviewRestoreDoNotAskCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedSessionVersion: Int

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedSessionVersion: Int
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              expectedSessionVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "doNotAsk restore requires a non-empty command id and positive version"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedSessionVersion = expectedSessionVersion
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "expectedSessionVersion": expectedSessionVersion,
            "confirmed": true,
        ]
    }
}

/// A separately named QA-only action that can reopen a cooldown only after
/// the backend's server-clock check has elapsed. It is not a generic
/// `boundary=open` write and it carries no client-controlled cooldown value.
struct OwnerTruthInterviewRestoreCooldownCommand: Equatable, Sendable {
    let commandID: String
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedSessionVersion: Int

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedSessionVersion: Int
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID),
              expectedSessionVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "cooldown restore requires a non-empty command id and positive version"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedSessionVersion = expectedSessionVersion
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "expectedSessionVersion": expectedSessionVersion,
        ]
    }
}

protocol OwnerTruthInterviewNaturalInputClient: AnyObject {
    func fetchOwnerTruthInterviewNaturalInputCurrentSession(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputCurrentSession, Error>) -> Void
    )

    func startOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputStartCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func appendOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputAppendCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func endOwnerTruthInterviewNaturalInput(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewEndCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func setOwnerTruthInterviewBoundary(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewBoundaryCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func recordOwnerTruthInterviewPacing(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPacingCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func pauseOwnerTruthInterviewForTopicSwitch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPauseForTopicSwitchCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func restoreOwnerTruthInterviewDoNotAsk(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreDoNotAskCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func restoreOwnerTruthInterviewCooldown(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreCooldownCommand,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputReceipt, Error>) -> Void
    )

    func fetchOwnerTruthInterviewNaturalInputContinuation(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewNaturalInputContinuation, Error>) -> Void
    )
}

// MARK: - Formal pending review-batch acknowledgement

/// The formal natural-input route can freeze a private session boundary before
/// any Candidate or Memory work begins. This trigger is intentionally only a
/// display-safe lifecycle label, never a summary of the shared content.
enum OwnerTruthInterviewReviewBatchTrigger: String, Equatable, Sendable {
    case turnThreshold
    case sessionExit
}

enum OwnerTruthInterviewReviewBatchAcknowledgementOutcome: String, Equatable, Sendable {
    case acknowledged
    case deduplicated
}

/// An opaque, same-owner handle for a frozen review boundary. It rejects any
/// additive field so this product path cannot silently become a transcript,
/// Source, Candidate, or Memory discovery transport.
struct OwnerTruthInterviewPendingReviewBatchInboxItem: Equatable, Sendable, Identifiable {
    let reviewBatchID: OwnerTruthRecordID
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let reviewBatchVersion: Int
    let sessionVersion: Int
    let trigger: OwnerTruthInterviewReviewBatchTrigger
    let capturedCandidateBatchTurnCount: Int

    var id: OwnerTruthRecordID { reviewBatchID }

    init(backendJSONObject object: [String: Any]) throws {
        let allowedKeys: Set<String> = [
            "reviewBatchId",
            "threadId",
            "sessionId",
            "reviewBatchVersion",
            "sessionVersion",
            "trigger",
            "capturedCandidateBatchTurnCount",
        ]
        guard Set(object.keys) == allowedKeys,
              let reviewBatchID = OwnerTruthInterviewReviewBatchContract.recordID(object["reviewBatchId"]),
              let threadID = OwnerTruthInterviewReviewBatchContract.recordID(object["threadId"]),
              let sessionID = OwnerTruthInterviewReviewBatchContract.recordID(object["sessionId"]),
              let reviewBatchVersion = OwnerTruthInterviewReviewBatchContract.positiveInt(
                object["reviewBatchVersion"]
              ),
              let sessionVersion = OwnerTruthInterviewReviewBatchContract.positiveInt(
                object["sessionVersion"]
              ),
              let triggerRaw = OwnerTruthInterviewReviewBatchContract.requiredString(object["trigger"]),
              let trigger = OwnerTruthInterviewReviewBatchTrigger(rawValue: triggerRaw),
              let capturedCandidateBatchTurnCount = OwnerTruthInterviewReviewBatchContract.positiveInt(
                object["capturedCandidateBatchTurnCount"]
              ) else {
            throw OwnerTruthRemoteContractError.invalidInterviewPendingReviewBatchInbox(
                "pending review batch must contain only a valid opaque acknowledgement handle"
            )
        }

        self.reviewBatchID = reviewBatchID
        self.threadID = threadID
        self.sessionID = sessionID
        self.reviewBatchVersion = reviewBatchVersion
        self.sessionVersion = sessionVersion
        self.trigger = trigger
        self.capturedCandidateBatchTurnCount = capturedCandidateBatchTurnCount
    }
}

private struct OwnerTruthInterviewPendingReviewBatchInboxLeaseBinding: Equatable, Sendable {
    let accountLease: AccountLease

    func matches(_ accountLease: AccountLease) -> Bool {
        self.accountLease == accountLease
    }
}

/// Value-minimized discovery for formal batches that are awaiting the Owner's
/// explicit acknowledgement. The remote response is bound to the account lease
/// only after its completion fence passes.
struct OwnerTruthInterviewPendingReviewBatchInbox: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-pending-review-batch-inbox-v1"

    let vaultID: OwnerTruthVaultID
    let reviewBatches: [OwnerTruthInterviewPendingReviewBatchInboxItem]
    private var leaseBinding: OwnerTruthInterviewPendingReviewBatchInboxLeaseBinding?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        let allowedKeys: Set<String> = ["schemaVersion", "vaultId", "reviewBatches"]
        guard Set(object.keys) == allowedKeys,
              OwnerTruthInterviewReviewBatchContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewReviewBatchContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let itemObjects = object["reviewBatches"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidInterviewPendingReviewBatchInbox(
                "pending review batch inbox does not match the value-minimized envelope"
            )
        }

        let reviewBatches = try itemObjects.map(OwnerTruthInterviewPendingReviewBatchInboxItem.init)
        guard Set(reviewBatches.map(\.reviewBatchID)).count == reviewBatches.count else {
            throw OwnerTruthRemoteContractError.invalidInterviewPendingReviewBatchInbox(
                "pending review batch inbox repeats a review batch handle"
            )
        }

        vaultID = expectedVaultID
        self.reviewBatches = reviewBatches
        leaseBinding = nil
    }

    func bound(to accountLease: AccountLease) -> Self {
        var copy = self
        copy.leaseBinding = OwnerTruthInterviewPendingReviewBatchInboxLeaseBinding(
            accountLease: accountLease
        )
        return copy
    }

    func isBound(to accountLease: AccountLease) -> Bool {
        leaseBinding?.matches(accountLease) == true
    }
}

/// No narrative, candidate selection, or promotion input is accepted here.
/// The Owner can only assert the opaque version fence for the same frozen batch.
struct OwnerTruthInterviewReviewBatchAcknowledgementCommand: Equatable, Sendable {
    let commandID: String
    let reviewBatchID: OwnerTruthRecordID
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let expectedSessionVersion: Int
    let expectedReviewBatchVersion: Int

    init(
        commandID: String,
        reviewBatchID: OwnerTruthRecordID,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        expectedSessionVersion: Int,
        expectedReviewBatchVersion: Int
    ) throws {
        guard let commandID = OwnerTruthInterviewReviewBatchContract.nonEmptyString(commandID),
              expectedSessionVersion > 0,
              expectedReviewBatchVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewReviewBatchAcknowledgement(
                "acknowledgement command requires a non-empty id and positive version fences"
            )
        }
        self.commandID = commandID
        self.reviewBatchID = reviewBatchID
        self.threadID = threadID
        self.sessionID = sessionID
        self.expectedSessionVersion = expectedSessionVersion
        self.expectedReviewBatchVersion = expectedReviewBatchVersion
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "sessionId": sessionID.rawValue.uuidString.lowercased(),
            "expectedSessionVersion": expectedSessionVersion,
            "expectedReviewBatchVersion": expectedReviewBatchVersion,
        ]
    }
}

/// Receipt for exactly one acknowledgement. It deliberately proves only that a
/// frozen boundary advanced; later Candidate admission and Memory activation
/// remain separate authority steps.
struct OwnerTruthInterviewReviewBatchAcknowledgementReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-review-batch-acknowledgement-response-v1"

    let vaultID: OwnerTruthVaultID
    let outcome: OwnerTruthInterviewReviewBatchAcknowledgementOutcome
    let threadID: OwnerTruthRecordID
    let sessionID: OwnerTruthRecordID
    let sessionVersion: Int
    let reviewBatchID: OwnerTruthRecordID
    let trigger: OwnerTruthInterviewReviewBatchTrigger
    let reviewBatchVersion: Int
    let capturedCandidateBatchTurnCount: Int

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedReviewBatchID: OwnerTruthRecordID
    ) throws {
        let allowedKeys: Set<String> = [
            "schemaVersion",
            "vaultId",
            "status",
            "session",
            "reviewBatch",
            "candidateProposal",
            "memoryActivation",
        ]
        guard Set(object.keys) == allowedKeys,
              OwnerTruthInterviewReviewBatchContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewReviewBatchContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let outcomeRaw = OwnerTruthInterviewReviewBatchContract.requiredString(object["status"]),
              let outcome = OwnerTruthInterviewReviewBatchAcknowledgementOutcome(rawValue: outcomeRaw),
              let session = object["session"] as? [String: Any],
              Set(session.keys) == ["threadId", "sessionId", "sessionVersion"],
              let threadID = OwnerTruthInterviewReviewBatchContract.recordID(session["threadId"]),
              let sessionID = OwnerTruthInterviewReviewBatchContract.recordID(session["sessionId"]),
              let sessionVersion = OwnerTruthInterviewReviewBatchContract.positiveInt(
                session["sessionVersion"]
              ),
              let reviewBatch = object["reviewBatch"] as? [String: Any],
              Set(reviewBatch.keys) == [
                "reviewBatchId",
                "trigger",
                "state",
                "capturedCandidateBatchTurnCount",
                "rowVersion",
              ],
              let reviewBatchID = OwnerTruthInterviewReviewBatchContract.recordID(
                reviewBatch["reviewBatchId"]
              ),
              reviewBatchID == expectedReviewBatchID,
              let triggerRaw = OwnerTruthInterviewReviewBatchContract.requiredString(reviewBatch["trigger"]),
              let trigger = OwnerTruthInterviewReviewBatchTrigger(rawValue: triggerRaw),
              OwnerTruthInterviewReviewBatchContract.requiredString(reviewBatch["state"]) == "acknowledged",
              let capturedCandidateBatchTurnCount = OwnerTruthInterviewReviewBatchContract.positiveInt(
                reviewBatch["capturedCandidateBatchTurnCount"]
              ),
              let reviewBatchVersion = OwnerTruthInterviewReviewBatchContract.positiveInt(
                reviewBatch["rowVersion"]
              ),
              let candidateProposal = object["candidateProposal"] as? [String: Any],
              Set(candidateProposal.keys) == ["status"],
              OwnerTruthInterviewReviewBatchContract.requiredString(candidateProposal["status"])
                == "notStarted",
              let memoryActivation = object["memoryActivation"] as? [String: Any],
              Set(memoryActivation.keys) == ["status"],
              OwnerTruthInterviewReviewBatchContract.requiredString(memoryActivation["status"])
                == "notApplicable" else {
            throw OwnerTruthRemoteContractError.invalidInterviewReviewBatchAcknowledgement(
                "acknowledgement receipt does not match the value-minimized formal contract"
            )
        }

        vaultID = expectedVaultID
        self.outcome = outcome
        self.threadID = threadID
        self.sessionID = sessionID
        self.sessionVersion = sessionVersion
        self.reviewBatchID = reviewBatchID
        self.trigger = trigger
        self.reviewBatchVersion = reviewBatchVersion
        self.capturedCandidateBatchTurnCount = capturedCandidateBatchTurnCount
    }

    func matches(_ command: OwnerTruthInterviewReviewBatchAcknowledgementCommand) -> Bool {
        threadID == command.threadID
            && sessionID == command.sessionID
            && reviewBatchID == command.reviewBatchID
            && sessionVersion > command.expectedSessionVersion
            && reviewBatchVersion > command.expectedReviewBatchVersion
    }
}

protocol OwnerTruthInterviewPendingReviewBatchInboxClient: AnyObject {
    func fetchOwnerTruthInterviewPendingReviewBatchInbox(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthInterviewPendingReviewBatchInbox, Error>) -> Void
    )
}

protocol OwnerTruthInterviewReviewBatchAcknowledgementClient: AnyObject {
    func acknowledgeOwnerTruthInterviewReviewBatch(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewReviewBatchAcknowledgementCommand,
        completion: @escaping (Result<OwnerTruthInterviewReviewBatchAcknowledgementReceipt, Error>) -> Void
    )
}

enum OwnerTruthInterviewReviewBatchAcknowledgementIntent: Equatable, Sendable {
    case acknowledge
}

enum OwnerTruthInterviewReviewBatchAcknowledgementPhase: Equatable, Sendable {
    case idle
    case discovering
    case acknowledging
    case acknowledged
    case unavailable
    case failed
}

enum OwnerTruthInterviewReviewBatchAcknowledgementNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case matchingBatchUnavailable
    case contractMismatch
    case requestFailed
}

struct OwnerTruthInterviewReviewBatchAcknowledgementViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewReviewBatchAcknowledgementPhase
    let receipt: OwnerTruthInterviewReviewBatchAcknowledgementReceipt?
    let notice: OwnerTruthInterviewReviewBatchAcknowledgementNotice?

    static let idle = OwnerTruthInterviewReviewBatchAcknowledgementViewState(
        phase: .idle,
        receipt: nil,
        notice: nil
    )
}

/// A lease-fenced two-step acknowledgement. Discovery is restricted to the
/// current natural-input thread/session; it never selects an arbitrary pending
/// batch and it cannot trigger Candidate, Source, Memory, or Provider work.
final class OwnerTruthInterviewReviewBatchAcknowledgementUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let threadID: OwnerTruthRecordID
    private let sessionID: OwnerTruthRecordID
    private let inboxClient: OwnerTruthInterviewPendingReviewBatchInboxClient
    private let acknowledgementClient: OwnerTruthInterviewReviewBatchAcknowledgementClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let identifierFactory: () -> UUID
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewReviewBatchAcknowledgementViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewReviewBatchAcknowledgementViewState) -> Void)?

    init(
        accountLease: AccountLease,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        inboxClient: OwnerTruthInterviewPendingReviewBatchInboxClient,
        acknowledgementClient: OwnerTruthInterviewReviewBatchAcknowledgementClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false },
        identifierFactory: @escaping () -> UUID = UUID.init
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.threadID = threadID
        self.sessionID = sessionID
        self.inboxClient = inboxClient
        self.acknowledgementClient = acknowledgementClient
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.identifierFactory = identifierFactory
    }

    func send(_ intent: OwnerTruthInterviewReviewBatchAcknowledgementIntent) {
        switch intent {
        case .acknowledge:
            acknowledge()
        }
    }

    private func acknowledge() {
        guard viewState.phase != .discovering,
              viewState.phase != .acknowledging,
              viewState.phase != .acknowledged,
              let vaultID = beginRequestOrFail() else {
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewReviewBatchAcknowledgementViewState(
            phase: .discovering,
            receipt: nil,
            notice: nil
        )
        inboxClient.fetchOwnerTruthInterviewPendingReviewBatchInbox(vaultID: vaultID) { [weak self] result in
            self?.receiveInbox(result, vaultID: vaultID, generation: generation)
        }
    }

    private func receiveInbox(
        _ result: Result<OwnerTruthInterviewPendingReviewBatchInbox, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .failure:
            transitionFailure(.requestFailed)
        case .success(let inbox):
            guard inbox.vaultID == vaultID,
                  inbox.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.contractMismatch)
                return
            }
            let boundInbox = inbox.bound(to: accountLease)
            guard boundInbox.isBound(to: accountLease) else {
                transitionFailure(.contractMismatch)
                return
            }
            let matches = boundInbox.reviewBatches.filter {
                $0.threadID == threadID && $0.sessionID == sessionID
            }
            guard matches.count == 1, let batch = matches.first else {
                transitionFailure(.matchingBatchUnavailable)
                return
            }
            do {
                let command = try OwnerTruthInterviewReviewBatchAcknowledgementCommand(
                    commandID: identifierFactory().uuidString.lowercased(),
                    reviewBatchID: batch.reviewBatchID,
                    threadID: batch.threadID,
                    sessionID: batch.sessionID,
                    expectedSessionVersion: batch.sessionVersion,
                    expectedReviewBatchVersion: batch.reviewBatchVersion
                )
                operationGeneration &+= 1
                let acknowledgementGeneration = operationGeneration
                viewState = OwnerTruthInterviewReviewBatchAcknowledgementViewState(
                    phase: .acknowledging,
                    receipt: nil,
                    notice: nil
                )
                acknowledgementClient.acknowledgeOwnerTruthInterviewReviewBatch(
                    vaultID: vaultID,
                    command: command
                ) { [weak self] acknowledgementResult in
                    self?.receiveAcknowledgement(
                        acknowledgementResult,
                        vaultID: vaultID,
                        command: command,
                        generation: acknowledgementGeneration
                    )
                }
            } catch {
                transitionFailure(.contractMismatch)
            }
        }
    }

    private func receiveAcknowledgement(
        _ result: Result<OwnerTruthInterviewReviewBatchAcknowledgementReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewReviewBatchAcknowledgementCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .failure:
            transitionFailure(.requestFailed)
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewReviewBatchAcknowledgementViewState(
                phase: .acknowledged,
                receipt: receipt,
                notice: nil
            )
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            transitionUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func canCommit(generation: UInt) -> Bool {
        guard generation == operationGeneration else { return false }
        guard releasePolicyAvailable() else {
            transitionUnavailable(.releasePolicyDisabled)
            return false
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            transitionUnavailable(.staleAccountLease)
            return false
        }
        return true
    }

    private func transitionUnavailable(_ notice: OwnerTruthInterviewReviewBatchAcknowledgementNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewReviewBatchAcknowledgementViewState(
            phase: .unavailable,
            receipt: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthInterviewReviewBatchAcknowledgementNotice) {
        viewState = OwnerTruthInterviewReviewBatchAcknowledgementViewState(
            phase: .failed,
            receipt: nil,
            notice: notice
        )
    }
}

// MARK: - Formal candidate proposal admission

/// The second explicit Owner action after a review batch is acknowledged.
/// It only names the frozen batch/version fence and cannot inject narrative,
/// Source metadata, Candidates, MemoryVersions, or provider instructions.
struct OwnerTruthInterviewCandidateProposalAdmissionCommand: Equatable, Sendable {
    let commandID: String
    let reviewBatchID: OwnerTruthRecordID
    let expectedReviewBatchVersion: Int

    init(
        commandID: String,
        reviewBatchID: OwnerTruthRecordID,
        expectedReviewBatchVersion: Int
    ) throws {
        guard let commandID = OwnerTruthInterviewReviewBatchContract.nonEmptyString(commandID),
              expectedReviewBatchVersion > 0 else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateProposalAdmission(
                "admission command requires a non-empty id and a positive review-batch version"
            )
        }
        self.commandID = commandID
        self.reviewBatchID = reviewBatchID
        self.expectedReviewBatchVersion = expectedReviewBatchVersion
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "expectedReviewBatchVersion": expectedReviewBatchVersion,
        ]
    }
}

/// Value-minimized evidence that one acknowledged review batch entered the
/// private Source/effect staging lane. It is not an extraction, Candidate, or
/// Memory completion result.
struct OwnerTruthInterviewCandidateProposalAdmissionReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-candidate-proposal-admission-response-v1"

    let vaultID: OwnerTruthVaultID
    let outcome: OwnerTruthCommandOutcome
    let reviewBatchID: OwnerTruthRecordID
    let sourceVersion: Int
    let ownerMessageCount: Int

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedReviewBatchID: OwnerTruthRecordID
    ) throws {
        let allowedKeys: Set<String> = [
            "schemaVersion",
            "vaultId",
            "status",
            "reviewBatch",
            "source",
            "candidateExtraction",
            "candidate",
            "memoryActivation",
        ]
        guard Set(object.keys) == allowedKeys,
              OwnerTruthInterviewReviewBatchContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewReviewBatchContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let outcomeRaw = OwnerTruthInterviewReviewBatchContract.requiredString(object["status"]),
              let outcome = OwnerTruthCommandOutcome(rawValue: outcomeRaw),
              let reviewBatch = object["reviewBatch"] as? [String: Any],
              Set(reviewBatch.keys) == Set(["reviewBatchId"]),
              let reviewBatchID = OwnerTruthInterviewReviewBatchContract.recordID(
                reviewBatch["reviewBatchId"]
              ),
              reviewBatchID == expectedReviewBatchID,
              let source = object["source"] as? [String: Any],
              Set(source.keys) == Set(["status", "kind", "version"]),
              OwnerTruthInterviewReviewBatchContract.requiredString(source["status"]) == "admitted",
              OwnerTruthInterviewReviewBatchContract.requiredString(source["kind"]) == "conversation",
              let sourceVersion = OwnerTruthInterviewReviewBatchContract.positiveInt(source["version"]),
              let candidateExtraction = object["candidateExtraction"] as? [String: Any],
              Set(candidateExtraction.keys) == Set(["status", "ownerMessageCount"]),
              OwnerTruthInterviewReviewBatchContract.requiredString(candidateExtraction["status"])
                == "requested",
              let ownerMessageCount = OwnerTruthInterviewReviewBatchContract.positiveInt(
                candidateExtraction["ownerMessageCount"]
              ),
              let candidate = object["candidate"] as? [String: Any],
              Set(candidate.keys) == Set(["status"]),
              OwnerTruthInterviewReviewBatchContract.requiredString(candidate["status"])
                == "notCreated",
              let memoryActivation = object["memoryActivation"] as? [String: Any],
              Set(memoryActivation.keys) == Set(["status"]),
              OwnerTruthInterviewReviewBatchContract.requiredString(memoryActivation["status"])
                == "notApplicable" else {
            throw OwnerTruthRemoteContractError.invalidInterviewCandidateProposalAdmission(
                "admission receipt does not match the value-minimized formal contract"
            )
        }

        vaultID = expectedVaultID
        self.outcome = outcome
        self.reviewBatchID = reviewBatchID
        self.sourceVersion = sourceVersion
        self.ownerMessageCount = ownerMessageCount
    }

    func matches(_ command: OwnerTruthInterviewCandidateProposalAdmissionCommand) -> Bool {
        reviewBatchID == command.reviewBatchID
    }
}

protocol OwnerTruthInterviewCandidateProposalAdmissionClient: AnyObject {
    func admitOwnerTruthInterviewCandidateProposal(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateProposalAdmissionCommand,
        completion: @escaping (Result<OwnerTruthInterviewCandidateProposalAdmissionReceipt, Error>) -> Void
    )
}

enum OwnerTruthInterviewCandidateProposalAdmissionIntent: Equatable, Sendable {
    case admit
}

enum OwnerTruthInterviewCandidateProposalAdmissionPhase: Equatable, Sendable {
    case idle
    case admitting
    case admitted
    case unavailable
    case failed
}

enum OwnerTruthInterviewCandidateProposalAdmissionNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
}

struct OwnerTruthInterviewCandidateProposalAdmissionViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewCandidateProposalAdmissionPhase
    let receipt: OwnerTruthInterviewCandidateProposalAdmissionReceipt?
    let notice: OwnerTruthInterviewCandidateProposalAdmissionNotice?

    static let idle = OwnerTruthInterviewCandidateProposalAdmissionViewState(
        phase: .idle,
        receipt: nil,
        notice: nil
    )
}

/// Lease-fenced formal staging. It can run only after the distinct review
/// acknowledgement receipt and under the separately captured
/// `ownerTruthCandidateReview` release policy.
final class OwnerTruthInterviewCandidateProposalAdmissionUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let acknowledgementReceipt: OwnerTruthInterviewReviewBatchAcknowledgementReceipt
    private let client: OwnerTruthInterviewCandidateProposalAdmissionClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private let identifierFactory: () -> UUID
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewCandidateProposalAdmissionViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewCandidateProposalAdmissionViewState) -> Void)?

    init(
        accountLease: AccountLease,
        acknowledgementReceipt: OwnerTruthInterviewReviewBatchAcknowledgementReceipt,
        client: OwnerTruthInterviewCandidateProposalAdmissionClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool = { false },
        identifierFactory: @escaping () -> UUID = UUID.init
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.acknowledgementReceipt = acknowledgementReceipt
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
        self.identifierFactory = identifierFactory
    }

    func send(_ intent: OwnerTruthInterviewCandidateProposalAdmissionIntent) {
        switch intent {
        case .admit:
            admit()
        }
    }

    private func admit() {
        guard viewState.phase != .admitting,
              viewState.phase != .admitted,
              let vaultID = beginRequestOrFail(),
              acknowledgementReceipt.vaultID == vaultID else {
            return
        }
        do {
            let command = try OwnerTruthInterviewCandidateProposalAdmissionCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                reviewBatchID: acknowledgementReceipt.reviewBatchID,
                expectedReviewBatchVersion: acknowledgementReceipt.reviewBatchVersion
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewCandidateProposalAdmissionViewState(
                phase: .admitting,
                receipt: nil,
                notice: nil
            )
            client.admitOwnerTruthInterviewCandidateProposal(
                vaultID: vaultID,
                command: command
            ) { [weak self] result in
                self?.receive(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            transitionFailure(.contractMismatch)
        }
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewCandidateProposalAdmissionReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewCandidateProposalAdmissionCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .failure:
            transitionFailure(.requestFailed)
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewCandidateProposalAdmissionViewState(
                phase: .admitted,
                receipt: receipt,
                notice: nil
            )
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            transitionUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func canCommit(generation: UInt) -> Bool {
        guard generation == operationGeneration else { return false }
        guard releasePolicyAvailable() else {
            transitionUnavailable(.releasePolicyDisabled)
            return false
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            transitionUnavailable(.staleAccountLease)
            return false
        }
        return true
    }

    private func transitionUnavailable(_ notice: OwnerTruthInterviewCandidateProposalAdmissionNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewCandidateProposalAdmissionViewState(
            phase: .unavailable,
            receipt: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthInterviewCandidateProposalAdmissionNotice) {
        viewState = OwnerTruthInterviewCandidateProposalAdmissionViewState(
            phase: .failed,
            receipt: nil,
            notice: notice
        )
    }
}

private enum OwnerTruthInterviewReviewBatchContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        return nonEmptyString(value)
    }

    static func nonEmptyString(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let value = requiredString(value), let uuid = UUID(uuidString: value) else {
            return nil
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func positiveInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value > 0 { return value }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue,
           value.intValue > 0 {
            return value.intValue
        }
        return nil
    }
}

// MARK: - QA-only Owner Truth knowledge recommendation plan

/// The two product-facing recommendation positions remain stable even while
/// the planner evolves. The plan is QA-only today and deliberately contains
/// no generated question or private memory content.
enum OwnerTruthKnowledgeRecommendationSlot: String, Codable, Equatable, Sendable {
    case continuity
    case breadth
}

/// The six V4 knowledge dimensions. They are policy-owned, so an unexpected
/// backend dimension fails closed instead of quietly becoming a new client
/// behavior.
enum OwnerTruthKnowledgeRecommendationDimension: String, CaseIterable, Codable, Equatable, Sendable {
    case lifeStage
    case importantPeople
    case keyDecisions
    case professionalExperience
    case values
    case aspirationsAndBoundaries

    /// This order is owned by the V4 policy and is used to canonicalize an
    /// explicit Owner selection before it crosses the QA-only transport.
    var facetOrder: [String] {
        switch self {
        case .lifeStage:
            return ["timeContext", "experience"]
        case .importantPeople:
            return ["person", "relationshipChange"]
        case .keyDecisions:
            return ["choice", "reason", "outcome"]
        case .professionalExperience:
            return ["practice", "judgment"]
        case .values:
            return ["priority", "reflection"]
        case .aspirationsAndBoundaries:
            return ["aspiration", "boundary"]
        }
    }

    func supportsFacet(_ value: String) -> Bool {
        facetOrder.contains(value)
    }
}

enum OwnerTruthKnowledgeRecommendationPlanState: String, Codable, Equatable, Sendable {
    case ready
    case rebuilding
    case unavailable
}

/// Count-only coverage displayed in QA diagnostics. Memory-version IDs,
/// source IDs and checkpoints are deliberately not retained on iOS.
struct OwnerTruthKnowledgeRecommendationCoverage: Equatable, Sendable {
    let dimension: OwnerTruthKnowledgeRecommendationDimension
    let evidenceCount: Int
    let coveredFacetCount: Int
    let missingFacetCount: Int
}

/// A usable recommendation without its server-side candidate identity or
/// question template. The public Echo surface will map these identifiers to
/// approved copy only in a later reviewed slice.
struct OwnerTruthKnowledgeRecommendation: Equatable, Sendable {
    let slot: OwnerTruthKnowledgeRecommendationSlot
    let targetDimension: OwnerTruthKnowledgeRecommendationDimension
    let missingFacet: String
    let reasonCode: String
    let evidenceReferenceCount: Int
}

/// Typed, value-minimized read model for the server-planned M0-B route. This
/// is intentionally not connected to a public Echo entry point.
struct OwnerTruthKnowledgeRecommendationPlan: Equatable, Sendable {
    static let schemaVersion = "owner-truth-knowledge-recommendation-plan-response-v1"
    static let recommendationSchemaVersion = "owner-truth-knowledge-recommendation-read-v1"
    static let plannerSchemaVersion = "owner-truth-knowledge-recommendation-plan-v1"
    static let dimensionReadSchemaVersion = "owner-truth-knowledge-dimension-read-v2"
    static let dimensionProjectionSchemaVersion = "owner-truth-dimension-projection-v1"
    static let selectionSchemaVersion = "owner-truth-recommendation-selection-v1"

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthKnowledgeRecommendationPlanState
    let coverage: [OwnerTruthKnowledgeRecommendationCoverage]
    let selected: [OwnerTruthKnowledgeRecommendation]
    let filteredCount: Int
    let policyVersion: String

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let recommendations = object["recommendations"] as? [String: Any],
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(recommendations["schemaVersion"])
                == Self.recommendationSchemaVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(recommendations["candidateSource"])
                == "serverPlanned",
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(recommendations["plannerSchemaVersion"])
                == Self.plannerSchemaVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(recommendations["dimensionReadSchemaVersion"])
                == Self.dimensionReadSchemaVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(recommendations["selectionSchemaVersion"])
                == Self.selectionSchemaVersion,
              let stateRaw = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(
                recommendations["selectionState"]
              ),
              let state = OwnerTruthKnowledgeRecommendationPlanState(rawValue: stateRaw),
              let policyVersion = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(
                recommendations["policyVersion"]
              ),
              let dimensionRead = recommendations["dimensionRead"] as? [String: Any],
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(dimensionRead["schemaVersion"])
                == Self.dimensionReadSchemaVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(dimensionRead["state"])
                == state.rawValue,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(dimensionRead["vaultId"])
                == expectedVaultID.rawValue,
              OwnerTruthKnowledgeRecommendationPlanContract.nonNegativeInt(dimensionRead["authorityEpoch"]) != nil else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "plan response misses a required value-minimized field"
            )
        }

        let coverage = try Self.parseCoverage(
            dimensionRead: dimensionRead,
            state: state,
            policyVersion: policyVersion
        )
        let selected = try Self.parseSelected(
            recommendations["selected"],
            state: state,
            policyVersion: policyVersion
        )
        let filteredCount = try Self.parseFilteredCount(recommendations["filtered"])

        vaultID = expectedVaultID
        self.state = state
        self.coverage = coverage
        self.selected = selected
        self.filteredCount = filteredCount
        self.policyVersion = policyVersion
    }

    private static func parseCoverage(
        dimensionRead: [String: Any],
        state: OwnerTruthKnowledgeRecommendationPlanState,
        policyVersion: String
    ) throws -> [OwnerTruthKnowledgeRecommendationCoverage] {
        guard state == .ready else {
            guard dimensionRead["coverage"] == nil || dimensionRead["coverage"] is NSNull else {
                throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                    "non-ready plan must not retain coverage"
                )
            }
            return []
        }
        guard let coverageObject = dimensionRead["coverage"] as? [String: Any],
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(coverageObject["schemaVersion"])
                == Self.dimensionProjectionSchemaVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.requiredString(coverageObject["policyVersion"])
                == policyVersion,
              OwnerTruthKnowledgeRecommendationPlanContract.nonNegativeInt(
                coverageObject["excludedEvidenceCount"]
              ) != nil else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "ready plan coverage misses a required count-only field"
            )
        }
        let dimensionObjects = try OwnerTruthKnowledgeRecommendationPlanContract.objectArray(
            coverageObject["dimensions"],
            field: "coverage.dimensions"
        )
        guard dimensionObjects.count == OwnerTruthKnowledgeRecommendationDimension.allCases.count else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "coverage must contain every stable knowledge dimension"
            )
        }

        let values = try dimensionObjects.map { object -> OwnerTruthKnowledgeRecommendationCoverage in
            guard let rawDimension = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(
                object["dimension"]
            ),
            let dimension = OwnerTruthKnowledgeRecommendationDimension(rawValue: rawDimension),
            let evidenceCount = OwnerTruthKnowledgeRecommendationPlanContract.nonNegativeInt(
                object["evidenceCount"]
            ),
            let coveredFacetCount = OwnerTruthKnowledgeRecommendationPlanContract.nonNegativeInt(
                object["coveredFacetCount"]
            ),
            let missingFacetCount = OwnerTruthKnowledgeRecommendationPlanContract.nonNegativeInt(
                object["missingFacetCount"]
            ) else {
                throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                    "coverage dimension has an unsupported value"
                )
            }
            return OwnerTruthKnowledgeRecommendationCoverage(
                dimension: dimension,
                evidenceCount: evidenceCount,
                coveredFacetCount: coveredFacetCount,
                missingFacetCount: missingFacetCount
            )
        }
        guard Set(values.map(\.dimension)).count == OwnerTruthKnowledgeRecommendationDimension.allCases.count else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "coverage must not duplicate a knowledge dimension"
            )
        }
        return values
    }

    private static func parseSelected(
        _ value: Any?,
        state: OwnerTruthKnowledgeRecommendationPlanState,
        policyVersion: String
    ) throws -> [OwnerTruthKnowledgeRecommendation] {
        let selectedObjects = try OwnerTruthKnowledgeRecommendationPlanContract.objectArray(
            value,
            field: "selected"
        )
        guard selectedObjects.count <= 2 else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "plan must not select more than two recommendations"
            )
        }
        guard state == .ready || selectedObjects.isEmpty else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "non-ready plan must not select recommendations"
            )
        }

        let values = try selectedObjects.map { object -> OwnerTruthKnowledgeRecommendation in
            // Candidate and template identifiers are verified as opaque server
            // references, then discarded. They must never become UI state.
            guard OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["candidateId"]) != nil,
                  OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["questionTemplateId"]) != nil,
                  let rawSlot = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["slot"]),
                  let slot = OwnerTruthKnowledgeRecommendationSlot(rawValue: rawSlot),
                  let rawDimension = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(
                    object["targetDimension"]
                  ),
                  let targetDimension = OwnerTruthKnowledgeRecommendationDimension(rawValue: rawDimension),
                  let missingFacet = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(
                    object["missingFacet"]
                  ),
                  let reasonCode = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(
                    object["reasonCode"]
                  ),
                  OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["policyVersion"])
                    == policyVersion,
                  let evidenceReferenceCount = OwnerTruthKnowledgeRecommendationPlanContract.nonNegativeInt(
                    object["evidenceRefCount"]
                  ),
                  targetDimension.supportsFacet(missingFacet) else {
                throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                    "selected recommendation has an unsupported value"
                )
            }
            return OwnerTruthKnowledgeRecommendation(
                slot: slot,
                targetDimension: targetDimension,
                missingFacet: missingFacet,
                reasonCode: reasonCode,
                evidenceReferenceCount: evidenceReferenceCount
            )
        }
        guard Set(values.map(\.slot)).count == values.count,
              Set(values.map { "\($0.targetDimension.rawValue):\($0.missingFacet)" }).count == values.count else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "selected recommendations must not duplicate a slot or knowledge gap"
            )
        }
        return values
    }

    private static func parseFilteredCount(_ value: Any?) throws -> Int {
        let filteredObjects = try OwnerTruthKnowledgeRecommendationPlanContract.objectArray(
            value,
            field: "filtered"
        )
        for object in filteredObjects {
            guard OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["candidateId"]) != nil,
                  OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["reasonCode"]) != nil,
                  let rawSlot = OwnerTruthKnowledgeRecommendationPlanContract.requiredString(object["slot"]),
                  OwnerTruthKnowledgeRecommendationSlot(rawValue: rawSlot) != nil else {
                throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                    "filtered recommendation has an unsupported value"
                )
            }
        }
        return filteredObjects.count
    }

}

protocol OwnerTruthKnowledgeRecommendationPlanClient: AnyObject {
    func fetchOwnerTruthKnowledgeRecommendationPlan(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthKnowledgeRecommendationPlan, Error>) -> Void
    )
}

private enum OwnerTruthKnowledgeRecommendationPlanContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value >= 0 { return value }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue,
           value.intValue >= 0 {
            return value.intValue
        }
        return nil
    }

    static func objectArray(_ value: Any?, field: String) throws -> [[String: Any]] {
        guard let values = value as? [Any] else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                "\(field) must be an array"
            )
        }
        return try values.map { value in
            guard let object = value as? [String: Any] else {
                throw OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan(
                    "\(field) must contain objects"
                )
            }
            return object
        }
    }
}

enum OwnerTruthKnowledgeRecommendationPlanUseCasePhase: String, Equatable, Sendable {
    case idle
    case loading
    case ready
    case rebuilding
    case unavailable
    case failed
}

enum OwnerTruthKnowledgeRecommendationPlanUseCaseNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
}

/// Value-minimized presentation state for the hidden M0-B plan reader. It is
/// deliberately separate from the transport model so no Vault identifier,
/// candidate identifier, question template, checkpoint or evidence reference
/// can survive into a future UI surface.
struct OwnerTruthKnowledgeRecommendationPlanViewState: Equatable, Sendable {
    let phase: OwnerTruthKnowledgeRecommendationPlanUseCasePhase
    let coverage: [OwnerTruthKnowledgeRecommendationCoverage]
    let recommendations: [OwnerTruthKnowledgeRecommendation]
    let filteredCount: Int
    let policyVersion: String?
    let notice: OwnerTruthKnowledgeRecommendationPlanUseCaseNotice?

    static let idle = OwnerTruthKnowledgeRecommendationPlanViewState(
        phase: .idle,
        coverage: [],
        recommendations: [],
        filteredCount: 0,
        policyVersion: nil,
        notice: nil
    )
}

/// QA-only lease-fenced reader for the server-planned M0-B recommendation
/// response. It only publishes count-level coverage and reviewed display-safe
/// recommendation metadata after both request and commit lease checks pass.
final class OwnerTruthKnowledgeRecommendationPlanUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthKnowledgeRecommendationPlanClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthKnowledgeRecommendationPlanViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthKnowledgeRecommendationPlanViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthKnowledgeRecommendationPlanClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthKnowledgeRecommendationPlanViewState(
            phase: .loading,
            coverage: [],
            recommendations: [],
            filteredCount: 0,
            policyVersion: nil,
            notice: nil
        )
        client.fetchOwnerTruthKnowledgeRecommendationPlan(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthKnowledgeRecommendationPlan, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let plan):
            guard plan.vaultID == vaultID,
                  plan.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.contractMismatch)
                return
            }
            let phase: OwnerTruthKnowledgeRecommendationPlanUseCasePhase
            switch plan.state {
            case .ready:
                phase = .ready
            case .rebuilding:
                phase = .rebuilding
            case .unavailable:
                phase = .unavailable
            }
            viewState = OwnerTruthKnowledgeRecommendationPlanViewState(
                phase: phase,
                coverage: plan.coverage,
                recommendations: plan.selected,
                filteredCount: plan.filteredCount,
                policyVersion: plan.policyVersion,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidKnowledgeRecommendationPlan = error {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthKnowledgeRecommendationPlanUseCaseNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthKnowledgeRecommendationPlanViewState(
            phase: .unavailable,
            coverage: [],
            recommendations: [],
            filteredCount: 0,
            policyVersion: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthKnowledgeRecommendationPlanUseCaseNotice) {
        viewState = OwnerTruthKnowledgeRecommendationPlanViewState(
            phase: .failed,
            coverage: [],
            recommendations: [],
            filteredCount: 0,
            policyVersion: nil,
            notice: notice
        )
    }
}

// MARK: - Default-off Owner Truth guided recommendation presentation

/// One display-safe prompt rendered by the formal M0-B route. Candidate,
/// evidence, reason and knowledge-dimension metadata must not cross into this
/// user-facing model.
struct OwnerTruthGuidedRecommendationPrompt: Equatable, Sendable {
    let slot: OwnerTruthKnowledgeRecommendationSlot
    let label: String
    let question: String
}

/// Strict response model for the formal product surface. It accepts only the
/// policy-owned presentation fields and rejects planner metadata rather than
/// accidentally retaining it for UI use.
struct OwnerTruthGuidedRecommendationPresentation: Equatable, Sendable {
    static let schemaVersion = "owner-truth-guided-recommendation-presentation-response-v2"

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthKnowledgeRecommendationPlanState
    /// Opaque selection binding used only when sending a feedback command.
    let recommendationSetID: String?
    let prompts: [OwnerTruthGuidedRecommendationPrompt]

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == [
            "schemaVersion",
            "vaultId",
            "state",
            "recommendationSetId",
            "recommendations",
        ],
              OwnerTruthGuidedRecommendationPresentationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthGuidedRecommendationPresentationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let stateRaw = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                object["state"]
              ),
              let state = OwnerTruthKnowledgeRecommendationPlanState(rawValue: stateRaw) else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "response misses a required presentation field"
            )
        }

        let recommendationSetID: String?
        if object["recommendationSetId"] is NSNull {
            recommendationSetID = nil
        } else if let value = OwnerTruthGuidedRecommendationPresentationContract.sha256(
            object["recommendationSetId"]
        ) {
            recommendationSetID = value
        } else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "response has an invalid recommendation set binding"
            )
        }

        let promptObjects = try OwnerTruthGuidedRecommendationPresentationContract.objectArray(
            object["recommendations"],
            field: "recommendations"
        )
        guard promptObjects.count <= 2 else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "response must not contain more than two prompts"
            )
        }
        guard state == .ready || promptObjects.isEmpty else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "non-ready response must not retain prompts"
            )
        }
        guard state != .ready || recommendationSetID != nil else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "ready response must bind its recommendation set"
            )
        }
        guard state == .ready || recommendationSetID == nil else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "non-ready response must not retain a recommendation set binding"
            )
        }

        let prompts = try promptObjects.map { object -> OwnerTruthGuidedRecommendationPrompt in
            guard Set(object.keys) == ["slot", "label", "question"],
                  let rawSlot = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                    object["slot"]
                  ),
                  let slot = OwnerTruthKnowledgeRecommendationSlot(rawValue: rawSlot),
                  let label = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                    object["label"]
                  ),
                  let question = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                    object["question"]
                  ),
                  question.count <= 280 else {
                throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                    "prompt contains an unsupported value"
                )
            }
            return OwnerTruthGuidedRecommendationPrompt(
                slot: slot,
                label: label,
                question: question
            )
        }
        guard Set(prompts.map(\.slot)).count == prompts.count else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "response must not duplicate a prompt slot"
            )
        }

        vaultID = expectedVaultID
        self.state = state
        self.recommendationSetID = recommendationSetID
        self.prompts = prompts
    }
}

protocol OwnerTruthGuidedRecommendationPresentationClient: AnyObject {
    func fetchOwnerTruthGuidedRecommendationPresentation(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthGuidedRecommendationPresentation, Error>) -> Void
    )

    func submitOwnerTruthGuidedRecommendationFeedback(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthGuidedRecommendationFeedbackCommand,
        completion: @escaping (Result<OwnerTruthGuidedRecommendationFeedbackReceipt, Error>) -> Void
    )

    func activateOwnerTruthGuidedRecommendation(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthGuidedRecommendationActivationCommand,
        completion: @escaping (Result<OwnerTruthGuidedRecommendationActivationReceipt, Error>) -> Void
    )
}

private enum OwnerTruthGuidedRecommendationPresentationContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func sha256(_ value: Any?) -> String? {
        guard let value = requiredString(value), value.count == 64 else { return nil }
        return value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
        } ? value : nil
    }

    static func objectArray(_ value: Any?, field: String) throws -> [[String: Any]] {
        guard let values = value as? [Any] else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                "\(field) must be an array"
            )
        }
        return try values.map { value in
            guard let object = value as? [String: Any] else {
                throw OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation(
                    "\(field) must contain objects"
                )
            }
            return object
        }
    }
}

enum OwnerTruthGuidedRecommendationFeedbackAction: String, Equatable, Sendable {
    case replace
    case notInterested
    case `defer`
}

enum OwnerTruthGuidedRecommendationFeedbackReason: String, Equatable, Sendable {
    case questionWording
    case topicPreference
    case recommendationType
    case timing
}

struct OwnerTruthGuidedRecommendationFeedbackCommand: Equatable, Sendable {
    let commandID: String
    let recommendationSetID: String
    let slot: OwnerTruthKnowledgeRecommendationSlot
    let action: OwnerTruthGuidedRecommendationFeedbackAction
    let reason: OwnerTruthGuidedRecommendationFeedbackReason

    init(
        commandID: String = UUID().uuidString.lowercased(),
        recommendationSetID: String,
        slot: OwnerTruthKnowledgeRecommendationSlot,
        action: OwnerTruthGuidedRecommendationFeedbackAction,
        reason: OwnerTruthGuidedRecommendationFeedbackReason
    ) {
        self.commandID = commandID
        self.recommendationSetID = recommendationSetID
        self.slot = slot
        self.action = action
        self.reason = reason
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "recommendationSetId": recommendationSetID,
            "slot": slot.rawValue,
            "feedbackAction": action.rawValue,
            "feedbackReason": reason.rawValue,
        ]
    }
}

enum OwnerTruthGuidedRecommendationFeedbackStatus: String, Equatable, Sendable {
    case created
    case deduplicated
}

struct OwnerTruthGuidedRecommendationFeedbackReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-guided-recommendation-feedback-response-v1"

    let vaultID: OwnerTruthVaultID
    let status: OwnerTruthGuidedRecommendationFeedbackStatus

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == ["schemaVersion", "vaultId", "feedback"],
              OwnerTruthGuidedRecommendationPresentationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthGuidedRecommendationPresentationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let feedback = object["feedback"] as? [String: Any],
              Set(feedback.keys) == ["status"],
              let rawStatus = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                feedback["status"]
              ),
              let status = OwnerTruthGuidedRecommendationFeedbackStatus(rawValue: rawStatus) else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationFeedback(
                "response misses a required value-free feedback field"
            )
        }
        vaultID = expectedVaultID
        self.status = status
    }
}

/// A formal prompt activation never carries the assistant question, candidate,
/// evidence, thread, session, or user narrative across the client boundary.
struct OwnerTruthGuidedRecommendationActivationCommand: Equatable, Sendable {
    let commandID: String
    let recommendationSetID: String
    let slot: OwnerTruthKnowledgeRecommendationSlot

    init(
        commandID: String = UUID().uuidString.lowercased(),
        recommendationSetID: String,
        slot: OwnerTruthKnowledgeRecommendationSlot
    ) {
        self.commandID = commandID
        self.recommendationSetID = recommendationSetID
        self.slot = slot
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "recommendationSetId": recommendationSetID,
            "slot": slot.rawValue,
        ]
    }
}

enum OwnerTruthGuidedRecommendationActivationStatus: String, Equatable, Sendable {
    case created
    case deduplicated
}

enum OwnerTruthGuidedRecommendationActivationInputState: String, Equatable, Sendable {
    case awaitingOwnerNarrative
}

struct OwnerTruthGuidedRecommendationActivationReceipt: Equatable, Sendable {
    static let schemaVersion = "owner-truth-guided-recommendation-activation-response-v1"

    let vaultID: OwnerTruthVaultID
    let status: OwnerTruthGuidedRecommendationActivationStatus
    let slot: OwnerTruthKnowledgeRecommendationSlot
    let nextAction: OwnerTruthInterviewOrchestrationAction
    let inputState: OwnerTruthGuidedRecommendationActivationInputState

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == ["schemaVersion", "vaultId", "activation"],
              OwnerTruthGuidedRecommendationPresentationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthGuidedRecommendationPresentationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let activation = object["activation"] as? [String: Any],
              Set(activation.keys) == ["status", "slot", "nextAction", "inputState"],
              let rawStatus = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                activation["status"]
              ),
              let status = OwnerTruthGuidedRecommendationActivationStatus(rawValue: rawStatus),
              let rawSlot = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                activation["slot"]
              ),
              let slot = OwnerTruthKnowledgeRecommendationSlot(rawValue: rawSlot),
              let rawAction = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                activation["nextAction"]
              ),
              let nextAction = OwnerTruthInterviewOrchestrationAction(rawValue: rawAction),
              let rawInputState = OwnerTruthGuidedRecommendationPresentationContract.requiredString(
                activation["inputState"]
              ),
              let inputState = OwnerTruthGuidedRecommendationActivationInputState(
                rawValue: rawInputState
              ),
              (slot == .continuity && nextAction == .listen)
                || (slot == .breadth && nextAction == .broaden) else {
            throw OwnerTruthRemoteContractError.invalidGuidedRecommendationActivation(
                "response misses a valid value-free activation state"
            )
        }

        vaultID = expectedVaultID
        self.status = status
        self.slot = slot
        self.nextAction = nextAction
        self.inputState = inputState
    }
}

enum OwnerTruthGuidedRecommendationPresentationPhase: Equatable, Sendable {
    case idle
    case loading
    case activating
    case ready
    case rebuilding
    case unavailable
    case failed
}

enum OwnerTruthGuidedRecommendationPresentationNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
    case feedbackRequestFailed
    case activationRequestFailed
}

/// UI state keeps only approved display copy. The Vault identifier stays in
/// the request boundary and is never retained by the natural-input surface.
struct OwnerTruthGuidedRecommendationPresentationViewState: Equatable, Sendable {
    let phase: OwnerTruthGuidedRecommendationPresentationPhase
    let prompts: [OwnerTruthGuidedRecommendationPrompt]
    let recommendationSetID: String?
    /// Display-only assistant question currently awaiting a user-authored response.
    let activePrompt: OwnerTruthGuidedRecommendationPrompt?
    let notice: OwnerTruthGuidedRecommendationPresentationNotice?

    static let idle = OwnerTruthGuidedRecommendationPresentationViewState(
        phase: .idle,
        prompts: [],
        recommendationSetID: nil,
        activePrompt: nil,
        notice: nil
    )
}

/// Lease-fenced presentation reader for the existing server planner. A denied
/// feature performs no network request and hidden/non-ready states publish no
/// prompts, keeping the natural input surface stable by default.
final class OwnerTruthGuidedRecommendationPresentationUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthGuidedRecommendationPresentationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthGuidedRecommendationPresentationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthGuidedRecommendationPresentationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthGuidedRecommendationPresentationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .loading,
            prompts: [],
            recommendationSetID: nil,
            activePrompt: nil,
            notice: nil
        )
        client.fetchOwnerTruthGuidedRecommendationPresentation(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    func submitFeedback(
        slot: OwnerTruthKnowledgeRecommendationSlot,
        action: OwnerTruthGuidedRecommendationFeedbackAction,
        reason: OwnerTruthGuidedRecommendationFeedbackReason
    ) {
        guard let vaultID = beginRequestOrFail() else { return }
        guard viewState.phase == .ready,
              viewState.prompts.contains(where: { $0.slot == slot }),
              let recommendationSetID = viewState.recommendationSetID else {
            preservePromptsWithFeedbackFailure(.contractMismatch)
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        let prompts = viewState.prompts
        let command = OwnerTruthGuidedRecommendationFeedbackCommand(
            recommendationSetID: recommendationSetID,
            slot: slot,
            action: action,
            reason: reason
        )
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .rebuilding,
            prompts: prompts,
            recommendationSetID: recommendationSetID,
            activePrompt: nil,
            notice: nil
        )
        client.submitOwnerTruthGuidedRecommendationFeedback(
            vaultID: vaultID,
            command: command
        ) { [weak self] result in
            self?.receiveFeedback(result, vaultID: vaultID, generation: generation)
        }
    }

    /// Bind the policy-owned question, then wait for a separate Owner-authored
    /// narrative. The question never enters the natural-input write lane.
    func activate(slot: OwnerTruthKnowledgeRecommendationSlot) {
        guard let vaultID = beginRequestOrFail() else { return }
        guard viewState.phase == .ready,
              viewState.activePrompt == nil,
              let prompt = viewState.prompts.first(where: { $0.slot == slot }),
              let recommendationSetID = viewState.recommendationSetID else {
            preservePromptsWithActivationFailure(.contractMismatch)
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        let prompts = viewState.prompts
        let command = OwnerTruthGuidedRecommendationActivationCommand(
            recommendationSetID: recommendationSetID,
            slot: slot
        )
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .activating,
            prompts: prompts,
            recommendationSetID: recommendationSetID,
            activePrompt: nil,
            notice: nil
        )
        client.activateOwnerTruthGuidedRecommendation(
            vaultID: vaultID,
            command: command
        ) { [weak self] result in
            self?.receiveActivation(
                result,
                vaultID: vaultID,
                prompt: prompt,
                generation: generation
            )
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthGuidedRecommendationPresentation, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let presentation):
            guard presentation.vaultID == vaultID,
                  presentation.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.contractMismatch)
                return
            }
            let phase: OwnerTruthGuidedRecommendationPresentationPhase
            switch presentation.state {
            case .ready:
                phase = .ready
            case .rebuilding:
                phase = .rebuilding
            case .unavailable:
                phase = .unavailable
            }
            viewState = OwnerTruthGuidedRecommendationPresentationViewState(
                phase: phase,
                prompts: phase == .ready ? presentation.prompts : [],
                recommendationSetID: phase == .ready ? presentation.recommendationSetID : nil,
                activePrompt: nil,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidGuidedRecommendationPresentation = error {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func receiveActivation(
        _ result: Result<OwnerTruthGuidedRecommendationActivationReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        prompt: OwnerTruthGuidedRecommendationPrompt,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID,
                  receipt.vaultID.rawValue == accountLease.vaultId,
                  receipt.slot == prompt.slot,
                  receipt.inputState == .awaitingOwnerNarrative else {
                preservePromptsWithActivationFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthGuidedRecommendationPresentationViewState(
                phase: .ready,
                prompts: [],
                recommendationSetID: nil,
                activePrompt: prompt,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidGuidedRecommendationActivation = error {
                preservePromptsWithActivationFailure(.contractMismatch)
            } else {
                preservePromptsWithActivationFailure(.activationRequestFailed)
            }
        }
    }

    private func receiveFeedback(
        _ result: Result<OwnerTruthGuidedRecommendationFeedbackReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID,
                  receipt.vaultID.rawValue == accountLease.vaultId else {
                preservePromptsWithFeedbackFailure(.contractMismatch)
                return
            }
            refresh()
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidGuidedRecommendationFeedback = error {
                preservePromptsWithFeedbackFailure(.contractMismatch)
            } else {
                preservePromptsWithFeedbackFailure(.feedbackRequestFailed)
            }
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthGuidedRecommendationPresentationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .unavailable,
            prompts: [],
            recommendationSetID: nil,
            activePrompt: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthGuidedRecommendationPresentationNotice) {
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .failed,
            prompts: [],
            recommendationSetID: nil,
            activePrompt: nil,
            notice: notice
        )
    }

    private func preservePromptsWithFeedbackFailure(
        _ notice: OwnerTruthGuidedRecommendationPresentationNotice
    ) {
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .ready,
            prompts: viewState.prompts,
            recommendationSetID: viewState.recommendationSetID,
            activePrompt: nil,
            notice: notice
        )
    }

    private func preservePromptsWithActivationFailure(
        _ notice: OwnerTruthGuidedRecommendationPresentationNotice
    ) {
        viewState = OwnerTruthGuidedRecommendationPresentationViewState(
            phase: .ready,
            prompts: viewState.prompts,
            recommendationSetID: viewState.recommendationSetID,
            activePrompt: nil,
            notice: notice
        )
    }
}

// MARK: - Default-off Owner Truth life-map presentation

/// One display-safe dimension node. Internal thread, association, source,
/// memory-version, checkpoint and policy identifiers never cross this model.
struct OwnerTruthLifeMapDimension: Equatable, Sendable {
    let dimension: OwnerTruthKnowledgeRecommendationDimension
    let confirmedEvidenceCount: Int
    let coveredFacetCount: Int
    let unfilledFacetCount: Int
    let relatedStoryCount: Int
}

/// Read-only M0-B life-map response for the product surface. The counts are
/// navigation hints, not a personal score or a claim of memory completeness.
struct OwnerTruthLifeMapPresentation: Equatable, Sendable {
    static let schemaVersion = "owner-truth-life-map-presentation-response-v1"

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthKnowledgeRecommendationPlanState
    let storyCount: Int
    let associatedStoryCount: Int
    let dimensions: [OwnerTruthLifeMapDimension]

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == ["schemaVersion", "vaultId", "lifeMap"],
              OwnerTruthLifeMapPresentationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthLifeMapPresentationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let lifeMap = object["lifeMap"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                "response misses a required presentation field"
            )
        }
        guard Set(lifeMap.keys) == [
            "state",
            "storyCount",
            "associatedStoryCount",
            "dimensions",
        ] else {
            throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                "response contains unsupported fields"
            )
        }
        guard let stateRaw = OwnerTruthLifeMapPresentationContract.requiredString(lifeMap["state"]),
              let state = OwnerTruthKnowledgeRecommendationPlanState(rawValue: stateRaw),
              let storyCount = OwnerTruthLifeMapPresentationContract.nonNegativeInt(
                lifeMap["storyCount"]
              ),
              let associatedStoryCount = OwnerTruthLifeMapPresentationContract.nonNegativeInt(
                lifeMap["associatedStoryCount"]
              ) else {
            throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                "response contains an invalid aggregate"
            )
        }

        let dimensionObjects = try OwnerTruthLifeMapPresentationContract.objectArray(
            lifeMap["dimensions"],
            field: "dimensions"
        )
        let dimensions = try dimensionObjects.map { item -> OwnerTruthLifeMapDimension in
            guard Set(item.keys) == [
                "dimension",
                "confirmedEvidenceCount",
                "coveredFacetCount",
                "unfilledFacetCount",
                "relatedStoryCount",
            ],
            let rawDimension = OwnerTruthLifeMapPresentationContract.requiredString(item["dimension"]),
            let dimension = OwnerTruthKnowledgeRecommendationDimension(rawValue: rawDimension),
            let confirmedEvidenceCount = OwnerTruthLifeMapPresentationContract.nonNegativeInt(
                item["confirmedEvidenceCount"]
            ),
            let coveredFacetCount = OwnerTruthLifeMapPresentationContract.nonNegativeInt(
                item["coveredFacetCount"]
            ),
            let unfilledFacetCount = OwnerTruthLifeMapPresentationContract.nonNegativeInt(
                item["unfilledFacetCount"]
            ),
            let relatedStoryCount = OwnerTruthLifeMapPresentationContract.nonNegativeInt(
                item["relatedStoryCount"]
            ) else {
                throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                    "dimension contains an unsupported value"
                )
            }
            return OwnerTruthLifeMapDimension(
                dimension: dimension,
                confirmedEvidenceCount: confirmedEvidenceCount,
                coveredFacetCount: coveredFacetCount,
                unfilledFacetCount: unfilledFacetCount,
                relatedStoryCount: relatedStoryCount
            )
        }

        let expectedDimensions = OwnerTruthKnowledgeRecommendationDimension.allCases
        guard state != .ready || dimensions.map(\.dimension) == expectedDimensions else {
            throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                "ready response must contain each stable dimension once"
            )
        }
        guard state == .ready || (
            storyCount == 0
                && associatedStoryCount == 0
                && dimensions.isEmpty
        ) else {
            throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                "non-ready response must not retain map content"
            )
        }

        vaultID = expectedVaultID
        self.state = state
        self.storyCount = storyCount
        self.associatedStoryCount = associatedStoryCount
        self.dimensions = dimensions
    }
}

protocol OwnerTruthLifeMapPresentationClient: AnyObject {
    func fetchOwnerTruthLifeMapPresentation(
        vaultID: OwnerTruthVaultID,
        completion: @escaping (Result<OwnerTruthLifeMapPresentation, Error>) -> Void
    )
}

private enum OwnerTruthLifeMapPresentationContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite,
              value.doubleValue.rounded() == value.doubleValue,
              value.intValue >= 0 else {
            return nil
        }
        return value.intValue
    }

    static func objectArray(_ value: Any?, field: String) throws -> [[String: Any]] {
        guard let values = value as? [Any] else {
            throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                "\(field) must be an array"
            )
        }
        return try values.map { value in
            guard let object = value as? [String: Any] else {
                throw OwnerTruthRemoteContractError.invalidLifeMapPresentation(
                    "\(field) must contain objects"
                )
            }
            return object
        }
    }
}

enum OwnerTruthLifeMapPresentationPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case rebuilding
    case unavailable
    case failed
}

enum OwnerTruthLifeMapPresentationNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
}

struct OwnerTruthLifeMapPresentationViewState: Equatable, Sendable {
    let phase: OwnerTruthLifeMapPresentationPhase
    let presentation: OwnerTruthLifeMapPresentation?
    let notice: OwnerTruthLifeMapPresentationNotice?

    static let idle = OwnerTruthLifeMapPresentationViewState(
        phase: .idle,
        presentation: nil,
        notice: nil
    )
}

/// Lease-fenced reader for the independent life-map policy. A closed policy
/// does not issue a request, and rebuilding/unavailable replies retain no
/// stale counts from an earlier account or projection.
final class OwnerTruthLifeMapPresentationUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthLifeMapPresentationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthLifeMapPresentationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthLifeMapPresentationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthLifeMapPresentationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthLifeMapPresentationViewState(
            phase: .loading,
            presentation: nil,
            notice: nil
        )
        client.fetchOwnerTruthLifeMapPresentation(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthLifeMapPresentation, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let presentation):
            guard presentation.vaultID == vaultID,
                  presentation.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.contractMismatch)
                return
            }
            let phase: OwnerTruthLifeMapPresentationPhase
            switch presentation.state {
            case .ready:
                phase = .ready
            case .rebuilding:
                phase = .rebuilding
            case .unavailable:
                phase = .unavailable
            }
            viewState = OwnerTruthLifeMapPresentationViewState(
                phase: phase,
                presentation: phase == .ready ? presentation : nil,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidLifeMapPresentation = error {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthLifeMapPresentationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthLifeMapPresentationViewState(
            phase: .unavailable,
            presentation: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthLifeMapPresentationNotice) {
        viewState = OwnerTruthLifeMapPresentationViewState(
            phase: .failed,
            presentation: nil,
            notice: notice
        )
    }
}

// MARK: - Default-off Owner Truth memory-search presentation

/// The product surface deliberately reports the current fallback mode.  Until
/// a semantic provider has its own approved contract, this must not be
/// presented as semantic ranking.
enum OwnerTruthMemorySearchRetrievalMode: String, Equatable, Sendable {
    case deterministicTextFallback
}

enum OwnerTruthMemorySearchPresentationState: String, Equatable, Sendable {
    case ready
    case rebuilding
}

/// A bounded display-safe result.  Identity, source, thread, citation,
/// checkpoint and policy fields never cross this Owner-only read model.
struct OwnerTruthMemorySearchPresentationResult: Equatable, Sendable {
    let rank: Int
    let preview: String
    let memoryKind: String
    let perspectiveType: String
    let sensitivity: String
    let matchKind: String
}

/// Read-only M0-B recall-search response.  A result can only originate from
/// the Owner's current confirmed MemoryVersion projection on the server.
struct OwnerTruthMemorySearchPresentation: Equatable, Sendable {
    static let schemaVersion = "owner-truth-memory-search-presentation-response-v1"
    static let maximumResultCount = 8
    static let maximumPreviewCharacterCount = 200

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthMemorySearchPresentationState
    let retrievalMode: OwnerTruthMemorySearchRetrievalMode
    let results: [OwnerTruthMemorySearchPresentationResult]

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == ["schemaVersion", "vaultId", "memorySearch"],
              OwnerTruthMemorySearchPresentationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthMemorySearchPresentationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let search = object["memorySearch"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                "response misses a required presentation field"
            )
        }
        guard Set(search.keys) == ["state", "retrievalMode", "resultCount", "results"],
              let rawState = OwnerTruthMemorySearchPresentationContract.requiredString(search["state"]),
              let state = OwnerTruthMemorySearchPresentationState(rawValue: rawState),
              let rawMode = OwnerTruthMemorySearchPresentationContract.requiredString(search["retrievalMode"]),
              let retrievalMode = OwnerTruthMemorySearchRetrievalMode(rawValue: rawMode),
              let resultCount = OwnerTruthMemorySearchPresentationContract.nonNegativeInt(search["resultCount"]),
              resultCount <= Self.maximumResultCount else {
            throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                "response contains an invalid aggregate"
            )
        }

        let resultObjects = try OwnerTruthMemorySearchPresentationContract.objectArray(
            search["results"],
            field: "results"
        )
        guard resultObjects.count == resultCount else {
            throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                "result count does not match results"
            )
        }
        let results = try resultObjects.map { item -> OwnerTruthMemorySearchPresentationResult in
            guard Set(item.keys) == [
                "rank",
                "preview",
                "memoryKind",
                "perspectiveType",
                "sensitivity",
                "matchKind",
            ],
            let rank = OwnerTruthMemorySearchPresentationContract.nonNegativeInt(item["rank"]),
            rank > 0,
            let preview = OwnerTruthMemorySearchPresentationContract.boundedString(
                item["preview"],
                maximumCharacterCount: Self.maximumPreviewCharacterCount
            ),
            let memoryKind = OwnerTruthMemorySearchPresentationContract.boundedString(
                item["memoryKind"],
                maximumCharacterCount: 80
            ),
            let perspectiveType = OwnerTruthMemorySearchPresentationContract.boundedString(
                item["perspectiveType"],
                maximumCharacterCount: 80
            ),
            let sensitivity = OwnerTruthMemorySearchPresentationContract.boundedString(
                item["sensitivity"],
                maximumCharacterCount: 80
            ),
            let matchKind = OwnerTruthMemorySearchPresentationContract.boundedString(
                item["matchKind"],
                maximumCharacterCount: 80
            ) else {
                throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                    "result contains unsupported fields"
                )
            }
            return OwnerTruthMemorySearchPresentationResult(
                rank: rank,
                preview: preview,
                memoryKind: memoryKind,
                perspectiveType: perspectiveType,
                sensitivity: sensitivity,
                matchKind: matchKind
            )
        }

        guard state == .ready || results.isEmpty else {
            throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                "rebuilding response must not retain results"
            )
        }
        guard results.enumerated().allSatisfy({ index, result in result.rank == index + 1 }) else {
            throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                "result ranks must be contiguous"
            )
        }

        vaultID = expectedVaultID
        self.state = state
        self.retrievalMode = retrievalMode
        self.results = results
    }
}

protocol OwnerTruthMemorySearchPresentationClient: AnyObject {
    func searchOwnerTruthMemoryPresentation(
        vaultID: OwnerTruthVaultID,
        query: String,
        completion: @escaping (Result<OwnerTruthMemorySearchPresentation, Error>) -> Void
    )
}

private enum OwnerTruthMemorySearchPresentationContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func boundedString(_ value: Any?, maximumCharacterCount: Int) -> String? {
        guard let normalized = requiredString(value),
              normalized.count <= maximumCharacterCount else {
            return nil
        }
        return normalized
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite,
              value.doubleValue.rounded() == value.doubleValue,
              value.intValue >= 0 else {
            return nil
        }
        return value.intValue
    }

    static func objectArray(_ value: Any?, field: String) throws -> [[String: Any]] {
        guard let values = value as? [Any] else {
            throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                "\(field) must be an array"
            )
        }
        return try values.map { value in
            guard let object = value as? [String: Any] else {
                throw OwnerTruthRemoteContractError.invalidMemorySearchPresentation(
                    "\(field) must contain objects"
                )
            }
            return object
        }
    }
}

enum OwnerTruthMemorySearchPresentationPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case rebuilding
    case unavailable
    case failed
}

enum OwnerTruthMemorySearchPresentationNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidQuery
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
}

struct OwnerTruthMemorySearchPresentationViewState: Equatable, Sendable {
    let phase: OwnerTruthMemorySearchPresentationPhase
    let presentation: OwnerTruthMemorySearchPresentation?
    let notice: OwnerTruthMemorySearchPresentationNotice?

    static let idle = OwnerTruthMemorySearchPresentationViewState(
        phase: .idle,
        presentation: nil,
        notice: nil
    )
}

/// Lease-fenced product reader.  A closed policy, stale account or failed
/// request clears the previous results rather than retaining another account's
/// private memory preview.
final class OwnerTruthMemorySearchPresentationUseCase {
    static let maximumQueryCharacterCount = 240

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthMemorySearchPresentationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthMemorySearchPresentationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthMemorySearchPresentationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthMemorySearchPresentationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func search(query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty,
              normalizedQuery.count <= Self.maximumQueryCharacterCount else {
            resetForUnavailable(.invalidQuery)
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthMemorySearchPresentationViewState(
            phase: .loading,
            presentation: nil,
            notice: nil
        )
        client.searchOwnerTruthMemoryPresentation(
            vaultID: vaultID,
            query: normalizedQuery
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthMemorySearchPresentation, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let presentation):
            guard presentation.vaultID == vaultID,
                  presentation.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.contractMismatch)
                return
            }
            let phase: OwnerTruthMemorySearchPresentationPhase = presentation.state == .ready
                ? .ready
                : .rebuilding
            viewState = OwnerTruthMemorySearchPresentationViewState(
                phase: phase,
                presentation: phase == .ready ? presentation : nil,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidMemorySearchPresentation = error {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthMemorySearchPresentationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthMemorySearchPresentationViewState(
            phase: .unavailable,
            presentation: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthMemorySearchPresentationNotice) {
        viewState = OwnerTruthMemorySearchPresentationViewState(
            phase: .failed,
            presentation: nil,
            notice: notice
        )
    }
}

// MARK: - Default-off Owner Truth interview outcome presentation

/// The product view intentionally has only two states. It never exposes a
/// thread/session id, review batch, source, Candidate, raw interview content,
/// or a model-inferred statement as an Owner-confirmed fact.
enum OwnerTruthInterviewOutcomePresentationState: String, Equatable, Sendable {
    case ready
    case rebuilding
}

/// Read-only ending summary for one Owner interview. Counts are current server
/// projections only; `rebuilding` responses retain no historical count.
struct OwnerTruthInterviewOutcomePresentation: Equatable, Sendable {
    static let schemaVersion = "owner-truth-interview-session-outcome-presentation-v1"
    static let maximumCount = 100_000

    let vaultID: OwnerTruthVaultID
    let state: OwnerTruthInterviewOutcomePresentationState
    let confirmedMemoryCount: Int
    let pendingReviewBatchCount: Int
    let canContinueLater: Bool
    let eligibleCueCount: Int

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        guard Set(object.keys) == ["schemaVersion", "vaultId", "sessionOutcome"],
              OwnerTruthInterviewOutcomePresentationContract.requiredString(object["schemaVersion"])
                == Self.schemaVersion,
              OwnerTruthInterviewOutcomePresentationContract.requiredString(object["vaultId"])
                == expectedVaultID.rawValue,
              let outcome = object["sessionOutcome"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidInterviewOutcomePresentation(
                "response misses a required presentation field"
            )
        }
        guard Set(outcome.keys) == ["state", "thisSession", "laterContinue"],
              let rawState = OwnerTruthInterviewOutcomePresentationContract.requiredString(
                outcome["state"]
              ),
              let state = OwnerTruthInterviewOutcomePresentationState(rawValue: rawState),
              let thisSession = outcome["thisSession"] as? [String: Any],
              let laterContinue = outcome["laterContinue"] as? [String: Any],
              Set(thisSession.keys) == ["confirmedMemoryCount", "pendingReviewBatchCount"],
              Set(laterContinue.keys) == ["canContinueLater", "eligibleCueCount"],
              let confirmedMemoryCount = OwnerTruthInterviewOutcomePresentationContract.nonNegativeInt(
                thisSession["confirmedMemoryCount"]
              ),
              let pendingReviewBatchCount = OwnerTruthInterviewOutcomePresentationContract.nonNegativeInt(
                thisSession["pendingReviewBatchCount"]
              ),
              let canContinueLater = laterContinue["canContinueLater"] as? Bool,
              let eligibleCueCount = OwnerTruthInterviewOutcomePresentationContract.nonNegativeInt(
                laterContinue["eligibleCueCount"]
              ),
              confirmedMemoryCount <= Self.maximumCount,
              pendingReviewBatchCount <= Self.maximumCount,
              eligibleCueCount <= Self.maximumCount else {
            throw OwnerTruthRemoteContractError.invalidInterviewOutcomePresentation(
                "response contains unsupported fields"
            )
        }
        guard state == .ready || (
            confirmedMemoryCount == 0
                && pendingReviewBatchCount == 0
                && eligibleCueCount == 0
        ) else {
            throw OwnerTruthRemoteContractError.invalidInterviewOutcomePresentation(
                "rebuilding response must not retain counts"
            )
        }

        vaultID = expectedVaultID
        self.state = state
        self.confirmedMemoryCount = confirmedMemoryCount
        self.pendingReviewBatchCount = pendingReviewBatchCount
        self.canContinueLater = canContinueLater
        self.eligibleCueCount = eligibleCueCount
    }
}

protocol OwnerTruthInterviewOutcomePresentationClient: AnyObject {
    func fetchOwnerTruthInterviewOutcomePresentation(
        vaultID: OwnerTruthVaultID,
        sessionID: OwnerTruthRecordID,
        completion: @escaping (Result<OwnerTruthInterviewOutcomePresentation, Error>) -> Void
    )
}

private enum OwnerTruthInterviewOutcomePresentationContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite,
              value.doubleValue.rounded() == value.doubleValue,
              value.intValue >= 0 else {
            return nil
        }
        return value.intValue
    }
}

enum OwnerTruthInterviewOutcomePresentationPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case rebuilding
    case unavailable
    case failed
}

enum OwnerTruthInterviewOutcomePresentationNotice: Equatable, Sendable {
    case releasePolicyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
}

struct OwnerTruthInterviewOutcomePresentationViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewOutcomePresentationPhase
    let presentation: OwnerTruthInterviewOutcomePresentation?
    let notice: OwnerTruthInterviewOutcomePresentationNotice?

    static let idle = OwnerTruthInterviewOutcomePresentationViewState(
        phase: .idle,
        presentation: nil,
        notice: nil
    )
}

/// Lease-fenced reader for the per-session ending summary. The session id is
/// intentionally confined to the request path; the response contains no
/// correlating identifier and is accepted only for the captured Owner Vault.
final class OwnerTruthInterviewOutcomePresentationUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let sessionID: OwnerTruthRecordID
    private let client: OwnerTruthInterviewOutcomePresentationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let releasePolicyAvailable: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewOutcomePresentationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewOutcomePresentationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        sessionID: OwnerTruthRecordID,
        client: OwnerTruthInterviewOutcomePresentationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        releasePolicyAvailable: @escaping () -> Bool
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.sessionID = sessionID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.releasePolicyAvailable = releasePolicyAvailable
    }

    func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewOutcomePresentationViewState(
            phase: .loading,
            presentation: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewOutcomePresentation(
            vaultID: vaultID,
            sessionID: sessionID
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthInterviewOutcomePresentation, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard releasePolicyAvailable() else {
            resetForUnavailable(.releasePolicyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let presentation):
            guard presentation.vaultID == vaultID,
                  presentation.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.contractMismatch)
                return
            }
            let phase: OwnerTruthInterviewOutcomePresentationPhase = presentation.state == .ready
                ? .ready
                : .rebuilding
            viewState = OwnerTruthInterviewOutcomePresentationViewState(
                phase: phase,
                presentation: phase == .ready ? presentation : nil,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidInterviewOutcomePresentation = error {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthInterviewOutcomePresentationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewOutcomePresentationViewState(
            phase: .unavailable,
            presentation: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthInterviewOutcomePresentationNotice) {
        viewState = OwnerTruthInterviewOutcomePresentationViewState(
            phase: .failed,
            presentation: nil,
            notice: notice
        )
    }
}

// MARK: - QA-only Owner-confirmed knowledge dimensions

/// The server recognizes only a newly recorded confirmation or an idempotent
/// replay. Keeping this separate from generic command outcomes prevents a
/// future public surface from treating the QA endpoint as a mutable review API.
enum OwnerTruthKnowledgeDimensionConfirmationOutcome: String, Codable, Equatable, Sendable {
    case created
    case deduplicated
}

/// A value-minimized command for one explicit Owner classification of an exact
/// current MemoryVersion. It has no narrative, provider output or client-owned
/// policy method; those values remain fixed at the server policy boundary.
struct OwnerTruthKnowledgeDimensionConfirmationCommand: Equatable, Sendable {
    static let confirmationMethod = "ownerExplicitSelection"
    static let uiSchemaVersion = "knowledge-dimension-review-v1"

    let commandID: String
    let memoryVersionID: OwnerTruthRecordID
    let expectedContentHash: String
    let dimension: OwnerTruthKnowledgeRecommendationDimension
    let coveredFacets: [String]

    init(
        commandID: String,
        memoryVersionID: OwnerTruthRecordID,
        expectedContentHash: String,
        dimension: OwnerTruthKnowledgeRecommendationDimension,
        coveredFacets: [String]
    ) throws {
        let normalizedCommandID = commandID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHash = expectedContentHash.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFacets = coveredFacets.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard OwnerTruthKnowledgeDimensionConfirmationContract.isOpaqueCommandID(normalizedCommandID),
              OwnerTruthKnowledgeDimensionConfirmationContract.isSHA256Digest(normalizedHash),
              !normalizedFacets.isEmpty,
              Set(normalizedFacets).count == normalizedFacets.count,
              normalizedFacets.allSatisfy(dimension.supportsFacet) else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeDimensionConfirmation(
                "command must include an opaque id, exact hash and unique supported facets"
            )
        }
        self.commandID = normalizedCommandID
        self.memoryVersionID = memoryVersionID
        self.expectedContentHash = normalizedHash
        self.dimension = dimension
        self.coveredFacets = dimension.facetOrder.filter(normalizedFacets.contains)
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "expectedContentHash": expectedContentHash,
            "dimension": dimension.rawValue,
            "coveredFacets": coveredFacets,
            "confirmationMethod": Self.confirmationMethod,
            "uiSchemaVersion": Self.uiSchemaVersion,
        ]
    }
}

/// The response keeps only classification metadata needed by a later reviewed
/// knowledge-map surface. Receipt and MemoryVersion identifiers plus the bound
/// hash are verified on receipt, then deliberately discarded.
struct OwnerTruthKnowledgeDimensionConfirmationReceipt: Equatable, Sendable {
    static let responseSchemaVersion = "owner-truth-knowledge-dimension-confirmation-response-v1"
    static let confirmationSchemaVersion = "owner-truth-knowledge-dimension-confirmation-v1"

    let outcome: OwnerTruthKnowledgeDimensionConfirmationOutcome
    let dimension: OwnerTruthKnowledgeRecommendationDimension
    let coveredFacets: [String]
    let authorityEpoch: Int

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthKnowledgeDimensionConfirmationCommand
    ) throws {
        guard OwnerTruthKnowledgeDimensionConfirmationContract.requiredString(object["schemaVersion"])
                == Self.responseSchemaVersion,
              let rawOutcome = OwnerTruthKnowledgeDimensionConfirmationContract.requiredString(object["status"]),
              let outcome = OwnerTruthKnowledgeDimensionConfirmationOutcome(rawValue: rawOutcome),
              let confirmation = object["confirmation"] as? [String: Any],
              OwnerTruthKnowledgeDimensionConfirmationContract.requiredString(confirmation["schemaVersion"])
                == Self.confirmationSchemaVersion,
              OwnerTruthKnowledgeDimensionConfirmationContract.requiredString(confirmation["status"])
                == outcome.rawValue,
              OwnerTruthKnowledgeDimensionConfirmationContract.recordID(confirmation["confirmationId"]) != nil,
              OwnerTruthKnowledgeDimensionConfirmationContract.recordID(confirmation["memoryId"]) != nil,
              OwnerTruthKnowledgeDimensionConfirmationContract.recordID(confirmation["memoryVersionId"])
                == expectedCommand.memoryVersionID,
              OwnerTruthKnowledgeDimensionConfirmationContract.requiredString(confirmation["boundContentHash"])
                == expectedCommand.expectedContentHash,
              OwnerTruthKnowledgeDimensionConfirmationContract.requiredString(confirmation["dimension"])
                == expectedCommand.dimension.rawValue,
              let coveredFacets = OwnerTruthKnowledgeDimensionConfirmationContract.stringArray(
                confirmation["coveredFacets"]
              ),
              coveredFacets == expectedCommand.coveredFacets,
              let authorityEpoch = OwnerTruthKnowledgeDimensionConfirmationContract.nonNegativeInt(
                confirmation["authorityEpoch"]
              ) else {
            throw OwnerTruthRemoteContractError.invalidKnowledgeDimensionConfirmation(
                "confirmation receipt does not match the requested current MemoryVersion"
            )
        }

        self.outcome = outcome
        self.dimension = expectedCommand.dimension
        self.coveredFacets = coveredFacets
        self.authorityEpoch = authorityEpoch
    }
}

protocol OwnerTruthKnowledgeDimensionConfirmationClient: AnyObject {
    func confirmOwnerTruthKnowledgeDimension(
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthKnowledgeDimensionConfirmationCommand,
        completion: @escaping (Result<OwnerTruthKnowledgeDimensionConfirmationReceipt, Error>) -> Void
    )
}

private enum OwnerTruthKnowledgeDimensionConfirmationContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let rawValue = requiredString(value),
              let uuid = UUID(uuidString: rawValue) else {
            return nil
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func stringArray(_ value: Any?) -> [String]? {
        guard let values = value as? [Any] else { return nil }
        let normalized = values.compactMap(requiredString)
        return normalized.count == values.count ? normalized : nil
    }

    static func nonNegativeInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value >= 0 { return value }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue,
           value.intValue >= 0 {
            return value.intValue
        }
        return nil
    }

    static func isOpaqueCommandID(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars)
        guard (1...128).contains(scalars.count),
              let first = scalars.first,
              isASCIILetter(first) else {
            return false
        }
        return scalars.dropFirst().allSatisfy(isAllowedOpaqueIdentifierScalar)
    }

    static func isSHA256Digest(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars)
        return scalars.count == 64 && scalars.allSatisfy(isLowercaseHexScalar)
    }

    private static func isASCIILetter(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    private static func isAllowedOpaqueIdentifierScalar(_ scalar: UnicodeScalar) -> Bool {
        isASCIILetter(scalar)
            || (48...57).contains(scalar.value)
            || [46, 58, 45, 95].contains(scalar.value)
    }

    private static func isLowercaseHexScalar(_ scalar: UnicodeScalar) -> Bool {
        (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
    }
}

enum OwnerTruthKnowledgeDimensionConfirmationPhase: Equatable, Sendable {
    case idle
    case confirming
    case confirmed
    case unavailable
    case failed
}

enum OwnerTruthKnowledgeDimensionConfirmationNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case memoryActivationUnavailable
    case invalidSelection
    case contractMismatch
    case requestFailed
}

/// This state intentionally keeps only the value-minimized confirmation
/// receipt. Memory and version identifiers plus the bound content hash are
/// inputs to the request and never become retained presentation state.
struct OwnerTruthKnowledgeDimensionConfirmationViewState: Equatable, Sendable {
    let phase: OwnerTruthKnowledgeDimensionConfirmationPhase
    let latestReceipt: OwnerTruthKnowledgeDimensionConfirmationReceipt?
    let notice: OwnerTruthKnowledgeDimensionConfirmationNotice?

    static let idle = OwnerTruthKnowledgeDimensionConfirmationViewState(
        phase: .idle,
        latestReceipt: nil,
        notice: nil
    )
}

/// QA-only bridge from an accepted/corrected Candidate activation to one
/// explicit knowledge-dimension confirmation. The server remains the final
/// authority for ownership and current-version validation; this coordinator
/// prevents stale-account callbacks and retry command drift on the client.
final class OwnerTruthKnowledgeDimensionConfirmationUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthKnowledgeDimensionConfirmationClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private let commandIDFactory: CommandIDFactory

    private var commandIDsBySelectionSignature: [String: String] = [:]
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthKnowledgeDimensionConfirmationViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthKnowledgeDimensionConfirmationViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthKnowledgeDimensionConfirmationClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled },
        commandIDFactory: @escaping CommandIDFactory = {
            "owner-truth-dimension-\(UUID().uuidString.lowercased())"
        }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.commandIDFactory = commandIDFactory
    }

    func confirm(
        memoryActivation: OwnerTruthCandidateMemoryActivation,
        dimension: OwnerTruthKnowledgeRecommendationDimension,
        coveredFacets: [String]
    ) {
        guard let vaultID = beginRequestOrFail(),
              let command = makeCommand(
                  memoryActivation: memoryActivation,
                  dimension: dimension,
                  coveredFacets: coveredFacets
              ) else {
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthKnowledgeDimensionConfirmationViewState(
            phase: .confirming,
            latestReceipt: nil,
            notice: nil
        )
        client.confirmOwnerTruthKnowledgeDimension(vaultID: vaultID, command: command) { [weak self] result in
            self?.receive(result, expectedCommand: command, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func makeCommand(
        memoryActivation: OwnerTruthCandidateMemoryActivation,
        dimension: OwnerTruthKnowledgeRecommendationDimension,
        coveredFacets: [String]
    ) -> OwnerTruthKnowledgeDimensionConfirmationCommand? {
        guard memoryActivation.outcome != .notApplicable,
              memoryActivation.memoryID != nil,
              let memoryVersionID = memoryActivation.memoryVersionID,
              let contentHash = memoryActivation.contentHash else {
            transitionFailure(.memoryActivationUnavailable)
            return nil
        }

        let normalizedFacets = coveredFacets.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let canonicalFacets = dimension.facetOrder.filter(normalizedFacets.contains)
        let signature = [
            memoryVersionID.rawValue.uuidString.lowercased(),
            contentHash.trimmingCharacters(in: .whitespacesAndNewlines),
            dimension.rawValue,
            canonicalFacets.joined(separator: ","),
        ].joined(separator: "|")
        let commandID = commandIDsBySelectionSignature[signature] ?? commandIDFactory()

        do {
            let command = try OwnerTruthKnowledgeDimensionConfirmationCommand(
                commandID: commandID,
                memoryVersionID: memoryVersionID,
                expectedContentHash: contentHash,
                dimension: dimension,
                coveredFacets: coveredFacets
            )
            commandIDsBySelectionSignature[signature] = commandID
            return command
        } catch {
            transitionFailure(.invalidSelection)
            return nil
        }
    }

    private func receive(
        _ result: Result<OwnerTruthKnowledgeDimensionConfirmationReceipt, Error>,
        expectedCommand: OwnerTruthKnowledgeDimensionConfirmationCommand,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let receipt):
            guard receipt.dimension == expectedCommand.dimension,
                  receipt.coveredFacets == expectedCommand.coveredFacets else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthKnowledgeDimensionConfirmationViewState(
                phase: .confirmed,
                latestReceipt: receipt,
                notice: nil
            )
        case .failure(let error):
            if case OwnerTruthRemoteContractError.invalidKnowledgeDimensionConfirmation = error {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthKnowledgeDimensionConfirmationNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthKnowledgeDimensionConfirmationViewState(
            phase: .unavailable,
            latestReceipt: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthKnowledgeDimensionConfirmationNotice) {
        viewState = OwnerTruthKnowledgeDimensionConfirmationViewState(
            phase: .failed,
            latestReceipt: nil,
            notice: notice
        )
    }
}

enum OwnerTruthInterviewNaturalInputIntent: Equatable, Sendable {
    case start
    case submit(text: String)
    case submitLiveTurn(text: String, role: OwnerTruthInterviewNaturalInputMessageRole)
    case end
    case setBoundary(OwnerTruthInterviewSessionBoundary)
    case recordPacing(OwnerTruthInterviewPacingEvent)
    case pauseForTopicSwitch
    case restoreDoNotAsk
    case restoreCooldown
}

enum OwnerTruthInterviewNaturalInputPhase: Equatable, Sendable {
    case idle
    case starting
    case ready
    case submitting
    case unavailable
    case failed
}

enum OwnerTruthInterviewNaturalInputNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case invalidInput
    case contractMismatch
    case requestFailed
}

/// View state deliberately contains receipt metadata only. The submitted text
/// is passed to the transport and then discarded by this QA client.
struct OwnerTruthInterviewNaturalInputViewState: Equatable, Sendable {
    let phase: OwnerTruthInterviewNaturalInputPhase
    let latestReceipt: OwnerTruthInterviewNaturalInputReceipt?
    let continuation: OwnerTruthInterviewNaturalInputContinuation?
    let notice: OwnerTruthInterviewNaturalInputNotice?

    static let idle = OwnerTruthInterviewNaturalInputViewState(
        phase: .idle,
        latestReceipt: nil,
        continuation: nil,
        notice: nil
    )
}

/// Account-lease fenced coordinator for the two-step natural-input write
/// contract. It has no public navigation responsibility and no authority to
/// create candidates, memories or provider effects.
final class OwnerTruthInterviewNaturalInputUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthInterviewNaturalInputClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private let identifierFactory: () -> UUID
    private let entryMode: OwnerTruthInterviewEntryMode
    private let allowsEntryModeTransition: Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthInterviewNaturalInputViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthInterviewNaturalInputViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthInterviewNaturalInputClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled },
        identifierFactory: @escaping () -> UUID = UUID.init,
        entryMode: OwnerTruthInterviewEntryMode = .naturalInput,
        allowsEntryModeTransition: Bool = false
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.identifierFactory = identifierFactory
        self.entryMode = entryMode
        self.allowsEntryModeTransition = allowsEntryModeTransition
    }

    func send(_ intent: OwnerTruthInterviewNaturalInputIntent) {
        switch intent {
        case .start:
            start()
        case .submit(let text):
            submit(text: text, role: .owner, captureMode: .naturalInput)
        case .submitLiveTurn(let text, let role):
            submit(text: text, role: role, captureMode: .live)
        case .end:
            end()
        case .setBoundary(let boundary):
            setBoundary(boundary)
        case .recordPacing(let event):
            recordPacing(event)
        case .pauseForTopicSwitch:
            pauseForTopicSwitch()
        case .restoreDoNotAsk:
            restoreDoNotAsk()
        case .restoreCooldown:
            restoreCooldown()
        }
    }

    private func start() {
        guard viewState.latestReceipt == nil, viewState.phase != .starting else { return }
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthInterviewNaturalInputViewState(
            phase: .starting,
            latestReceipt: nil,
            continuation: nil,
            notice: nil
        )
        client.fetchOwnerTruthInterviewNaturalInputCurrentSession(vaultID: vaultID) { [weak self] result in
            self?.receiveCurrentSession(result, vaultID: vaultID, generation: generation)
        }
    }

    private func startNewSession(vaultID: OwnerTruthVaultID) {
        do {
            let command = try OwnerTruthInterviewNaturalInputStartCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: OwnerTruthRecordID(rawValue: identifierFactory()),
                sessionID: OwnerTruthRecordID(rawValue: identifierFactory()),
                entryMode: entryMode
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .starting,
                latestReceipt: nil,
                continuation: nil,
                notice: nil
            )
            client.startOwnerTruthInterviewNaturalInput(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveStart(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            transitionFailure(.invalidInput)
        }
    }

    private func receiveCurrentSession(
        _ result: Result<OwnerTruthInterviewNaturalInputCurrentSession, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let current):
            guard current.vaultID == vaultID else {
                transitionFailure(.contractMismatch)
                return
            }
            guard let receipt = current.receipt else {
                startNewSession(vaultID: vaultID)
                return
            }
            guard let currentEntryMode = current.entryMode,
                  receipt.outcome == .resumed,
                  receipt.lifecycle == .active,
                  receipt.messageID == nil,
                  receipt.messageSequence == nil else {
                transitionFailure(.contractMismatch)
                return
            }
            guard currentEntryMode == entryMode else {
                guard allowsEntryModeTransition else {
                    transitionFailure(.contractMismatch)
                    return
                }
                pauseCurrentSessionForEntryModeTransition(
                    vaultID: vaultID,
                    receipt: receipt
                )
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            // Failing closed is important here: creating a fresh session after
            // a failed current-session read could bypass an existing boundary.
            transitionFailure(.requestFailed)
        }
    }

    private func pauseCurrentSessionForEntryModeTransition(
        vaultID: OwnerTruthVaultID,
        receipt: OwnerTruthInterviewNaturalInputReceipt
    ) {
        do {
            let command = try OwnerTruthInterviewPauseForTopicSwitchCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedThreadVersion: receipt.threadVersion,
                expectedSessionVersion: receipt.sessionVersion
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            client.pauseOwnerTruthInterviewForTopicSwitch(
                vaultID: vaultID,
                command: command
            ) { [weak self] result in
                self?.receiveTopicSwitchPause(
                    result,
                    vaultID: vaultID,
                    command: command,
                    generation: generation
                )
            }
        } catch {
            transitionFailure(.invalidInput)
        }
    }

    private func submit(
        text: String,
        role: OwnerTruthInterviewNaturalInputMessageRole,
        captureMode: OwnerTruthInterviewNaturalInputCaptureMode
    ) {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewNaturalInputAppendCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                messageID: OwnerTruthRecordID(rawValue: identifierFactory()),
                expectedThreadVersion: receipt.threadVersion,
                expectedSessionVersion: receipt.sessionVersion,
                text: text,
                role: role,
                captureMode: captureMode
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.appendOwnerTruthInterviewNaturalInput(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveAppend(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func end() {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready,
              receipt.lifecycle == .active,
              receipt.boundary == .open,
              receipt.messageSequence != nil else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewEndCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedThreadVersion: receipt.threadVersion,
                expectedSessionVersion: receipt.sessionVersion
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.endOwnerTruthInterviewNaturalInput(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveEnd(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func setBoundary(_ boundary: OwnerTruthInterviewSessionBoundary) {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewBoundaryCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedSessionVersion: receipt.sessionVersion,
                boundary: boundary
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.setOwnerTruthInterviewBoundary(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveBoundary(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func recordPacing(_ event: OwnerTruthInterviewPacingEvent) {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready,
              receipt.lifecycle == .active,
              receipt.boundary == .open else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewPacingCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedSessionVersion: receipt.sessionVersion,
                event: event
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.recordOwnerTruthInterviewPacing(vaultID: vaultID, command: command) { [weak self] result in
                self?.receivePacing(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func restoreDoNotAsk() {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready,
              receipt.boundary == .doNotAsk else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewRestoreDoNotAskCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedSessionVersion: receipt.sessionVersion
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.restoreOwnerTruthInterviewDoNotAsk(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveDoNotAskRestore(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func pauseForTopicSwitch() {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready,
              receipt.lifecycle == .active else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewPauseForTopicSwitchCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedThreadVersion: receipt.threadVersion,
                expectedSessionVersion: receipt.sessionVersion
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.pauseOwnerTruthInterviewForTopicSwitch(
                vaultID: vaultID,
                command: command
            ) { [weak self] result in
                self?.receiveTopicSwitchPause(
                    result,
                    vaultID: vaultID,
                    command: command,
                    generation: generation
                )
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func restoreCooldown() {
        guard let receipt = viewState.latestReceipt,
              viewState.phase == .ready,
              receipt.boundary == .cooldown else {
            return
        }
        guard let vaultID = beginRequestOrFail() else { return }
        do {
            let command = try OwnerTruthInterviewRestoreCooldownCommand(
                commandID: identifierFactory().uuidString.lowercased(),
                threadID: receipt.threadID,
                sessionID: receipt.sessionID,
                expectedSessionVersion: receipt.sessionVersion
            )
            operationGeneration &+= 1
            let generation = operationGeneration
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .submitting,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: nil
            )
            client.restoreOwnerTruthInterviewCooldown(vaultID: vaultID, command: command) { [weak self] result in
                self?.receiveCooldownRestore(result, vaultID: vaultID, command: command, generation: generation)
            }
        } catch {
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: viewState.continuation,
                notice: .invalidInput
            )
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receiveStart(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputStartCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveAppend(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewNaturalInputAppendCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveEnd(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewEndCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveBoundary(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewBoundaryCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receivePacing(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPacingCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveTopicSwitchPause(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewPauseForTopicSwitchCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            // The old thread is now fenced. Starting the new thread is an
            // explicit second command so the backend never receives topic
            // text or a client-selected replacement session in this pause.
            startNewSession(vaultID: vaultID)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveDoNotAskRestore(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreDoNotAskCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func receiveCooldownRestore(
        _ result: Result<OwnerTruthInterviewNaturalInputReceipt, Error>,
        vaultID: OwnerTruthVaultID,
        command: OwnerTruthInterviewRestoreCooldownCommand,
        generation: UInt
    ) {
        guard canCommit(generation: generation) else { return }
        switch result {
        case .success(let receipt):
            guard receipt.vaultID == vaultID, receipt.matches(command) else {
                transitionFailure(.contractMismatch)
                return
            }
            viewState = OwnerTruthInterviewNaturalInputViewState(
                phase: .ready,
                latestReceipt: receipt,
                continuation: nil,
                notice: nil
            )
            refreshContinuation(vaultID: vaultID, receipt: receipt)
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func canCommit(generation: UInt) -> Bool {
        guard generation == operationGeneration else { return false }
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return false
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            transitionUnavailable(.staleAccountLease)
            return false
        }
        return true
    }

    /// A continuation read is advisory product presentation only. It cannot
    /// create Candidates, accept a review, or expose private conversation
    /// content. A failed advisory read preserves the durable write receipt.
    private func refreshContinuation(
        vaultID: OwnerTruthVaultID,
        receipt: OwnerTruthInterviewNaturalInputReceipt
    ) {
        guard viewState.phase == .ready,
              viewState.latestReceipt == receipt else {
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        client.fetchOwnerTruthInterviewNaturalInputContinuation(
            vaultID: vaultID,
            sessionID: receipt.sessionID
        ) { [weak self] result in
            self?.receiveContinuation(
                result,
                vaultID: vaultID,
                receipt: receipt,
                generation: generation
            )
        }
    }

    private func receiveContinuation(
        _ result: Result<OwnerTruthInterviewNaturalInputContinuation, Error>,
        vaultID: OwnerTruthVaultID,
        receipt: OwnerTruthInterviewNaturalInputReceipt,
        generation: UInt
    ) {
        guard canCommit(generation: generation),
              viewState.phase == .ready,
              viewState.latestReceipt == receipt else {
            return
        }
        guard case .success(let continuation) = result,
              continuation.vaultID == vaultID else {
            return
        }
        viewState = OwnerTruthInterviewNaturalInputViewState(
            phase: .ready,
            latestReceipt: receipt,
            continuation: continuation,
            notice: nil
        )
    }

    private func transitionUnavailable(_ notice: OwnerTruthInterviewNaturalInputNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthInterviewNaturalInputViewState(
            phase: .unavailable,
            latestReceipt: nil,
            continuation: nil,
            notice: notice
        )
    }

    private func transitionFailure(_ notice: OwnerTruthInterviewNaturalInputNotice) {
        viewState = OwnerTruthInterviewNaturalInputViewState(
            phase: .failed,
            latestReceipt: nil,
            continuation: nil,
            notice: notice
        )
    }
}

private enum OwnerTruthInterviewNaturalInputContract {
    static func requiredString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        return nonEmptyString(value)
    }

    static func nonEmptyString(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func recordID(_ value: Any?) -> OwnerTruthRecordID? {
        guard let value = requiredString(value), let uuid = UUID(uuidString: value) else {
            return nil
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func optionalRecordID(_ value: Any?, field: String) throws -> OwnerTruthRecordID? {
        guard let value, !(value is NSNull) else { return nil }
        guard let identifier = recordID(value) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "\(field) must be a UUID or null"
            )
        }
        return identifier
    }

    static func positiveInt(_ value: Any?) -> Int? {
        if let value = value as? Int, value > 0 { return value }
        if let value = value as? NSNumber,
           CFGetTypeID(value) != CFBooleanGetTypeID(),
           value.doubleValue.rounded() == value.doubleValue,
           value.intValue > 0 {
            return value.intValue
        }
        return nil
    }

    static func optionalPositiveInt(_ value: Any?, field: String) throws -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        guard let integer = positiveInt(value) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "\(field) must be a positive integer or null"
            )
        }
        return integer
    }

    static func requiredBool(_ value: Any?) -> Bool? {
        guard let value = value as? Bool else { return nil }
        return value
    }
}

// MARK: - Default-off Owner Truth Projection compatibility read

/// This gate is intentionally separate from candidate review.  The read
/// envelope is a narrow QA cohort contract, not a switch for legacy KBLite or
/// public Echo context selection.
enum OwnerTruthKBLiteCompatibilityQAGate {
    static let launchArgument = "DJEnableOwnerTruthKBLiteCompatibilityQA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        return false
        #endif
    }
}

enum OwnerTruthKBLiteCompatibilityReadState: String, Codable, Equatable, Sendable {
    case disabled
    case rebuilding
    case ready
}

enum OwnerTruthKBLiteCompatibilityCacheDisposition: String, Codable, Equatable, Sendable {
    case discard
    case replace
}

struct OwnerTruthKBLiteCompatibilityFactCitation: Codable, Equatable, Sendable {
    let memoryID: String
    let memoryVersionID: String
    let sourceID: String
    let sourceVersion: Int
    let contentHash: String
    let memoryVersion: Int

    init(backendJSONObject object: [String: Any]) throws {
        guard let memoryID = Self.nonEmptyString(object["memoryId"]),
              let memoryVersionID = Self.nonEmptyString(object["memoryVersionId"]),
              let sourceID = Self.nonEmptyString(object["sourceId"]),
              let sourceVersion = Self.positiveInt(object["sourceVersion"]),
              let contentHash = Self.nonEmptyString(object["contentHash"]),
              let memoryVersion = Self.positiveInt(object["memoryVersion"]) else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "fact citation is incomplete"
            )
        }
        self.memoryID = memoryID
        self.memoryVersionID = memoryVersionID
        self.sourceID = sourceID
        self.sourceVersion = sourceVersion
        self.contentHash = contentHash
        self.memoryVersion = memoryVersion
    }

    var backendJSONObject: [String: Any] {
        [
            "memoryId": memoryID,
            "memoryVersionId": memoryVersionID,
            "sourceId": sourceID,
            "sourceVersion": sourceVersion,
            "contentHash": contentHash,
            "memoryVersion": memoryVersion,
        ]
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func positiveInt(_ value: Any?) -> Int? {
        guard !(value is Bool), let value = value as? Int, value > 0 else { return nil }
        return value
    }
}

struct OwnerTruthKBLiteCompatibilityFact: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let statement: String
    let confidence: String
    let evidenceStatus: String
    let compatibilitySource: String
    let citation: OwnerTruthKBLiteCompatibilityFactCitation

    init(backendJSONObject object: [String: Any]) throws {
        guard let id = Self.nonEmptyString(object["id"]),
              let statement = Self.nonEmptyString(object["statement"]),
              Self.nonEmptyString(object["confidence"]) == "confirmed",
              Self.nonEmptyString(object["evidenceStatus"]) == "confirmed",
              Self.nonEmptyString(object["compatibilitySource"])
                == OwnerTruthKBLiteCompatibilityReadEnvelope.compatibilitySource,
              let citationObject = object["citation"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "fact is not a confirmed standard compatibility fact"
            )
        }
        self.id = id
        self.statement = statement
        self.confidence = "confirmed"
        self.evidenceStatus = "confirmed"
        self.compatibilitySource = OwnerTruthKBLiteCompatibilityReadEnvelope.compatibilitySource
        self.citation = try OwnerTruthKBLiteCompatibilityFactCitation(
            backendJSONObject: citationObject
        )
    }

    var backendJSONObject: [String: Any] {
        [
            "id": id,
            "statement": statement,
            "confidence": confidence,
            "evidenceStatus": evidenceStatus,
            "compatibilitySource": compatibilitySource,
            "citation": citation.backendJSONObject,
        ]
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}

/// The compatibility graph remains intentionally smaller than a legacy
/// KBLite graph.  Projection facts are the only cacheable values in this
/// cohort; people, places, and events must stay empty until their own policy
/// is approved.
struct OwnerTruthKBLiteCompatibilityGraph: Codable, Equatable, Sendable {
    let facts: [OwnerTruthKBLiteCompatibilityFact]

    static let empty = OwnerTruthKBLiteCompatibilityGraph(facts: [])

    init(facts: [OwnerTruthKBLiteCompatibilityFact]) {
        self.facts = facts
    }

    init(backendJSONObject object: [String: Any]) throws {
        guard let people = object["people"] as? [Any], people.isEmpty,
              let places = object["places"] as? [Any], places.isEmpty,
              let events = object["events"] as? [Any], events.isEmpty,
              let factObjects = object["facts"] as? [[String: Any]] else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "graph must contain only an empty legacy shape and typed facts"
            )
        }
        facts = try factObjects.map(OwnerTruthKBLiteCompatibilityFact.init(backendJSONObject:))
    }

    var isEmpty: Bool {
        facts.isEmpty
    }

    var backendJSONObject: [String: Any] {
        [
            "people": [],
            "places": [],
            "events": [],
            "facts": facts.map(\.backendJSONObject),
        ]
    }
}

/// Typed parsing boundary for the only cacheable Owner Truth -> KBLite
/// compatibility response.  It fails closed before any data reaches disk.
struct OwnerTruthKBLiteCompatibilityReadEnvelope: Equatable, Sendable {
    static let schemaVersion = "owner-truth-kblite-read-envelope-v1"
    static let projectionSource = "v4"
    static let compatibilitySource = "owner-truth-memory-projection"

    let state: OwnerTruthKBLiteCompatibilityReadState
    let vaultID: OwnerTruthVaultID
    let ownerSubjectID: String
    let authorityEpoch: Int?
    let projectionCheckpoint: String?
    let cacheDisposition: OwnerTruthKBLiteCompatibilityCacheDisposition
    let contentHash: String?
    let graph: OwnerTruthKBLiteCompatibilityGraph

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String
    ) throws {
        let normalizedOwnerSubjectID = Self.nonEmptyString(expectedOwnerSubjectID)
        guard Self.nonEmptyString(object["schemaVersion"]) == Self.schemaVersion,
              Self.nonEmptyString(object["projectionSource"]) == Self.projectionSource,
              Self.nonEmptyString(object["compatibilitySource"]) == Self.compatibilitySource,
              Self.nonEmptyString(object["vaultId"]) == expectedVaultID.rawValue,
              let normalizedOwnerSubjectID,
              Self.nonEmptyString(object["ownerSubjectId"]) == normalizedOwnerSubjectID,
              let state = OwnerTruthKBLiteCompatibilityReadState(
                rawValue: Self.nonEmptyString(object["state"]) ?? ""
              ),
              let cacheDisposition = OwnerTruthKBLiteCompatibilityCacheDisposition(
                rawValue: Self.nonEmptyString(object["cacheDisposition"]) ?? ""
              ),
              let graphObject = object["graph"] as? [String: Any] else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "schema, owner, vault or graph does not match the contract"
            )
        }

        let graph = try OwnerTruthKBLiteCompatibilityGraph(backendJSONObject: graphObject)
        let authorityEpoch = try Self.optionalNonnegativeInt(object["authorityEpoch"])
        let projectionCheckpoint = try Self.optionalNonEmptyString(
            object["projectionCheckpoint"],
            field: "projectionCheckpoint"
        )
        let contentHash = try Self.optionalNonEmptyString(
            object["contentHash"],
            field: "contentHash"
        )

        switch state {
        case .ready:
            guard cacheDisposition == .replace,
                  authorityEpoch != nil,
                  projectionCheckpoint != nil,
                  let contentHash,
                  Self.isSHA256Digest(contentHash),
                  try Self.graphContentHash(graph) == contentHash else {
                throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                    "ready envelope integrity fields are invalid"
                )
            }
        case .disabled, .rebuilding:
            guard cacheDisposition == .discard,
                  projectionCheckpoint == nil,
                  contentHash == nil,
                  graph.isEmpty else {
                throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                    "non-ready envelope must discard an empty graph"
                )
            }
        }

        self.state = state
        self.vaultID = expectedVaultID
        self.ownerSubjectID = normalizedOwnerSubjectID
        self.authorityEpoch = authorityEpoch
        self.projectionCheckpoint = projectionCheckpoint
        self.cacheDisposition = cacheDisposition
        self.contentHash = contentHash
        self.graph = graph
    }

    static func graphContentHash(
        _ graph: OwnerTruthKBLiteCompatibilityGraph
    ) throws -> String {
        let object = graph.backendJSONObject
        guard JSONSerialization.isValidJSONObject(object) else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "graph cannot be canonicalized"
            )
        }
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func optionalNonEmptyString(_ value: Any?, field: String) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        guard let normalized = nonEmptyString(value) else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "\(field) must be a non-empty string or null"
            )
        }
        return normalized
    }

    private static func optionalNonnegativeInt(_ value: Any?) throws -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        guard !(value is Bool), let value = value as? Int, value >= 0 else {
            throw OwnerTruthRemoteContractError.invalidKBLiteCompatibilityReadEnvelope(
                "authorityEpoch must be a non-negative integer or null"
            )
        }
        return value
    }

    private static func isSHA256Digest(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit }
    }
}

struct OwnerTruthKBLiteCompatibilityCachedProjection: Codable, Equatable, Sendable {
    let projectionAuthorityEpoch: Int
    let projectionCheckpoint: String
    let contentHash: String
    let graph: OwnerTruthKBLiteCompatibilityGraph
}

enum OwnerTruthKBLiteCompatibilityCacheLoadResult: Equatable, Sendable {
    case ready(OwnerTruthKBLiteCompatibilityCachedProjection)
    case rebuilding
    case unavailable
}

/// Separate disk store for the QA compatibility cohort.  It never imports or
/// writes the legacy `kb_graph_<userId>.json` store.  A cache line is bound to
/// all account-lease identity fields so an A -> B -> A account transition
/// cannot revive the first account's projection.
final class OwnerTruthKBLiteCompatibilityStore {
    static let fileName = "owner_truth_kblite_compatibility_v1.json"

    private static let cacheSchemaVersion = "owner-truth-kblite-compatibility-cache-v1"

    private struct CacheEnvelope: Codable {
        let schemaVersion: String
        let subjectID: String
        let vaultID: String
        let sessionID: String
        let generation: UInt64
        let generationID: UUID
        let leaseAuthorityEpoch: String
        let projection: OwnerTruthKBLiteCompatibilityCachedProjection

        init(accountLease: AccountLease, projection: OwnerTruthKBLiteCompatibilityCachedProjection) {
            schemaVersion = OwnerTruthKBLiteCompatibilityStore.cacheSchemaVersion
            subjectID = accountLease.subjectId
            vaultID = accountLease.vaultId
            sessionID = accountLease.sessionId
            generation = accountLease.generation
            generationID = accountLease.generationId
            leaseAuthorityEpoch = accountLease.authorityEpoch
            self.projection = projection
        }

        func matches(_ accountLease: AccountLease) -> Bool {
            schemaVersion == OwnerTruthKBLiteCompatibilityStore.cacheSchemaVersion
                && subjectID == accountLease.subjectId
                && vaultID == accountLease.vaultId
                && sessionID == accountLease.sessionId
                && generation == accountLease.generation
                && generationID == accountLease.generationId
                && leaseAuthorityEpoch == accountLease.authorityEpoch
        }
    }

    private let directoryURL: URL
    private let fileManager: FileManager
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    @discardableResult
    func apply(
        _ envelope: OwnerTruthKBLiteCompatibilityReadEnvelope,
        for accountLease: AccountLease
    ) -> OwnerTruthKBLiteCompatibilityCacheLoadResult {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            discardCachedProjection()
            return .unavailable
        }
        guard envelope.vaultID.rawValue == accountLease.vaultId,
              envelope.ownerSubjectID == accountLease.subjectId else {
            discardCachedProjection()
            return .unavailable
        }
        guard envelope.state == .ready,
              envelope.cacheDisposition == .replace,
              let projectionAuthorityEpoch = envelope.authorityEpoch,
              let projectionCheckpoint = envelope.projectionCheckpoint,
              let contentHash = envelope.contentHash else {
            discardCachedProjection()
            return .rebuilding
        }

        let projection = OwnerTruthKBLiteCompatibilityCachedProjection(
            projectionAuthorityEpoch: projectionAuthorityEpoch,
            projectionCheckpoint: projectionCheckpoint,
            contentHash: contentHash,
            graph: envelope.graph
        )
        guard (try? OwnerTruthKBLiteCompatibilityReadEnvelope.graphContentHash(projection.graph))
            == projection.contentHash else {
            discardCachedProjection()
            return .rebuilding
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(CacheEnvelope(accountLease: accountLease, projection: projection))
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                discardCachedProjection()
                return .unavailable
            }
            try data.write(to: cacheURL, options: [.atomic])
            #if os(iOS)
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: cacheURL.path
            )
            #endif
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
                  accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                discardCachedProjection()
                return .unavailable
            }
            return .ready(projection)
        } catch {
            discardCachedProjection()
            return .rebuilding
        }
    }

    func load(for accountLease: AccountLease) -> OwnerTruthKBLiteCompatibilityCacheLoadResult {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            discardCachedProjection()
            return .unavailable
        }
        guard fileManager.fileExists(atPath: cacheURL.path) else {
            return .rebuilding
        }
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(CacheEnvelope.self, from: data),
              cache.matches(accountLease),
              (try? OwnerTruthKBLiteCompatibilityReadEnvelope.graphContentHash(cache.projection.graph))
                == cache.projection.contentHash,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            discardCachedProjection()
            return .rebuilding
        }
        return .ready(cache.projection)
    }

    func discardCachedProjection() {
        try? fileManager.removeItem(at: cacheURL)
    }

    private var cacheURL: URL {
        directoryURL.appendingPathComponent(Self.fileName, isDirectory: false)
    }
}

/// Narrow transport port for the default-off compatibility cohort.  The
/// concrete backend client authenticates the request and owns the QA header;
/// callers must still validate and scope the returned envelope through the
/// store above.
protocol OwnerTruthKBLiteCompatibilityClient: AnyObject {
    func fetchOwnerTruthKBLiteCompatibilityReadEnvelope(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        completion: @escaping (Result<OwnerTruthKBLiteCompatibilityReadEnvelope, Error>) -> Void
    )
}

// MARK: - Default-off Owner Truth Projection compatibility refresh

/// The compatibility cache is deliberately separate from the mutable legacy
/// KBLite graph. This use case is the only iOS path that may fetch and apply
/// the derived Owner Truth envelope, and it remains QA-only until a later
/// cutover work item explicitly promotes it.
enum OwnerTruthKBLiteCompatibilityProjectionPhase: Equatable, Sendable {
    case idle
    case loading
    case ready
    case rebuilding
    case unavailable
    case failed
}

enum OwnerTruthKBLiteCompatibilityProjectionNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case invalidVault
    case accountUnavailable
    case staleAccountLease
    case contractMismatch
    case requestFailed
}

/// Value-minimized state suitable for QA diagnostics. The compatibility facts
/// themselves remain only in the isolated cache and are never made UI state.
struct OwnerTruthKBLiteCompatibilityProjectionReadout: Equatable, Sendable {
    let authorityEpoch: Int
    let projectionCheckpoint: String
    let factCount: Int
}

struct OwnerTruthKBLiteCompatibilityProjectionViewState: Equatable, Sendable {
    let phase: OwnerTruthKBLiteCompatibilityProjectionPhase
    let readout: OwnerTruthKBLiteCompatibilityProjectionReadout?
    let notice: OwnerTruthKBLiteCompatibilityProjectionNotice?

    static let idle = OwnerTruthKBLiteCompatibilityProjectionViewState(
        phase: .idle,
        readout: nil,
        notice: nil
    )
}

/// Lease-fenced, default-off reader for the Owner Truth compatibility cache.
/// It does not call, mutate, merge with, or expose the legacy KBLite sync
/// graph. A stale request completion always discards the compatibility cache.
final class OwnerTruthKBLiteCompatibilityProjectionUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthKBLiteCompatibilityClient
    private let store: OwnerTruthKBLiteCompatibilityStore
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthKBLiteCompatibilityProjectionViewState = .idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthKBLiteCompatibilityProjectionViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthKBLiteCompatibilityClient,
        store: OwnerTruthKBLiteCompatibilityStore,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthKBLiteCompatibilityQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.store = store
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthKBLiteCompatibilityProjectionViewState(
            phase: .loading,
            readout: nil,
            notice: nil
        )
        client.fetchOwnerTruthKBLiteCompatibilityReadEnvelope(
            vaultID: vaultID,
            expectedOwnerSubjectID: accountLease.subjectId
        ) { [weak self] result in
            self?.receive(result, generation: generation)
        }
    }

    /// Cancels an in-flight QA read and removes its derived cache. Account
    /// lifecycle callers may use this before unmounting a private runtime.
    func invalidate() {
        operationGeneration &+= 1
        store.discardCachedProjection()
        viewState = OwnerTruthKBLiteCompatibilityProjectionViewState(
            phase: .unavailable,
            readout: nil,
            notice: .staleAccountLease
        )
    }

    /// Returns only a current cache line. Any lease or integrity mismatch is
    /// handled by the store as a destructive fail-closed cache discard.
    func loadCachedProjection() -> OwnerTruthKBLiteCompatibilityCacheLoadResult {
        guard qaGateEnabled(),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            store.discardCachedProjection()
            return .unavailable
        }
        return store.load(for: accountLease)
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            transitionUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            transitionUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            transitionUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthKBLiteCompatibilityReadEnvelope, Error>,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            store.discardCachedProjection()
            transitionUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            store.discardCachedProjection()
            transitionUnavailable(.staleAccountLease)
            return
        }

        switch result {
        case .success(let envelope):
            guard envelope.vaultID.rawValue == accountLease.vaultId,
                  envelope.ownerSubjectID == accountLease.subjectId else {
                store.discardCachedProjection()
                transitionFailure(.contractMismatch)
                return
            }
            switch store.apply(envelope, for: accountLease) {
            case .ready(let projection):
                viewState = OwnerTruthKBLiteCompatibilityProjectionViewState(
                    phase: .ready,
                    readout: OwnerTruthKBLiteCompatibilityProjectionReadout(
                        authorityEpoch: projection.projectionAuthorityEpoch,
                        projectionCheckpoint: projection.projectionCheckpoint,
                        factCount: projection.graph.facts.count
                    ),
                    notice: nil
                )
            case .rebuilding:
                viewState = OwnerTruthKBLiteCompatibilityProjectionViewState(
                    phase: .rebuilding,
                    readout: nil,
                    notice: nil
                )
            case .unavailable:
                transitionUnavailable(.staleAccountLease)
            }
        case .failure(let error):
            store.discardCachedProjection()
            if let contractError = error as? OwnerTruthRemoteContractError,
               case .invalidKBLiteCompatibilityReadEnvelope = contractError {
                transitionFailure(.contractMismatch)
            } else {
                transitionFailure(.requestFailed)
            }
        }
    }

    private func transitionUnavailable(
        _ notice: OwnerTruthKBLiteCompatibilityProjectionNotice
    ) {
        viewState = OwnerTruthKBLiteCompatibilityProjectionViewState(
            phase: .unavailable,
            readout: nil,
            notice: notice
        )
    }

    private func transitionFailure(
        _ notice: OwnerTruthKBLiteCompatibilityProjectionNotice
    ) {
        viewState = OwnerTruthKBLiteCompatibilityProjectionViewState(
            phase: .failed,
            readout: nil,
            notice: notice
        )
    }
}

/// Owns the lifetime of the default-off compatibility read inside the existing
/// knowledge-sync runtime. It is intentionally a shadow reader: mounting it
/// can refresh only the isolated Owner Truth cache and never applies a graph
/// to `KBLiteManager`, submits a legacy mutation, or selects an Echo context.
final class OwnerTruthKBLiteCompatibilityProjectionRuntime {
    private let client: OwnerTruthKBLiteCompatibilityClient
    private let directoryURL: URL
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var activeAccountLease: AccountLease?
    private var useCase: OwnerTruthKBLiteCompatibilityProjectionUseCase?

    init(
        client: OwnerTruthKBLiteCompatibilityClient,
        directoryURL: URL? = nil,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthKBLiteCompatibilityQAGate.isEnabled }
    ) {
        self.client = client
        self.directoryURL = directoryURL ?? Self.defaultDirectoryURL()
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    #if !SWIFT_PACKAGE
    convenience init(
        directoryURL: URL? = nil,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthKBLiteCompatibilityQAGate.isEnabled }
    ) {
        self.init(
            client: DreamJourneyBackendClient.shared,
            directoryURL: directoryURL,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: qaGateEnabled
        )
    }
    #endif

    var viewState: OwnerTruthKBLiteCompatibilityProjectionViewState {
        useCase?.viewState ?? .idle
    }

    /// Mounts the current private account and immediately performs a QA-only
    /// read. A different account lease first invalidates the old cache, so an
    /// A -> B transition cannot leave an A projection available to B.
    func mount(accountLease: AccountLease) {
        guard qaGateEnabled(),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            unmount()
            return
        }

        if activeAccountLease != accountLease {
            unmount()
            activeAccountLease = accountLease
            useCase = OwnerTruthKBLiteCompatibilityProjectionUseCase(
                accountLease: accountLease,
                client: client,
                store: OwnerTruthKBLiteCompatibilityStore(
                    directoryURL: directoryURL,
                    accountLeaseRuntime: accountLeaseRuntime
                ),
                accountLeaseRuntime: accountLeaseRuntime,
                qaGateEnabled: qaGateEnabled
            )
        }
        useCase?.refresh()
    }

    /// Must be called before account replacement, logout, suspension, or
    /// deletion. It advances the use-case generation and deletes the isolated
    /// cache; a late network completion is therefore a no-op.
    func unmount() {
        useCase?.invalidate()
        useCase = nil
        activeAccountLease = nil
    }

    private static func defaultDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return root.appendingPathComponent("owner_truth_kblite_compatibility", isDirectory: true)
    }
}

enum OwnerTruthCandidateReviewIntent: Equatable, Sendable {
    case refresh
    case accept(candidateID: OwnerTruthRecordID)
    case acceptBatch(candidateIDs: [OwnerTruthRecordID])
    case correct(
        candidateID: OwnerTruthRecordID,
        correctedPrimaryValue: String,
        correctedFacetValues: [OwnerTruthMemoryFacetKind: [String]]? = nil
    )
    case reject(candidateID: OwnerTruthRecordID)
}

enum OwnerTruthCandidateInboxPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case submitting(OwnerTruthRecordID)
    case submittingBatch(completedCount: Int, totalCount: Int)
    case failed
}

enum OwnerTruthCandidateInboxNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case accountUnavailable
    case staleAccountLease
    case invalidVault
    case candidateUnavailable
    case batchSelectionRequired
    case batchSelectionInvalid
    case correctionRequired
    case candidateSourceInactive
    case candidateVersionChanged
    case reviewResultMismatch
    case requestFailed
    case candidateAccepted
    case candidateCorrected
    case candidateRejected
    case batchAccepted(count: Int)
    case batchInterrupted(acceptedCount: Int)
}

struct OwnerTruthCandidateInboxItemViewState: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let proposalPreview: String
    let primaryField: OwnerTruthCandidatePrimaryField
    let primaryFieldTitle: String
    let primaryValue: String
    let memoryKind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let facetsState: OwnerTruthMemoryFacetsState
    let evidenceCount: Int
    let sourceReferences: [OwnerTruthCandidateSourceReferenceViewState]
    let reviewMode: String
    let candidateVersion: Int
    let supportsCorrection: Bool
    let supportsBatchAcceptance: Bool
}

struct OwnerTruthCandidateSourceReferenceViewState: Equatable, Sendable, Identifiable {
    let ordinal: Int
    let sourceVersion: Int
    let spanStart: Int?
    let spanEnd: Int?

    var id: Int { ordinal }
}

struct OwnerTruthCandidateReviewReceiptViewState: Equatable, Sendable {
    let candidateID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let outcome: OwnerTruthCommandOutcome
    let createdMemoryVersion: Bool
}

/// A batch is intentionally a sequence of per-Candidate server decisions.
/// It never claims that several Candidate receipts were committed atomically.
/// The remaining IDs are the only items the UI may offer for retry after a
/// network error, source invalidation, or version conflict.
struct OwnerTruthCandidateBatchReviewSummary: Equatable, Sendable {
    let requestedCandidateIDs: [OwnerTruthRecordID]
    let acceptedCandidateIDs: [OwnerTruthRecordID]
    let pendingCandidateIDs: [OwnerTruthRecordID]
    let failedCandidateID: OwnerTruthRecordID?

    var requestedCount: Int {
        requestedCandidateIDs.count
    }

    var acceptedCount: Int {
        acceptedCandidateIDs.count
    }
}

struct OwnerTruthCandidateInboxViewState: Equatable, Sendable {
    let phase: OwnerTruthCandidateInboxPhase
    let items: [OwnerTruthCandidateInboxItemViewState]
    let notice: OwnerTruthCandidateInboxNotice?
    let latestReceipt: OwnerTruthCandidateReviewReceiptViewState?
    let latestBatchSummary: OwnerTruthCandidateBatchReviewSummary?

    static let idle = OwnerTruthCandidateInboxViewState(
        phase: .idle,
        items: [],
        notice: nil,
        latestReceipt: nil,
        latestBatchSummary: nil
    )
}

/// Closed-pilot application boundary for Candidate review. It never accepts an
/// owner identifier from the UI, does not write legacy Archive/KBLite state,
/// and rejects stale account or stale async completion paths before ViewState
/// is updated.
final class OwnerTruthCandidateReviewUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthCandidateReviewClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private let commandIDFactory: CommandIDFactory
    /// Optional in-memory scope used when a processed media Source hands the
    /// owner into review. The server inbox remains authoritative; this only
    /// narrows the rendered Candidate set to that derived Source.
    private let sourceIDFilter: OwnerTruthRecordID?

    private var candidatesByID: [OwnerTruthRecordID: OwnerTruthCandidateInboxItem] = [:]
    private var orderedCandidateIDs: [OwnerTruthRecordID] = []
    // Commands remain stable for a pending batch retry in the same app
    // lifetime. They are never persisted; after a restart the server inbox is
    // authoritative and a 409 is explicitly surfaced instead of hidden.
    private var batchCommandIDsByCandidateID: [OwnerTruthRecordID: String] = [:]
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthCandidateInboxViewState = .idle {
        didSet {
            onViewStateChange?(viewState)
        }
    }

    var onViewStateChange: ((OwnerTruthCandidateInboxViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthCandidateReviewClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled },
        sourceIDFilter: OwnerTruthRecordID? = nil,
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.sourceIDFilter = sourceIDFilter
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthCandidateReviewIntent) {
        switch intent {
        case .refresh:
            refresh()
        case .accept(let candidateID):
            submit(candidateID: candidateID, action: .accept, correctedPrimaryValue: nil)
        case .acceptBatch(let candidateIDs):
            submitBatch(candidateIDs: candidateIDs)
        case .correct(let candidateID, let correctedPrimaryValue, let correctedFacetValues):
            submit(
                candidateID: candidateID,
                action: .correct,
                correctedPrimaryValue: correctedPrimaryValue,
                correctedFacetValues: correctedFacetValues
            )
        case .reject(let candidateID):
            submit(candidateID: candidateID, action: .reject, correctedPrimaryValue: nil)
        }
    }

    private func refresh() {
        guard let vaultID = beginRequestOrFail() else { return }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .loading,
            items: currentItems,
            notice: nil,
            latestReceipt: nil,
            latestBatchSummary: nil
        )
        client.fetchOwnerTruthCandidateInbox(vaultID: vaultID) { [weak self] result in
            self?.receiveInbox(result, vaultID: vaultID, generation: generation)
        }
    }

    private func submit(
        candidateID: OwnerTruthRecordID,
        action: OwnerTruthCandidateReviewAction,
        correctedPrimaryValue: String?,
        correctedFacetValues: [OwnerTruthMemoryFacetKind: [String]]? = nil
    ) {
        guard let vaultID = beginRequestOrFail() else { return }
        guard let candidate = candidatesByID[candidateID] else {
            transitionFailure(.candidateUnavailable)
            return
        }
        guard let command = makeCommand(
            candidate: candidate,
            action: action,
            correctedPrimaryValue: correctedPrimaryValue,
            correctedFacetValues: correctedFacetValues
        ) else {
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .submitting(candidateID),
            items: currentItems,
            notice: nil,
            latestReceipt: nil,
            latestBatchSummary: nil
        )
        client.reviewOwnerTruthCandidate(
            vaultID: vaultID,
            candidateID: candidateID,
            command: command
        ) { [weak self] result in
            self?.receiveDecision(
                result,
                candidate: candidate,
                expectedAction: action,
                generation: generation
            )
        }
    }

    private func submitBatch(candidateIDs: [OwnerTruthRecordID]) {
        guard let vaultID = beginRequestOrFail() else { return }

        let requestedIDs = orderedBatchCandidateIDs(from: candidateIDs)
        guard !requestedIDs.isEmpty else {
            transitionFailure(.batchSelectionRequired)
            return
        }
        guard requestedIDs.count == Set(candidateIDs).count,
              requestedIDs.allSatisfy({
                  guard let candidate = candidatesByID[$0] else { return false }
                  return Self.supportsBatchAcceptance(candidate)
              }) else {
            transitionFailure(.batchSelectionInvalid)
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        submitNextBatchCandidate(
            requestedCandidateIDs: requestedIDs,
            nextIndex: 0,
            acceptedCandidateIDs: [],
            latestReceipt: nil,
            vaultID: vaultID,
            generation: generation
        )
    }

    private func submitNextBatchCandidate(
        requestedCandidateIDs: [OwnerTruthRecordID],
        nextIndex: Int,
        acceptedCandidateIDs: [OwnerTruthRecordID],
        latestReceipt: OwnerTruthCandidateReviewReceiptViewState?,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard nextIndex < requestedCandidateIDs.count else {
            finishBatchSuccess(
                requestedCandidateIDs: requestedCandidateIDs,
                acceptedCandidateIDs: acceptedCandidateIDs,
                latestReceipt: latestReceipt
            )
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return
        }

        let candidateID = requestedCandidateIDs[nextIndex]
        guard let candidate = candidatesByID[candidateID],
              Self.supportsBatchAcceptance(candidate) else {
            finishBatchFailure(
                notice: .batchSelectionInvalid,
                requestedCandidateIDs: requestedCandidateIDs,
                acceptedCandidateIDs: acceptedCandidateIDs,
                failedCandidateID: candidateID,
                latestReceipt: latestReceipt
            )
            return
        }
        let commandID = batchCommandIDsByCandidateID[candidateID] ?? commandIDFactory()
        batchCommandIDsByCandidateID[candidateID] = commandID
        guard let command = makeCommand(
            candidate: candidate,
            action: .accept,
            correctedPrimaryValue: nil,
            commandID: commandID
        ) else {
            return
        }

        viewState = OwnerTruthCandidateInboxViewState(
            phase: .submittingBatch(
                completedCount: acceptedCandidateIDs.count,
                totalCount: requestedCandidateIDs.count
            ),
            items: currentItems,
            notice: nil,
            latestReceipt: latestReceipt,
            latestBatchSummary: batchSummary(
                requestedCandidateIDs: requestedCandidateIDs,
                acceptedCandidateIDs: acceptedCandidateIDs,
                failedCandidateID: nil
            )
        )
        client.reviewOwnerTruthCandidate(
            vaultID: vaultID,
            candidateID: candidateID,
            command: command
        ) { [weak self] result in
            self?.receiveBatchDecision(
                result,
                candidate: candidate,
                requestedCandidateIDs: requestedCandidateIDs,
                nextIndex: nextIndex,
                acceptedCandidateIDs: acceptedCandidateIDs,
                latestReceipt: latestReceipt,
                vaultID: vaultID,
                generation: generation
            )
        }
    }

    private func receiveBatchDecision(
        _ result: Result<OwnerTruthCandidateDecisionResult, Error>,
        candidate: OwnerTruthCandidateInboxItem,
        requestedCandidateIDs: [OwnerTruthRecordID],
        nextIndex: Int,
        acceptedCandidateIDs: [OwnerTruthRecordID],
        latestReceipt: OwnerTruthCandidateReviewReceiptViewState?,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let decision):
            guard decision.receipt.candidateID == candidate.id,
                  decision.receipt.decision == OwnerTruthCandidateDecision.accepted else {
                finishBatchFailure(
                    notice: .reviewResultMismatch,
                    requestedCandidateIDs: requestedCandidateIDs,
                    acceptedCandidateIDs: acceptedCandidateIDs,
                    failedCandidateID: candidate.id,
                    latestReceipt: latestReceipt
                )
                return
            }
            candidatesByID.removeValue(forKey: candidate.id)
            orderedCandidateIDs.removeAll { $0 == candidate.id }
            batchCommandIDsByCandidateID.removeValue(forKey: candidate.id)
            let receipt = Self.receiptViewState(from: decision)
            submitNextBatchCandidate(
                requestedCandidateIDs: requestedCandidateIDs,
                nextIndex: nextIndex + 1,
                acceptedCandidateIDs: acceptedCandidateIDs + [candidate.id],
                latestReceipt: receipt,
                vaultID: vaultID,
                generation: generation
            )
        case .failure(let error):
            finishBatchFailure(
                notice: Self.failureNotice(for: error),
                requestedCandidateIDs: requestedCandidateIDs,
                acceptedCandidateIDs: acceptedCandidateIDs,
                failedCandidateID: candidate.id,
                latestReceipt: latestReceipt
            )
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func makeCommand(
        candidate: OwnerTruthCandidateInboxItem,
        action: OwnerTruthCandidateReviewAction,
        correctedPrimaryValue: String?,
        correctedFacetValues: [OwnerTruthMemoryFacetKind: [String]]? = nil,
        commandID: String? = nil
    ) -> OwnerTruthCandidateReviewCommand? {
        do {
            let stableCommandID = commandID ?? commandIDFactory()
            switch action {
            case .accept:
                return try OwnerTruthCandidateReviewCommand(
                    commandID: stableCommandID,
                    expectedCandidateVersion: candidate.candidateVersion,
                    action: .accept,
                    reasonCode: "ownerReviewed"
                )
            case .reject:
                return try OwnerTruthCandidateReviewCommand(
                    commandID: stableCommandID,
                    expectedCandidateVersion: candidate.candidateVersion,
                    action: .reject,
                    reasonCode: "ownerReviewed"
                )
            case .correct:
                let normalizedValue = correctedPrimaryValue?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !normalizedValue.isEmpty else {
                    transitionFailure(.correctionRequired)
                    return nil
                }
                var correctedValue = candidate.content
                correctedValue[candidate.primaryField.rawValue] = .string(normalizedValue)
                if let correctedFacetValues {
                    guard case .available(let facets) = candidate.facetsState else {
                        transitionFailure(.requestFailed)
                        return nil
                    }
                    correctedValue["facets"] = facets.ownerCorrectedJSONValue(
                        valuesByKind: correctedFacetValues
                    )
                }
                return try OwnerTruthCandidateReviewCommand(
                    commandID: stableCommandID,
                    expectedCandidateVersion: candidate.candidateVersion,
                    action: .correct,
                    correctedValue: correctedValue,
                    correctedValueSchemaVersion: candidate.contentSchemaVersion,
                    reasonCode: "ownerCorrected"
                )
            }
        } catch {
            transitionFailure(.requestFailed)
            return nil
        }
    }

    private func receiveInbox(
        _ result: Result<OwnerTruthCandidateInbox, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return
        }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let inbox):
            guard inbox.vaultID == vaultID,
                  inbox.vaultID.rawValue == accountLease.vaultId else {
                transitionFailure(.requestFailed)
                return
            }
            let scopedCandidates = inbox.candidates.filter { candidate in
                guard let sourceIDFilter else { return true }
                return candidate.sourceID == sourceIDFilter
                    && candidate.sourceReferences.contains(where: { $0.sourceID == sourceIDFilter })
            }
            var nextCandidates: [OwnerTruthRecordID: OwnerTruthCandidateInboxItem] = [:]
            for candidate in scopedCandidates {
                guard nextCandidates[candidate.id] == nil else {
                    transitionFailure(.requestFailed)
                    return
                }
                nextCandidates[candidate.id] = candidate
            }
            let retainedBatchCommandIDs = batchCommandIDsByCandidateID.filter { candidateID, _ in
                guard let nextCandidate = nextCandidates[candidateID],
                      let previousCandidate = candidatesByID[candidateID] else {
                    return false
                }
                return nextCandidate.candidateVersion == previousCandidate.candidateVersion
            }
            candidatesByID = nextCandidates
            orderedCandidateIDs = scopedCandidates.map(\.id)
            batchCommandIDsByCandidateID = retainedBatchCommandIDs
            viewState = OwnerTruthCandidateInboxViewState(
                phase: scopedCandidates.isEmpty ? .empty : .ready,
                items: currentItems,
                notice: nil,
                latestReceipt: nil,
                latestBatchSummary: nil
            )
        case .failure(let error):
            transitionFailure(Self.failureNotice(for: error))
        }
    }

    private func receiveDecision(
        _ result: Result<OwnerTruthCandidateDecisionResult, Error>,
        candidate: OwnerTruthCandidateInboxItem,
        expectedAction: OwnerTruthCandidateReviewAction,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let decision):
            guard decision.receipt.candidateID == candidate.id,
                  decision.receipt.decision == expectedAction.terminalDecision else {
                transitionFailure(.reviewResultMismatch)
                return
            }
            candidatesByID.removeValue(forKey: candidate.id)
            orderedCandidateIDs.removeAll { $0 == candidate.id }
            let receipt = Self.receiptViewState(from: decision)
            viewState = OwnerTruthCandidateInboxViewState(
                phase: orderedCandidateIDs.isEmpty ? .empty : .ready,
                items: currentItems,
                notice: Self.successNotice(for: expectedAction),
                latestReceipt: receipt,
                latestBatchSummary: nil
            )
        case .failure(let error):
            transitionFailure(Self.failureNotice(for: error))
        }
    }

    private var currentItems: [OwnerTruthCandidateInboxItemViewState] {
        orderedCandidateIDs.compactMap { candidateID in
            guard let candidate = candidatesByID[candidateID] else { return nil }
            return OwnerTruthCandidateInboxItemViewState(
                id: candidate.id,
                proposalPreview: candidate.primaryValue,
                primaryField: candidate.primaryField,
                primaryFieldTitle: candidate.primaryField.title,
                primaryValue: candidate.primaryValue,
                memoryKind: candidate.memoryKind,
                perspective: candidate.perspective,
                epistemicStatus: candidate.epistemicStatus,
                sensitivity: candidate.sensitivity,
                facetsState: candidate.facetsState,
                evidenceCount: candidate.sourceReferences.count,
                sourceReferences: candidate.sourceReferences.enumerated().map { index, reference in
                    OwnerTruthCandidateSourceReferenceViewState(
                        ordinal: index + 1,
                        sourceVersion: reference.sourceVersion,
                        spanStart: reference.span?.start,
                        spanEnd: reference.span?.end
                    )
                },
                reviewMode: candidate.reviewMode,
                candidateVersion: candidate.candidateVersion,
                supportsCorrection: true,
                supportsBatchAcceptance: Self.supportsBatchAcceptance(candidate)
            )
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthCandidateInboxNotice) {
        operationGeneration &+= 1
        candidatesByID.removeAll()
        orderedCandidateIDs.removeAll()
        batchCommandIDsByCandidateID.removeAll()
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .unavailable,
            items: [],
            notice: notice,
            latestReceipt: nil,
            latestBatchSummary: nil
        )
    }

    private func transitionFailure(
        _ notice: OwnerTruthCandidateInboxNotice,
        latestReceipt: OwnerTruthCandidateReviewReceiptViewState? = nil,
        latestBatchSummary: OwnerTruthCandidateBatchReviewSummary? = nil
    ) {
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .failed,
            items: currentItems,
            notice: notice,
            latestReceipt: latestReceipt,
            latestBatchSummary: latestBatchSummary
        )
    }

    private func finishBatchSuccess(
        requestedCandidateIDs: [OwnerTruthRecordID],
        acceptedCandidateIDs: [OwnerTruthRecordID],
        latestReceipt: OwnerTruthCandidateReviewReceiptViewState?
    ) {
        let summary = batchSummary(
            requestedCandidateIDs: requestedCandidateIDs,
            acceptedCandidateIDs: acceptedCandidateIDs,
            failedCandidateID: nil
        )
        viewState = OwnerTruthCandidateInboxViewState(
            phase: orderedCandidateIDs.isEmpty ? .empty : .ready,
            items: currentItems,
            notice: .batchAccepted(count: acceptedCandidateIDs.count),
            latestReceipt: latestReceipt,
            latestBatchSummary: summary
        )
    }

    private func finishBatchFailure(
        notice: OwnerTruthCandidateInboxNotice,
        requestedCandidateIDs: [OwnerTruthRecordID],
        acceptedCandidateIDs: [OwnerTruthRecordID],
        failedCandidateID: OwnerTruthRecordID?,
        latestReceipt: OwnerTruthCandidateReviewReceiptViewState?
    ) {
        let normalizedNotice: OwnerTruthCandidateInboxNotice
        switch notice {
        case .requestFailed:
            normalizedNotice = .batchInterrupted(acceptedCount: acceptedCandidateIDs.count)
        default:
            normalizedNotice = notice
        }
        transitionFailure(
            normalizedNotice,
            latestReceipt: latestReceipt,
            latestBatchSummary: batchSummary(
                requestedCandidateIDs: requestedCandidateIDs,
                acceptedCandidateIDs: acceptedCandidateIDs,
                failedCandidateID: failedCandidateID
            )
        )
    }

    private func orderedBatchCandidateIDs(
        from candidateIDs: [OwnerTruthRecordID]
    ) -> [OwnerTruthRecordID] {
        let requestedIDs = Set(candidateIDs)
        return orderedCandidateIDs.filter { requestedIDs.contains($0) }
    }

    private func batchSummary(
        requestedCandidateIDs: [OwnerTruthRecordID],
        acceptedCandidateIDs: [OwnerTruthRecordID],
        failedCandidateID: OwnerTruthRecordID?
    ) -> OwnerTruthCandidateBatchReviewSummary {
        let acceptedIDs = Set(acceptedCandidateIDs)
        return OwnerTruthCandidateBatchReviewSummary(
            requestedCandidateIDs: requestedCandidateIDs,
            acceptedCandidateIDs: acceptedCandidateIDs,
            pendingCandidateIDs: requestedCandidateIDs.filter { !acceptedIDs.contains($0) },
            failedCandidateID: failedCandidateID
        )
    }

    private static func supportsBatchAcceptance(
        _ candidate: OwnerTruthCandidateInboxItem
    ) -> Bool {
        candidate.sensitivity == .standard && candidate.reviewMode == "batch"
    }

    private static func receiptViewState(
        from decision: OwnerTruthCandidateDecisionResult
    ) -> OwnerTruthCandidateReviewReceiptViewState {
        OwnerTruthCandidateReviewReceiptViewState(
            candidateID: decision.receipt.candidateID,
            decision: decision.receipt.decision,
            outcome: decision.outcome,
            createdMemoryVersion: decision.memoryActivation.memoryVersionID != nil
        )
    }

    private static func failureNotice(for error: Error) -> OwnerTruthCandidateInboxNotice {
        switch OwnerTruthCandidateReviewFailureDisposition(error: error) {
        case .releasePolicyDisabled:
            return .qaOnlyDisabled
        case .sourceInactive:
            return .candidateSourceInactive
        case .candidateVersionChanged:
            return .candidateVersionChanged
        case .retryable:
            return .requestFailed
        }
    }

    private static func successNotice(
        for action: OwnerTruthCandidateReviewAction
    ) -> OwnerTruthCandidateInboxNotice {
        switch action {
        case .accept:
            return .candidateAccepted
        case .correct:
            return .candidateCorrected
        case .reject:
            return .candidateRejected
        }
    }
}

private enum OwnerTruthCandidateReviewFailureDisposition {
    case releasePolicyDisabled
    case sourceInactive
    case candidateVersionChanged
    case retryable

    init(error: Error) {
        guard let clientError = error as? any OwnerTruthBackendFailureClassifying else {
            self = .retryable
            return
        }

        if clientError.ownerTruthFeaturePolicyDenied {
            self = .releasePolicyDisabled
        } else if clientError.ownerTruthBackendErrorCode == "release_policy_denied"
                    || clientError.ownerTruthBackendErrorCode == "ownerTruthCandidateReviewUnavailable" {
            self = .releasePolicyDisabled
        } else if clientError.ownerTruthBackendErrorCode == "ownerTruthCandidateSourceInactive" {
            self = .sourceInactive
        } else if clientError.ownerTruthBackendErrorCode == "ownerTruthCandidateVersionConflict"
                    || clientError.ownerTruthBackendStatusCode == 409 {
            self = .candidateVersionChanged
        } else {
            self = .retryable
        }
    }
}

enum OwnerTruthCandidateReviewHistoryPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case failed
}

struct OwnerTruthCandidateReviewHistoryItemViewState: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let proposalPreview: String
    let memoryKind: OwnerTruthMemoryKind
    let sensitivity: OwnerTruthSensitivityLevel
    let decision: OwnerTruthCandidateDecision
    let decidedAt: Date
    let memoryActivationStatus: OwnerTruthCandidateMemoryActivationStatus
    let memoryID: OwnerTruthRecordID?
    let sourceCount: Int
}

struct OwnerTruthCandidateReviewHistoryViewState: Equatable, Sendable {
    let phase: OwnerTruthCandidateReviewHistoryPhase
    let items: [OwnerTruthCandidateReviewHistoryItemViewState]

    static let idle = OwnerTruthCandidateReviewHistoryViewState(
        phase: .idle,
        items: []
    )
}

final class OwnerTruthCandidateReviewHistoryUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let client: OwnerTruthCandidateReviewClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState = OwnerTruthCandidateReviewHistoryViewState.idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthCandidateReviewHistoryViewState) -> Void)?

    init(
        accountLease: AccountLease,
        client: OwnerTruthCandidateReviewClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    func refresh() {
        guard qaGateEnabled(),
              let vaultID,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            operationGeneration &+= 1
            viewState = OwnerTruthCandidateReviewHistoryViewState(
                phase: .unavailable,
                items: []
            )
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthCandidateReviewHistoryViewState(
            phase: .loading,
            items: viewState.items
        )
        client.fetchOwnerTruthCandidateReviewHistory(vaultID: vaultID) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func receive(
        _ result: Result<OwnerTruthCandidateReviewHistory, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled(),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            operationGeneration &+= 1
            viewState = OwnerTruthCandidateReviewHistoryViewState(
                phase: .unavailable,
                items: []
            )
            return
        }
        switch result {
        case .success(let history):
            guard history.vaultID == vaultID,
                  history.vaultID.rawValue == accountLease.vaultId else {
                viewState = OwnerTruthCandidateReviewHistoryViewState(
                    phase: .failed,
                    items: []
                )
                return
            }
            let items = history.reviews.map(Self.makeViewState)
            viewState = OwnerTruthCandidateReviewHistoryViewState(
                phase: items.isEmpty ? .empty : .ready,
                items: items
            )
        case .failure:
            viewState = OwnerTruthCandidateReviewHistoryViewState(
                phase: .failed,
                items: viewState.items
            )
        }
    }

    private static func makeViewState(
        _ item: OwnerTruthCandidateReviewHistoryItem
    ) -> OwnerTruthCandidateReviewHistoryItemViewState {
        OwnerTruthCandidateReviewHistoryItemViewState(
            id: item.id,
            proposalPreview: proposalPreview(for: item.candidate),
            memoryKind: item.candidate.memoryKind,
            sensitivity: item.candidate.sensitivity,
            decision: item.decision,
            decidedAt: item.decidedAt,
            memoryActivationStatus: item.memoryActivation.status,
            memoryID: item.memoryActivation.memoryID,
            sourceCount: item.candidate.sourceReferences.count
        )
    }

    private static func proposalPreview(for candidate: OwnerTruthCandidateInboxItem) -> String {
        for key in ["summary", "title", "text", "claim", "label"] {
            guard case .string(let rawValue)? = candidate.content[key] else { continue }
            let normalized = rawValue
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return String(normalized.prefix(160))
            }
        }
        return "已审核记忆"
    }
}

enum OwnerTruthMemoryVersionHistoryPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case failed
}

struct OwnerTruthMemoryVersionHistoryItemViewState: Equatable, Sendable, Identifiable {
    let versionNumber: Int
    let status: OwnerTruthMemoryVersionHistoryStatus
    let decision: OwnerTruthCandidateDecision
    let summary: String
    let facetsState: OwnerTruthMemoryFacetsState
    let sourceCount: Int
    let createdAt: Date

    var id: Int { versionNumber }
}

struct OwnerTruthMemoryVersionHistoryViewState: Equatable, Sendable {
    let phase: OwnerTruthMemoryVersionHistoryPhase
    let memoryKind: OwnerTruthMemoryKind?
    let items: [OwnerTruthMemoryVersionHistoryItemViewState]

    static let idle = OwnerTruthMemoryVersionHistoryViewState(
        phase: .idle,
        memoryKind: nil,
        items: []
    )
}

final class OwnerTruthMemoryVersionHistoryUseCase {
    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let memoryID: OwnerTruthRecordID
    private let client: OwnerTruthCandidateReviewClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private var operationGeneration: UInt = 0

    private(set) var viewState = OwnerTruthMemoryVersionHistoryViewState.idle {
        didSet { onViewStateChange?(viewState) }
    }

    var onViewStateChange: ((OwnerTruthMemoryVersionHistoryViewState) -> Void)?

    init(
        accountLease: AccountLease,
        memoryID: OwnerTruthRecordID,
        client: OwnerTruthCandidateReviewClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.memoryID = memoryID
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
    }

    func refresh() {
        guard qaGateEnabled(),
              let vaultID,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            operationGeneration &+= 1
            viewState = OwnerTruthMemoryVersionHistoryViewState(
                phase: .unavailable,
                memoryKind: nil,
                items: []
            )
            return
        }
        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthMemoryVersionHistoryViewState(
            phase: .loading,
            memoryKind: viewState.memoryKind,
            items: viewState.items
        )
        client.fetchOwnerTruthMemoryVersionHistory(
            vaultID: vaultID,
            memoryID: memoryID
        ) { [weak self] result in
            self?.receive(result, vaultID: vaultID, generation: generation)
        }
    }

    private func receive(
        _ result: Result<OwnerTruthMemoryVersionHistory, Error>,
        vaultID: OwnerTruthVaultID,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard qaGateEnabled(),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            operationGeneration &+= 1
            viewState = OwnerTruthMemoryVersionHistoryViewState(
                phase: .unavailable,
                memoryKind: nil,
                items: []
            )
            return
        }
        switch result {
        case .success(let history):
            guard history.vaultID == vaultID,
                  history.vaultID.rawValue == accountLease.vaultId else {
                viewState = OwnerTruthMemoryVersionHistoryViewState(
                    phase: .failed,
                    memoryKind: nil,
                    items: []
                )
                return
            }
            viewState = OwnerTruthMemoryVersionHistoryViewState(
                phase: .ready,
                memoryKind: history.memoryKind,
                items: history.versions.map(Self.makeViewState)
            )
        case .failure:
            viewState = OwnerTruthMemoryVersionHistoryViewState(
                phase: .failed,
                memoryKind: viewState.memoryKind,
                items: viewState.items
            )
        }
    }

    private static func makeViewState(
        _ item: OwnerTruthMemoryVersionHistoryItem
    ) -> OwnerTruthMemoryVersionHistoryItemViewState {
        OwnerTruthMemoryVersionHistoryItemViewState(
            versionNumber: item.versionNumber,
            status: item.status,
            decision: item.decision,
            summary: summary(for: item.content),
            facetsState: item.facetsState,
            sourceCount: item.sourceCount,
            createdAt: item.createdAt
        )
    }

    private static func summary(for content: [String: OwnerTruthJSONValue]) -> String {
        for key in ["summary", "title", "text", "claim", "label"] {
            guard case .string(let rawValue)? = content[key] else { continue }
            let normalized = rawValue
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return String(normalized.prefix(240))
            }
        }
        return "正式记忆版本"
    }
}

struct OwnerTruthSourceReference: Codable, Equatable, Sendable {
    let vaultID: OwnerTruthVaultID
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int

    init(vaultID: OwnerTruthVaultID, sourceID: OwnerTruthRecordID, sourceVersion: Int) {
        self.vaultID = vaultID
        self.sourceID = sourceID
        self.sourceVersion = max(1, sourceVersion)
    }
}

struct OwnerTruthSource: Codable, Equatable, Sendable {
    let id: OwnerTruthRecordID
    let vaultID: OwnerTruthVaultID
    let ownerSubjectID: String
    let kind: OwnerTruthSourceKind
    let state: OwnerTruthSourceState
    let sourceVersion: Int
    let contentHash: String
    let policyVersion: String
    let authorityEpoch: Int

    init(
        id: OwnerTruthRecordID,
        vaultID: OwnerTruthVaultID,
        ownerSubjectID: String,
        kind: OwnerTruthSourceKind,
        state: OwnerTruthSourceState,
        sourceVersion: Int,
        contentHash: String,
        policyVersion: String,
        authorityEpoch: Int
    ) {
        self.id = id
        self.vaultID = vaultID
        self.ownerSubjectID = ownerSubjectID
        self.kind = kind
        self.state = state
        self.sourceVersion = max(1, sourceVersion)
        self.contentHash = contentHash
        self.policyVersion = policyVersion
        self.authorityEpoch = max(0, authorityEpoch)
    }
}

struct OwnerTruthMemoryRecord: Codable, Equatable, Sendable {
    let id: OwnerTruthRecordID
    let vaultID: OwnerTruthVaultID
    let ownerSubjectID: String
    let kind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let status: String
    let sourceReference: OwnerTruthSourceReference?
    let policyVersion: String
    let contentHash: String
    let authorityEpoch: Int
    let rowVersion: Int
}

struct OwnerTruthMemoryVersion: Codable, Equatable, Sendable {
    let id: OwnerTruthRecordID
    let vaultID: OwnerTruthVaultID
    let memoryID: OwnerTruthRecordID
    let versionNumber: Int
    let isCurrent: Bool
    let schemaVersion: String
    let contentHash: String
}

// MARK: - Default-off Owner QA Context / typed Citation

/// This shadow gate is separate from the public Context Packet and legacy
/// KBLite. It must never make the QA-only owner projection readable in a
/// release build.
enum OwnerTruthContextCitationQAGate {
    static let launchArgument = "DJEnableOwnerTruthContextCitationQA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        return false
        #endif
    }
}

/// Creating a correction Candidate is a state-changing Owner Truth operation.
/// Keep it behind a separate default-off switch from read-only Context/Citation
/// evidence, so enabling an evidence export cannot accidentally permit writes.
enum OwnerTruthCorrectionRequestQAGate {
    static let launchArgument = "DJEnableOwnerTruthCorrectionRequestQA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        return false
        #endif
    }
}

enum OwnerTruthContextShadowState: String, Codable, Equatable, Sendable {
    case disabled
    case rebuilding
    case ready
}

/// QA-only Context selection modes. The public Context Packet does not consume
/// either mode until the separate Owner Truth cutover gate is approved.
enum OwnerTruthContextSelectionMode: String, Codable, Equatable, Sendable {
    case projectionCitationOrder
    case deterministicTextFallback
}

enum OwnerTruthAnswerCitationOutcome: String, Codable, Equatable, Sendable {
    case created
    case deduplicated
}

private enum OwnerTruthContextCitationContract {
    static let projectionSource = "owner-truth-memory-projection"
    static let contextBuildResponseSchemaVersion = "owner-truth-context-shadow-build-response-v1"
    static let contextBuildSchemaVersion = "owner-truth-context-shadow-build-v1"
    static let contextCompareResponseSchemaVersion = "owner-truth-context-shadow-compare-response-v1"
    static let contextCompareSchemaVersion = "owner-truth-context-shadow-compare-v1"
    static let contextComparePolicyVersion = "owner-truth-context-shadow-compare-policy-v1"
    static let contextRequestCorrelationSchemaVersion = "echo-context-request-correlation-v1"
    static let contextVersion = "echo-context-v4-shadow"
    static let policyVersion = "owner-truth-context-shadow-build-policy-v1"
    static let answerCitationResponseSchemaVersion = "owner-truth-answer-citation-receipt-response-v1"
    static let answerCitationSchemaVersion = "owner-truth-answer-citation-v1"
    static let correctionRequestResponseSchemaVersion = "owner-truth-correction-request-response-v1"
    static let correctionRequestSchemaVersion = "owner-truth-correction-request-v1"
    static let correctionResolutionResponseSchemaVersion = "owner-truth-correction-resolution-response-v1"
    static let correctionResolutionSchemaVersion = "owner-truth-correction-resolution-v1"
    static let correctionRequestPendingReviewStatus = "pendingReview"
    static let correctionRequestMaximumTextScalars = 20_000
    static let citationResolution = "current_confirmed_projection_entry"
    static let defaultSelectionMode = OwnerTruthContextSelectionMode.projectionCitationOrder
    static let unavailableFallback = "owner_truth_context_unavailable_no_personal_memory"
    static let emptyFallback = "owner_truth_context_no_eligible_personal_memory"
    static let searchUnavailableFallback = "owner_truth_context_search_unavailable_no_personal_memory"
    static let queryNoMatchFallback = "owner_truth_context_no_query_match_no_personal_memory"

    /// A QA evidence response is citation-only. These fields would carry
    /// human-readable private content and are rejected at the mobile boundary.
    private static let rawContentKeys: Set<String> = [
        "answer",
        "answerText",
        "claim",
        "content",
        "correctionText",
        "memoryContent",
        "query",
        "statement",
        "summary",
        "text",
        "value",
    ]

    static func contextError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidContextCitationShadowBuild(detail)
    }

    static func contextCompareError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidContextCitationShadowCompare(detail)
    }

    static func receiptError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidAnswerCitationReceipt(detail)
    }

    static func correctionCommandError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidCorrectionRequestCommand(detail)
    }

    static func correctionReceiptError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidCorrectionRequestReceipt(detail)
    }

    static func correctionResolutionCommandError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidCorrectionResolutionCommand(detail)
    }

    static func correctionResolutionReceiptError(_ detail: String) -> OwnerTruthRemoteContractError {
        .invalidCorrectionResolutionReceipt(detail)
    }

    static func nonEmptyString(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String {
        guard let value = value as? String else {
            throw error("\(field) must be a non-empty string")
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw error("\(field) must be a non-empty string")
        }
        return normalized
    }

    static func optionalString(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return try nonEmptyString(value, field: field, error: error)
    }

    static func bool(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> Bool {
        guard let value = value as? Bool else {
            throw error("\(field) must be a Boolean")
        }
        return value
    }

    static func positiveInt(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> Int {
        guard let value = integer(value), value > 0 else {
            throw error("\(field) must be a positive integer")
        }
        return value
    }

    static func nonnegativeInt(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> Int {
        guard let value = integer(value), value >= 0 else {
            throw error("\(field) must be a non-negative integer")
        }
        return value
    }

    /// `JSONSerialization` exposes numeric JSON values as `NSNumber`. Keep the
    /// wire contract strict by accepting only finite, in-range integral values
    /// and rejecting Boolean and fractional numbers.
    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        let doubleValue = number.doubleValue
        guard doubleValue.isFinite,
              doubleValue.rounded(.towardZero) == doubleValue,
              number.compare(NSNumber(value: Int.min)) != .orderedAscending,
              number.compare(NSNumber(value: Int.max)) != .orderedDescending else {
            return nil
        }
        return number.intValue
    }

    static func optionalNonnegativeInt(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        return try nonnegativeInt(value, field: field, error: error)
    }

    static func object(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> [String: Any] {
        guard let value = value as? [String: Any] else {
            throw error("\(field) must be an object")
        }
        return value
    }

    static func objects(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> [[String: Any]] {
        guard let value = value as? [[String: Any]] else {
            throw error("\(field) must be an object array")
        }
        return value
    }

    static func strings(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> [String] {
        guard let value = value as? [String] else {
            throw error("\(field) must be a string array")
        }
        return try value.enumerated().map { index, value in
            try nonEmptyString(value, field: "\(field)[\(index)]", error: error)
        }
    }

    static func sha256(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String {
        let normalized = try nonEmptyString(value, field: field, error: error)
        guard normalized.count == 64,
              normalized == normalized.lowercased(),
              normalized.allSatisfy(\.isHexDigit) else {
            throw error("\(field) must be a lowercase sha256 digest")
        }
        return normalized
    }

    static func optionalSHA256(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return try sha256(value, field: field, error: error)
    }

    static func recordID(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> OwnerTruthRecordID {
        let rawValue = try nonEmptyString(value, field: field, error: error)
        guard let uuid = UUID(uuidString: rawValue) else {
            throw error("\(field) must be a UUID")
        }
        return OwnerTruthRecordID(rawValue: uuid)
    }

    static func digest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func normalizedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func scalarCount(_ value: String) -> Int {
        value.unicodeScalars.count
    }

    static func opaqueIdentifier(
        _ value: String,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String {
        let normalized = normalizedText(value)
        guard normalized.unicodeScalars.count <= 128,
              let first = normalized.unicodeScalars.first,
              isASCIIAlpha(first),
              normalized.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 45, 46, 58, 95, 48...57, 65...90, 97...122:
                      return true
                  default:
                      return false
                  }
              }) else {
            throw error("\(field) must be a bounded opaque identifier")
        }
        return normalized
    }

    static func correctionText(
        _ value: String,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String {
        let normalized = normalizedText(value)
        guard !normalized.isEmpty,
              scalarCount(normalized) <= correctionRequestMaximumTextScalars else {
            throw error("\(field) must be non-empty and within the QA evidence limit")
        }
        return normalized
    }

    static func ensureNoRawContent(
        _ object: [String: Any],
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws {
        for key in rawContentKeys where object[key] != nil && !(object[key] is NSNull) {
            throw error("\(field) contains prohibited raw field \(key)")
        }
    }

    static func ensureNoRawContentRecursively(
        _ value: Any,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws {
        if let object = value as? [String: Any] {
            try ensureNoRawContent(object, field: field, error: error)
            for (key, nestedValue) in object {
                try ensureNoRawContentRecursively(
                    nestedValue,
                    field: "\(field).\(key)",
                    error: error
                )
            }
        } else if let values = value as? [Any] {
            for (index, nestedValue) in values.enumerated() {
                try ensureNoRawContentRecursively(
                    nestedValue,
                    field: "\(field)[\(index)]",
                    error: error
                )
            }
        }
    }

    private static func isASCIIAlpha(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 65...90, 97...122:
            return true
        default:
            return false
        }
    }

    static func safeCode(
        _ value: Any?,
        field: String,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws -> String {
        let normalized = try nonEmptyString(value, field: field, error: error)
        guard normalized.count <= 160,
              normalized.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 45, 46, 58, 95, 48...57, 65...90, 97...122:
                      return true
                  default:
                      return false
                  }
              }) else {
            throw error("\(field) must be a bounded diagnostic code")
        }
        return normalized
    }
}

struct OwnerTruthContextCitation: Codable, Equatable, Sendable {
    let vaultID: OwnerTruthVaultID
    let memoryID: OwnerTruthRecordID
    let memoryVersionID: OwnerTruthRecordID
    let memoryVersion: Int
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int
    let contentHash: String

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        error: (String) -> OwnerTruthRemoteContractError = OwnerTruthContextCitationContract.contextError
    ) throws {
        try OwnerTruthContextCitationContract.ensureNoRawContent(
            object,
            field: "citation",
            error: error
        )
        let vaultID = try OwnerTruthContextCitationContract.nonEmptyString(
            object["vaultId"],
            field: "citation.vaultId",
            error: error
        )
        guard vaultID == expectedVaultID.rawValue else {
            throw error("citation.vaultId does not match the requested Vault")
        }
        self.vaultID = expectedVaultID
        self.memoryID = try OwnerTruthContextCitationContract.recordID(
            object["memoryId"],
            field: "citation.memoryId",
            error: error
        )
        self.memoryVersionID = try OwnerTruthContextCitationContract.recordID(
            object["memoryVersionId"],
            field: "citation.memoryVersionId",
            error: error
        )
        self.memoryVersion = try OwnerTruthContextCitationContract.positiveInt(
            object["memoryVersion"],
            field: "citation.memoryVersion",
            error: error
        )
        self.sourceID = try OwnerTruthContextCitationContract.recordID(
            object["sourceId"],
            field: "citation.sourceId",
            error: error
        )
        self.sourceVersion = try OwnerTruthContextCitationContract.positiveInt(
            object["sourceVersion"],
            field: "citation.sourceVersion",
            error: error
        )
        self.contentHash = try OwnerTruthContextCitationContract.sha256(
            object["contentHash"],
            field: "citation.contentHash",
            error: error
        )
    }

    var backendJSONObject: [String: Any] {
        [
            "vaultId": vaultID.rawValue,
            "memoryId": memoryID.rawValue.uuidString.lowercased(),
            "memoryVersionId": memoryVersionID.rawValue.uuidString.lowercased(),
            "memoryVersion": memoryVersion,
            "sourceId": sourceID.rawValue.uuidString.lowercased(),
            "sourceVersion": sourceVersion,
            "contentHash": contentHash,
        ]
    }
}

struct OwnerTruthContextSourceReference: Codable, Equatable, Sendable {
    let vaultID: OwnerTruthVaultID
    let sourceID: OwnerTruthRecordID
    let sourceVersion: Int

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        error: (String) -> OwnerTruthRemoteContractError = OwnerTruthContextCitationContract.contextError
    ) throws {
        try OwnerTruthContextCitationContract.ensureNoRawContent(
            object,
            field: "sourceRef",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["vaultId"],
            field: "sourceRef.vaultId",
            error: error
        ) == expectedVaultID.rawValue else {
            throw error("sourceRef.vaultId does not match the requested Vault")
        }
        self.vaultID = expectedVaultID
        self.sourceID = try OwnerTruthContextCitationContract.recordID(
            object["sourceId"],
            field: "sourceRef.sourceId",
            error: error
        )
        self.sourceVersion = try OwnerTruthContextCitationContract.positiveInt(
            object["sourceVersion"],
            field: "sourceRef.sourceVersion",
            error: error
        )
    }

    var backendJSONObject: [String: Any] {
        [
            "vaultId": vaultID.rawValue,
            "sourceId": sourceID.rawValue.uuidString.lowercased(),
            "sourceVersion": sourceVersion,
        ]
    }
}

struct OwnerTruthContextCitationRank: Codable, Equatable, Sendable {
    let position: Int
    let strategy: String

    init(backendJSONObject object: [String: Any]) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "rank", error: error)
        position = try OwnerTruthContextCitationContract.positiveInt(
            object["position"],
            field: "rank.position",
            error: error
        )
        guard let selectionMode = OwnerTruthContextSelectionMode(rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
            object["strategy"],
            field: "rank.strategy",
            error: error
        )) else {
            throw error("rank.strategy is not an approved Context selection mode")
        }
        strategy = selectionMode.rawValue
    }
}

struct OwnerTruthContextShadowItem: Codable, Equatable, Sendable, Identifiable {
    let source: String
    let refID: String
    let citation: OwnerTruthContextCitation
    let sourceReference: OwnerTruthContextSourceReference
    let reason: String
    let rank: OwnerTruthContextCitationRank?
    let memoryKind: String?
    let perspectiveType: String?
    let epistemicStatus: String?
    let sensitivity: String?
    let visibility: String?

    var id: String { refID }

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        requiresRank: Bool
    ) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "context item", error: error)
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["source"],
            field: "contextItem.source",
            error: error
        ) == OwnerTruthContextCitationContract.projectionSource else {
            throw error("contextItem.source is not the Owner Truth projection")
        }
        source = OwnerTruthContextCitationContract.projectionSource
        refID = try OwnerTruthContextCitationContract.nonEmptyString(
            object["refId"],
            field: "contextItem.refId",
            error: error
        )
        let citationObject = try OwnerTruthContextCitationContract.object(
            object["citation"],
            field: "contextItem.citation",
            error: error
        )
        let sourceReferenceObject = try OwnerTruthContextCitationContract.object(
            object["sourceRef"],
            field: "contextItem.sourceRef",
            error: error
        )
        citation = try OwnerTruthContextCitation(
            backendJSONObject: citationObject,
            expectedVaultID: expectedVaultID,
            error: error
        )
        sourceReference = try OwnerTruthContextSourceReference(
            backendJSONObject: sourceReferenceObject,
            expectedVaultID: expectedVaultID,
            error: error
        )
        guard sourceReference.sourceID == citation.sourceID,
              sourceReference.sourceVersion == citation.sourceVersion,
              refID == "memory-version:\(citation.memoryVersionID.rawValue.uuidString.lowercased())" else {
            throw error("context item citation/source reference identity does not match")
        }
        reason = try OwnerTruthContextCitationContract.safeCode(
            object["reason"],
            field: "contextItem.reason",
            error: error
        )
        if requiresRank {
            rank = try OwnerTruthContextCitationRank(
                backendJSONObject: OwnerTruthContextCitationContract.object(
                    object["rank"],
                    field: "contextItem.rank",
                    error: error
                )
            )
        } else {
            guard object["rank"] == nil || object["rank"] is NSNull else {
                throw error("filtered Context item must not carry a rank")
            }
            rank = nil
        }
        memoryKind = try Self.optionalDiagnosticCode(object["memoryKind"], field: "contextItem.memoryKind")
        perspectiveType = try Self.optionalDiagnosticCode(object["perspectiveType"], field: "contextItem.perspectiveType")
        epistemicStatus = try Self.optionalDiagnosticCode(object["epistemicStatus"], field: "contextItem.epistemicStatus")
        sensitivity = try Self.optionalDiagnosticCode(object["sensitivity"], field: "contextItem.sensitivity")
        visibility = try Self.optionalDiagnosticCode(object["visibility"], field: "contextItem.visibility")
    }

    private static func optionalDiagnosticCode(_ value: Any?, field: String) throws -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return try OwnerTruthContextCitationContract.safeCode(
            value,
            field: field,
            error: OwnerTruthContextCitationContract.contextError
        )
    }
}

struct OwnerTruthContextRankingTrace: Codable, Equatable, Sendable {
    let refID: String
    let source: String
    let selected: Bool
    let reason: String
    let rank: OwnerTruthContextCitationRank

    init(backendJSONObject object: [String: Any]) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "rankingTrace", error: error)
        refID = try OwnerTruthContextCitationContract.nonEmptyString(
            object["refId"],
            field: "rankingTrace.refId",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["source"],
            field: "rankingTrace.source",
            error: error
        ) == OwnerTruthContextCitationContract.projectionSource else {
            throw error("rankingTrace.source is not the Owner Truth projection")
        }
        source = OwnerTruthContextCitationContract.projectionSource
        selected = try OwnerTruthContextCitationContract.bool(
            object["selected"],
            field: "rankingTrace.selected",
            error: error
        )
        guard selected else {
            throw error("rankingTrace must only describe selected Context")
        }
        reason = try OwnerTruthContextCitationContract.safeCode(
            object["reason"],
            field: "rankingTrace.reason",
            error: error
        )
        rank = try OwnerTruthContextCitationRank(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                object["rank"],
                field: "rankingTrace.rank",
                error: error
            )
        )
    }
}

struct OwnerTruthContextCitationProof: Codable, Equatable, Sendable {
    let refID: String
    let source: String
    let resolved: Bool
    let resolution: String
    let citation: OwnerTruthContextCitation
    let sourceReference: OwnerTruthContextSourceReference

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "citationProof", error: error)
        refID = try OwnerTruthContextCitationContract.nonEmptyString(
            object["refId"],
            field: "citationProof.refId",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["source"],
            field: "citationProof.source",
            error: error
        ) == OwnerTruthContextCitationContract.projectionSource else {
            throw error("citationProof.source is not the Owner Truth projection")
        }
        source = OwnerTruthContextCitationContract.projectionSource
        resolved = try OwnerTruthContextCitationContract.bool(
            object["resolved"],
            field: "citationProof.resolved",
            error: error
        )
        guard resolved,
              try OwnerTruthContextCitationContract.nonEmptyString(
                object["resolution"],
                field: "citationProof.resolution",
                error: error
              ) == OwnerTruthContextCitationContract.citationResolution else {
            throw error("citationProof is not a resolved current projection entry")
        }
        resolution = OwnerTruthContextCitationContract.citationResolution
        citation = try OwnerTruthContextCitation(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                object["citation"],
                field: "citationProof.citation",
                error: error
            ),
            expectedVaultID: expectedVaultID,
            error: error
        )
        sourceReference = try OwnerTruthContextSourceReference(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                object["sourceRef"],
                field: "citationProof.sourceRef",
                error: error
            ),
            expectedVaultID: expectedVaultID,
            error: error
        )
        guard citation.sourceID == sourceReference.sourceID,
              citation.sourceVersion == sourceReference.sourceVersion else {
            throw error("citationProof source reference does not match citation")
        }
    }
}

struct OwnerTruthContextShadowRequestSummary: Codable, Equatable, Sendable {
    let intent: String
    let queryHash: String?
    let queryLength: Int
    let selectionMode: OwnerTruthContextSelectionMode

    init(
        backendJSONObject object: [String: Any],
        expectedIntent: String,
        expectedQuery: String,
        expectedSelectionMode: OwnerTruthContextSelectionMode
    ) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "context request", error: error)
        let normalizedIntent = OwnerTruthContextCitationContract.normalizedText(expectedIntent)
        let expectedIntent = normalizedIntent.isEmpty ? "echo_chat" : normalizedIntent
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["intent"],
            field: "request.intent",
            error: error
        ) == expectedIntent else {
            throw error("request.intent does not match the submitted intent")
        }
        intent = expectedIntent
        let normalizedQuery = OwnerTruthContextCitationContract.normalizedText(expectedQuery)
        queryHash = try OwnerTruthContextCitationContract.optionalSHA256(
            object["queryHash"],
            field: "request.queryHash",
            error: error
        )
        queryLength = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["queryLength"],
            field: "request.queryLength",
            error: error
        )
        let expectedLength = OwnerTruthContextCitationContract.scalarCount(normalizedQuery)
        guard queryLength == expectedLength else {
            throw error("request.queryLength does not match the submitted query")
        }
        let expectedHash = normalizedQuery.isEmpty
            ? nil
            : OwnerTruthContextCitationContract.digest(normalizedQuery)
        guard queryHash == expectedHash else {
            throw error("request.queryHash does not match the submitted query")
        }
        guard let selectionMode = OwnerTruthContextSelectionMode(rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
            object["selectionMode"],
            field: "request.selectionMode",
            error: error
        )), selectionMode == expectedSelectionMode else {
            throw error("request.selectionMode does not match the submitted selection mode")
        }
        self.selectionMode = selectionMode
    }
}

struct OwnerTruthContextShadowAuthority: Codable, Equatable, Sendable {
    let source: String
    let state: OwnerTruthContextShadowState
    let vaultID: OwnerTruthVaultID
    let authorityEpoch: Int?
    let projectionCheckpoint: String?

    init(backendJSONObject object: [String: Any], expectedVaultID: OwnerTruthVaultID) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "authority", error: error)
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["source"],
            field: "authority.source",
            error: error
        ) == OwnerTruthContextCitationContract.projectionSource,
        let state = OwnerTruthContextShadowState(
            rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
                object["state"],
                field: "authority.state",
                error: error
            )
        ),
        try OwnerTruthContextCitationContract.nonEmptyString(
            object["vaultId"],
            field: "authority.vaultId",
            error: error
        ) == expectedVaultID.rawValue else {
            throw error("authority source, state or Vault is invalid")
        }
        source = OwnerTruthContextCitationContract.projectionSource
        self.state = state
        vaultID = expectedVaultID
        authorityEpoch = try OwnerTruthContextCitationContract.optionalNonnegativeInt(
            object["authorityEpoch"],
            field: "authority.authorityEpoch",
            error: error
        )
        projectionCheckpoint = try OwnerTruthContextCitationContract.optionalSHA256(
            object["projectionCheckpoint"],
            field: "authority.projectionCheckpoint",
            error: error
        )
        if state == .ready, (authorityEpoch == nil || projectionCheckpoint == nil) {
            throw error("ready authority requires epoch and projection checkpoint")
        }
    }
}

struct OwnerTruthContextShadowBuild: Codable, Equatable, Sendable {
    let contextVersion: String
    let policyVersion: String
    let shadowOnly: Bool
    let legacyContextUnchanged: Bool
    let legacyContextRead: Bool
    let contextHash: String
    let request: OwnerTruthContextShadowRequestSummary
    let authority: OwnerTruthContextShadowAuthority
    let selectedContext: [OwnerTruthContextShadowItem]
    let filteredContext: [OwnerTruthContextShadowItem]
    let rankingTrace: [OwnerTruthContextRankingTrace]
    let citationProof: [OwnerTruthContextCitationProof]
    let selectedContextSourceCounts: [String: Int]
    let fallbacks: [String]

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID,
        expectedIntent: String,
        expectedQuery: String,
        expectedSelectionMode: OwnerTruthContextSelectionMode = .projectionCitationOrder
    ) throws {
        let error = OwnerTruthContextCitationContract.contextError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "context response", error: error)
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["schemaVersion"],
            field: "schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextBuildResponseSchemaVersion else {
            throw error("unexpected context response schemaVersion")
        }
        let shadow = try OwnerTruthContextCitationContract.object(
            object["contextShadow"],
            field: "contextShadow",
            error: error
        )
        try OwnerTruthContextCitationContract.ensureNoRawContent(shadow, field: "contextShadow", error: error)
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            shadow["schemaVersion"],
            field: "contextShadow.schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextBuildSchemaVersion,
        try OwnerTruthContextCitationContract.nonEmptyString(
            shadow["contextVersion"],
            field: "contextShadow.contextVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextVersion,
        try OwnerTruthContextCitationContract.nonEmptyString(
            shadow["policyVersion"],
            field: "contextShadow.policyVersion",
            error: error
        ) == OwnerTruthContextCitationContract.policyVersion else {
            throw error("contextShadow schema or policy version is not approved")
        }
        contextVersion = OwnerTruthContextCitationContract.contextVersion
        policyVersion = OwnerTruthContextCitationContract.policyVersion
        shadowOnly = try OwnerTruthContextCitationContract.bool(
            shadow["shadowOnly"],
            field: "contextShadow.shadowOnly",
            error: error
        )
        legacyContextUnchanged = try OwnerTruthContextCitationContract.bool(
            shadow["legacyContextUnchanged"],
            field: "contextShadow.legacyContextUnchanged",
            error: error
        )
        legacyContextRead = try OwnerTruthContextCitationContract.bool(
            shadow["legacyContextRead"],
            field: "contextShadow.legacyContextRead",
            error: error
        )
        guard shadowOnly, legacyContextUnchanged, !legacyContextRead else {
            throw error("Owner Truth Context QA must remain shadow-only and legacy-free")
        }
        contextHash = try OwnerTruthContextCitationContract.sha256(
            shadow["contextHash"],
            field: "contextShadow.contextHash",
            error: error
        )
        request = try OwnerTruthContextShadowRequestSummary(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                shadow["request"],
                field: "contextShadow.request",
                error: error
            ),
            expectedIntent: expectedIntent,
            expectedQuery: expectedQuery,
            expectedSelectionMode: expectedSelectionMode
        )
        authority = try OwnerTruthContextShadowAuthority(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                shadow["authority"],
                field: "contextShadow.authority",
                error: error
            ),
            expectedVaultID: expectedVaultID
        )
        selectedContext = try OwnerTruthContextCitationContract.objects(
            shadow["selectedContext"],
            field: "contextShadow.selectedContext",
            error: error
        ).map {
            try OwnerTruthContextShadowItem(
                backendJSONObject: $0,
                expectedVaultID: expectedVaultID,
                requiresRank: true
            )
        }
        filteredContext = try OwnerTruthContextCitationContract.objects(
            shadow["filteredContext"],
            field: "contextShadow.filteredContext",
            error: error
        ).map {
            try OwnerTruthContextShadowItem(
                backendJSONObject: $0,
                expectedVaultID: expectedVaultID,
                requiresRank: false
            )
        }
        rankingTrace = try OwnerTruthContextCitationContract.objects(
            shadow["rankingTrace"],
            field: "contextShadow.rankingTrace",
            error: error
        ).map(OwnerTruthContextRankingTrace.init(backendJSONObject:))
        citationProof = try OwnerTruthContextCitationContract.objects(
            shadow["citationProof"],
            field: "contextShadow.citationProof",
            error: error
        ).map {
            try OwnerTruthContextCitationProof(
                backendJSONObject: $0,
                expectedVaultID: expectedVaultID
            )
        }
        selectedContextSourceCounts = try Self.sourceCounts(
            shadow["selectedContextSourceCounts"],
            selectedContext: selectedContext
        )
        fallbacks = try OwnerTruthContextCitationContract.strings(
            shadow["fallbacks"],
            field: "contextShadow.fallbacks",
            error: error
        ).map {
            try OwnerTruthContextCitationContract.safeCode(
                $0,
                field: "contextShadow.fallback",
                error: error
            )
        }
        try Self.validateReferences(
            selectedContext: selectedContext,
            filteredContext: filteredContext,
            rankingTrace: rankingTrace,
            citationProof: citationProof,
            authority: authority,
            fallbacks: fallbacks,
            selectionMode: request.selectionMode
        )
        try Self.validateTraceCounts(
            shadow["trace"],
            selectedCount: selectedContext.count,
            filteredCount: filteredContext.count,
            rankingCount: rankingTrace.count,
            citationCount: citationProof.count,
            fallbackCount: fallbacks.count
        )
    }

    func traceSummary(
        receipt: OwnerTruthAnswerCitationReceipt? = nil
    ) -> OwnerTruthContextCitationTraceSummary {
        OwnerTruthContextCitationTraceSummary(context: self, receipt: receipt)
    }

    private static func sourceCounts(
        _ value: Any?,
        selectedContext: [OwnerTruthContextShadowItem]
    ) throws -> [String: Int] {
        let error = OwnerTruthContextCitationContract.contextError
        guard let object = value as? [String: Any] else {
            throw error("contextShadow.selectedContextSourceCounts must be a string/integer map")
        }
        var counts: [String: Int] = [:]
        for (source, rawCount) in object {
            let normalizedSource = try OwnerTruthContextCitationContract.safeCode(
                source,
                field: "contextShadow.selectedContextSourceCounts.source",
                error: error
            )
            counts[normalizedSource] = try OwnerTruthContextCitationContract.nonnegativeInt(
                rawCount,
                field: "contextShadow.selectedContextSourceCounts.\(normalizedSource)",
                error: error
            )
        }
        let expected = [OwnerTruthContextCitationContract.projectionSource: selectedContext.count]
        guard counts == expected else {
            throw error("selected Context source counts do not match typed Context")
        }
        return counts
    }

    private static func validateReferences(
        selectedContext: [OwnerTruthContextShadowItem],
        filteredContext: [OwnerTruthContextShadowItem],
        rankingTrace: [OwnerTruthContextRankingTrace],
        citationProof: [OwnerTruthContextCitationProof],
        authority: OwnerTruthContextShadowAuthority,
        fallbacks: [String],
        selectionMode: OwnerTruthContextSelectionMode
    ) throws {
        let error = OwnerTruthContextCitationContract.contextError
        let selectedByRef = Dictionary(uniqueKeysWithValues: selectedContext.map { ($0.refID, $0) })
        guard selectedByRef.count == selectedContext.count else {
            throw error("selected Context contains duplicate refs")
        }
        let filteredRefs = Set(filteredContext.map(\.refID))
        guard filteredRefs.count == filteredContext.count,
              filteredRefs.isDisjoint(with: Set(selectedByRef.keys)) else {
            throw error("selected and filtered Context refs must be disjoint")
        }
        guard rankingTrace.count == selectedContext.count,
              citationProof.count == selectedContext.count else {
            throw error("ranking and citation proof must cover every selected Context item")
        }
        let expectedPositions = Set(selectedContext.indices.map { $0 + 1 })
        let actualPositions = Set(rankingTrace.map(\.rank.position))
        guard actualPositions == expectedPositions else {
            throw error("ranking positions must form a deterministic sequence")
        }
        for trace in rankingTrace {
            guard let selected = selectedByRef[trace.refID],
                  trace.source == selected.source,
                  trace.reason == selected.reason,
                  trace.rank == selected.rank,
                  trace.rank.strategy == selectionMode.rawValue else {
                throw error("ranking trace does not match its selected Context item")
            }
        }
        for proof in citationProof {
            guard let selected = selectedByRef[proof.refID],
                  proof.source == selected.source,
                  proof.citation == selected.citation,
                  proof.sourceReference == selected.sourceReference else {
                throw error("citation proof does not match its selected Context item")
            }
        }
        switch authority.state {
        case .ready:
            if selectedContext.isEmpty {
                let allowedFallbacks: Set<String>
                switch selectionMode {
                case .projectionCitationOrder:
                    allowedFallbacks = [OwnerTruthContextCitationContract.emptyFallback]
                case .deterministicTextFallback:
                    allowedFallbacks = [
                        OwnerTruthContextCitationContract.emptyFallback,
                        OwnerTruthContextCitationContract.searchUnavailableFallback,
                        OwnerTruthContextCitationContract.queryNoMatchFallback,
                    ]
                }
                guard fallbacks.count == 1, let fallback = fallbacks.first,
                      allowedFallbacks.contains(fallback) else {
                    throw error("ready empty Context has an invalid fallback for its selection mode")
                }
            } else if !fallbacks.isEmpty {
                throw error("selected Context must not carry a fallback")
            }
        case .disabled, .rebuilding:
            guard selectedContext.isEmpty,
                  rankingTrace.isEmpty,
                  citationProof.isEmpty,
                  fallbacks == [OwnerTruthContextCitationContract.unavailableFallback] else {
                throw error("unavailable Context must fail closed without personal memory")
            }
        }
    }

    private static func validateTraceCounts(
        _ value: Any?,
        selectedCount: Int,
        filteredCount: Int,
        rankingCount: Int,
        citationCount: Int,
        fallbackCount: Int
    ) throws {
        let error = OwnerTruthContextCitationContract.contextError
        let trace = try OwnerTruthContextCitationContract.object(value, field: "contextShadow.trace", error: error)
        try OwnerTruthContextCitationContract.ensureNoRawContent(trace, field: "contextShadow.trace", error: error)
        let actual = [
            "selectedContextCount": selectedCount,
            "filteredContextCount": filteredCount,
            "rankingTraceCount": rankingCount,
            "citationProofCount": citationCount,
            "fallbackCount": fallbackCount,
        ]
        for (field, expected) in actual {
            guard try OwnerTruthContextCitationContract.nonnegativeInt(
                trace[field],
                field: "contextShadow.trace.\(field)",
                error: error
            ) == expected else {
                throw error("contextShadow.trace.\(field) does not match typed Context")
            }
        }
    }
}

/// The QA-only compare endpoint never exposes either Context body.  This
/// enum records whether the server observed a safe comparison, rather than
/// giving a client permission to switch Context authority.
enum OwnerTruthContextShadowCompareDisposition: String, Codable, Equatable, Sendable {
    case observed
    case requestMismatch = "request_mismatch"
    case v4TypedCitationIncomplete = "v4_typed_citation_incomplete"
    case v4NoPersonalMemory = "v4_no_personal_memory"
}

struct OwnerTruthContextShadowCompareRequestCorrelation: Codable, Equatable, Sendable {
    let intent: String
    let queryHash: String?
    let queryLength: Int

    init(
        backendJSONObject object: [String: Any],
        expectedIntent: String,
        expectedQuery: String
    ) throws {
        let error = OwnerTruthContextCitationContract.contextCompareError
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            object,
            field: "contextComparison.requestCorrelation",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["schemaVersion"],
            field: "contextComparison.requestCorrelation.schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextRequestCorrelationSchemaVersion else {
            throw error("request correlation schemaVersion is not approved")
        }
        intent = try OwnerTruthContextCitationContract.nonEmptyString(
            object["intent"],
            field: "contextComparison.requestCorrelation.intent",
            error: error
        )
        let normalizedExpectedIntent = OwnerTruthContextCitationContract.normalizedText(expectedIntent)
        guard intent == normalizedExpectedIntent else {
            throw error("request correlation intent does not match submitted request")
        }
        queryHash = try OwnerTruthContextCitationContract.optionalSHA256(
            object["queryHash"],
            field: "contextComparison.requestCorrelation.queryHash",
            error: error
        )
        queryLength = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["queryLength"],
            field: "contextComparison.requestCorrelation.queryLength",
            error: error
        )
        let normalizedExpectedQuery = OwnerTruthContextCitationContract.normalizedText(expectedQuery)
        let expectedHash = normalizedExpectedQuery.isEmpty
            ? nil
            : OwnerTruthContextCitationContract.digest(normalizedExpectedQuery)
        guard queryHash == expectedHash,
              queryLength == OwnerTruthContextCitationContract.scalarCount(normalizedExpectedQuery) else {
            throw error("request correlation does not match submitted query")
        }
    }
}

struct OwnerTruthContextShadowCompareLegacySummary: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let contextVersion: String
    let selectedContextCount: Int
    let filteredContextCount: Int
    let fallbackCount: Int

    init(backendJSONObject object: [String: Any]) throws {
        let error = OwnerTruthContextCitationContract.contextCompareError
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            object,
            field: "contextComparison.legacy",
            error: error
        )
        schemaVersion = try OwnerTruthContextCitationContract.positiveInt(
            object["schemaVersion"],
            field: "contextComparison.legacy.schemaVersion",
            error: error
        )
        contextVersion = try OwnerTruthContextCitationContract.safeCode(
            object["contextVersion"],
            field: "contextComparison.legacy.contextVersion",
            error: error
        )
        selectedContextCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["selectedContextCount"],
            field: "contextComparison.legacy.selectedContextCount",
            error: error
        )
        filteredContextCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["filteredContextCount"],
            field: "contextComparison.legacy.filteredContextCount",
            error: error
        )
        fallbackCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["fallbackCount"],
            field: "contextComparison.legacy.fallbackCount",
            error: error
        )
    }
}

struct OwnerTruthContextShadowCompareV4Summary: Codable, Equatable, Sendable {
    let schemaVersion: String
    let contextVersion: String
    let policyVersion: String
    let state: OwnerTruthContextShadowState
    let selectedContextCount: Int
    let filteredContextCount: Int
    let fallbackCount: Int
    let allSelectedItemsHaveTypedCitation: Bool
    let authorityEpochPresent: Bool
    let projectionCheckpointPresent: Bool

    init(backendJSONObject object: [String: Any]) throws {
        let error = OwnerTruthContextCitationContract.contextCompareError
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            object,
            field: "contextComparison.v4",
            error: error
        )
        let parsedSchemaVersion = try OwnerTruthContextCitationContract.safeCode(
            object["schemaVersion"],
            field: "contextComparison.v4.schemaVersion",
            error: error
        )
        let parsedContextVersion = try OwnerTruthContextCitationContract.safeCode(
            object["contextVersion"],
            field: "contextComparison.v4.contextVersion",
            error: error
        )
        let parsedPolicyVersion = try OwnerTruthContextCitationContract.safeCode(
            object["policyVersion"],
            field: "contextComparison.v4.policyVersion",
            error: error
        )
        guard parsedSchemaVersion == OwnerTruthContextCitationContract.contextBuildSchemaVersion,
              parsedContextVersion == OwnerTruthContextCitationContract.contextVersion,
              parsedPolicyVersion == OwnerTruthContextCitationContract.policyVersion else {
            throw error("V4 Context schema or policy version is not approved")
        }
        schemaVersion = parsedSchemaVersion
        contextVersion = parsedContextVersion
        policyVersion = parsedPolicyVersion
        guard let parsedState = OwnerTruthContextShadowState(rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
            object["state"],
            field: "contextComparison.v4.state",
            error: error
        )) else {
            throw error("V4 Context state is not approved")
        }
        state = parsedState
        selectedContextCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["selectedContextCount"],
            field: "contextComparison.v4.selectedContextCount",
            error: error
        )
        filteredContextCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["filteredContextCount"],
            field: "contextComparison.v4.filteredContextCount",
            error: error
        )
        fallbackCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            object["fallbackCount"],
            field: "contextComparison.v4.fallbackCount",
            error: error
        )
        allSelectedItemsHaveTypedCitation = try OwnerTruthContextCitationContract.bool(
            object["allSelectedItemsHaveTypedCitation"],
            field: "contextComparison.v4.allSelectedItemsHaveTypedCitation",
            error: error
        )
        authorityEpochPresent = try OwnerTruthContextCitationContract.bool(
            object["authorityEpochPresent"],
            field: "contextComparison.v4.authorityEpochPresent",
            error: error
        )
        projectionCheckpointPresent = try OwnerTruthContextCitationContract.bool(
            object["projectionCheckpointPresent"],
            field: "contextComparison.v4.projectionCheckpointPresent",
            error: error
        )
    }
}

/// A typed, value-free V1/V4 comparison. It is diagnostic evidence only;
/// neither this result nor any disposition may select a public Context writer.
struct OwnerTruthContextShadowCompare: Codable, Equatable, Sendable {
    let disposition: OwnerTruthContextShadowCompareDisposition
    let requestCorrelation: OwnerTruthContextShadowCompareRequestCorrelation
    let requestCorrelationMatches: Bool
    let legacy: OwnerTruthContextShadowCompareLegacySummary
    let v4: OwnerTruthContextShadowCompareV4Summary

    init(
        backendJSONObject object: [String: Any],
        expectedIntent: String,
        expectedQuery: String
    ) throws {
        let error = OwnerTruthContextCitationContract.contextCompareError
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            object,
            field: "context comparison response",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["schemaVersion"],
            field: "schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextCompareResponseSchemaVersion else {
            throw error("unexpected context comparison response schemaVersion")
        }
        let comparison = try OwnerTruthContextCitationContract.object(
            object["contextComparison"],
            field: "contextComparison",
            error: error
        )
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            comparison,
            field: "contextComparison",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            comparison["schemaVersion"],
            field: "contextComparison.schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextCompareSchemaVersion,
        try OwnerTruthContextCitationContract.nonEmptyString(
            comparison["policyVersion"],
            field: "contextComparison.policyVersion",
            error: error
        ) == OwnerTruthContextCitationContract.contextComparePolicyVersion else {
            throw error("context comparison schema or policy version is not approved")
        }
        guard try OwnerTruthContextCitationContract.bool(
            comparison["shadowOnly"],
            field: "contextComparison.shadowOnly",
            error: error
        ),
        try OwnerTruthContextCitationContract.bool(
            comparison["legacyContextUnchanged"],
            field: "contextComparison.legacyContextUnchanged",
            error: error
        ),
        try OwnerTruthContextCitationContract.bool(
            comparison["legacyContextRead"],
            field: "contextComparison.legacyContextRead",
            error: error
        ) else {
            throw error("context comparison must remain QA-only and legacy read-only")
        }
        guard let parsedDisposition = OwnerTruthContextShadowCompareDisposition(rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
            comparison["disposition"],
            field: "contextComparison.disposition",
            error: error
        )) else {
            throw error("context comparison disposition is not approved")
        }
        disposition = parsedDisposition
        requestCorrelation = try OwnerTruthContextShadowCompareRequestCorrelation(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                comparison["requestCorrelation"],
                field: "contextComparison.requestCorrelation",
                error: error
            ),
            expectedIntent: expectedIntent,
            expectedQuery: expectedQuery
        )
        requestCorrelationMatches = try OwnerTruthContextCitationContract.bool(
            comparison["requestCorrelationMatches"],
            field: "contextComparison.requestCorrelationMatches",
            error: error
        )
        legacy = try OwnerTruthContextShadowCompareLegacySummary(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                comparison["legacy"],
                field: "contextComparison.legacy",
                error: error
            )
        )
        v4 = try OwnerTruthContextShadowCompareV4Summary(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                comparison["v4"],
                field: "contextComparison.v4",
                error: error
            )
        )
        try Self.validate(disposition: disposition, requestCorrelationMatches: requestCorrelationMatches, v4: v4, error: error)
    }

    private static func validate(
        disposition: OwnerTruthContextShadowCompareDisposition,
        requestCorrelationMatches: Bool,
        v4: OwnerTruthContextShadowCompareV4Summary,
        error: (String) -> OwnerTruthRemoteContractError
    ) throws {
        guard requestCorrelationMatches == (disposition != .requestMismatch) else {
            throw error("request correlation flag and disposition disagree")
        }
        switch disposition {
        case .observed:
            guard v4.state == .ready,
                  v4.selectedContextCount > 0,
                  v4.allSelectedItemsHaveTypedCitation,
                  v4.authorityEpochPresent,
                  v4.projectionCheckpointPresent,
                  v4.fallbackCount == 0 else {
                throw error("observed comparison must have ready current V4 citations")
            }
        case .requestMismatch:
            break
        case .v4TypedCitationIncomplete:
            guard !v4.allSelectedItemsHaveTypedCitation else {
                throw error("typed citation disposition requires incomplete V4 citation")
            }
        case .v4NoPersonalMemory:
            guard v4.state != .ready || v4.selectedContextCount == 0 || v4.fallbackCount > 0 else {
                throw error("no-personal-memory disposition must not report ready selected Context")
            }
        }
    }
}

struct OwnerTruthAnswerCitation: Codable, Equatable, Sendable, Identifiable {
    let citationID: OwnerTruthRecordID
    let position: Int
    let resolved: Bool
    let resolution: String
    let citation: OwnerTruthContextCitation

    var id: OwnerTruthRecordID { citationID }

    init(
        backendJSONObject object: [String: Any],
        expectedVaultID: OwnerTruthVaultID
    ) throws {
        let error = OwnerTruthContextCitationContract.receiptError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "answerCitation.citation", error: error)
        citationID = try OwnerTruthContextCitationContract.recordID(
            object["citationId"],
            field: "answerCitation.citationId",
            error: error
        )
        position = try OwnerTruthContextCitationContract.positiveInt(
            object["position"],
            field: "answerCitation.position",
            error: error
        )
        resolved = try OwnerTruthContextCitationContract.bool(
            object["resolved"],
            field: "answerCitation.resolved",
            error: error
        )
        guard resolved,
              try OwnerTruthContextCitationContract.nonEmptyString(
                object["resolution"],
                field: "answerCitation.resolution",
                error: error
              ) == OwnerTruthContextCitationContract.citationResolution else {
            throw error("answer citation must resolve one current projection entry")
        }
        resolution = OwnerTruthContextCitationContract.citationResolution
        citation = try OwnerTruthContextCitation(
            backendJSONObject: OwnerTruthContextCitationContract.object(
                object["citation"],
                field: "answerCitation.citation",
                error: error
            ),
            expectedVaultID: expectedVaultID,
            error: error
        )
    }
}

struct OwnerTruthAnswerCitationReceipt: Codable, Equatable, Sendable {
    let outcome: OwnerTruthAnswerCitationOutcome
    let answerID: OwnerTruthRecordID
    let commandIDHash: String
    let contextHash: String
    let contextVersion: String
    let queryHash: String?
    let answerHash: String
    let answerLength: Int
    let authorityEpoch: Int?
    let projectionCheckpoint: String?
    let citations: [OwnerTruthAnswerCitation]
    let fallbacks: [String]

    init(
        backendJSONObject object: [String: Any],
        expectedContext: OwnerTruthContextShadowBuild,
        expectedCommandID: String,
        expectedQuery: String,
        expectedAnswerText: String
    ) throws {
        let error = OwnerTruthContextCitationContract.receiptError
        try OwnerTruthContextCitationContract.ensureNoRawContent(object, field: "answer citation response", error: error)
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["schemaVersion"],
            field: "schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.answerCitationResponseSchemaVersion,
        let outcome = OwnerTruthAnswerCitationOutcome(
            rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
                object["status"],
                field: "status",
                error: error
            )
        ) else {
            throw error("answer citation response schemaVersion or status is invalid")
        }
        let receipt = try OwnerTruthContextCitationContract.object(
            object["answerCitation"],
            field: "answerCitation",
            error: error
        )
        try OwnerTruthContextCitationContract.ensureNoRawContent(receipt, field: "answerCitation", error: error)
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            receipt["schemaVersion"],
            field: "answerCitation.schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.answerCitationSchemaVersion,
        try OwnerTruthContextCitationContract.nonEmptyString(
            receipt["outcome"],
            field: "answerCitation.outcome",
            error: error
        ) == outcome.rawValue else {
            throw error("answerCitation schemaVersion or outcome is invalid")
        }
        self.outcome = outcome
        answerID = try OwnerTruthContextCitationContract.recordID(
            receipt["answerId"],
            field: "answerCitation.answerId",
            error: error
        )
        commandIDHash = try OwnerTruthContextCitationContract.sha256(
            receipt["commandIdHash"],
            field: "answerCitation.commandIdHash",
            error: error
        )
        let normalizedCommandID = OwnerTruthContextCitationContract.normalizedText(expectedCommandID)
        guard !normalizedCommandID.isEmpty,
              commandIDHash == OwnerTruthContextCitationContract.digest(normalizedCommandID) else {
            throw error("answerCitation.commandIdHash does not match the submitted command")
        }
        contextHash = try OwnerTruthContextCitationContract.sha256(
            receipt["contextHash"],
            field: "answerCitation.contextHash",
            error: error
        )
        guard contextHash == expectedContext.contextHash else {
            throw error("answerCitation.contextHash does not match the selected Context")
        }
        contextVersion = try OwnerTruthContextCitationContract.nonEmptyString(
            receipt["contextVersion"],
            field: "answerCitation.contextVersion",
            error: error
        )
        guard contextVersion == expectedContext.contextVersion else {
            throw error("answerCitation.contextVersion does not match the selected Context")
        }
        queryHash = try OwnerTruthContextCitationContract.optionalSHA256(
            receipt["queryHash"],
            field: "answerCitation.queryHash",
            error: error
        )
        let normalizedQuery = OwnerTruthContextCitationContract.normalizedText(expectedQuery)
        let expectedQueryHash = normalizedQuery.isEmpty
            ? nil
            : OwnerTruthContextCitationContract.digest(normalizedQuery)
        guard queryHash == expectedQueryHash, queryHash == expectedContext.request.queryHash else {
            throw error("answerCitation.queryHash does not match the selected Context request")
        }
        answerHash = try OwnerTruthContextCitationContract.sha256(
            receipt["answerHash"],
            field: "answerCitation.answerHash",
            error: error
        )
        let normalizedAnswer = OwnerTruthContextCitationContract.normalizedText(expectedAnswerText)
        guard !normalizedAnswer.isEmpty,
              answerHash == OwnerTruthContextCitationContract.digest(normalizedAnswer) else {
            throw error("answerCitation.answerHash does not match the submitted answer")
        }
        answerLength = try OwnerTruthContextCitationContract.nonnegativeInt(
            receipt["answerLength"],
            field: "answerCitation.answerLength",
            error: error
        )
        guard answerLength == OwnerTruthContextCitationContract.scalarCount(normalizedAnswer) else {
            throw error("answerCitation.answerLength does not match the submitted answer")
        }
        authorityEpoch = try OwnerTruthContextCitationContract.optionalNonnegativeInt(
            receipt["authorityEpoch"],
            field: "answerCitation.authorityEpoch",
            error: error
        )
        projectionCheckpoint = try OwnerTruthContextCitationContract.optionalSHA256(
            receipt["projectionCheckpoint"],
            field: "answerCitation.projectionCheckpoint",
            error: error
        )
        guard authorityEpoch == expectedContext.authority.authorityEpoch,
              projectionCheckpoint == expectedContext.authority.projectionCheckpoint else {
            throw error("answerCitation authority does not match the selected Context")
        }
        let expectedVaultID = expectedContext.authority.vaultID
        citations = try OwnerTruthContextCitationContract.objects(
            receipt["citations"],
            field: "answerCitation.citations",
            error: error
        ).map {
            try OwnerTruthAnswerCitation(
                backendJSONObject: $0,
                expectedVaultID: expectedVaultID
            )
        }
        let citationCount = try OwnerTruthContextCitationContract.nonnegativeInt(
            receipt["citationCount"],
            field: "answerCitation.citationCount",
            error: error
        )
        guard citationCount == citations.count,
              citationCount == expectedContext.selectedContext.count else {
            throw error("answerCitation.citationCount does not cover the selected Context")
        }
        fallbacks = try OwnerTruthContextCitationContract.strings(
            receipt["fallbacks"],
            field: "answerCitation.fallbacks",
            error: error
        ).map {
            try OwnerTruthContextCitationContract.safeCode(
                $0,
                field: "answerCitation.fallback",
                error: error
            )
        }
        guard fallbacks == expectedContext.fallbacks else {
            throw error("answerCitation fallbacks do not match the selected Context")
        }
        let expectedCitations = Dictionary(
            uniqueKeysWithValues: expectedContext.selectedContext.enumerated().map {
                ($0.offset + 1, $0.element.citation)
            }
        )
        let actualPositions = Set(citations.map(\.position))
        guard actualPositions == Set(expectedCitations.keys),
              Set(citations.map(\.citationID)).count == citations.count else {
            throw error("answer citations have duplicate or missing positions")
        }
        for citation in citations {
            guard expectedCitations[citation.position] == citation.citation else {
                throw error("answer citation does not resolve the selected MemoryVersion")
            }
        }
    }
}

enum OwnerTruthCorrectionRequestOutcome: String, Codable, Equatable, Sendable {
    case created
    case deduplicated
}

enum OwnerTruthCorrectionRequestStatus: String, Codable, Equatable, Sendable {
    case pendingReview
}

/// One QA-only correction request derived from a citation already verified in
/// an immutable Owner Truth answer receipt. The raw correction text exists
/// only long enough to construct the backend request; it is never copied into
/// a receipt or QA readout.
struct OwnerTruthCorrectionRequestCommand: Equatable, Sendable {
    let commandID: String
    let vaultID: OwnerTruthVaultID
    let answerID: OwnerTruthRecordID
    let citationID: OwnerTruthRecordID
    let memoryID: OwnerTruthRecordID
    let expectedMemoryVersionID: OwnerTruthRecordID
    let correctionText: String
    let reasonCode: String

    init(
        commandID: String,
        answerCitationReceipt: OwnerTruthAnswerCitationReceipt,
        citationID: OwnerTruthRecordID,
        correctionText: String,
        reasonCode: String
    ) throws {
        let error = OwnerTruthContextCitationContract.correctionCommandError
        let normalizedCommandID = try OwnerTruthContextCitationContract.opaqueIdentifier(
            commandID,
            field: "commandId",
            error: error
        )
        let normalizedReasonCode = try OwnerTruthContextCitationContract.opaqueIdentifier(
            reasonCode,
            field: "reasonCode",
            error: error
        )
        let normalizedCorrectionText = try OwnerTruthContextCitationContract.correctionText(
            correctionText,
            field: "correctionText",
            error: error
        )
        guard let citation = answerCitationReceipt.citations.first(where: { $0.citationID == citationID }),
              citation.resolved,
              citation.resolution == OwnerTruthContextCitationContract.citationResolution else {
            throw error("citationId must belong to the verified answer receipt")
        }

        self.commandID = normalizedCommandID
        vaultID = citation.citation.vaultID
        answerID = answerCitationReceipt.answerID
        self.citationID = citation.citationID
        memoryID = citation.citation.memoryID
        expectedMemoryVersionID = citation.citation.memoryVersionID
        self.correctionText = normalizedCorrectionText
        self.reasonCode = normalizedReasonCode
    }

    init(
        commandID: String,
        receipt: OwnerTruthAnswerCitationReceipt,
        citationID: OwnerTruthRecordID,
        correctionText: String,
        reasonCode: String
    ) throws {
        try self.init(
            commandID: commandID,
            answerCitationReceipt: receipt,
            citationID: citationID,
            correctionText: correctionText,
            reasonCode: reasonCode
        )
    }

    var correctionTextHash: String {
        OwnerTruthContextCitationContract.digest(correctionText)
    }

    var correctionTextLength: Int {
        OwnerTruthContextCitationContract.scalarCount(correctionText)
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "answerId": answerID.rawValue.uuidString.lowercased(),
            "citationId": citationID.rawValue.uuidString.lowercased(),
            "expectedMemoryVersionId": expectedMemoryVersionID.rawValue.uuidString.lowercased(),
            "correctionText": correctionText,
            "reasonCode": reasonCode,
        ]
    }

    var backendJSONObject: [String: Any] {
        backendPayload
    }
}

/// A value-free confirmation that a correction has entered pending review. The
/// Vault is carried forward only from the verified request command; the private
/// correction Source, answer text and memory contents are never represented in
/// this mobile-domain receipt.
struct OwnerTruthCorrectionRequestReceipt: Codable, Equatable, Sendable {
    let outcome: OwnerTruthCorrectionRequestOutcome
    let vaultID: OwnerTruthVaultID
    let correctionRequestID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let candidateVersion: Int
    let answerID: OwnerTruthRecordID
    let citationID: OwnerTruthRecordID
    let memoryID: OwnerTruthRecordID
    let expectedMemoryVersionID: OwnerTruthRecordID
    let correctionSourceID: OwnerTruthRecordID
    let correctionTextHash: String
    let correctionTextLength: Int
    let status: OwnerTruthCorrectionRequestStatus

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthCorrectionRequestCommand
    ) throws {
        let error = OwnerTruthContextCitationContract.correctionReceiptError
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            object,
            field: "correction request response",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["schemaVersion"],
            field: "schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.correctionRequestResponseSchemaVersion,
        let outcome = OwnerTruthCorrectionRequestOutcome(
            rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
                object["status"],
                field: "status",
                error: error
            )
        ) else {
            throw error("correction request response schemaVersion or status is invalid")
        }
        let request = try OwnerTruthContextCitationContract.object(
            object["correctionRequest"],
            field: "correctionRequest",
            error: error
        )
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            request,
            field: "correctionRequest",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            request["schemaVersion"],
            field: "correctionRequest.schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.correctionRequestSchemaVersion,
        try OwnerTruthContextCitationContract.nonEmptyString(
            request["outcome"],
            field: "correctionRequest.outcome",
            error: error
        ) == outcome.rawValue else {
            throw error("correctionRequest schemaVersion or outcome is invalid")
        }

        self.outcome = outcome
        vaultID = expectedCommand.vaultID
        correctionRequestID = try OwnerTruthContextCitationContract.recordID(
            request["correctionRequestId"],
            field: "correctionRequest.correctionRequestId",
            error: error
        )
        candidateID = try OwnerTruthContextCitationContract.recordID(
            request["candidateId"],
            field: "correctionRequest.candidateId",
            error: error
        )
        candidateVersion = try OwnerTruthContextCitationContract.positiveInt(
            request["candidateVersion"],
            field: "correctionRequest.candidateVersion",
            error: error
        )
        answerID = try OwnerTruthContextCitationContract.recordID(
            request["answerId"],
            field: "correctionRequest.answerId",
            error: error
        )
        citationID = try OwnerTruthContextCitationContract.recordID(
            request["citationId"],
            field: "correctionRequest.citationId",
            error: error
        )
        memoryID = try OwnerTruthContextCitationContract.recordID(
            request["memoryId"],
            field: "correctionRequest.memoryId",
            error: error
        )
        expectedMemoryVersionID = try OwnerTruthContextCitationContract.recordID(
            request["expectedMemoryVersionId"],
            field: "correctionRequest.expectedMemoryVersionId",
            error: error
        )
        correctionSourceID = try OwnerTruthContextCitationContract.recordID(
            request["correctionSourceId"],
            field: "correctionRequest.correctionSourceId",
            error: error
        )
        correctionTextHash = try OwnerTruthContextCitationContract.sha256(
            request["correctionTextHash"],
            field: "correctionRequest.correctionTextHash",
            error: error
        )
        correctionTextLength = try OwnerTruthContextCitationContract.nonnegativeInt(
            request["correctionTextLength"],
            field: "correctionRequest.correctionTextLength",
            error: error
        )
        guard let status = OwnerTruthCorrectionRequestStatus(
            rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
                request["status"],
                field: "correctionRequest.status",
                error: error
            )
        ), status.rawValue == OwnerTruthContextCitationContract.correctionRequestPendingReviewStatus else {
            throw error("correctionRequest.status must remain pendingReview")
        }
        self.status = status

        guard answerID == expectedCommand.answerID,
              citationID == expectedCommand.citationID,
              memoryID == expectedCommand.memoryID,
              expectedMemoryVersionID == expectedCommand.expectedMemoryVersionID else {
            throw error("correctionRequest identity does not match the submitted citation command")
        }
        guard correctionTextHash == expectedCommand.correctionTextHash,
              correctionTextLength == expectedCommand.correctionTextLength else {
            throw error("correctionRequest correction text integrity does not match the submitted command")
        }
    }
}

/// The correction resolver deliberately excludes generic candidate acceptance.
/// A correction either supersedes the cited MemoryVersion or rejects the pending
/// Candidate without changing memory authority.
enum OwnerTruthCorrectionResolutionAction: String, CaseIterable, Codable, Sendable {
    case correct
    case reject

    var terminalDecision: OwnerTruthCandidateDecision {
        switch self {
        case .correct:
            return .corrected
        case .reject:
            return .rejected
        }
    }
}

enum OwnerTruthCorrectionResolutionOutcome: String, Codable, Equatable, Sendable {
    case created
    case deduplicated
}

/// A terminal, QA-only decision bound to one pending correction request. Raw
/// corrected values are retained only while constructing the transport payload;
/// no value is copied into a receipt or view state.
struct OwnerTruthCorrectionResolutionCommand: Equatable, Sendable {
    let commandID: String
    let vaultID: OwnerTruthVaultID
    let correctionRequestID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let expectedCandidateVersion: Int
    let expectedMemoryVersionID: OwnerTruthRecordID
    let action: OwnerTruthCorrectionResolutionAction
    let correctedValue: [String: OwnerTruthJSONValue]?
    let correctedValueSchemaVersion: String?
    let reasonCode: String

    init(
        commandID: String,
        correctionRequestReceipt: OwnerTruthCorrectionRequestReceipt,
        action: OwnerTruthCorrectionResolutionAction,
        correctedValue: [String: OwnerTruthJSONValue]? = nil,
        correctedValueSchemaVersion: String? = nil,
        reasonCode: String
    ) throws {
        let error = OwnerTruthContextCitationContract.correctionResolutionCommandError
        let normalizedCommandID = try OwnerTruthContextCitationContract.opaqueIdentifier(
            commandID,
            field: "commandId",
            error: error
        )
        let normalizedReasonCode = try OwnerTruthContextCitationContract.opaqueIdentifier(
            reasonCode,
            field: "reasonCode",
            error: error
        )
        let normalizedSchemaVersion = correctedValueSchemaVersion.map(
            OwnerTruthContextCitationContract.normalizedText
        )

        switch action {
        case .correct:
            guard let correctedValue, !correctedValue.isEmpty,
                  let normalizedSchemaVersion, !normalizedSchemaVersion.isEmpty else {
                throw error("correct requires correctedValue and correctedValueSchemaVersion")
            }
            self.correctedValue = correctedValue
            self.correctedValueSchemaVersion = normalizedSchemaVersion
        case .reject:
            guard correctedValue == nil, correctedValueSchemaVersion == nil else {
                throw error("reject must not include correctedValue or correctedValueSchemaVersion")
            }
            self.correctedValue = nil
            self.correctedValueSchemaVersion = nil
        }

        self.commandID = normalizedCommandID
        vaultID = correctionRequestReceipt.vaultID
        correctionRequestID = correctionRequestReceipt.correctionRequestID
        candidateID = correctionRequestReceipt.candidateID
        expectedCandidateVersion = correctionRequestReceipt.candidateVersion
        expectedMemoryVersionID = correctionRequestReceipt.expectedMemoryVersionID
        self.action = action
        self.reasonCode = normalizedReasonCode
    }

    var backendPayload: [String: Any] {
        var payload: [String: Any] = [
            "commandId": commandID,
            "expectedCandidateVersion": expectedCandidateVersion,
            "expectedMemoryVersionId": expectedMemoryVersionID.rawValue.uuidString.lowercased(),
            "action": action.rawValue,
            "reasonCode": reasonCode,
        ]
        if let correctedValue, let correctedValueSchemaVersion {
            payload["correctedValue"] = correctedValue.mapValues(\.backendJSONObject)
            payload["correctedValueSchemaVersion"] = correctedValueSchemaVersion
        }
        return payload
    }
}

/// A value-free terminal correction receipt. A corrected outcome must identify
/// the successor of the exact cited MemoryVersion; a rejected outcome must not
/// carry successor or outdated-answer metadata.
struct OwnerTruthCorrectionResolutionReceipt: Codable, Equatable, Sendable {
    let outcome: OwnerTruthCorrectionResolutionOutcome
    let correctionRequestID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let candidateVersion: Int
    let receiptID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let supersededMemoryVersionID: OwnerTruthRecordID?
    let replacementMemoryVersionID: OwnerTruthRecordID?
    let replacementMemoryVersion: Int?
    let answerOutdatedEventID: OwnerTruthRecordID?
    let authorityEpoch: Int?
    let contentHash: String?

    init(
        backendJSONObject object: [String: Any],
        expectedCommand: OwnerTruthCorrectionResolutionCommand
    ) throws {
        let error = OwnerTruthContextCitationContract.correctionResolutionReceiptError
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            object,
            field: "correction resolution response",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            object["schemaVersion"],
            field: "schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.correctionResolutionResponseSchemaVersion,
        let outcome = OwnerTruthCorrectionResolutionOutcome(
            rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
                object["status"],
                field: "status",
                error: error
            )
        ) else {
            throw error("correction resolution response schemaVersion or status is invalid")
        }

        let resolution = try OwnerTruthContextCitationContract.object(
            object["correctionResolution"],
            field: "correctionResolution",
            error: error
        )
        try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
            resolution,
            field: "correctionResolution",
            error: error
        )
        guard try OwnerTruthContextCitationContract.nonEmptyString(
            resolution["schemaVersion"],
            field: "correctionResolution.schemaVersion",
            error: error
        ) == OwnerTruthContextCitationContract.correctionResolutionSchemaVersion,
        try OwnerTruthContextCitationContract.nonEmptyString(
            resolution["outcome"],
            field: "correctionResolution.outcome",
            error: error
        ) == outcome.rawValue,
        let decision = OwnerTruthCandidateDecision(
            rawValue: try OwnerTruthContextCitationContract.nonEmptyString(
                resolution["decision"],
                field: "correctionResolution.decision",
                error: error
            )
        ) else {
            throw error("correctionResolution schemaVersion, outcome or decision is invalid")
        }

        self.outcome = outcome
        correctionRequestID = try OwnerTruthContextCitationContract.recordID(
            resolution["correctionRequestId"],
            field: "correctionResolution.correctionRequestId",
            error: error
        )
        candidateID = try OwnerTruthContextCitationContract.recordID(
            resolution["candidateId"],
            field: "correctionResolution.candidateId",
            error: error
        )
        candidateVersion = try OwnerTruthContextCitationContract.positiveInt(
            resolution["candidateVersion"],
            field: "correctionResolution.candidateVersion",
            error: error
        )
        receiptID = try OwnerTruthContextCitationContract.recordID(
            resolution["receiptId"],
            field: "correctionResolution.receiptId",
            error: error
        )
        self.decision = decision

        func optionalRecordID(_ key: String) throws -> OwnerTruthRecordID? {
            guard let rawValue = try OwnerTruthContextCitationContract.optionalString(
                resolution[key],
                field: "correctionResolution.\(key)",
                error: error
            ) else {
                return nil
            }
            return try OwnerTruthContextCitationContract.recordID(
                rawValue,
                field: "correctionResolution.\(key)",
                error: error
            )
        }

        supersededMemoryVersionID = try optionalRecordID("supersededMemoryVersionId")
        replacementMemoryVersionID = try optionalRecordID("replacementMemoryVersionId")
        answerOutdatedEventID = try optionalRecordID("answerOutdatedEventId")
        if let value = resolution["replacementMemoryVersion"], !(value is NSNull) {
            replacementMemoryVersion = try OwnerTruthContextCitationContract.positiveInt(
                value,
                field: "correctionResolution.replacementMemoryVersion",
                error: error
            )
        } else {
            replacementMemoryVersion = nil
        }
        authorityEpoch = try OwnerTruthContextCitationContract.optionalNonnegativeInt(
            resolution["authorityEpoch"],
            field: "correctionResolution.authorityEpoch",
            error: error
        )
        contentHash = try OwnerTruthContextCitationContract.optionalSHA256(
            resolution["contentHash"],
            field: "correctionResolution.contentHash",
            error: error
        )
        if let projectionEffect = resolution["projectionEffect"], !(projectionEffect is NSNull) {
            let effect = try OwnerTruthContextCitationContract.object(
                projectionEffect,
                field: "correctionResolution.projectionEffect",
                error: error
            )
            try OwnerTruthContextCitationContract.ensureNoRawContentRecursively(
                effect,
                field: "correctionResolution.projectionEffect",
                error: error
            )
        }

        guard correctionRequestID == expectedCommand.correctionRequestID,
              candidateID == expectedCommand.candidateID,
              candidateVersion == expectedCommand.expectedCandidateVersion,
              decision == expectedCommand.action.terminalDecision else {
            throw error("correctionResolution identity or terminal decision does not match the submitted command")
        }

        switch expectedCommand.action {
        case .correct:
            guard supersededMemoryVersionID == expectedCommand.expectedMemoryVersionID,
                  let replacementMemoryVersionID,
                  replacementMemoryVersionID != expectedCommand.expectedMemoryVersionID,
                  replacementMemoryVersion != nil,
                  answerOutdatedEventID != nil,
                  authorityEpoch != nil,
                  contentHash != nil else {
                throw error("corrected resolution must identify one successor MemoryVersion and outdated answer event")
            }
        case .reject:
            guard supersededMemoryVersionID == nil,
                  replacementMemoryVersionID == nil,
                  replacementMemoryVersion == nil,
                  answerOutdatedEventID == nil,
                  authorityEpoch == nil,
                  contentHash == nil else {
                throw error("rejected resolution must not contain successor MemoryVersion metadata")
            }
        }
    }
}

enum OwnerTruthCorrectionRequestIntent: Equatable, Sendable {
    case submit(citationID: OwnerTruthRecordID, correctionText: String, reasonCode: String)
}

enum OwnerTruthCorrectionRequestPhase: Equatable, Sendable {
    case idle
    case unavailable
    case submitting(OwnerTruthRecordID)
    case submitted
    case failed
}

enum OwnerTruthCorrectionRequestNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case accountUnavailable
    case staleAccountLease
    case invalidVault
    case citationUnavailable
    case invalidCorrection
    case requestResultMismatch
    case requestFailed
    case requestCreated
    case requestDeduplicated
}

struct OwnerTruthCorrectionRequestReceiptViewState: Equatable, Sendable {
    let correctionRequestID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let candidateVersion: Int
    let outcome: OwnerTruthCorrectionRequestOutcome
}

/// This state contains no answer, query, memory or correction text. It is a
/// QA-only application seam that later UI may consume without becoming an
/// authority mutation path.
struct OwnerTruthCorrectionRequestViewState: Equatable, Sendable {
    let phase: OwnerTruthCorrectionRequestPhase
    let notice: OwnerTruthCorrectionRequestNotice?
    let latestReceipt: OwnerTruthCorrectionRequestReceiptViewState?

    static let idle = OwnerTruthCorrectionRequestViewState(
        phase: .idle,
        notice: nil,
        latestReceipt: nil
    )
}

/// Builds one pending correction Candidate from one exact verified Answer /
/// Citation receipt. It intentionally stops before review or activation; the
/// normal Archive and KBLite write paths remain untouched.
final class OwnerTruthCorrectionRequestUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let answerCitationReceipt: OwnerTruthAnswerCitationReceipt
    private let client: OwnerTruthCorrectionRequestClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private let commandIDFactory: CommandIDFactory
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthCorrectionRequestViewState = .idle {
        didSet {
            onViewStateChange?(viewState)
        }
    }

    var onViewStateChange: ((OwnerTruthCorrectionRequestViewState) -> Void)?

    init(
        accountLease: AccountLease,
        answerCitationReceipt: OwnerTruthAnswerCitationReceipt,
        client: OwnerTruthCorrectionRequestClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCorrectionRequestQAGate.isEnabled },
        commandIDFactory: @escaping CommandIDFactory = {
            "owner-truth-correction-\(UUID().uuidString.lowercased())"
        }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.answerCitationReceipt = answerCitationReceipt
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthCorrectionRequestIntent) {
        switch intent {
        case .submit(let citationID, let correctionText, let reasonCode):
            submit(
                citationID: citationID,
                correctionText: correctionText,
                reasonCode: reasonCode
            )
        }
    }

    private func submit(citationID: OwnerTruthRecordID, correctionText: String, reasonCode: String) {
        guard let vaultID = beginRequestOrFail() else { return }
        let command: OwnerTruthCorrectionRequestCommand
        do {
            command = try OwnerTruthCorrectionRequestCommand(
                commandID: commandIDFactory(),
                answerCitationReceipt: answerCitationReceipt,
                citationID: citationID,
                correctionText: correctionText,
                reasonCode: reasonCode
            )
        } catch let error as OwnerTruthRemoteContractError {
            switch error {
            case .invalidCorrectionRequestCommand:
                transitionFailure(.invalidCorrection)
            default:
                transitionFailure(.citationUnavailable)
            }
            return
        } catch {
            transitionFailure(.requestFailed)
            return
        }
        guard command.vaultID == vaultID else {
            transitionFailure(.citationUnavailable)
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthCorrectionRequestViewState(
            phase: .submitting(citationID),
            notice: nil,
            latestReceipt: nil
        )
        client.requestOwnerTruthCorrection(
            vaultID: vaultID,
            expectedOwnerSubjectID: accountLease.subjectId,
            command: command
        ) { [weak self] result in
            self?.receive(result, command: command, generation: generation)
        }
    }

    private func beginRequestOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthCorrectionRequestReceipt, Error>,
        command: OwnerTruthCorrectionRequestCommand,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let receipt):
            guard receipt.answerID == command.answerID,
                  receipt.citationID == command.citationID,
                  receipt.memoryID == command.memoryID,
                  receipt.expectedMemoryVersionID == command.expectedMemoryVersionID,
                  receipt.status == .pendingReview else {
                transitionFailure(.requestResultMismatch)
                return
            }
            viewState = OwnerTruthCorrectionRequestViewState(
                phase: .submitted,
                notice: receipt.outcome == .created ? .requestCreated : .requestDeduplicated,
                latestReceipt: OwnerTruthCorrectionRequestReceiptViewState(
                    correctionRequestID: receipt.correctionRequestID,
                    candidateID: receipt.candidateID,
                    candidateVersion: receipt.candidateVersion,
                    outcome: receipt.outcome
                )
            )
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthCorrectionRequestNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthCorrectionRequestViewState(
            phase: .unavailable,
            notice: notice,
            latestReceipt: nil
        )
    }

    private func transitionFailure(_ notice: OwnerTruthCorrectionRequestNotice) {
        viewState = OwnerTruthCorrectionRequestViewState(
            phase: .failed,
            notice: notice,
            latestReceipt: nil
        )
    }
}

enum OwnerTruthCorrectionResolutionIntent: Equatable, Sendable {
    case resolve(
        action: OwnerTruthCorrectionResolutionAction,
        correctedValue: [String: OwnerTruthJSONValue]?,
        correctedValueSchemaVersion: String?,
        reasonCode: String
    )
}

enum OwnerTruthCorrectionResolutionPhase: Equatable, Sendable {
    case idle
    case unavailable
    case resolving(OwnerTruthRecordID)
    case resolved
    case failed
}

enum OwnerTruthCorrectionResolutionNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case accountUnavailable
    case staleAccountLease
    case invalidVault
    case invalidResolution
    case resolutionResultMismatch
    case resolutionFailed
    case resolutionCreated
    case resolutionDeduplicated
}

struct OwnerTruthCorrectionResolutionReceiptViewState: Equatable, Sendable {
    let correctionRequestID: OwnerTruthRecordID
    let candidateID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let replacementMemoryVersionID: OwnerTruthRecordID?
    let outcome: OwnerTruthCorrectionResolutionOutcome
}

/// Value-free state for the default-off correction resolver. It deliberately
/// does not retain corrected values, source text or a Memory payload.
struct OwnerTruthCorrectionResolutionViewState: Equatable, Sendable {
    let phase: OwnerTruthCorrectionResolutionPhase
    let notice: OwnerTruthCorrectionResolutionNotice?
    let latestReceipt: OwnerTruthCorrectionResolutionReceiptViewState?

    static let idle = OwnerTruthCorrectionResolutionViewState(
        phase: .idle,
        notice: nil,
        latestReceipt: nil
    )
}

/// Resolves a pending correction through the dedicated backend route. This is
/// intentionally separate from generic Candidate review, which must not create
/// a second MemoryRecord for a correction Candidate.
final class OwnerTruthCorrectionResolutionUseCase {
    typealias CommandIDFactory = () -> String

    private let accountLease: AccountLease
    private let vaultID: OwnerTruthVaultID?
    private let correctionRequestReceipt: OwnerTruthCorrectionRequestReceipt
    private let client: OwnerTruthCorrectionResolutionClient
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let qaGateEnabled: () -> Bool
    private let commandIDFactory: CommandIDFactory
    private var operationGeneration: UInt = 0

    private(set) var viewState: OwnerTruthCorrectionResolutionViewState = .idle {
        didSet {
            onViewStateChange?(viewState)
        }
    }

    var onViewStateChange: ((OwnerTruthCorrectionResolutionViewState) -> Void)?

    init(
        accountLease: AccountLease,
        correctionRequestReceipt: OwnerTruthCorrectionRequestReceipt,
        client: OwnerTruthCorrectionResolutionClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        qaGateEnabled: @escaping () -> Bool = { OwnerTruthCorrectionRequestQAGate.isEnabled },
        commandIDFactory: @escaping CommandIDFactory = {
            "owner-truth-correction-resolution-\(UUID().uuidString.lowercased())"
        }
    ) {
        self.accountLease = accountLease
        vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.correctionRequestReceipt = correctionRequestReceipt
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthCorrectionResolutionIntent) {
        switch intent {
        case .resolve(let action, let correctedValue, let correctedValueSchemaVersion, let reasonCode):
            resolve(
                action: action,
                correctedValue: correctedValue,
                correctedValueSchemaVersion: correctedValueSchemaVersion,
                reasonCode: reasonCode
            )
        }
    }

    private func resolve(
        action: OwnerTruthCorrectionResolutionAction,
        correctedValue: [String: OwnerTruthJSONValue]?,
        correctedValueSchemaVersion: String?,
        reasonCode: String
    ) {
        guard let vaultID = beginResolutionOrFail() else { return }
        let command: OwnerTruthCorrectionResolutionCommand
        do {
            command = try OwnerTruthCorrectionResolutionCommand(
                commandID: commandIDFactory(),
                correctionRequestReceipt: correctionRequestReceipt,
                action: action,
                correctedValue: correctedValue,
                correctedValueSchemaVersion: correctedValueSchemaVersion,
                reasonCode: reasonCode
            )
        } catch let error as OwnerTruthRemoteContractError {
            switch error {
            case .invalidCorrectionResolutionCommand:
                transitionFailure(.invalidResolution)
            default:
                transitionFailure(.resolutionFailed)
            }
            return
        } catch {
            transitionFailure(.resolutionFailed)
            return
        }
        guard command.vaultID == vaultID else {
            resetForUnavailable(.invalidVault)
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthCorrectionResolutionViewState(
            phase: .resolving(command.correctionRequestID),
            notice: nil,
            latestReceipt: nil
        )
        client.resolveOwnerTruthCorrection(
            vaultID: vaultID,
            expectedOwnerSubjectID: accountLease.subjectId,
            command: command
        ) { [weak self] result in
            self?.receive(result, command: command, generation: generation)
        }
    }

    private func beginResolutionOrFail() -> OwnerTruthVaultID? {
        guard qaGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return nil
        }
        guard let vaultID, correctionRequestReceipt.vaultID == vaultID else {
            resetForUnavailable(.invalidVault)
            return nil
        }
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            resetForUnavailable(.accountUnavailable)
            return nil
        }
        return vaultID
    }

    private func receive(
        _ result: Result<OwnerTruthCorrectionResolutionReceipt, Error>,
        command: OwnerTruthCorrectionResolutionCommand,
        generation: UInt
    ) {
        guard generation == operationGeneration else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            resetForUnavailable(.staleAccountLease)
            return
        }
        switch result {
        case .success(let receipt):
            guard receipt.correctionRequestID == command.correctionRequestID,
                  receipt.candidateID == command.candidateID,
                  receipt.candidateVersion == command.expectedCandidateVersion,
                  receipt.decision == command.action.terminalDecision else {
                transitionFailure(.resolutionResultMismatch)
                return
            }
            viewState = OwnerTruthCorrectionResolutionViewState(
                phase: .resolved,
                notice: receipt.outcome == .created ? .resolutionCreated : .resolutionDeduplicated,
                latestReceipt: OwnerTruthCorrectionResolutionReceiptViewState(
                    correctionRequestID: receipt.correctionRequestID,
                    candidateID: receipt.candidateID,
                    decision: receipt.decision,
                    replacementMemoryVersionID: receipt.replacementMemoryVersionID,
                    outcome: receipt.outcome
                )
            )
        case .failure:
            transitionFailure(.resolutionFailed)
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthCorrectionResolutionNotice) {
        operationGeneration &+= 1
        viewState = OwnerTruthCorrectionResolutionViewState(
            phase: .unavailable,
            notice: notice,
            latestReceipt: nil
        )
    }

    private func transitionFailure(_ notice: OwnerTruthCorrectionResolutionNotice) {
        viewState = OwnerTruthCorrectionResolutionViewState(
            phase: .failed,
            notice: notice,
            latestReceipt: nil
        )
    }
}

/// QA-only bridge from a citation-bound correction request to the existing
/// Candidate Inbox. It retains only opaque request/candidate identifiers for
/// visibility. Terminal decisions must use `OwnerTruthCorrectionResolutionUseCase`,
/// because generic Candidate activation cannot supersede the cited MemoryVersion.
/// No correction text, answer text or Memory authority is retained here.
enum OwnerTruthCorrectionCandidateInboxHandoffIntent: Equatable, Sendable {
    case submit(citationID: OwnerTruthRecordID, correctionText: String, reasonCode: String)
}

enum OwnerTruthCorrectionCandidateInboxHandoffPhase: Equatable, Sendable {
    case idle
    case unavailable
    case submitting(OwnerTruthRecordID)
    case locatingCandidate(OwnerTruthRecordID)
    case ready
    case failed
}

enum OwnerTruthCorrectionCandidateInboxHandoffNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case accountUnavailable
    case correctionRequestFailed
    case candidateUnavailable
    case candidateInboxFailed
}

/// The handoff state is intentionally value-free. The existing QA Candidate
/// Inbox owns any review preview and terminal decision state.
struct OwnerTruthCorrectionCandidateInboxHandoffViewState: Equatable, Sendable {
    let phase: OwnerTruthCorrectionCandidateInboxHandoffPhase
    let notice: OwnerTruthCorrectionCandidateInboxHandoffNotice?
    let correctionRequestID: OwnerTruthRecordID?
    let candidateID: OwnerTruthRecordID?

    static let idle = OwnerTruthCorrectionCandidateInboxHandoffViewState(
        phase: .idle,
        notice: nil,
        correctionRequestID: nil,
        candidateID: nil
    )
}

/// Composes the QA-only request and inbox refresh paths without exposing a
/// generic terminal-review handle for correction Candidates. A submitted
/// correction must reappear in Candidate Inbox before this handoff is
/// considered ready; normal Archive/KBLite writers are never called.
final class OwnerTruthCorrectionCandidateInboxHandoffUseCase {
    private let candidateInboxUseCase: OwnerTruthCandidateReviewUseCase

    private let correctionRequestUseCase: OwnerTruthCorrectionRequestUseCase
    private let correctionQAGateEnabled: () -> Bool
    private let candidateReviewQAGateEnabled: () -> Bool
    private var awaitingCandidateID: OwnerTruthRecordID?

    private(set) var viewState: OwnerTruthCorrectionCandidateInboxHandoffViewState = .idle {
        didSet {
            onViewStateChange?(viewState)
        }
    }

    var onViewStateChange: ((OwnerTruthCorrectionCandidateInboxHandoffViewState) -> Void)?

    init(
        accountLease: AccountLease,
        answerCitationReceipt: OwnerTruthAnswerCitationReceipt,
        correctionClient: OwnerTruthCorrectionRequestClient,
        candidateReviewClient: OwnerTruthCandidateReviewClient,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        correctionQAGateEnabled: @escaping () -> Bool = { OwnerTruthCorrectionRequestQAGate.isEnabled },
        candidateReviewQAGateEnabled: @escaping () -> Bool = { OwnerTruthCandidateReviewQAGate.isEnabled },
        correctionCommandIDFactory: @escaping OwnerTruthCorrectionRequestUseCase.CommandIDFactory = {
            "owner-truth-correction-\(UUID().uuidString.lowercased())"
        }
    ) {
        self.correctionQAGateEnabled = correctionQAGateEnabled
        self.candidateReviewQAGateEnabled = candidateReviewQAGateEnabled
        candidateInboxUseCase = OwnerTruthCandidateReviewUseCase(
            accountLease: accountLease,
            client: candidateReviewClient,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: candidateReviewQAGateEnabled
        )
        correctionRequestUseCase = OwnerTruthCorrectionRequestUseCase(
            accountLease: accountLease,
            answerCitationReceipt: answerCitationReceipt,
            client: correctionClient,
            accountLeaseRuntime: accountLeaseRuntime,
            qaGateEnabled: correctionQAGateEnabled,
            commandIDFactory: correctionCommandIDFactory
        )

        correctionRequestUseCase.onViewStateChange = { [weak self] state in
            self?.receiveCorrectionRequest(state)
        }
        candidateInboxUseCase.onViewStateChange = { [weak self] state in
            self?.receiveCandidateInbox(state)
        }
    }

    func send(_ intent: OwnerTruthCorrectionCandidateInboxHandoffIntent) {
        guard correctionQAGateEnabled(), candidateReviewQAGateEnabled() else {
            resetForUnavailable(.qaOnlyDisabled)
            return
        }

        switch intent {
        case .submit(let citationID, let correctionText, let reasonCode):
            awaitingCandidateID = nil
            viewState = OwnerTruthCorrectionCandidateInboxHandoffViewState(
                phase: .submitting(citationID),
                notice: nil,
                correctionRequestID: nil,
                candidateID: nil
            )
            correctionRequestUseCase.send(.submit(
                citationID: citationID,
                correctionText: correctionText,
                reasonCode: reasonCode
            ))
        }
    }

    private func receiveCorrectionRequest(_ state: OwnerTruthCorrectionRequestViewState) {
        switch state.phase {
        case .idle, .submitting:
            return
        case .unavailable:
            switch state.notice {
            case .qaOnlyDisabled:
                resetForUnavailable(.qaOnlyDisabled)
            case .accountUnavailable, .staleAccountLease:
                resetForUnavailable(.accountUnavailable)
            default:
                transitionFailure(.correctionRequestFailed)
            }
        case .failed:
            transitionFailure(.correctionRequestFailed)
        case .submitted:
            guard correctionQAGateEnabled(), candidateReviewQAGateEnabled() else {
                resetForUnavailable(.qaOnlyDisabled)
                return
            }
            guard let receipt = state.latestReceipt else {
                transitionFailure(.correctionRequestFailed)
                return
            }
            awaitingCandidateID = receipt.candidateID
            viewState = OwnerTruthCorrectionCandidateInboxHandoffViewState(
                phase: .locatingCandidate(receipt.candidateID),
                notice: nil,
                correctionRequestID: receipt.correctionRequestID,
                candidateID: receipt.candidateID
            )
            candidateInboxUseCase.send(.refresh)
        }
    }

    private func receiveCandidateInbox(_ state: OwnerTruthCandidateInboxViewState) {
        guard let candidateID = awaitingCandidateID else { return }
        switch state.phase {
        case .idle, .loading, .submitting, .submittingBatch:
            return
        case .unavailable:
            switch state.notice {
            case .qaOnlyDisabled:
                resetForUnavailable(.qaOnlyDisabled)
            case .accountUnavailable, .staleAccountLease:
                resetForUnavailable(.accountUnavailable)
            default:
                transitionFailure(.candidateInboxFailed)
            }
        case .failed:
            transitionFailure(.candidateInboxFailed)
        case .empty:
            transitionFailure(.candidateUnavailable)
        case .ready:
            guard state.items.contains(where: { $0.id == candidateID }) else {
                transitionFailure(.candidateUnavailable)
                return
            }
            awaitingCandidateID = nil
            viewState = OwnerTruthCorrectionCandidateInboxHandoffViewState(
                phase: .ready,
                notice: nil,
                correctionRequestID: viewState.correctionRequestID,
                candidateID: candidateID
            )
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthCorrectionCandidateInboxHandoffNotice) {
        awaitingCandidateID = nil
        viewState = OwnerTruthCorrectionCandidateInboxHandoffViewState(
            phase: .unavailable,
            notice: notice,
            correctionRequestID: nil,
            candidateID: nil
        )
    }

    private func transitionFailure(_ notice: OwnerTruthCorrectionCandidateInboxHandoffNotice) {
        awaitingCandidateID = nil
        viewState = OwnerTruthCorrectionCandidateInboxHandoffViewState(
            phase: .failed,
            notice: notice,
            correctionRequestID: viewState.correctionRequestID,
            candidateID: viewState.candidateID
        )
    }
}

/// A value-free bridge for existing Echo QA evidence. It has no runtime or
/// model text and therefore can be exported alongside the current trace.
struct OwnerTruthContextCitationTraceSummary: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-context-citation-trace-v1"

    let contextVersion: String
    let policyVersion: String
    let selectionMode: OwnerTruthContextSelectionMode
    let queryHash: String?
    let queryLength: Int?
    let contextHash: String
    let authorityState: OwnerTruthContextShadowState
    let authorityEpoch: Int?
    let projectionCheckpoint: String?
    let selectedContextRefs: [String]
    let selectedContextRefsBySource: [String: [String]]
    let filteredContextReasons: [String]
    let selectedContextCount: Int
    let filteredContextCount: Int
    let rankingTraceCount: Int
    let citationCount: Int
    let answerCitationCount: Int
    let selectedContextSourceCounts: [String: Int]
    let fallbacks: [String]

    init(context: OwnerTruthContextShadowBuild, receipt: OwnerTruthAnswerCitationReceipt?) {
        contextVersion = context.contextVersion
        policyVersion = context.policyVersion
        selectionMode = context.request.selectionMode
        queryHash = context.request.queryHash
        queryLength = context.request.queryLength
        contextHash = context.contextHash
        authorityState = context.authority.state
        authorityEpoch = context.authority.authorityEpoch
        projectionCheckpoint = context.authority.projectionCheckpoint
        selectedContextRefs = context.selectedContext.map(\.refID)
        selectedContextRefsBySource = Dictionary(grouping: context.selectedContext, by: \.source)
            .mapValues { $0.map(\.refID) }
        filteredContextReasons = context.filteredContext.map(\.reason)
        selectedContextCount = context.selectedContext.count
        filteredContextCount = context.filteredContext.count
        rankingTraceCount = context.rankingTrace.count
        citationCount = context.citationProof.count
        answerCitationCount = receipt?.citations.count ?? 0
        selectedContextSourceCounts = context.selectedContextSourceCounts
        fallbacks = context.fallbacks
    }

    init(
        contextVersion: String,
        policyVersion: String,
        selectionMode: OwnerTruthContextSelectionMode,
        queryHash: String? = nil,
        queryLength: Int? = nil,
        contextHash: String,
        authorityState: OwnerTruthContextShadowState,
        authorityEpoch: Int?,
        projectionCheckpoint: String?,
        selectedContextRefs: [String],
        selectedContextRefsBySource: [String: [String]],
        filteredContextReasons: [String],
        selectedContextCount: Int,
        filteredContextCount: Int,
        rankingTraceCount: Int,
        citationCount: Int,
        answerCitationCount: Int,
        selectedContextSourceCounts: [String: Int],
        fallbacks: [String]
    ) {
        self.contextVersion = contextVersion
        self.policyVersion = policyVersion
        self.selectionMode = selectionMode
        self.queryHash = queryHash
        self.queryLength = queryLength
        self.contextHash = contextHash
        self.authorityState = authorityState
        self.authorityEpoch = authorityEpoch
        self.projectionCheckpoint = projectionCheckpoint
        self.selectedContextRefs = selectedContextRefs
        self.selectedContextRefsBySource = selectedContextRefsBySource
        self.filteredContextReasons = filteredContextReasons
        self.selectedContextCount = selectedContextCount
        self.filteredContextCount = filteredContextCount
        self.rankingTraceCount = rankingTraceCount
        self.citationCount = citationCount
        self.answerCitationCount = answerCitationCount
        self.selectedContextSourceCounts = selectedContextSourceCounts
        self.fallbacks = fallbacks
    }

    /// The trace preserves only a normalized request hash and scalar count.
    /// This lets a QA observer reject a response for another Echo turn without
    /// retaining the user's text in a runtime trace or export bundle.
    static func queryFingerprint(for query: String) -> (hash: String?, length: Int) {
        let normalized = OwnerTruthContextCitationContract.normalizedText(query)
        return (
            normalized.isEmpty ? nil : OwnerTruthContextCitationContract.digest(normalized),
            OwnerTruthContextCitationContract.scalarCount(normalized)
        )
    }

    func matchesSubmittedQuery(_ query: String) -> Bool {
        let fingerprint = Self.queryFingerprint(for: query)
        guard let queryLength else { return false }
        return queryHash == fingerprint.hash && queryLength == fingerprint.length
    }
}

/// This is the only Owner Truth Context shape allowed into the Echo QA panel
/// and export bundle. Reference identifiers and Context authority material are
/// one-way digested before the UI layer sees them; query, answer and memory
/// values never enter this representation.
struct OwnerTruthContextCitationQAEvidenceReadout: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-context-citation-readout-v1"

    let schemaVersion: String
    let contextVersion: String
    let policyVersion: String
    let selectionMode: OwnerTruthContextSelectionMode
    let queryHashDigest: String?
    let queryLength: Int?
    let contextHashDigest: String
    let authorityState: OwnerTruthContextShadowState
    let authorityEpoch: Int?
    let projectionCheckpointDigest: String?
    let selectedContextRefDigests: [String]
    let selectedContextRefDigestsBySource: [String: [String]]
    let filteredContextReasons: [String]
    let selectedContextCount: Int
    let filteredContextCount: Int
    let rankingTraceCount: Int
    let citationCount: Int
    let answerCitationCount: Int
    let selectedContextSourceCounts: [String: Int]
    let fallbacks: [String]

    init(summary: OwnerTruthContextCitationTraceSummary) {
        schemaVersion = Self.schemaVersion
        contextVersion = summary.contextVersion
        policyVersion = summary.policyVersion
        selectionMode = summary.selectionMode
        queryHashDigest = summary.queryHash.map(Self.digest)
        queryLength = summary.queryLength
        contextHashDigest = Self.digest(summary.contextHash)
        authorityState = summary.authorityState
        authorityEpoch = summary.authorityEpoch
        projectionCheckpointDigest = summary.projectionCheckpoint.map(Self.digest)
        selectedContextRefDigests = summary.selectedContextRefs.map(Self.digest)
        selectedContextRefDigestsBySource = summary.selectedContextRefsBySource
            .mapValues { $0.map(Self.digest) }
        filteredContextReasons = summary.filteredContextReasons
        selectedContextCount = summary.selectedContextCount
        filteredContextCount = summary.filteredContextCount
        rankingTraceCount = summary.rankingTraceCount
        citationCount = summary.citationCount
        answerCitationCount = summary.answerCitationCount
        selectedContextSourceCounts = summary.selectedContextSourceCounts
        fallbacks = summary.fallbacks
    }

    func panelLines(prefix: String = "ownerCtx") -> [String] {
        [
            "\(prefix) schema: \(schemaVersion)",
            "\(prefix) selection: \(selectionMode.rawValue)",
            "\(prefix) query: length=\(queryLength.map(String.init) ?? "unknown") hash=\(queryHashDigest ?? "none")",
            "\(prefix) authority: \(authorityState.rawValue) epoch=\(authorityEpoch.map(String.init) ?? "none")",
            "\(prefix) selected/filtered: \(selectedContextCount)/\(filteredContextCount)",
            "\(prefix) citation/answer: \(citationCount)/\(answerCitationCount)",
            "\(prefix) ranking: \(rankingTraceCount)",
            "\(prefix) sources: \(sourceCountsText)",
            "\(prefix) filtered: \(filteredCodesText)",
            "\(prefix) fallbacks: \(fallbackCodesText)"
        ]
    }

    private var sourceCountsText: String {
        guard !selectedContextSourceCounts.isEmpty else { return "none" }
        return selectedContextSourceCounts
            .sorted { $0.key < $1.key }
            .map { "\($0.key):\($0.value)" }
            .joined(separator: ",")
    }

    private var filteredCodesText: String {
        previewCodes(filteredContextReasons)
    }

    private var fallbackCodesText: String {
        previewCodes(fallbacks)
    }

    private func previewCodes(_ codes: [String], limit: Int = 3) -> String {
        guard !codes.isEmpty else { return "none" }
        let prefix = codes.prefix(limit).joined(separator: ",")
        return codes.count > limit ? prefix + "+\(codes.count - limit)" : prefix
    }

    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

/// The concrete backend client keeps HTTP/auth/header ownership. Callers only
/// receive typed, value-free evidence and cannot enable this in release.
protocol OwnerTruthContextCitationClient: AnyObject {
    func buildOwnerTruthContextShadow(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        intent: String,
        query: String,
        selectionMode: OwnerTruthContextSelectionMode,
        completion: @escaping (Result<OwnerTruthContextShadowBuild, Error>) -> Void
    )

    func recordOwnerTruthAnswerCitationReceipt(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        expectedContext: OwnerTruthContextShadowBuild,
        commandID: String,
        intent: String,
        query: String,
        answerText: String,
        completion: @escaping (Result<OwnerTruthAnswerCitationReceipt, Error>) -> Void
    )
}

/// Read-only QA transport for the server-side same-request V1/V4 comparison.
/// It cannot return either Context body and is intentionally separate from the
/// public Context client and writer contracts.
protocol OwnerTruthContextShadowCompareClient: AnyObject {
    func compareOwnerTruthContextShadow(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        intent: String,
        query: String,
        completion: @escaping (Result<OwnerTruthContextShadowCompare, Error>) -> Void
    )
}

/// Narrow write port for the default-off Answer/Citation correction request.
/// The transport layer owns authentication and the QA header; callers submit a
/// command already derived from a verified citation receipt.
protocol OwnerTruthCorrectionRequestClient: AnyObject {
    func requestOwnerTruthCorrection(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        command: OwnerTruthCorrectionRequestCommand,
        completion: @escaping (Result<OwnerTruthCorrectionRequestReceipt, Error>) -> Void
    )
}

/// Narrow write port for the terminal, QA-only correction resolver. The
/// separate route preserves the cited MemoryRecord lineage instead of using the
/// generic Candidate activation path.
protocol OwnerTruthCorrectionResolutionClient: AnyObject {
    func resolveOwnerTruthCorrection(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        command: OwnerTruthCorrectionResolutionCommand,
        completion: @escaping (Result<OwnerTruthCorrectionResolutionReceipt, Error>) -> Void
    )
}

// MARK: - Migration C05 ViewState parity shadow (QA-only)

/// C05 never changes a user-visible result. This gate only permits the
/// value-minimized parity comparator in debug/UIQA builds; callers must keep
/// legacy and V4 reads separate and may not use a result to select a writer.
enum OwnerTruthMigrationParityQAGate {
    static let launchArgument = "DJEnableOwnerTruthMigrationParityQA"

    static var isEnabled: Bool {
        #if DEBUG || UI_QA_SIMULATOR
        return ProcessInfo.processInfo.arguments.contains(launchArgument)
        #else
        return false
        #endif
    }
}

/// A validated SHA-256 value. C05 ViewState evidence intentionally accepts
/// digests only, so neither the parity report nor a future QA export can carry
/// archive text, identifiers, route URLs, or presentation strings.
struct OwnerTruthMigrationParityDigest: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init?(rawValue: String) {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("sha256:"),
              normalized.count == "sha256:".count + 64,
              normalized.dropFirst("sha256:".count).allSatisfy(\.isHexDigit) else {
            return nil
        }
        self.rawValue = normalized
    }

    init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let value = Self(rawValue: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Owner Truth migration parity values must be SHA-256 digests"
            )
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func make(_ canonicalValue: String) -> Self {
        let digest = SHA256.hash(data: Data(canonicalValue.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        // SHA256 always produces 64 lowercase hexadecimal characters.
        return Self(rawValue: "sha256:\(digest)")!
    }
}

enum OwnerTruthMigrationParitySurface: String, CaseIterable, Codable, Sendable {
    case read
    case projection
    case context
}

enum OwnerTruthMigrationParityClientGeneration: String, Codable, Sendable {
    case legacy
    case v4
}

enum OwnerTruthMigrationParityRouteDecision: String, CaseIterable, Codable, Sendable {
    case allowed
    case denied
    case unavailable
}

enum OwnerTruthMigrationParityVisibility: String, CaseIterable, Codable, Sendable {
    case visible
    case redacted
    case hidden
    case denied
}

enum OwnerTruthMigrationParityViewStatePhase: String, CaseIterable, Codable, Sendable {
    case ready
    case empty
    case unavailable
    case failed
    case retryableFailure
}

enum OwnerTruthMigrationParityCacheState: String, CaseIterable, Codable, Sendable {
    case fresh
    case stale
    case invalidated
    case unavailable
}

/// The C05 taxonomy mirrors the backend shadow contract. M01-M07 stop a
/// promotion window; M08 is only eligible for a scoped, expiring presentation
/// disposition and is never a blanket compatibility waiver.
enum OwnerTruthMigrationParityMismatchCode: String, CaseIterable, Codable, Sendable {
    case m01AuthorityBinding = "M01"
    case m02IntentOrRoute = "M02"
    case m03Visibility = "M03"
    case m04AuthorityEpoch = "M04"
    case m05ViewState = "M05"
    case m06Citation = "M06"
    case m07CacheOrCheckpoint = "M07"
    case m08Presentation = "M08"

    var isPromotionBlocker: Bool {
        self != .m08Presentation
    }
}

enum OwnerTruthMigrationParityMismatchDimension: String, Codable, Sendable {
    case authorityBinding
    case intent
    case routeDecision
    case visibility
    case authorityEpoch
    case viewStatePhase
    case viewStateHash
    case citationSet
    case projectionCheckpoint
    case cacheState
    case presentation

    var code: OwnerTruthMigrationParityMismatchCode {
        switch self {
        case .authorityBinding:
            return .m01AuthorityBinding
        case .intent, .routeDecision:
            return .m02IntentOrRoute
        case .visibility:
            return .m03Visibility
        case .authorityEpoch:
            return .m04AuthorityEpoch
        case .viewStatePhase, .viewStateHash:
            return .m05ViewState
        case .citationSet:
            return .m06Citation
        case .projectionCheckpoint, .cacheState:
            return .m07CacheOrCheckpoint
        case .presentation:
            return .m08Presentation
        }
    }
}

struct OwnerTruthMigrationParityAuthorityBinding: Codable, Equatable, Sendable {
    let ownerSubjectHash: OwnerTruthMigrationParityDigest
    let vaultHash: OwnerTruthMigrationParityDigest
    let authorityEpochHash: OwnerTruthMigrationParityDigest

    var fingerprint: OwnerTruthMigrationParityDigest {
        OwnerTruthMigrationParityDigest.make([
            "owner-truth-migration-authority-binding-v1",
            ownerSubjectHash.rawValue,
            vaultHash.rawValue,
        ].joined(separator: "|"))
    }
}

/// A value-minimized rendering result produced from one semantic Intent. The
/// source is intentionally explicit: a comparison must be legacy-to-V4, never
/// legacy-to-legacy or V4-to-V4. Route decisions are semantic outcomes, not
/// endpoint strings, because migration endpoints are expected to differ.
struct OwnerTruthMigrationParityViewStateSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-migration-view-state-snapshot-v1"

    let schemaVersion: String
    let source: OwnerTruthMigrationParityClientGeneration
    let surface: OwnerTruthMigrationParitySurface
    let intentHash: OwnerTruthMigrationParityDigest
    let authority: OwnerTruthMigrationParityAuthorityBinding
    let routeDecision: OwnerTruthMigrationParityRouteDecision
    let visibility: OwnerTruthMigrationParityVisibility
    let phase: OwnerTruthMigrationParityViewStatePhase
    let cacheState: OwnerTruthMigrationParityCacheState
    let viewStateHash: OwnerTruthMigrationParityDigest
    let citationSetHash: OwnerTruthMigrationParityDigest?
    let projectionCheckpointHash: OwnerTruthMigrationParityDigest?
    let presentationHash: OwnerTruthMigrationParityDigest?

    init(
        source: OwnerTruthMigrationParityClientGeneration,
        surface: OwnerTruthMigrationParitySurface,
        intentHash: OwnerTruthMigrationParityDigest,
        authority: OwnerTruthMigrationParityAuthorityBinding,
        routeDecision: OwnerTruthMigrationParityRouteDecision,
        visibility: OwnerTruthMigrationParityVisibility,
        phase: OwnerTruthMigrationParityViewStatePhase,
        cacheState: OwnerTruthMigrationParityCacheState,
        viewStateHash: OwnerTruthMigrationParityDigest,
        citationSetHash: OwnerTruthMigrationParityDigest? = nil,
        projectionCheckpointHash: OwnerTruthMigrationParityDigest? = nil,
        presentationHash: OwnerTruthMigrationParityDigest? = nil
    ) {
        self.schemaVersion = Self.schemaVersion
        self.source = source
        self.surface = surface
        self.intentHash = intentHash
        self.authority = authority
        self.routeDecision = routeDecision
        self.visibility = visibility
        self.phase = phase
        self.cacheState = cacheState
        self.viewStateHash = viewStateHash
        self.citationSetHash = citationSetHash
        self.projectionCheckpointHash = projectionCheckpointHash
        self.presentationHash = presentationHash
    }
}

/// M08 approval is bound to one exact pair of presentation digests and one
/// surface. It cannot approve a route, visibility, citation, cache, owner, or
/// epoch mismatch, and it expires rather than becoming permanent policy.
struct OwnerTruthMigrationParityM08Disposition: Codable, Equatable, Sendable {
    let surface: OwnerTruthMigrationParitySurface
    let legacyPresentationHash: OwnerTruthMigrationParityDigest
    let v4PresentationHash: OwnerTruthMigrationParityDigest
    let approvalReferenceHash: OwnerTruthMigrationParityDigest
    let expiresAt: Date

    func covers(
        surface: OwnerTruthMigrationParitySurface,
        legacyPresentationHash: OwnerTruthMigrationParityDigest,
        v4PresentationHash: OwnerTruthMigrationParityDigest,
        at date: Date
    ) -> Bool {
        self.surface == surface
            && self.legacyPresentationHash == legacyPresentationHash
            && self.v4PresentationHash == v4PresentationHash
            && expiresAt > date
    }
}

enum OwnerTruthMigrationParityM08DispositionStatus: String, Codable, Sendable {
    case notApplicable
    case unapproved
    case approved
    case expired
}

struct OwnerTruthMigrationParityViewStateMismatch: Codable, Equatable, Sendable {
    let code: OwnerTruthMigrationParityMismatchCode
    let dimension: OwnerTruthMigrationParityMismatchDimension
    let legacyFingerprint: OwnerTruthMigrationParityDigest
    let v4Fingerprint: OwnerTruthMigrationParityDigest
    let m08DispositionStatus: OwnerTruthMigrationParityM08DispositionStatus

    var isPromotionBlocker: Bool {
        code.isPromotionBlocker
            || m08DispositionStatus == .unapproved
            || m08DispositionStatus == .expired
    }
}

struct OwnerTruthMigrationParityViewStateReport: Codable, Equatable, Sendable {
    static let schemaVersion = "owner-truth-migration-view-state-parity-v1"

    let schemaVersion: String
    let surface: OwnerTruthMigrationParitySurface
    let intentHash: OwnerTruthMigrationParityDigest
    let legacyCacheState: OwnerTruthMigrationParityCacheState
    let v4CacheState: OwnerTruthMigrationParityCacheState
    let legacyAuthorityEpochHash: OwnerTruthMigrationParityDigest
    let v4AuthorityEpochHash: OwnerTruthMigrationParityDigest
    let mismatches: [OwnerTruthMigrationParityViewStateMismatch]
    let blockerCount: Int
    let unresolvedM08Count: Int

    var isEligibleForApprovedWindow: Bool {
        blockerCount == 0 && unresolvedM08Count == 0
    }
}

enum OwnerTruthMigrationParityViewStateComparisonError: Error, Equatable, Sendable {
    case qaDisabled
    case invalidSourcePair
    case surfaceMismatch
}

/// Pure comparator for C05 G1. It has no network, persistence, cache mutation,
/// UI mutation, command submission, or Authority selection behavior. A caller
/// may use the returned report as QA evidence only after both independent
/// legacy and V4 reads have completed.
enum OwnerTruthMigrationParityViewStateComparator {
    static func compare(
        legacy: OwnerTruthMigrationParityViewStateSnapshot,
        v4: OwnerTruthMigrationParityViewStateSnapshot,
        m08Dispositions: [OwnerTruthMigrationParityM08Disposition] = [],
        at date: Date = Date(),
        qaGateEnabled: Bool = OwnerTruthMigrationParityQAGate.isEnabled
    ) throws -> OwnerTruthMigrationParityViewStateReport {
        guard qaGateEnabled else {
            throw OwnerTruthMigrationParityViewStateComparisonError.qaDisabled
        }
        guard legacy.source == .legacy, v4.source == .v4 else {
            throw OwnerTruthMigrationParityViewStateComparisonError.invalidSourcePair
        }
        guard legacy.surface == v4.surface else {
            throw OwnerTruthMigrationParityViewStateComparisonError.surfaceMismatch
        }

        var mismatches: [OwnerTruthMigrationParityViewStateMismatch] = []
        let surface = legacy.surface

        appendIfDifferent(
            dimension: .authorityBinding,
            legacy: legacy.authority.fingerprint,
            v4: v4.authority.fingerprint,
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .intent,
            legacy: legacy.intentHash,
            v4: v4.intentHash,
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .routeDecision,
            legacy: fingerprint(legacy.routeDecision.rawValue),
            v4: fingerprint(v4.routeDecision.rawValue),
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .visibility,
            legacy: fingerprint(legacy.visibility.rawValue),
            v4: fingerprint(v4.visibility.rawValue),
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .authorityEpoch,
            legacy: legacy.authority.authorityEpochHash,
            v4: v4.authority.authorityEpochHash,
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .viewStatePhase,
            legacy: fingerprint(legacy.phase.rawValue),
            v4: fingerprint(v4.phase.rawValue),
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .viewStateHash,
            legacy: legacy.viewStateHash,
            v4: v4.viewStateHash,
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .citationSet,
            legacy: optionalFingerprint(legacy.citationSetHash),
            v4: optionalFingerprint(v4.citationSetHash),
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .projectionCheckpoint,
            legacy: optionalFingerprint(legacy.projectionCheckpointHash),
            v4: optionalFingerprint(v4.projectionCheckpointHash),
            to: &mismatches
        )
        appendIfDifferent(
            dimension: .cacheState,
            legacy: fingerprint(legacy.cacheState.rawValue),
            v4: fingerprint(v4.cacheState.rawValue),
            to: &mismatches
        )

        let legacyPresentationHash = optionalFingerprint(legacy.presentationHash)
        let v4PresentationHash = optionalFingerprint(v4.presentationHash)
        if legacyPresentationHash != v4PresentationHash {
            let dispositionStatus = m08DispositionStatus(
                surface: surface,
                legacyPresentationHash: legacyPresentationHash,
                v4PresentationHash: v4PresentationHash,
                dispositions: m08Dispositions,
                at: date
            )
            mismatches.append(
                OwnerTruthMigrationParityViewStateMismatch(
                    code: .m08Presentation,
                    dimension: .presentation,
                    legacyFingerprint: legacyPresentationHash,
                    v4Fingerprint: v4PresentationHash,
                    m08DispositionStatus: dispositionStatus
                )
            )
        }

        let blockerCount = mismatches.filter(\.isPromotionBlocker).count
        let unresolvedM08Count = mismatches.filter {
            $0.code == .m08Presentation && $0.m08DispositionStatus != .approved
        }.count
        return OwnerTruthMigrationParityViewStateReport(
            schemaVersion: OwnerTruthMigrationParityViewStateReport.schemaVersion,
            surface: surface,
            intentHash: legacy.intentHash,
            legacyCacheState: legacy.cacheState,
            v4CacheState: v4.cacheState,
            legacyAuthorityEpochHash: legacy.authority.authorityEpochHash,
            v4AuthorityEpochHash: v4.authority.authorityEpochHash,
            mismatches: mismatches,
            blockerCount: blockerCount,
            unresolvedM08Count: unresolvedM08Count
        )
    }

    private static func appendIfDifferent(
        dimension: OwnerTruthMigrationParityMismatchDimension,
        legacy: OwnerTruthMigrationParityDigest,
        v4: OwnerTruthMigrationParityDigest,
        to mismatches: inout [OwnerTruthMigrationParityViewStateMismatch]
    ) {
        guard legacy != v4 else { return }
        mismatches.append(
            OwnerTruthMigrationParityViewStateMismatch(
                code: dimension.code,
                dimension: dimension,
                legacyFingerprint: legacy,
                v4Fingerprint: v4,
                m08DispositionStatus: .notApplicable
            )
        )
    }

    private static func m08DispositionStatus(
        surface: OwnerTruthMigrationParitySurface,
        legacyPresentationHash: OwnerTruthMigrationParityDigest,
        v4PresentationHash: OwnerTruthMigrationParityDigest,
        dispositions: [OwnerTruthMigrationParityM08Disposition],
        at date: Date
    ) -> OwnerTruthMigrationParityM08DispositionStatus {
        let matchingDispositions = dispositions.filter {
            $0.surface == surface
                && $0.legacyPresentationHash == legacyPresentationHash
                && $0.v4PresentationHash == v4PresentationHash
        }
        guard !matchingDispositions.isEmpty else { return .unapproved }
        return matchingDispositions.contains {
            $0.covers(
                surface: surface,
                legacyPresentationHash: legacyPresentationHash,
                v4PresentationHash: v4PresentationHash,
                at: date
            )
        } ? .approved : .expired
    }

    private static func optionalFingerprint(
        _ value: OwnerTruthMigrationParityDigest?
    ) -> OwnerTruthMigrationParityDigest {
        value ?? fingerprint("owner-truth-migration-parity-absent-v1")
    }

    private static func fingerprint(_ value: String) -> OwnerTruthMigrationParityDigest {
        OwnerTruthMigrationParityDigest.make("owner-truth-migration-parity-v1|\(value)")
    }
}
