import Foundation
import UIKit

enum DigitalHumanSessionState: Equatable {
    case idle
    case preparing
    case connecting
    case ready
    case listening
    case thinking
    case buffering
    case speaking(requestID: String)
    case interrupting
    case reconnecting
    case degraded
    case failed(code: String)
    case closed
}

struct DigitalHumanProfile: Equatable {
    var provider: String
    var personaId: String
    var displayName: String
    var lifecycleMode: DigitalHumanMode
    var driveMode: String
    var alphaEnabled: Bool
    var smartActionEnabled: Bool
    var assetKey: String?

    init(
        provider: String,
        personaId: String,
        displayName: String,
        lifecycleMode: DigitalHumanMode,
        driveMode: String = "streamText",
        alphaEnabled: Bool = true,
        smartActionEnabled: Bool = false,
        assetKey: String? = nil
    ) {
        self.provider = provider
        self.personaId = personaId
        self.displayName = displayName
        self.lifecycleMode = lifecycleMode
        self.driveMode = driveMode
        self.alphaEnabled = alphaEnabled
        self.smartActionEnabled = smartActionEnabled
        self.assetKey = assetKey
    }
}

/// Immutable authority carried by a voice or digital-human operation. The provider
/// never receives this whole value; adapters map only the backend contract fields.
struct VoiceDigitalHumanOperationScope: Equatable, Sendable {
    let accountLease: AccountLease
    let personaOwnerId: String
    let roleKey: String
    let runtimeGeneration: UInt64

    init?(
        accountLease: AccountLease,
        personaOwnerId: String,
        roleKey: String,
        runtimeGeneration: UInt64
    ) {
        let normalizedPersonaOwnerId = personaOwnerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRoleKey = roleKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPersonaOwnerId.isEmpty, !normalizedRoleKey.isEmpty else {
            return nil
        }
        self.accountLease = accountLease
        self.personaOwnerId = normalizedPersonaOwnerId
        self.roleKey = normalizedRoleKey
        self.runtimeGeneration = runtimeGeneration
    }

    var ownerUserId: String {
        accountLease.subjectId
    }
}

/// Value-minimized Authority data that may accompany a future backend contract.
/// It is observational only until the server and client share an enforceable
/// authority-epoch mapping.
struct VoiceDigitalHumanAuthorityEnvelope: Equatable, Sendable {
    let schemaVersion: Int
    let subjectId: String
    let vaultId: String
    let authorityEpoch: String
    let purpose: String
    let resourceKind: String
    let status: String
    let receiptIdHash: String

    init?(json: [String: Any]?) {
        guard let json,
              let schemaVersion = Self.intValue(json["schemaVersion"]),
              schemaVersion > 0,
              let subjectId = Self.opaqueIdentifier(json["subjectId"]),
              let vaultId = Self.opaqueIdentifier(json["vaultId"]),
              let authorityEpoch = Self.opaqueIdentifier(Self.stringValue(json["authorityEpoch"])),
              let purpose = Self.opaqueIdentifier(json["purpose"]),
              let resourceKind = Self.opaqueIdentifier(json["resourceKind"]),
              let status = Self.opaqueIdentifier(json["status"]),
              let receiptIdHash = Self.sha256(json["receiptIdHash"]) else {
            return nil
        }
        self.schemaVersion = schemaVersion
        self.subjectId = subjectId
        self.vaultId = vaultId
        self.authorityEpoch = authorityEpoch
        self.purpose = purpose
        self.resourceKind = resourceKind
        self.status = status
        self.receiptIdHash = receiptIdHash
    }

