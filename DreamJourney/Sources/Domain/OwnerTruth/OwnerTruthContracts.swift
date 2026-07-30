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
    case invalidInterviewCandidateReview(String)
    case invalidInterviewCandidateConfirmation(String)
    case invalidInterviewCandidateDecision(String)
    case invalidInterviewSessionState(String)
    case invalidInterviewOrchestration(String)
    case invalidInterviewNaturalInput(String)
    case invalidKnowledgeDimensionConfirmation(String)
    case invalidKnowledgeRecommendationPlan(String)
    case invalidKBLiteCompatibilityReadEnvelope(String)
    case invalidContextCitationShadowBuild(String)
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
        case .invalidInterviewCandidateReview(let detail):
            return "访谈候选审核合同无效：\(detail)"
        case .invalidInterviewCandidateConfirmation(let detail):
            return "访谈候选确认合同无效：\(detail)"
        case .invalidInterviewCandidateDecision(let detail):
            return "访谈候选审核回执合同无效：\(detail)"
        case .invalidInterviewSessionState(let detail):
            return "访谈会话状态合同无效：\(detail)"
        case .invalidInterviewOrchestration(let detail):
            return "访谈编排合同无效：\(detail)"
        case .invalidInterviewNaturalInput(let detail):
            return "访谈自然输入合同无效：\(detail)"
        case .invalidKnowledgeDimensionConfirmation(let detail):
            return "知识维度确认合同无效：\(detail)"
        case .invalidKnowledgeRecommendationPlan(let detail):
            return "知识推荐合同无效：\(detail)"
        case .invalidKBLiteCompatibilityReadEnvelope(let detail):
            return "兼容读取合同无效：\(detail)"
        case .invalidContextCitationShadowBuild(let detail):
            return "上下文引用合同无效：\(detail)"
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
        for key in ["summary", "title", "text"] {
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
        for key in ["summary", "title", "text"] where candidate.content[key] != nil {
            return key
        }
        return "summary"
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
        case .failure:
            transitionFailure()
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
        case .failure:
            transitionFailure(.requestFailed)
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
        case .failure:
            transitionFailure(.reconciliationFailed, latestResult: actionResult)
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
            receipt = parsedReceipt
        } else {
            receipt = nil
        }
        vaultID = expectedVaultID
    }
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

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID
    ) throws {
        guard let commandID = OwnerTruthInterviewNaturalInputContract.nonEmptyString(commandID) else {
            throw OwnerTruthRemoteContractError.invalidInterviewNaturalInput(
                "start command id must be non-empty"
            )
        }
        self.commandID = commandID
        self.threadID = threadID
        self.sessionID = sessionID
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "sessionId": sessionID.rawValue.uuidString.lowercased(),
        ]
    }
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

    init(
        commandID: String,
        threadID: OwnerTruthRecordID,
        sessionID: OwnerTruthRecordID,
        messageID: OwnerTruthRecordID,
        expectedThreadVersion: Int,
        expectedSessionVersion: Int,
        text: String
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
    }

    var backendPayload: [String: Any] {
        [
            "commandId": commandID,
            "threadId": threadID.rawValue.uuidString.lowercased(),
            "messageId": messageID.rawValue.uuidString.lowercased(),
            "expectedThreadVersion": expectedThreadVersion,
            "expectedSessionVersion": expectedSessionVersion,
            "text": text,
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
        identifierFactory: @escaping () -> UUID = UUID.init
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.identifierFactory = identifierFactory
    }

    func send(_ intent: OwnerTruthInterviewNaturalInputIntent) {
        switch intent {
        case .start:
            start()
        case .submit(let text):
            submit(text: text)
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
                sessionID: OwnerTruthRecordID(rawValue: identifierFactory())
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
            guard receipt.outcome == .resumed,
                  receipt.lifecycle == .active,
                  receipt.messageID == nil,
                  receipt.messageSequence == nil else {
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
            // Failing closed is important here: creating a fresh session after
            // a failed current-session read could bypass an existing boundary.
            transitionFailure(.requestFailed)
        }
    }

    private func submit(text: String) {
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
                text: text
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

enum OwnerTruthCandidateReviewIntent: Equatable, Sendable {
    case refresh
    case accept(candidateID: OwnerTruthRecordID)
    case correct(candidateID: OwnerTruthRecordID, correctedSummary: String)
    case reject(candidateID: OwnerTruthRecordID)
}

enum OwnerTruthCandidateInboxPhase: Equatable, Sendable {
    case idle
    case unavailable
    case loading
    case ready
    case empty
    case submitting(OwnerTruthRecordID)
    case failed
}

enum OwnerTruthCandidateInboxNotice: Equatable, Sendable {
    case qaOnlyDisabled
    case accountUnavailable
    case staleAccountLease
    case invalidVault
    case candidateUnavailable
    case correctionRequired
    case reviewResultMismatch
    case requestFailed
    case candidateAccepted
    case candidateCorrected
    case candidateRejected
}

struct OwnerTruthCandidateInboxItemViewState: Equatable, Sendable, Identifiable {
    let id: OwnerTruthRecordID
    let proposalPreview: String
    let memoryKind: OwnerTruthMemoryKind
    let perspective: OwnerTruthPerspectiveType
    let epistemicStatus: OwnerTruthEpistemicStatus
    let sensitivity: OwnerTruthSensitivityLevel
    let evidenceCount: Int
    let reviewMode: String
    let candidateVersion: Int
    let supportsCorrection: Bool
}

struct OwnerTruthCandidateReviewReceiptViewState: Equatable, Sendable {
    let candidateID: OwnerTruthRecordID
    let decision: OwnerTruthCandidateDecision
    let outcome: OwnerTruthCommandOutcome
    let createdMemoryVersion: Bool
}

struct OwnerTruthCandidateInboxViewState: Equatable, Sendable {
    let phase: OwnerTruthCandidateInboxPhase
    let items: [OwnerTruthCandidateInboxItemViewState]
    let notice: OwnerTruthCandidateInboxNotice?
    let latestReceipt: OwnerTruthCandidateReviewReceiptViewState?

    static let idle = OwnerTruthCandidateInboxViewState(
        phase: .idle,
        items: [],
        notice: nil,
        latestReceipt: nil
    )
}

/// QA-only application boundary for Candidate review. It never accepts an
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

    private var candidatesByID: [OwnerTruthRecordID: OwnerTruthCandidateInboxItem] = [:]
    private var orderedCandidateIDs: [OwnerTruthRecordID] = []
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
        commandIDFactory: @escaping CommandIDFactory = { UUID().uuidString.lowercased() }
    ) {
        self.accountLease = accountLease
        self.vaultID = OwnerTruthVaultID(accountLease.vaultId)
        self.client = client
        self.accountLeaseRuntime = accountLeaseRuntime
        self.qaGateEnabled = qaGateEnabled
        self.commandIDFactory = commandIDFactory
    }

    func send(_ intent: OwnerTruthCandidateReviewIntent) {
        switch intent {
        case .refresh:
            refresh()
        case .accept(let candidateID):
            submit(candidateID: candidateID, action: .accept, correctedSummary: nil)
        case .correct(let candidateID, let correctedSummary):
            submit(candidateID: candidateID, action: .correct, correctedSummary: correctedSummary)
        case .reject(let candidateID):
            submit(candidateID: candidateID, action: .reject, correctedSummary: nil)
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
            latestReceipt: nil
        )
        client.fetchOwnerTruthCandidateInbox(vaultID: vaultID) { [weak self] result in
            self?.receiveInbox(result, vaultID: vaultID, generation: generation)
        }
    }

    private func submit(
        candidateID: OwnerTruthRecordID,
        action: OwnerTruthCandidateReviewAction,
        correctedSummary: String?
    ) {
        guard let vaultID = beginRequestOrFail() else { return }
        guard let candidate = candidatesByID[candidateID] else {
            transitionFailure(.candidateUnavailable)
            return
        }
        guard let command = makeCommand(
            candidate: candidate,
            action: action,
            correctedSummary: correctedSummary
        ) else {
            return
        }

        operationGeneration &+= 1
        let generation = operationGeneration
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .submitting(candidateID),
            items: currentItems,
            notice: nil,
            latestReceipt: nil
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
        correctedSummary: String?
    ) -> OwnerTruthCandidateReviewCommand? {
        do {
            switch action {
            case .accept:
                return try OwnerTruthCandidateReviewCommand(
                    commandID: commandIDFactory(),
                    expectedCandidateVersion: candidate.candidateVersion,
                    action: .accept,
                    reasonCode: "ownerReviewed"
                )
            case .reject:
                return try OwnerTruthCandidateReviewCommand(
                    commandID: commandIDFactory(),
                    expectedCandidateVersion: candidate.candidateVersion,
                    action: .reject,
                    reasonCode: "ownerReviewed"
                )
            case .correct:
                let normalizedSummary = correctedSummary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !normalizedSummary.isEmpty else {
                    transitionFailure(.correctionRequired)
                    return nil
                }
                var correctedValue = candidate.content
                correctedValue[Self.correctionTextKey(for: candidate)] = .string(normalizedSummary)
                return try OwnerTruthCandidateReviewCommand(
                    commandID: commandIDFactory(),
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
            var nextCandidates: [OwnerTruthRecordID: OwnerTruthCandidateInboxItem] = [:]
            for candidate in inbox.candidates {
                guard nextCandidates[candidate.id] == nil else {
                    transitionFailure(.requestFailed)
                    return
                }
                nextCandidates[candidate.id] = candidate
            }
            candidatesByID = nextCandidates
            orderedCandidateIDs = inbox.candidates.map(\.id)
            viewState = OwnerTruthCandidateInboxViewState(
                phase: inbox.candidates.isEmpty ? .empty : .ready,
                items: currentItems,
                notice: nil,
                latestReceipt: nil
            )
        case .failure:
            transitionFailure(.requestFailed)
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
            let receipt = OwnerTruthCandidateReviewReceiptViewState(
                candidateID: candidate.id,
                decision: decision.receipt.decision,
                outcome: decision.outcome,
                createdMemoryVersion: decision.memoryActivation.memoryVersionID != nil
            )
            viewState = OwnerTruthCandidateInboxViewState(
                phase: orderedCandidateIDs.isEmpty ? .empty : .ready,
                items: currentItems,
                notice: Self.successNotice(for: expectedAction),
                latestReceipt: receipt
            )
        case .failure:
            transitionFailure(.requestFailed)
        }
    }

    private var currentItems: [OwnerTruthCandidateInboxItemViewState] {
        orderedCandidateIDs.compactMap { candidateID in
            guard let candidate = candidatesByID[candidateID] else { return nil }
            return OwnerTruthCandidateInboxItemViewState(
                id: candidate.id,
                proposalPreview: Self.proposalPreview(for: candidate),
                memoryKind: candidate.memoryKind,
                perspective: candidate.perspective,
                epistemicStatus: candidate.epistemicStatus,
                sensitivity: candidate.sensitivity,
                evidenceCount: candidate.sourceReferences.count,
                reviewMode: candidate.reviewMode,
                candidateVersion: candidate.candidateVersion,
                supportsCorrection: true
            )
        }
    }

    private func resetForUnavailable(_ notice: OwnerTruthCandidateInboxNotice) {
        operationGeneration &+= 1
        candidatesByID.removeAll()
        orderedCandidateIDs.removeAll()
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .unavailable,
            items: [],
            notice: notice,
            latestReceipt: nil
        )
    }

    private func transitionFailure(_ notice: OwnerTruthCandidateInboxNotice) {
        viewState = OwnerTruthCandidateInboxViewState(
            phase: .failed,
            items: currentItems,
            notice: notice,
            latestReceipt: nil
        )
    }

    private static func proposalPreview(for candidate: OwnerTruthCandidateInboxItem) -> String {
        for key in ["summary", "title", "text"] {
            guard case .string(let rawValue)? = candidate.content[key] else { continue }
            let normalized = rawValue
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalized.isEmpty {
                return String(normalized.prefix(160))
            }
        }
        return "待确认记忆"
    }

    private static func correctionTextKey(for candidate: OwnerTruthCandidateInboxItem) -> String {
        for key in ["summary", "title", "text"] where candidate.content[key] != nil {
            return key
        }
        return "summary"
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
        case .idle, .loading, .submitting:
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
