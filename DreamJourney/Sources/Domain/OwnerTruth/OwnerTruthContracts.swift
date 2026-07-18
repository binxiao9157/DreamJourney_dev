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

enum OwnerTruthContractError: Error, Equatable, Sendable {
    case terminalDecisionImmutable
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