    private static func opaqueIdentifier(_ value: Any?) -> String? {
        guard let raw = value as? String else {
            return nil
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              normalized.count <= 128,
              normalized.unicodeScalars.allSatisfy({ scalar in
                  CharacterSet.alphanumerics.contains(scalar)
                      || scalar == "."
                      || scalar == "_"
                      || scalar == ":"
                      || scalar == "-"
              }) else {
            return nil
        }
        return normalized
    }

    private static func sha256(_ value: Any?) -> String? {
        guard let raw = value as? String else {
            return nil
        }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hexadecimal = CharacterSet(charactersIn: "0123456789abcdef")
        guard normalized.count == 64,
              normalized.unicodeScalars.allSatisfy({ hexadecimal.contains($0) }) else {
            return nil
        }
        return normalized
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int {
            return value
        }
        if let value = value as? NSNumber {
            return value.intValue
        }
        if let value = value as? String {
            return Int(value)
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let value = value as? String {
            return value
        }
        if let value = value as? NSNumber {
            return value.stringValue
        }
        return nil
    }
}

enum VoiceDigitalHumanAuthorityDecisionState: Equatable, Sendable {
    case unavailable
    case subjectMismatch
    case vaultMismatch
    case defaultDenied
    case observedDefaultDeny
}

struct VoiceDigitalHumanAuthorityDecision: Equatable, Sendable {
    let state: VoiceDigitalHumanAuthorityDecisionState
    let authority: VoiceDigitalHumanAuthorityEnvelope?
    let providerEffectAllowed: Bool = false
    let runtimePromotionAllowed: Bool = false
}

enum VoiceDigitalHumanAuthorityAdapter {
    static func decide(
        authority: VoiceDigitalHumanAuthorityEnvelope?,
        accountLease: AccountLease
    ) -> VoiceDigitalHumanAuthorityDecision {
        guard let authority else {
            return VoiceDigitalHumanAuthorityDecision(state: .unavailable, authority: nil)
        }
        guard authority.subjectId == accountLease.subjectId else {
            return VoiceDigitalHumanAuthorityDecision(state: .subjectMismatch, authority: authority)
        }
        guard authority.vaultId == accountLease.vaultId else {
            return VoiceDigitalHumanAuthorityDecision(state: .vaultMismatch, authority: authority)
        }
        guard !authority.authorityEpoch.isEmpty, authority.status == "blocked" else {
            return VoiceDigitalHumanAuthorityDecision(state: .defaultDenied, authority: authority)
        }
        return VoiceDigitalHumanAuthorityDecision(state: .observedDefaultDeny, authority: authority)
    }
}

struct VoiceCloneSynthesisRequest: Equatable, Sendable {
    let scope: VoiceDigitalHumanOperationScope
    let voiceProfileId: String
    let text: String
    let audioFormat: String
    let sampleRate: Int
    let speechRate: Int
    let loudnessRate: Int
    let outputMode: String?

    init?(
        scope: VoiceDigitalHumanOperationScope,
        voiceProfileId: String,
        text: String,
        audioFormat: String,
        sampleRate: Int,
        speechRate: Int,
        loudnessRate: Int,
        outputMode: String? = nil
    ) {
        let normalizedVoiceProfileId = voiceProfileId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAudioFormat = audioFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOutputMode = outputMode?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedVoiceProfileId.isEmpty,
              !normalizedText.isEmpty,
              !normalizedAudioFormat.isEmpty,
              sampleRate > 0 else {
            return nil
        }
        self.scope = scope
        self.voiceProfileId = normalizedVoiceProfileId
        self.text = normalizedText
        self.audioFormat = normalizedAudioFormat
        self.sampleRate = sampleRate
        self.speechRate = speechRate
        self.loudnessRate = loudnessRate
        self.outputMode = normalizedOutputMode?.isEmpty == false ? normalizedOutputMode : nil
    }

    var ownerUserId: String {
        scope.ownerUserId
    }
}

struct DigitalHumanSessionRequest: Equatable, Sendable {
    let scope: VoiceDigitalHumanOperationScope
    let scene: String
    let deviceId: String
    let lifecycleMode: DigitalHumanMode

    init?(
        scope: VoiceDigitalHumanOperationScope,
        scene: String,
        deviceId: String,
        lifecycleMode: DigitalHumanMode
    ) {
        let normalizedScene = scene.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDeviceId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedScene.isEmpty, !normalizedDeviceId.isEmpty else {
            return nil
        }
        self.scope = scope
        self.scene = normalizedScene
        self.deviceId = normalizedDeviceId
        self.lifecycleMode = lifecycleMode
    }

    var ownerUserId: String {
        scope.ownerUserId
    }

    var personaId: String {
        scope.personaOwnerId
    }
}

struct DigitalHumanSessionLeaseOperationRequest {
    let accountLease: AccountLease
    let contract: DigitalHumanSessionContract
    let reason: String?

    init(
        accountLease: AccountLease,
        contract: DigitalHumanSessionContract,
        reason: String? = nil
    ) {
        self.accountLease = accountLease
        self.contract = contract
        self.reason = reason
    }

    var isAccountBound: Bool {
        contract.userId.trimmingCharacters(in: .whitespacesAndNewlines) == accountLease.subjectId
    }
}

enum VoiceDigitalHumanClientPortError: Error, Equatable {
    case accountContractMismatch
}

protocol VoiceCloneSynthesisClientPort: AnyObject {
    var isVoiceCloneSynthesisConfigured: Bool { get }

    func fetchVoiceCloneRuntimeCapability(
        completion: @escaping (Result<VoiceCloneRuntimeCapability, Error>) -> Void
    )

    func requestVoiceCloneSynthesis(
        _ request: VoiceCloneSynthesisRequest,
        completion: @escaping (Result<VoiceCloneSynthesisResult, Error>) -> Void
    )
}

protocol DigitalHumanSessionClientPort: AnyObject {
    func createDigitalHumanSession(
        _ request: DigitalHumanSessionRequest,
        completion: @escaping (Result<DigitalHumanSessionContract, Error>) -> Void
    )

    func heartbeatDigitalHumanSession(
        _ request: DigitalHumanSessionLeaseOperationRequest,
        completion: @escaping (Result<DigitalHumanSessionLeaseOperationResult, Error>) -> Void
    )

    func releaseDigitalHumanSession(
        _ request: DigitalHumanSessionLeaseOperationRequest,
        completion: @escaping (Result<DigitalHumanSessionLeaseOperationResult, Error>) -> Void
    )
}

extension DreamJourneyBackendClient: VoiceCloneSynthesisClientPort, DigitalHumanSessionClientPort {
    func requestVoiceCloneSynthesis(
        _ request: VoiceCloneSynthesisRequest,
        completion: @escaping (Result<VoiceCloneSynthesisResult, Error>) -> Void
    ) {
        requestVoiceCloneSynthesis(
            userId: request.ownerUserId,
            voiceProfileId: request.voiceProfileId,
            text: request.text,
            audioFormat: request.audioFormat,
            sampleRate: request.sampleRate,
            speechRate: request.speechRate,
            loudnessRate: request.loudnessRate,
            outputMode: request.outputMode,
            completion: completion
        )
    }

    func createDigitalHumanSession(
        _ request: DigitalHumanSessionRequest,
        completion: @escaping (Result<DigitalHumanSessionContract, Error>) -> Void
    ) {
        createDigitalHumanSession(
            userId: request.ownerUserId,
            personaId: request.personaId,
            scene: request.scene,
            deviceId: request.deviceId,
            lifecycleMode: request.lifecycleMode,
            completion: completion
        )
    }

    func heartbeatDigitalHumanSession(
        _ request: DigitalHumanSessionLeaseOperationRequest,
        completion: @escaping (Result<DigitalHumanSessionLeaseOperationResult, Error>) -> Void
    ) {
        guard request.isAccountBound else {
            completion(.failure(VoiceDigitalHumanClientPortError.accountContractMismatch))
            return
        }
        heartbeatDigitalHumanSession(request.contract, completion: completion)
    }

    func releaseDigitalHumanSession(
        _ request: DigitalHumanSessionLeaseOperationRequest,
        completion: @escaping (Result<DigitalHumanSessionLeaseOperationResult, Error>) -> Void
    ) {
        guard request.isAccountBound else {
            completion(.failure(VoiceDigitalHumanClientPortError.accountContractMismatch))
            return
        }
        releaseDigitalHumanSession(
            request.contract,
            reason: request.reason ?? "runtimeRelease",
            completion: completion
        )
    }
}

protocol DigitalHumanRuntime: AnyObject {
    var contentView: UIView { get }
    var state: DigitalHumanSessionState { get }
    var profile: DigitalHumanProfile? { get }
    var onStateChange: ((DigitalHumanSessionState) -> Void)? { get set }

    func configure(_ profile: DigitalHumanProfile) throws
    func open() throws
    func sendTextChunk(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws
    func sendPCMChunk(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws
    func interrupt()
    func close()
}

enum DigitalHumanRuntimeError: Error, Equatable {
    case missingProfile
    case silentModeDisabled
    case unsupportedOperation(String)
}
