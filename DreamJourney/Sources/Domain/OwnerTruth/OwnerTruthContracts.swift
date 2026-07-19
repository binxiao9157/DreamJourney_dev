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
    case invalidKBLiteCompatibilityReadEnvelope(String)

    var errorDescription: String? {
        switch self {
        case .invalidInbox(let detail):
            return "候选收件箱合同无效：\(detail)"
        case .invalidDecision(let detail):
            return "候选审核回执合同无效：\(detail)"
        case .invalidCommand(let detail):
            return "候选审核命令无效：\(detail)"
        case .invalidKBLiteCompatibilityReadEnvelope(let detail):
            return "兼容读取合同无效：\(detail)"
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
