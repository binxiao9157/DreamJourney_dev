import Foundation

let narrativeCommandSchemaVersion = "narrative-command-v1"
let narrativeErrorSchemaVersion = "narrative-error-v1"
let narrativeFixtureSchemaVersion = "narrative-contract-fixture-v1"

enum BookProjectType: String, CaseIterable, Codable, Sendable {
    case selfAutobiography
    case taStory
}

enum NarrativeNarratorType: String, CaseIterable, Codable, Sendable {
    case selfFirstPerson
    case thirdPersonBiography
    case controllerWitness
}

enum BookProjectState: String, CaseIterable, Codable, Sendable {
    case notStarted
    case checkingReadiness
    case needsMoreMemory
    case readyForConfirmation
    case generatingAuditions
    case auditionsReady
    case generatingGoldenSample
    case goldenSampleReview
    case toneConfirmed
    case outlineReview
    case writing
    case updateAvailable
    case paused
    case disputed
    case suspended
    case archived
    case deleted
}

enum NarrativeArtifactType: String, CaseIterable, Codable, Sendable {
    case writingAudition
    case goldenSample
    case narrativeStyleProfile
    case writingConstitution
    case outline
    case chapter
}

enum NarrativeArtifactState: String, CaseIterable, Codable, Sendable {
    case draft
    case readyForReview
    case confirmed
    case final
    case stale
    case superseded
}

enum NarrativeCommandType: String, CaseIterable, Codable, Sendable {
    case confirmSetup
    case generateAuditions
    case selectAudition
    case generateGoldenSample
    case submitArtifactFeedback
    case confirmGoldenSample
    case generateOutline
    case reviseOutline
    case confirmOutline
    case generateChapter
    case reviseChapter
    case finalizeChapter
    case editArtifact
    case restoreArtifactVersion
    case adoptMemoryUpdate
    case ignoreMemoryUpdate
    case pauseProject
    case resumeProject
    case archiveProject
}

enum NarrativeJobState: String, CaseIterable, Codable, Sendable {
    case queued
    case snapshotting
    case retrieving
    case planning
    case drafting
    case validatingFacts
    case editingStyle
    case finalValidation
    case readyForReview
    case needsEcho
    case failed
    case cancelled
    case superseded
}

enum NarrativeErrorCode: String, CaseIterable, Codable, Sendable {
    case jobAccepted = "job_accepted"
    case releasePolicyDenied = "release_policy_denied"
    case capabilityUnavailable = "capability_unavailable"
    case resourceNotFound = "resource_not_found"
    case projectVersionConflict = "project_version_conflict"
    case invalidState = "invalid_state"
    case memorySnapshotStale = "memory_snapshot_stale"
    case contractInvalid = "contract_invalid"
    case unsupportedFactDetected = "unsupported_fact_detected"
    case providerUnavailable = "provider_unavailable"
}

enum NarrativeContractError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(String)
    case negativeProjectVersion
    case blankMessage
}

enum NarrativeJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int)
    case number(Double)
    case boolean(Bool)
    case object([String: NarrativeJSONValue])
    case array([NarrativeJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: NarrativeJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([NarrativeJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported narrative JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct NarrativeCommandEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: String
    let commandID: UUID
    let commandType: NarrativeCommandType
    let expectedProjectVersion: Int
    let confirmed: Bool
    let payload: [String: NarrativeJSONValue]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case commandID = "commandId"
        case commandType
        case expectedProjectVersion
        case confirmed
        case payload
    }

    init(
        commandID: UUID,
        commandType: NarrativeCommandType,
        expectedProjectVersion: Int,
        confirmed: Bool,
        payload: [String: NarrativeJSONValue]
    ) throws {
        guard expectedProjectVersion >= 0 else {
            throw NarrativeContractError.negativeProjectVersion
        }
        self.schemaVersion = narrativeCommandSchemaVersion
        self.commandID = commandID
        self.commandType = commandType
        self.expectedProjectVersion = expectedProjectVersion
        self.confirmed = confirmed
        self.payload = payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == narrativeCommandSchemaVersion else {
            throw NarrativeContractError.unsupportedSchemaVersion(schemaVersion)
        }
        let expectedProjectVersion = try container.decode(Int.self, forKey: .expectedProjectVersion)
        guard expectedProjectVersion >= 0 else {
            throw NarrativeContractError.negativeProjectVersion
        }
        self.schemaVersion = schemaVersion
        self.commandID = try container.decode(UUID.self, forKey: .commandID)
        self.commandType = try container.decode(NarrativeCommandType.self, forKey: .commandType)
        self.expectedProjectVersion = expectedProjectVersion
        self.confirmed = try container.decode(Bool.self, forKey: .confirmed)
        self.payload = try container.decode([String: NarrativeJSONValue].self, forKey: .payload)
    }
}

struct NarrativeErrorEnvelope: Codable, Equatable, Sendable {
    let schemaVersion: String
    let errorCode: NarrativeErrorCode
    let message: String
    let retryable: Bool
    let currentProjectVersion: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(String.self, forKey: .schemaVersion)
        guard schemaVersion == narrativeErrorSchemaVersion else {
            throw NarrativeContractError.unsupportedSchemaVersion(schemaVersion)
        }
        let message = try container.decode(String.self, forKey: .message)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { throw NarrativeContractError.blankMessage }
        let currentProjectVersion = try container.decodeIfPresent(Int.self, forKey: .currentProjectVersion)
        guard currentProjectVersion.map({ $0 >= 0 }) ?? true else {
            throw NarrativeContractError.negativeProjectVersion
        }
        self.schemaVersion = schemaVersion
        self.errorCode = try container.decode(NarrativeErrorCode.self, forKey: .errorCode)
        self.message = message
        self.retryable = try container.decode(Bool.self, forKey: .retryable)
        self.currentProjectVersion = currentProjectVersion
    }
}

enum NarrativeWritingAccessPreflightError: Error, Equatable {
    case refreshFailed
    case unavailable
}

enum NarrativeWritingPolicyRefreshPolicy {
    private static let refreshableReasons: Set<String> = [
        "capturedPolicyExpired",
        "policyVersionChanged",
        "missingPolicyCache",
        "expiredPolicyCache",
    ]

    static func shouldRefresh(after reason: String) -> Bool {
        refreshableReasons.contains(reason)
    }
}

/// Rechecks server-owned release policy when a cold or expired cache denies
/// the writing entry. This never grants access locally; the refreshed server
/// decision remains the authority.
final class NarrativeWritingAccessPreflight {
    typealias AuthorizationCheck = () -> Bool
    typealias PolicyRefresh = (@escaping (Bool) -> Void) -> Void
    typealias Completion = (Result<Void, NarrativeWritingAccessPreflightError>) -> Void

    private let isAuthorized: AuthorizationCheck
    private let refreshPolicy: PolicyRefresh

    init(
        isAuthorized: @escaping AuthorizationCheck,
        refreshPolicy: @escaping PolicyRefresh
    ) {
        self.isAuthorized = isAuthorized
        self.refreshPolicy = refreshPolicy
    }

    func authorize(completion: @escaping Completion) {
        guard !isAuthorized() else {
            completion(.success(()))
            return
        }

        refreshPolicy { [isAuthorized] refreshed in
            guard refreshed else {
                completion(.failure(.refreshFailed))
                return
            }
            guard isAuthorized() else {
                completion(.failure(.unavailable))
                return
            }
            completion(.success(()))
        }
    }
}
