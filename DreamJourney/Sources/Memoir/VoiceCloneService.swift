import CocoaLumberjack
import CryptoKit
import Foundation

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
import UIKit
#endif

enum VoiceCloneSampleStatus: String, Codable {
    case notProvided
    case pending
    case ready
    case disabled
    case deleted
    case failed

    var displayText: String {
        switch self {
        case .notProvided:
            return "未提供声音样本"
        case .pending:
            return "样本待审核"
        case .ready:
            return "样本可用"
        case .disabled:
            return "样本已禁用"
        case .deleted:
            return "样本已删除"
        case .failed:
            return "样本处理失败"
        }
    }
}

struct VoiceCloneProfileSnapshot {
    let voiceProfileId: String
    let sampleStatus: VoiceCloneSampleStatus
    let authorizationCopy: String
    let isEnabled: Bool
    let realCloneProviderReady: Bool
    let qualityAcceptanceRequired: Bool
    let disableContract: String
    let deleteContract: String
    let providerMode: String
    let providerStatus: String
    let providerMessage: String
    let contractVersion: Int
    let defaultReleaseVisible: Bool
    let providerBindingMode: String
    let providerSlotManaged: Bool
    let providerSlotState: String
    let exitState: String
    let accessRevoked: Bool
    let localCleanupState: String
    let providerCleanupState: String
    let providerCleanupReceiptAvailable: Bool
    let lifecycleSchemaVersion: String?
    let lifecycleState: VoiceProfileLifecycleState?
    let profileVersion: Int
    let retryGeneration: Int
    let stateChangedAt: String?
    let eligibilityAllowed: Bool
    let eligibilityReasonCode: String
    let consentPurpose: String?
    let consentState: String
    let consentExpiresAt: String?
    let allowedOperations: Set<String>

    init(
        voiceProfileId: String,
        sampleStatus: VoiceCloneSampleStatus,
        authorizationCopy: String,
        isEnabled: Bool,
        realCloneProviderReady: Bool = false,
        qualityAcceptanceRequired: Bool = true,
        disableContract: String,
        deleteContract: String,
        providerMode: String = "localFallback",
        providerStatus: String = "",
        providerMessage: String = "",
        contractVersion: Int = 1,
        defaultReleaseVisible: Bool = true,
        providerBindingMode: String = "unassigned",
        providerSlotManaged: Bool = false,
        providerSlotState: String = "",
        exitState: String = "",
        accessRevoked: Bool? = nil,
        localCleanupState: String = "",
        providerCleanupState: String = "",
        providerCleanupReceiptAvailable: Bool = false,
        lifecycleSchemaVersion: String? = nil,
        lifecycleState: VoiceProfileLifecycleState? = nil,
        profileVersion: Int = 0,
        retryGeneration: Int = 0,
        stateChangedAt: String? = nil,
        eligibilityAllowed: Bool = false,
        eligibilityReasonCode: String = "unavailable",
        consentPurpose: String? = nil,
        consentState: String = "missing",
        consentExpiresAt: String? = nil,
        allowedOperations: Set<String> = []
    ) {
        self.voiceProfileId = voiceProfileId
        self.sampleStatus = sampleStatus
        self.authorizationCopy = authorizationCopy
        self.isEnabled = isEnabled
        self.realCloneProviderReady = realCloneProviderReady
        self.qualityAcceptanceRequired = qualityAcceptanceRequired
        self.disableContract = disableContract
        self.deleteContract = deleteContract
        self.providerMode = providerMode
        self.providerStatus = providerStatus
        self.providerMessage = providerMessage
        self.contractVersion = contractVersion
        self.defaultReleaseVisible = defaultReleaseVisible
        self.providerBindingMode = providerBindingMode
        self.providerSlotManaged = providerSlotManaged
        self.providerSlotState = providerSlotState
        self.exitState = exitState.isEmpty ? Self.defaultExitState(for: sampleStatus) : exitState
        self.accessRevoked = accessRevoked ?? (sampleStatus == .disabled || sampleStatus == .deleted)
        self.localCleanupState = localCleanupState.isEmpty ? Self.defaultLocalCleanupState(for: sampleStatus) : localCleanupState
        self.providerCleanupState = providerCleanupState.isEmpty ? Self.defaultProviderCleanupState(for: sampleStatus) : providerCleanupState
        self.providerCleanupReceiptAvailable = providerCleanupReceiptAvailable
        self.lifecycleSchemaVersion = lifecycleSchemaVersion
        self.lifecycleState = lifecycleState
        self.profileVersion = profileVersion
        self.retryGeneration = max(retryGeneration, 0)
        self.stateChangedAt = stateChangedAt
        self.eligibilityAllowed = eligibilityAllowed
        self.eligibilityReasonCode = eligibilityReasonCode
        self.consentPurpose = consentPurpose
        self.consentState = consentState
        self.consentExpiresAt = consentExpiresAt
        self.allowedOperations = allowedOperations
    }

    init(backendContract: VoiceCloneProfileContract) {
        self.init(
            voiceProfileId: backendContract.voiceProfileId,
            sampleStatus: backendContract.sampleStatus,
            authorizationCopy: backendContract.authorizationCopy,
            isEnabled: backendContract.isEnabled,
            realCloneProviderReady: backendContract.realCloneProviderReady,
            qualityAcceptanceRequired: backendContract.qualityAcceptanceRequired,
            disableContract: backendContract.disableContract,
            deleteContract: backendContract.deleteContract,
            providerMode: backendContract.providerMode,
            providerStatus: backendContract.providerStatus,
            providerMessage: backendContract.providerMessage,
            contractVersion: backendContract.contractVersion,
            defaultReleaseVisible: backendContract.defaultReleaseVisible,
            providerBindingMode: backendContract.providerBindingMode,
            providerSlotManaged: backendContract.providerSlotManaged,
            providerSlotState: backendContract.providerSlotState,
            exitState: backendContract.exitState,
            accessRevoked: backendContract.accessRevoked,
            localCleanupState: backendContract.localCleanupState,
            providerCleanupState: backendContract.providerCleanupState,
            providerCleanupReceiptAvailable: backendContract.providerCleanupReceiptAvailable,
            lifecycleSchemaVersion: backendContract.lifecycleSchemaVersion,
            lifecycleState: backendContract.lifecycleState,
            profileVersion: backendContract.profileVersion,
            retryGeneration: backendContract.retryGeneration,
            stateChangedAt: backendContract.stateChangedAt,
            eligibilityAllowed: backendContract.eligibility.isAllowed,
            eligibilityReasonCode: backendContract.eligibility.reasonCode,
            consentPurpose: backendContract.consent.purpose,
            consentState: backendContract.consent.state,
            consentExpiresAt: backendContract.consent.expiresAt,
            allowedOperations: backendContract.allowedOperations
        )
    }

    var exitDisclosureText: String {
        switch exitState {
        case "accessRevoked":
            return "该音色已暂停用于回响，不会再用于新的回响合成。"
        case "pending":
            return "该音色已停止用于回响，正在等待第三方服务确认清理结果。"
        case "partial":
            if providerCleanupReceiptAvailable {
                return "该音色已停止用于回响，部分第三方清理结果仍待完成。"
            }
            return "该音色已停止用于回响。本地记录已标记删除，第三方服务清理结果尚待确认。"
        case "completed":
            return "该音色已停止用于回响，第三方服务已确认完成清理。"
        case "unsupported":
            return "该音色已停止用于回响。第三方服务暂不支持返回清理结果。"
        default:
            return ""
        }
    }

    var isUseRevoked: Bool {
        accessRevoked
            || sampleStatus == .disabled
            || sampleStatus == .deleted
            || lifecycleState == .paused
            || lifecycleState == .deleting
            || lifecycleState == .deleted
    }

    var canDisableRemotely: Bool {
        hasCanonicalLifecycleContract
            && !isUseRevoked
            && allowedOperations.contains("disable")
    }

    var canDeleteRemotely: Bool {
        hasCanonicalLifecycleContract
            && lifecycleState != .deleting
            && lifecycleState != .deleted
            && sampleStatus != .deleted
            && allowedOperations.contains("delete")
    }

    var canRefreshExitState: Bool {
        hasCanonicalLifecycleContract
            && (
                lifecycleState == .deleting
                    || (lifecycleState == .deleted && exitState != "completed")
            )
    }

    private var hasCanonicalLifecycleContract: Bool {
        lifecycleSchemaVersion == "voice-profile-lifecycle-v1" && lifecycleState != nil
    }

    private static func defaultExitState(for sampleStatus: VoiceCloneSampleStatus) -> String {
        switch sampleStatus {
        case .disabled:
            return "accessRevoked"
        case .deleted:
            return "partial"
        default:
            return "active"
        }
    }

    private static func defaultLocalCleanupState(for sampleStatus: VoiceCloneSampleStatus) -> String {
        sampleStatus == .deleted ? "tombstoned" : (sampleStatus == .disabled ? "retained" : "notRequested")
    }

    private static func defaultProviderCleanupState(for sampleStatus: VoiceCloneSampleStatus) -> String {
        sampleStatus == .deleted ? "unsupported" : "notRequested"
    }

    var isReadyForUse: Bool {
        lifecycleSchemaVersion == "voice-profile-lifecycle-v1"
            && lifecycleState == .accepted
            && sampleStatus == .ready
            && isEnabled
            && realCloneProviderReady
            && eligibilityAllowed
            && consentState == "active"
            && consentPurpose == "private_synthesis"
            && allowedOperations.contains("synthesize")
    }

    var canPreviewQuality: Bool {
        lifecycleSchemaVersion == "voice-profile-lifecycle-v1"
            && (lifecycleState == .previewReady || lifecycleState == .accepted)
            && sampleStatus == .ready
            && realCloneProviderReady
            && eligibilityAllowed
            && consentState == "active"
            && allowedOperations.contains("preview")
    }

    var canAcceptQuality: Bool {
        lifecycleSchemaVersion == "voice-profile-lifecycle-v1"
            && lifecycleState == .previewReady
            && eligibilityAllowed
            && consentState == "active"
            && allowedOperations.contains("accept")
    }

    var canRetryTraining: Bool {
        lifecycleSchemaVersion == "voice-profile-lifecycle-v1"
            && lifecycleState == .failed
            && sampleStatus == .failed
            && !accessRevoked
            && allowedOperations.contains("retry")
    }

    var providerFailureDisplayText: String? {
        let trimmed = providerMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.localizedCaseInsensitiveContains("Invalid X-Api-Key") {
            return "服务器火山音色复刻 API Key 无效，请更新后端配置后重试。"
        }
        if trimmed.localizedCaseInsensitiveContains("resource not granted")
            || trimmed.localizedCaseInsensitiveContains("volc.megatts.timbre") {
            return "火山声音复刻资源未授权。请在服务器确认音色模式：预付费/免费音色需配置 consoleSpeakerId 和控制台生成的 S_ 音色 ID；后付费自定义音色需开通 volc.megatts.timbre 资源权限。"
        }
        return trimmed
    }
}

// MARK: - 声音复刻服务（后端代理火山引擎 Voice Clone V3）

private struct VoiceClonePersonaTarget: Equatable {
    let userId: String
    let personaScope: String
    let digitalHumanId: String
    let familyMemberId: String?

    var isFamilyMember: Bool {
        familyMemberId != nil
    }
}

/// A single in-process training operation. Provider work may finish after a
/// role/account transition, so every timer tick and completion must prove it
/// still belongs to the currently selected persona before it can update state.
private struct VoiceCloneTrainingRuntimeOperation: Equatable {
    let id: UUID
    let runtimeGeneration: UInt64
    let speakerId: String
    let target: VoiceClonePersonaTarget
    let accountLease: AccountLease
}

private struct VoiceCloneTrainingRetryRequest {
    let voiceProfileId: String
    let retryGeneration: Int
    let expectedProfileVersion: Int
}

/// A server-issued, short-lived statement that must be explicitly confirmed
/// before a selected voice sample can enter the training path. The receipt is
/// bound to one owner and one profile; the client never fabricates it.
struct VoiceCloneSampleAuthorizationPreparation {
    let voiceProfileId: String
    let authorization: VoiceCloneSampleAuthorizationContract
}

private struct VoiceCloneTrainingRuntimeCompletions {
    let primary: ((Result<String, VoiceCloneError>) -> Void)?
    let pending: ((Result<String, VoiceCloneError>) -> Void)?
}

private struct VoiceCloneLocalOwnerScope: Equatable {
    static let storeSchemaVersion = 2

    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID

    init?(accountLease: AccountLease) {
        let subjectId = accountLease.subjectId.trimmingCharacters(in: .whitespacesAndNewlines)
        let vaultId = accountLease.vaultId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subjectId.isEmpty, !vaultId.isEmpty else { return nil }
        self.subjectId = subjectId
        self.vaultId = vaultId
        generation = accountLease.generation
        generationId = accountLease.generationId
    }

    var storageKey: String {
        let identity = [
            "subject", subjectId,
            "vault", vaultId,
            "generation", String(generation),
            "generation-id", generationId.uuidString.lowercased(),
        ]
        let canonicalIdentity = identity
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonicalIdentity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "dj.voiceclone.localState.scoped.v2.\(digest)"
    }
}

private struct VoiceClonePersistedState: Codable, Equatable {
    var speakerId: String?
    var sampleStatus: VoiceCloneSampleStatus?
    var isEnabled: Bool?
    var realCloneProviderReady: Bool?
    var qualityAcceptanceRequired: Bool?
    var providerMode: String?
    var providerStatus: String?
    var providerMessage: String?
    var lifecycleSchemaVersion: String?
    var lifecycleStateRaw: String?
    var profileVersion: Int?
    var retryGeneration: Int?
    var stateChangedAt: String?
    var eligibilityAllowed: Bool?
    var eligibilityReasonCode: String?
    var consentPurpose: String?
    var consentState: String?
    var consentExpiresAt: String?
    var allowedOperations: [String]?

    static let empty = VoiceClonePersistedState(
        speakerId: nil,
        sampleStatus: nil,
        isEnabled: nil,
        realCloneProviderReady: nil,
        qualityAcceptanceRequired: nil,
        providerMode: nil,
        providerStatus: nil,
        providerMessage: nil,
        lifecycleSchemaVersion: nil,
        lifecycleStateRaw: nil,
        profileVersion: nil,
        retryGeneration: nil,
        stateChangedAt: nil,
        eligibilityAllowed: nil,
        eligibilityReasonCode: nil,
        consentPurpose: nil,
        consentState: nil,
        consentExpiresAt: nil,
        allowedOperations: nil
    )
}

private struct VoiceCloneLocalStateEnvelope: Codable, Equatable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let state: VoiceClonePersistedState

    init(state: VoiceClonePersistedState, scope: VoiceCloneLocalOwnerScope) {
        storeSchemaVersion = VoiceCloneLocalOwnerScope.storeSchemaVersion
        subjectId = scope.subjectId
        vaultId = scope.vaultId
        generation = scope.generation
        generationId = scope.generationId
        self.state = state
    }

    func matches(_ scope: VoiceCloneLocalOwnerScope) -> Bool {
        storeSchemaVersion == VoiceCloneLocalOwnerScope.storeSchemaVersion
            && subjectId == scope.subjectId
            && vaultId == scope.vaultId
            && generation == scope.generation
            && generationId == scope.generationId
    }
}

private struct VoiceCloneLegacyStateSnapshot: Codable, Equatable {
    let speakerId: String?
    let sampleStatus: String?
    let isEnabled: Bool?
    let realCloneProviderReady: Bool?
    let qualityAcceptanceRequired: Bool?
    let providerMode: String?
    let providerStatus: String?
    let providerMessage: String?

    var hasPayload: Bool {
        speakerId != nil
            || sampleStatus != nil
            || isEnabled != nil
            || realCloneProviderReady != nil
            || qualityAcceptanceRequired != nil
            || providerMode != nil
            || providerStatus != nil
            || providerMessage != nil
    }
}

private struct VoiceCloneLegacyQuarantineRecord: Codable, Equatable {
    let recordSchemaVersion: Int
    let ownerEvidence: String
    let sourceStorageKeys: [String]
    let payload: VoiceCloneLegacyStateSnapshot
    let quarantinedAt: Date
}

private struct VoiceCloneLegacyQuarantineEnvelope: Codable, Equatable {
    let quarantineSchemaVersion: Int
    var records: [VoiceCloneLegacyQuarantineRecord]
}

private enum VoiceCloneLocalStateLifecycleDisposition: Equatable {
    case absent
    case retained
    case removed
    case invalidEnvelope

    var remainingLocalData: Bool {
        switch self {
        case .retained, .invalidEnvelope:
            return true
        case .absent, .removed:
            return false
        }
    }
}

private final class VoiceCloneLocalStateStore {
    private enum LegacyKey {
        static let speakerId = "dj.voiceclone.speakerId"
        static let sampleStatus = "dj.voiceclone.sampleStatus"
        static let isEnabled = "dj.voiceclone.isEnabled"
        static let realCloneProviderReady = "dj.voiceclone.realCloneProviderReady"
        static let qualityAcceptanceRequired = "dj.voiceclone.qualityAcceptanceRequired"
        static let providerMode = "dj.voiceclone.providerMode"
        static let providerStatus = "dj.voiceclone.providerStatus"
        static let providerMessage = "dj.voiceclone.providerMessage"

        static let all = [
            speakerId,
            sampleStatus,
            isEnabled,
            realCloneProviderReady,
            qualityAcceptanceRequired,
            providerMode,
            providerStatus,
            providerMessage,
        ]
    }

    private let legacyQuarantineKey = "dj.voiceclone.legacyQuarantine.v1"
    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let now: () -> Date
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
        self.now = now
    }

    func load(accountLease: AccountLease) -> VoiceClonePersistedState? {
        guard let scope = VoiceCloneLocalOwnerScope(accountLease: accountLease),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        guard isolateLegacyPayloadIfNeeded(),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        guard let data = defaults.data(forKey: scope.storageKey) else {
            return nil
        }
        guard let envelope = try? JSONDecoder().decode(
            VoiceCloneLocalStateEnvelope.self,
            from: data
        ), envelope.matches(scope) else {
            return nil
        }
        return envelope.state
    }

    @discardableResult
    func update(
        accountLease: AccountLease,
        mutate: (inout VoiceClonePersistedState) -> Void
    ) -> VoiceClonePersistedState? {
        guard let scope = VoiceCloneLocalOwnerScope(accountLease: accountLease),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        guard isolateLegacyPayloadIfNeeded(),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return nil
        }

        let storageKey = scope.storageKey
        let previousData = defaults.data(forKey: storageKey)
        let previousEnvelope: VoiceCloneLocalStateEnvelope?
        if let previousData {
            guard let decoded = try? JSONDecoder().decode(
                VoiceCloneLocalStateEnvelope.self,
                from: previousData
            ), decoded.matches(scope) else {
                return nil
            }
            previousEnvelope = decoded
        } else {
            previousEnvelope = nil
        }

        var state = previousEnvelope?.state ?? .empty
        mutate(&state)
        let envelope = VoiceCloneLocalStateEnvelope(state: state, scope: scope)
        guard let replacementData = try? JSONEncoder().encode(envelope) else {
            return nil
        }
        defaults.set(replacementData, forKey: storageKey)

        guard defaults.data(forKey: storageKey) == replacementData,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            restore(
                previousData: previousData,
                replacing: replacementData,
                forKey: storageKey
            )
            return nil
        }
        return state
    }

    /// Lifecycle teardown deliberately accepts a captured, stale AccountLease. It never
    /// consults the current runtime lease, and only touches an envelope that exactly
    /// matches the deterministic scope captured before the account transition.
    func handleAccountLifecycle(
        accountLease: AccountLease,
        purge: Bool
    ) -> VoiceCloneLocalStateLifecycleDisposition {
        guard let scope = VoiceCloneLocalOwnerScope(accountLease: accountLease) else {
            return .invalidEnvelope
        }

        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: scope.storageKey) else {
            return .absent
        }
        guard let envelope = try? JSONDecoder().decode(
            VoiceCloneLocalStateEnvelope.self,
            from: data
        ), envelope.matches(scope) else {
            return .invalidEnvelope
        }
        guard purge else {
            return .retained
        }

        defaults.removeObject(forKey: scope.storageKey)
        return defaults.data(forKey: scope.storageKey) == nil ? .removed : .invalidEnvelope
    }

    private func restore(previousData: Data?, replacing replacementData: Data, forKey key: String) {
        guard defaults.data(forKey: key) == replacementData else { return }
        if let previousData {
            defaults.set(previousData, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func isolateLegacyPayloadIfNeeded() -> Bool {
        let payload = VoiceCloneLegacyStateSnapshot(
            speakerId: defaults.string(forKey: LegacyKey.speakerId),
            sampleStatus: defaults.string(forKey: LegacyKey.sampleStatus),
            isEnabled: optionalBool(forKey: LegacyKey.isEnabled),
            realCloneProviderReady: optionalBool(forKey: LegacyKey.realCloneProviderReady),
            qualityAcceptanceRequired: optionalBool(forKey: LegacyKey.qualityAcceptanceRequired),
            providerMode: defaults.string(forKey: LegacyKey.providerMode),
            providerStatus: defaults.string(forKey: LegacyKey.providerStatus),
            providerMessage: defaults.string(forKey: LegacyKey.providerMessage)
        )
        guard payload.hasPayload else { return true }

        var quarantine: VoiceCloneLegacyQuarantineEnvelope
        if let data = defaults.data(forKey: legacyQuarantineKey) {
            guard let decoded = try? JSONDecoder().decode(
                VoiceCloneLegacyQuarantineEnvelope.self,
                from: data
            ), decoded.quarantineSchemaVersion == 1 else {
                return false
            }
            quarantine = decoded
        } else {
            quarantine = VoiceCloneLegacyQuarantineEnvelope(
                quarantineSchemaVersion: 1,
                records: []
            )
        }

        if !quarantine.records.contains(where: { $0.payload == payload }) {
            quarantine.records.append(
                VoiceCloneLegacyQuarantineRecord(
                    recordSchemaVersion: 1,
                    ownerEvidence: "unverified",
                    sourceStorageKeys: LegacyKey.all,
                    payload: payload,
                    quarantinedAt: now()
                )
            )
        }
        guard let quarantineData = try? JSONEncoder().encode(quarantine) else {
            return false
        }
        defaults.set(quarantineData, forKey: legacyQuarantineKey)
        guard defaults.data(forKey: legacyQuarantineKey) == quarantineData else {
            return false
        }

        LegacyKey.all.forEach { defaults.removeObject(forKey: $0) }
        return LegacyKey.all.allSatisfy { defaults.object(forKey: $0) == nil }
    }

    private func optionalBool(forKey key: String) -> Bool? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return defaults.bool(forKey: key)
    }
}

#if UI_QA_SIMULATOR && targetEnvironment(simulator)
/// Simulator-only evidence for the Voice Clone store's account boundary. This
/// exercises the production local store without creating a provider session or
/// exposing any QA state in the public product surface.
private struct VoiceCloneOwnerScopeUIQAResult: Codable {
    static let fileName = "voice-clone-owner-scope-uiqa-result.json"

    let completed: Bool
    let accountIsolation: Bool
    let generationFence: Bool
    let staleWriteRejected: Bool
    let deletePurgesOnlyOldScope: Bool
    let legacyPayloadQuarantined: Bool
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum VoiceCloneOwnerScopeUIQASmoke {
    private static let accountA = "uiqa-voice-account-a"
    private static let accountB = "uiqa-voice-account-b"

    static func runAndPresent() {
        let result = run()
        do {
            let resultURL = try result.writeToDocuments()
            print("[UI_QA] VoiceCloneOwnerScopeSmoke result=\(resultURL.path)")
        } catch {
            print(
                "[UI_QA] VoiceCloneOwnerScopeSmoke failed to write result " +
                    "error=\(error.localizedDescription)"
            )
        }

        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            keyWindow.rootViewController = VoiceCloneOwnerScopeUIQAViewController(result: result)
            keyWindow.makeKeyAndVisible()
        }
        print("[UI_QA] VoiceCloneOwnerScopeSmoke completed success=\(result.completed)")
    }

    private static func run() -> VoiceCloneOwnerScopeUIQAResult {
        let suiteName = "voice-clone-owner-scope-uiqa.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return failedResult(reason: "unableToCreateUserDefaultsSuite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let leaseA = makeLease(
            subjectId: accountA,
            vaultId: "uiqa-voice-vault-a",
            generation: 1,
            generationId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        )
        let leaseANext = makeLease(
            subjectId: accountA,
            vaultId: "uiqa-voice-vault-a",
            generation: 2,
            generationId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
        )
        let leaseB = makeLease(
            subjectId: accountB,
            vaultId: "uiqa-voice-vault-b",
            generation: 1,
            generationId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
        )
        let runtime = VoiceCloneOwnerScopeUIQAMutableLeaseRuntime(activeLease: leaseA)
        let store = VoiceCloneLocalStateStore(
            defaults: defaults,
            accountLeaseRuntime: runtime,
            now: { Date(timeIntervalSince1970: 1_784_736_000) }
        )

        let legacySpeakerKey = ["dj", "voiceclone", "speakerId"].joined(separator: ".")
        defaults.set("legacy-unattributed-speaker", forKey: legacySpeakerKey)
        let storedA = store.update(accountLease: leaseA) { state in
            state.speakerId = "uiqa-profile-a"
            state.sampleStatus = .ready
            state.isEnabled = true
            state.realCloneProviderReady = true
            state.qualityAcceptanceRequired = false
        }
        let legacyPayloadQuarantined = defaults.object(forKey: legacySpeakerKey) == nil
            && storedA?.speakerId == "uiqa-profile-a"

        runtime.publish(leaseB)
        let bInitiallyEmpty = store.load(accountLease: leaseB) == nil
        let staleWriteRejected = store.update(accountLease: leaseA) { state in
            state.speakerId = "stale-profile-a"
        } == nil
        let storedB = store.update(accountLease: leaseB) { state in
            state.speakerId = "uiqa-profile-b"
            state.sampleStatus = .ready
            state.isEnabled = true
        }
        let bStateWritten = storedB?.speakerId == "uiqa-profile-b"

        runtime.publish(leaseA)
        let originalAStillPresent = store.load(accountLease: leaseA)?.speakerId == "uiqa-profile-a"

        runtime.publish(leaseANext)
        let oldGenerationRejected = store.load(accountLease: leaseA) == nil
        let nextGenerationDoesNotInherit = store.load(accountLease: leaseANext) == nil

        let removal = store.handleAccountLifecycle(accountLease: leaseA, purge: true)
        runtime.publish(leaseA)
        let oldScopeRemoved = store.load(accountLease: leaseA) == nil
        runtime.publish(leaseB)
        let bSurvivesOldScopeDeletion = store.load(accountLease: leaseB)?.speakerId == "uiqa-profile-b"

        let accountIsolation = bInitiallyEmpty && originalAStillPresent && bStateWritten
        let generationFence = oldGenerationRejected && nextGenerationDoesNotInherit
        let deletePurgesOnlyOldScope = removal == .removed
            && oldScopeRemoved
            && bSurvivesOldScopeDeletion
        let completed = accountIsolation
            && generationFence
            && staleWriteRejected
            && deletePurgesOnlyOldScope
            && legacyPayloadQuarantined

        return VoiceCloneOwnerScopeUIQAResult(
            completed: completed,
            accountIsolation: accountIsolation,
            generationFence: generationFence,
            staleWriteRejected: staleWriteRejected,
            deletePurgesOnlyOldScope: deletePurgesOnlyOldScope,
            legacyPayloadQuarantined: legacyPayloadQuarantined,
            failureReason: completed ? nil : "voiceCloneOwnerScopeAssertionFailed"
        )
    }

    private static func makeLease(
        subjectId: String,
        vaultId: String,
        generation: UInt64,
        generationId: String
    ) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: vaultId,
            sessionId: "uiqa-voice-session-\(subjectId)-\(generation)",
            generation: generation,
            generationId: UUID(uuidString: generationId)!,
            authorityEpoch: "uiqa-voice-authority"
        )
    }

    private static func failedResult(reason: String) -> VoiceCloneOwnerScopeUIQAResult {
        VoiceCloneOwnerScopeUIQAResult(
            completed: false,
            accountIsolation: false,
            generationFence: false,
            staleWriteRejected: false,
            deletePurgesOnlyOldScope: false,
            legacyPayloadQuarantined: false,
            failureReason: reason
        )
    }
}

private final class VoiceCloneOwnerScopeUIQAMutableLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    private let lock = NSLock()
    private var activeLease: AccountLease?

    init(activeLease: AccountLease?) {
        self.activeLease = activeLease
    }

    func publish(_ lease: AccountLease?) {
        lock.lock()
        activeLease = lease
        lock.unlock()
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        lock.lock()
        defer { lock.unlock() }
        guard let activeLease,
              subjectId == nil || subjectId == activeLease.subjectId else {
            return nil
        }
        return activeLease
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        lock.lock()
        let activeLease = activeLease
        lock.unlock()
        let allowed = activeLease == lease
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: allowed,
            reason: allowed ? .allowed : .generationMismatch,
            sessionRotated: false
        )
    }
}

private final class VoiceCloneOwnerScopeUIQAViewController: UIViewController {
    private let result: VoiceCloneOwnerScopeUIQAResult

    init(result: VoiceCloneOwnerScopeUIQAResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let titleLabel = UILabel()
        titleLabel.text = "Voice Clone 账号隔离"
        titleLabel.font = .systemFont(ofSize: 25, weight: .bold)
        titleLabel.textColor = .label

        let statusLabel = UILabel()
        statusLabel.text = result.completed ? "G1 UIQA 通过" : "G1 UIQA 失败"
        statusLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        statusLabel.textColor = result.completed ? .systemGreen : .systemRed

        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        detailLabel.text = [
            "Account A/B: \(mark(result.accountIsolation))",
            "Generation fence: \(mark(result.generationFence))",
            "Stale write: \(mark(result.staleWriteRejected))",
            "Delete scope: \(mark(result.deletePurgesOnlyOldScope))",
            "Legacy quarantine: \(mark(result.legacyPayloadQuarantined))",
        ].joined(separator: "\n")

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func mark(_ passed: Bool) -> String {
        passed ? "PASS" : "FAIL"
    }
}
#endif

/// 封装 DreamJourney 后端声音复刻合同：
/// 1. iOS 只提交授权后的声音样本给后端
/// 2. 后端持有火山引擎声音复刻 API Key 并代理训练/查询
/// 3. 训练成功后 voiceProfileId/speaker_id 可用于后端代理合成
final class VoiceCloneService {

    static let shared = VoiceCloneService()

    // MARK: - 配置

    private static let emptyVoiceProfileId = "voiceProfileId_not_created"
    static let backendContractEndpoint = "/voice/profiles"
    private static let authorizationCopy = "音色复刻必须由用户主动授权，仅使用用户确认提交的声音样本；训练、查询、合成、禁用和删除都通过 DreamJourney 后端代理执行，iOS 不保存火山语音密钥。"
    private static let disableContract = "禁用音色会调用后端撤销该 voiceProfileId 的合成权限，并在本地记录样本已禁用。"
    private static let deleteContract = "删除音色会调用后端删除样本、训练产物和关联授权记录，并清理本地 voiceProfileId。"

    /// 训练轮询定时器
    private var pollTimer: Timer?

    /// 正在等待音色就绪的附加回调（用于 checkPendingTraining 加速完成）。
    /// 主回调由创建 runtime operation 的调用方持有，附加回调只会在同一
    /// operation 仍有效时触发。
    private var pendingCompletion: ((Result<String, VoiceCloneError>) -> Void)?
    private var trainingPrimaryCompletion: ((Result<String, VoiceCloneError>) -> Void)?
    private var trainingCompletionOperationID: UUID?

    /// 训练中的唯一 runtime token，替代彼此独立的 speaker/persona/lease
    /// 字段，避免旧角色的异步回调拼接到新角色的运行态。
    private var trainingRuntimeOperation: VoiceCloneTrainingRuntimeOperation?
    private var nextTrainingRuntimeGeneration: UInt64 = 0
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let localStateStore: VoiceCloneLocalStateStore
    private var digitalHumanContextObserver: NSObjectProtocol?

    // MARK: - Init

    private init(accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared) {
        self.accountLeaseRuntime = accountLeaseRuntime
        localStateStore = VoiceCloneLocalStateStore(accountLeaseRuntime: accountLeaseRuntime)
        digitalHumanContextObserver = NotificationCenter.default.addObserver(
            forName: .djDigitalHumanContextDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleDigitalHumanContextChange(notification)
        }
    }

    deinit {
        if let digitalHumanContextObserver {
            NotificationCenter.default.removeObserver(digitalHumanContextObserver)
        }
    }

    // MARK: - 公开 API

    /// 获取当前保存的 speaker_id
    var currentSpeakerId: String? {
        guard let operation = activePersonaOperation() else { return nil }
        return normalizedVoiceProfileId(
            localStateStore.load(accountLease: operation.accountLease)?.speakerId
        )
    }

    var currentUsableSpeakerId: String? {
        let snapshot = voiceCloneShellSnapshot()
        guard snapshot.isReadyForUse,
              let speakerId = normalizedVoiceProfileId(snapshot.voiceProfileId) else {
            return nil
        }
        return speakerId
    }

    /// Resolves a usable personal profile for a persisted owner, without
    /// consulting the currently selected Digital Human persona. Memoir playback
    /// may only fall back to its author's own profile; a family role selected in
    /// Echo must never influence that choice.
    func currentUsablePersonalSpeakerId(forOwnerId ownerId: String) -> String? {
        let normalizedOwnerId = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwnerId.isEmpty,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: normalizedOwnerId),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }

        let personalTarget = VoiceClonePersonaTarget(
            userId: normalizedOwnerId,
            personaScope: "personal",
            digitalHumanId: normalizedOwnerId,
            familyMemberId: nil
        )
        let snapshot = voiceCloneShellSnapshot(
            accountLease: accountLease,
            target: personalTarget
        )
        guard snapshot.isReadyForUse else { return nil }
        return normalizedVoiceProfileId(snapshot.voiceProfileId)
    }

    func handleAccountLifecycle(
        _ context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard requestedOutcome != .failed else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "voiceLifecycleRequestedFailure"
            )
        }
        guard let oldAccountLease = context.oldAccountLease,
              oldAccountLease.generation == context.oldGeneration,
              VoiceCloneLocalOwnerScope(accountLease: oldAccountLease) != nil else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "voiceLifecycleOldScopeMissing"
            )
        }

        cancelTrainingRuntime(for: oldAccountLease)
        let purge = context.event == .accountDeletion
            || requestedOutcome == .cleared
            || requestedOutcome == .purged
        let disposition = localStateStore.handleAccountLifecycle(
            accountLease: oldAccountLease,
            purge: purge
        )
        guard disposition != .invalidEnvelope else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "voiceLifecycleScopeValidationFailed"
            )
        }

        return .completed(
            requestedOutcome,
            remainingLocalData: disposition.remainingLocalData,
            detailCode: voiceLifecycleDetailCode(for: requestedOutcome)
        )
    }

    func voiceCloneShellSnapshot() -> VoiceCloneProfileSnapshot {
        guard let operation = activePersonaOperation() else {
            return emptyVoiceCloneShellSnapshot()
        }
        return voiceCloneShellSnapshot(
            accountLease: operation.accountLease,
            target: operation.target
        )
    }

    private func voiceCloneShellSnapshot(
        accountLease: AccountLease,
        target: VoiceClonePersonaTarget
    ) -> VoiceCloneProfileSnapshot {
        guard accountLease.subjectId == target.userId,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return emptyVoiceCloneShellSnapshot()
        }
        if let familySnapshot = familyVoiceCloneShellSnapshot(for: target) {
            return familySnapshot
        }

        let state = localStateStore.load(accountLease: accountLease)
        let speakerId = normalizedVoiceProfileId(state?.speakerId)
        let profileId = speakerId ?? Self.emptyVoiceProfileId
        let sampleStatus = state?.sampleStatus ?? (speakerId == nil ? .notProvided : .pending)
        return VoiceCloneProfileSnapshot(
            voiceProfileId: profileId,
            sampleStatus: sampleStatus,
            authorizationCopy: Self.authorizationCopy,
            isEnabled: state?.isEnabled ?? false,
            realCloneProviderReady: state?.realCloneProviderReady ?? false,
            qualityAcceptanceRequired: state?.qualityAcceptanceRequired ?? true,
            disableContract: Self.disableContract,
            deleteContract: Self.deleteContract,
            providerMode: state?.providerMode ?? "localFallback",
            providerStatus: state?.providerStatus ?? "",
            providerMessage: state?.providerMessage ?? "",
            lifecycleSchemaVersion: state?.lifecycleSchemaVersion,
            lifecycleState: state?.lifecycleStateRaw.flatMap(VoiceProfileLifecycleState.init(rawValue:)),
            profileVersion: state?.profileVersion ?? 0,
            retryGeneration: state?.retryGeneration ?? 0,
            stateChangedAt: state?.stateChangedAt,
            eligibilityAllowed: state?.eligibilityAllowed ?? false,
            eligibilityReasonCode: state?.eligibilityReasonCode ?? "unavailable",
            consentPurpose: state?.consentPurpose,
            consentState: state?.consentState ?? "missing",
            consentExpiresAt: state?.consentExpiresAt,
            allowedOperations: Set(state?.allowedOperations ?? [])
        )
    }

    private func emptyVoiceCloneShellSnapshot() -> VoiceCloneProfileSnapshot {
        VoiceCloneProfileSnapshot(
            voiceProfileId: Self.emptyVoiceProfileId,
            sampleStatus: .notProvided,
            authorizationCopy: Self.authorizationCopy,
            isEnabled: false,
            realCloneProviderReady: false,
            qualityAcceptanceRequired: true,
            disableContract: Self.disableContract,
            deleteContract: Self.deleteContract
        )
    }

    func voiceCloneShellSnapshot(from backendContract: VoiceCloneProfileContract) -> VoiceCloneProfileSnapshot {
        VoiceCloneProfileSnapshot(backendContract: backendContract)
    }

    func preferredVoiceCloneProfile(
        from profiles: [VoiceCloneProfileContract],
        preferredProfileId: String? = nil
    ) -> VoiceCloneProfileContract? {
        let activeProfiles = profiles.filter { $0.sampleStatus != .deleted }
        guard let operation = activePersonaOperation() else { return nil }
        let target = operation.target
        let targetProfiles = activeProfiles.filter { profile($0, matches: target) }
        let personalCompatibleProfiles = activeProfiles.filter {
            $0.personaScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "family"
        }
        let selectableProfiles: [VoiceCloneProfileContract]
        if targetProfiles.isEmpty && !target.isFamilyMember {
            selectableProfiles = personalCompatibleProfiles
        } else {
            selectableProfiles = targetProfiles
        }
        let preferredProfileId = normalizedVoiceProfileId(preferredProfileId)
        if let preferredProfileId,
           let preferred = selectableProfiles.first(where: {
               $0.voiceProfileId == preferredProfileId
           }) {
            return preferred
        }
        if let readyProfile = selectableProfiles.first(where: { Self.isBackendProfileReadyForUse($0) }) {
            return readyProfile
        }
        return selectableProfiles.first(where: { $0.sampleStatus == .ready && $0.isEnabled })
            ?? selectableProfiles.first(where: { $0.sampleStatus == .pending })
            ?? selectableProfiles.first(where: { $0.sampleStatus == .failed })
            ?? selectableProfiles.first
    }

    func persistSnapshot(_ snapshot: VoiceCloneProfileSnapshot) {
        guard let operation = activePersonaOperation() else { return }
        persistSnapshot(
            snapshot,
            target: operation.target,
            accountLease: operation.accountLease
        )
    }

    private func persistSnapshot(
        _ snapshot: VoiceCloneProfileSnapshot,
        target: VoiceClonePersonaTarget,
        accountLease: AccountLease
    ) {
        guard accountLease.subjectId == target.userId,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return
        }
        if let memberId = target.familyMemberId {
            FamilyRepository.shared.updateVoiceProfile(
                memberId: memberId,
                voiceProfileId: normalizedVoiceProfileId(snapshot.voiceProfileId),
                sampleStatus: snapshot.sampleStatus.rawValue,
                voiceEnabled: snapshot.isEnabled
            )
            return
        }

        _ = localStateStore.update(accountLease: accountLease) { state in
            if let speakerId = normalizedVoiceProfileId(snapshot.voiceProfileId),
               snapshot.sampleStatus != .notProvided,
               snapshot.sampleStatus != .deleted {
                state.speakerId = speakerId
            } else if snapshot.sampleStatus == .notProvided || snapshot.sampleStatus == .deleted {
                state.speakerId = nil
            }
            state.sampleStatus = snapshot.sampleStatus
            state.isEnabled = snapshot.isEnabled
            state.realCloneProviderReady = snapshot.realCloneProviderReady
            state.qualityAcceptanceRequired = snapshot.qualityAcceptanceRequired
            state.providerMode = snapshot.providerMode
            state.providerStatus = snapshot.providerStatus
            state.providerMessage = snapshot.providerMessage
            state.lifecycleSchemaVersion = snapshot.lifecycleSchemaVersion
            state.lifecycleStateRaw = snapshot.lifecycleState?.rawValue
            state.profileVersion = snapshot.profileVersion
            state.retryGeneration = snapshot.retryGeneration
            state.stateChangedAt = snapshot.stateChangedAt
            state.eligibilityAllowed = snapshot.eligibilityAllowed
            state.eligibilityReasonCode = snapshot.eligibilityReasonCode
            state.consentPurpose = snapshot.consentPurpose
            state.consentState = snapshot.consentState
            state.consentExpiresAt = snapshot.consentExpiresAt
            state.allowedOperations = snapshot.allowedOperations.sorted()
        }
    }

    @discardableResult
    func disableVoiceProfile(profileId: String) -> VoiceCloneProfileSnapshot {
        guard !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return voiceCloneShellSnapshot()
        }
        guard let operation = activePersonaOperation() else {
            return emptyVoiceCloneShellSnapshot()
        }
        let current = voiceCloneShellSnapshot(
            accountLease: operation.accountLease,
            target: operation.target
        )
        let disabled = snapshot(
            current,
            sampleStatus: .disabled,
            isEnabled: false
        )
        persistSnapshot(
            disabled,
            target: operation.target,
            accountLease: operation.accountLease
        )
        return voiceCloneShellSnapshot(
            accountLease: operation.accountLease,
            target: operation.target
        )
    }

    @discardableResult
    func deleteVoiceProfile(profileId: String) -> VoiceCloneProfileSnapshot {
        guard !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return voiceCloneShellSnapshot()
        }
        guard let operation = activePersonaOperation() else {
            return emptyVoiceCloneShellSnapshot()
        }
        let current = voiceCloneShellSnapshot(
            accountLease: operation.accountLease,
            target: operation.target
        )
        let deleted = snapshot(
            current,
            voiceProfileId: Self.emptyVoiceProfileId,
            sampleStatus: .deleted,
            isEnabled: false,
            realCloneProviderReady: false
        )
        persistSnapshot(
            deleted,
            target: operation.target,
            accountLease: operation.accountLease
        )
        return voiceCloneShellSnapshot(
            accountLease: operation.accountLease,
            target: operation.target
        )
    }

    func disableVoiceProfileRemote(
        profileId: String,
        completion: @escaping (Result<VoiceCloneProfileSnapshot, VoiceCloneError>) -> Void
    ) {
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let trimmedProfileId = profileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProfileId.isEmpty, trimmedProfileId != Self.emptyVoiceProfileId else {
            completion(.failure(.speakerIdNotFound))
            return
        }

        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        let accountLease = operation.accountLease
        let target = operation.target
        DreamJourneyBackendClient.shared.disableVoiceCloneProfile(
            userId: accountLease.subjectId,
            profileId: trimmedProfileId
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            switch result {
            case .success(let profile):
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.persistBackendProfileIfUsable(
                    profile,
                    target: target,
                    accountLease: accountLease
                )
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.deliver(
                    .success(VoiceCloneProfileSnapshot(backendContract: profile)),
                    accountLease: accountLease,
                    completion: completion
                )
            case .failure(let error):
                DDLogError("[VoiceClone] 后端禁用失败: \(error.localizedDescription)")
                self.deliver(
                    .failure(.networkError(error.localizedDescription)),
                    accountLease: accountLease,
                    completion: completion
                )
            }
        }
    }

    func deleteVoiceProfileRemote(
        profileId: String,
        completion: @escaping (Result<VoiceCloneProfileSnapshot, VoiceCloneError>) -> Void
    ) {
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let trimmedProfileId = profileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProfileId.isEmpty, trimmedProfileId != Self.emptyVoiceProfileId else {
            completion(.failure(.speakerIdNotFound))
            return
        }

        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        let accountLease = operation.accountLease
        let target = operation.target
        DreamJourneyBackendClient.shared.deleteVoiceCloneProfile(
            userId: accountLease.subjectId,
            profileId: trimmedProfileId
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            switch result {
            case .success(let profile):
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.persistBackendProfileIfUsable(
                    profile,
                    target: target,
                    accountLease: accountLease
                )
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.deliver(
                    .success(VoiceCloneProfileSnapshot(backendContract: profile)),
                    accountLease: accountLease,
                    completion: completion
                )
            case .failure(let error):
                DDLogError("[VoiceClone] 后端删除失败: \(error.localizedDescription)")
                self.deliver(
                    .failure(.networkError(error.localizedDescription)),
                    accountLease: accountLease,
                    completion: completion
                )
            }
        }
    }

    func acceptVoiceProfileQualityRemote(
        profileId: String,
        previewReceiptId: String,
        completion: @escaping (Result<VoiceCloneProfileSnapshot, VoiceCloneError>) -> Void
    ) {
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let trimmedProfileId = profileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProfileId.isEmpty, trimmedProfileId != Self.emptyVoiceProfileId else {
            completion(.failure(.speakerIdNotFound))
            return
        }
        let trimmedPreviewReceiptId = previewReceiptId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPreviewReceiptId.isEmpty else {
            completion(.failure(.networkError("请先生成并试听复刻音频后再确认。")))
            return
        }

        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        let accountLease = operation.accountLease
        let target = operation.target
        DreamJourneyBackendClient.shared.acceptVoiceCloneQuality(
            userId: accountLease.subjectId,
            profileId: trimmedProfileId,
            previewReceiptId: trimmedPreviewReceiptId
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            switch result {
            case .success(let profile):
                let snapshot = VoiceCloneProfileSnapshot(backendContract: profile)
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.persistSnapshot(
                    snapshot,
                    target: target,
                    accountLease: accountLease
                )
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.deliver(.success(snapshot), accountLease: accountLease, completion: completion)
            case .failure(let error):
                DDLogError("[VoiceClone] 音色试听确认失败: \(error.localizedDescription)")
                self.deliver(
                    .failure(.networkError(error.localizedDescription)),
                    accountLease: accountLease,
                    completion: completion
                )
            }
        }
    }

    private func saveSampleStatus(
        _ status: VoiceCloneSampleStatus,
        accountLease: AccountLease
    ) {
        _ = localStateStore.update(accountLease: accountLease) { state in
            state.sampleStatus = status
        }
    }

    private func persistBackendProfileIfUsable(
        _ profile: VoiceCloneProfileContract,
        target: VoiceClonePersonaTarget? = nil,
        accountLease: AccountLease
    ) {
        let snapshot = VoiceCloneProfileSnapshot(backendContract: profile)
        let resolvedTarget = target
            ?? personaTarget(from: profile, fallbackUserId: accountLease.subjectId)
            ?? currentPersonaTarget(userId: accountLease.subjectId)
        persistSnapshot(
            snapshot,
            target: resolvedTarget,
            accountLease: accountLease
        )
    }

    private static func isBackendProfileReadyForUse(_ profile: VoiceCloneProfileContract) -> Bool {
        profile.isReadyForEcho
    }

    private func normalizedVoiceProfileId(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != Self.emptyVoiceProfileId else {
            return nil
        }
        return trimmed
    }

    private func snapshot(
        _ source: VoiceCloneProfileSnapshot,
        voiceProfileId: String? = nil,
        sampleStatus: VoiceCloneSampleStatus? = nil,
        isEnabled: Bool? = nil,
        realCloneProviderReady: Bool? = nil
    ) -> VoiceCloneProfileSnapshot {
        VoiceCloneProfileSnapshot(
            voiceProfileId: voiceProfileId ?? source.voiceProfileId,
            sampleStatus: sampleStatus ?? source.sampleStatus,
            authorizationCopy: source.authorizationCopy,
            isEnabled: isEnabled ?? source.isEnabled,
            realCloneProviderReady: realCloneProviderReady ?? source.realCloneProviderReady,
            qualityAcceptanceRequired: source.qualityAcceptanceRequired,
            disableContract: source.disableContract,
            deleteContract: source.deleteContract,
            providerMode: source.providerMode,
            providerStatus: source.providerStatus,
            providerMessage: source.providerMessage,
            contractVersion: source.contractVersion,
            defaultReleaseVisible: source.defaultReleaseVisible,
            providerBindingMode: source.providerBindingMode,
            providerSlotManaged: source.providerSlotManaged,
            providerSlotState: source.providerSlotState,
            exitState: source.exitState,
            accessRevoked: source.accessRevoked,
            localCleanupState: source.localCleanupState,
            providerCleanupState: source.providerCleanupState,
            providerCleanupReceiptAvailable: source.providerCleanupReceiptAvailable,
            lifecycleSchemaVersion: source.lifecycleSchemaVersion,
            lifecycleState: source.lifecycleState,
            profileVersion: source.profileVersion,
            retryGeneration: source.retryGeneration,
            stateChangedAt: source.stateChangedAt,
            eligibilityAllowed: source.eligibilityAllowed,
            eligibilityReasonCode: source.eligibilityReasonCode,
            consentPurpose: source.consentPurpose,
            consentState: source.consentState,
            consentExpiresAt: source.consentExpiresAt,
            allowedOperations: source.allowedOperations
        )
    }

    private func activePersonaOperation() -> (accountLease: AccountLease, target: VoiceClonePersonaTarget)? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        return (accountLease, currentPersonaTarget(userId: accountLease.subjectId))
    }

    private func beginTrainingRuntime(
        speakerId: String,
        target: VoiceClonePersonaTarget,
        accountLease: AccountLease
    ) -> VoiceCloneTrainingRuntimeOperation {
        invalidateTrainingRuntime()
        nextTrainingRuntimeGeneration &+= 1
        let operation = VoiceCloneTrainingRuntimeOperation(
            id: UUID(),
            runtimeGeneration: nextTrainingRuntimeGeneration,
            speakerId: speakerId,
            target: target,
            accountLease: accountLease
        )
        trainingRuntimeOperation = operation
        return operation
    }

    private func isCurrentTrainingRuntimeOperation(
        _ operation: VoiceCloneTrainingRuntimeOperation,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        guard trainingRuntimeOperation == operation,
              accountLeaseRuntime.validate(operation.accountLease, at: checkpoint).allowed else {
            return false
        }
        return currentPersonaTarget(userId: operation.accountLease.subjectId) == operation.target
    }

    private func handleDigitalHumanContextChange(_ notification: Notification) {
        guard let operation = trainingRuntimeOperation,
              accountLeaseRuntime.validate(operation.accountLease, at: .runtime).allowed else {
            return
        }
        guard let context = notification.object as? DigitalHumanContext,
              personaTarget(
                  for: context,
                  userId: operation.accountLease.subjectId
              ) == operation.target else {
            invalidateTrainingRuntime(expected: operation)
            return
        }
    }

    private func cancelTrainingRuntime(for oldAccountLease: AccountLease) {
        guard let oldScope = VoiceCloneLocalOwnerScope(accountLease: oldAccountLease),
              let operation = trainingRuntimeOperation,
              VoiceCloneLocalOwnerScope(accountLease: operation.accountLease) == oldScope else {
            return
        }
        invalidateTrainingRuntime(expected: operation)
    }

    private func invalidateTrainingRuntime(
        expected operation: VoiceCloneTrainingRuntimeOperation? = nil,
        timer: Timer? = nil
    ) {
        guard operation == nil || trainingRuntimeOperation == operation else {
            timer?.invalidate()
            return
        }
        timer?.invalidate()
        pollTimer?.invalidate()
        pollTimer = nil
        pendingCompletion = nil
        trainingPrimaryCompletion = nil
        trainingCompletionOperationID = nil
        trainingRuntimeOperation = nil
    }

    private func bindTrainingPrimaryCompletion(
        _ completion: @escaping (Result<String, VoiceCloneError>) -> Void,
        to operation: VoiceCloneTrainingRuntimeOperation
    ) {
        guard trainingRuntimeOperation == operation else { return }
        trainingPrimaryCompletion = completion
        trainingCompletionOperationID = operation.id
    }

    private func completeTrainingRuntimeIfCurrent(
        _ operation: VoiceCloneTrainingRuntimeOperation,
        timer: Timer? = nil
    ) -> VoiceCloneTrainingRuntimeCompletions? {
        guard trainingRuntimeOperation == operation else {
            timer?.invalidate()
            return nil
        }
        timer?.invalidate()
        pollTimer?.invalidate()
        pollTimer = nil
        let completions = VoiceCloneTrainingRuntimeCompletions(
            primary: trainingCompletionOperationID == operation.id ? trainingPrimaryCompletion : nil,
            pending: pendingCompletion
        )
        pendingCompletion = nil
        trainingPrimaryCompletion = nil
        trainingCompletionOperationID = nil
        trainingRuntimeOperation = nil
        return completions
    }

    private func deliverTrainingResult(
        _ result: Result<String, VoiceCloneError>,
        operation: VoiceCloneTrainingRuntimeOperation,
        primaryCompletion: @escaping (Result<String, VoiceCloneError>) -> Void,
        timer: Timer? = nil
    ) {
        guard isCurrentTrainingRuntimeOperation(operation, at: .ui) else {
            invalidateTrainingRuntime(expected: operation, timer: timer)
            return
        }
        let completions = completeTrainingRuntimeIfCurrent(operation, timer: timer)
        deliver(result, accountLease: operation.accountLease, completion: primaryCompletion)
        if let pending = completions?.pending {
            deliver(result, accountLease: operation.accountLease, completion: pending)
        }
    }

    private func deliverPendingTrainingResult(
        _ result: Result<String, VoiceCloneError>,
        operation: VoiceCloneTrainingRuntimeOperation,
        timer: Timer? = nil
    ) {
        guard isCurrentTrainingRuntimeOperation(operation, at: .ui) else {
            invalidateTrainingRuntime(expected: operation, timer: timer)
            return
        }
        guard let completions = completeTrainingRuntimeIfCurrent(operation, timer: timer) else {
            return
        }
        if let primary = completions.primary {
            deliver(result, accountLease: operation.accountLease, completion: primary)
        }
        if let pending = completions.pending {
            deliver(result, accountLease: operation.accountLease, completion: pending)
        }
    }

    private func voiceLifecycleDetailCode(
        for outcome: AccountLifecycleModuleOutcome
    ) -> String {
        switch outcome {
        case .retainedLocked:
            return "voiceLifecycleRetainedLocked"
        case .unmounted:
            return "voiceLifecycleUnmounted"
        case .cancelled:
            return "voiceLifecycleCancelled"
        case .cleared:
            return "voiceLifecycleCleared"
        case .purged:
            return "voiceLifecyclePurged"
        case .skipped:
            return "voiceLifecycleSkipped"
        case .failed:
            return "voiceLifecycleRequestedFailure"
        }
    }

    private func deliver<T>(
        _ result: Result<T, VoiceCloneError>,
        accountLease: AccountLease,
        completion: @escaping (Result<T, VoiceCloneError>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
        completion(result)
    }

    private func currentPersonaTarget(userId: String) -> VoiceClonePersonaTarget {
        personaTarget(for: DigitalHumanContextStore.shared.current, userId: userId)
    }

    private func personaTarget(
        for context: DigitalHumanContext,
        userId: String
    ) -> VoiceClonePersonaTarget {
        let normalizedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let ownerId = context.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let isFamilyPersona = !context.isSelfAssistant
            && !ownerId.isEmpty
            && ownerId != normalizedUserId

        if isFamilyPersona {
            return VoiceClonePersonaTarget(
                userId: normalizedUserId,
                personaScope: "family",
                digitalHumanId: ownerId,
                familyMemberId: ownerId
            )
        }

        return VoiceClonePersonaTarget(
            userId: normalizedUserId,
            personaScope: "personal",
            digitalHumanId: normalizedUserId,
            familyMemberId: nil
        )
    }

    private func personaTarget(
        from profile: VoiceCloneProfileContract,
        fallbackUserId: String
    ) -> VoiceClonePersonaTarget? {
        let scope = profile.personaScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digitalHumanId = profile.digitalHumanId.trimmingCharacters(in: .whitespacesAndNewlines)
        let userId = fallbackUserId.trimmingCharacters(in: .whitespacesAndNewlines)

        if scope == "family", !digitalHumanId.isEmpty {
            return VoiceClonePersonaTarget(
                userId: userId,
                personaScope: "family",
                digitalHumanId: digitalHumanId,
                familyMemberId: digitalHumanId
            )
        }

        if scope == "personal" {
            return VoiceClonePersonaTarget(
                userId: userId,
                personaScope: "personal",
                digitalHumanId: digitalHumanId.isEmpty ? userId : digitalHumanId,
                familyMemberId: nil
            )
        }

        return nil
    }

    private func profile(_ profile: VoiceCloneProfileContract, matches target: VoiceClonePersonaTarget) -> Bool {
        let scope = profile.personaScope.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digitalHumanId = profile.digitalHumanId.trimmingCharacters(in: .whitespacesAndNewlines)

        if let familyMemberId = target.familyMemberId {
            return scope == "family" && digitalHumanId == familyMemberId
        }

        return scope == "personal"
            && (digitalHumanId.isEmpty || digitalHumanId == target.digitalHumanId || digitalHumanId == target.userId)
    }

    private func familyVoiceCloneShellSnapshot(for target: VoiceClonePersonaTarget) -> VoiceCloneProfileSnapshot? {
        guard let memberId = target.familyMemberId,
              let member = FamilyRepository.shared.get(by: memberId) else {
            return nil
        }
        let status = VoiceCloneSampleStatus(rawValue: member.voiceSampleStatus) ?? .notProvided
        let profileId = member.normalizedVoiceProfileId ?? Self.emptyVoiceProfileId
        let readyForEcho = member.isVoiceProfileReadyForEcho
        return VoiceCloneProfileSnapshot(
            voiceProfileId: profileId,
            sampleStatus: status,
            authorizationCopy: Self.authorizationCopy,
            isEnabled: member.voiceEnabled,
            realCloneProviderReady: readyForEcho,
            qualityAcceptanceRequired: !readyForEcho,
            disableContract: Self.disableContract,
            deleteContract: Self.deleteContract,
            providerMode: "familyProfile",
            providerStatus: member.voiceCloneStatusLabel,
            providerMessage: ""
        )
    }

    /// 上传音频训练声音复刻
    /// - Parameters:
    ///   - audioURL: 本地 PCM WAV 音频文件 URL（建议 10–30 秒，≤10MB）
    ///   - speakerId: 指定的音色 ID，为空则自动生成
    ///   - language: 语种，0=中文（默认）
    ///   - authorizationConfirmed: 用户已主动确认本人授权
    ///   - retryingProfile: 失败态的既有 profile；仅通过显式 retry generation 重试，绝不生成新 profile ID
    ///   - onProfileAccepted: 后端接收 pending/ready profile 后的即时回调，用于 UI 回显 voiceProfileId
    ///   - completion: 结果回调
    func trainVoice(audioURL: URL,
                    speakerId: String? = nil,
                    language: Int = 0,
                    authorizationConfirmed: Bool,
                    sampleAuthorization: VoiceCloneSampleAuthorizationContract,
                    retryingProfile: VoiceCloneProfileSnapshot? = nil,
                    onProfileAccepted: ((VoiceCloneProfileSnapshot) -> Void)? = nil,
                    completion: @escaping (Result<String, VoiceCloneError>) -> Void) {

        guard authorizationConfirmed else {
            completion(.failure(.authorizationRequired))
            return
        }

        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        let accountLease = operation.accountLease
        let target = operation.target

        let retryRequest: VoiceCloneTrainingRetryRequest?
        if let retryingProfile {
            guard let request = trainingRetryRequest(for: retryingProfile) else {
                completion(.failure(.retryNotAllowed))
                return
            }
            retryRequest = request
        } else {
            retryRequest = nil
        }
        let currentSnapshot = voiceCloneShellSnapshot(
            accountLease: accountLease,
            target: target
        )
        guard currentSnapshot.sampleStatus != .failed || retryRequest != nil else {
            completion(.failure(.retryNotAllowed))
            return
        }

        // 读取音频文件并 base64 编码
        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(.audioReadFailed))
            return
        }

        guard !audioData.isEmpty else {
            completion(.failure(.audioReadFailed))
            return
        }

        guard audioData.count <= 10 * 1024 * 1024 else {
            completion(.failure(.audioTooLarge))
            return
        }

        let base64Audio = audioData.base64EncodedString()
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return
        }

        let finalSpeakerId = retryRequest?.voiceProfileId
            ?? speakerId
            ?? reusableSpeakerIdForTraining(target: target, accountLease: accountLease)
            ?? Self.makeSpeakerId()

        // 确定音频格式
        guard let format = audioFormat(from: audioURL) else {
            completion(.failure(.unsupportedAudioFormat))
            return
        }

        let trainingOperation = beginTrainingRuntime(
            speakerId: finalSpeakerId,
            target: target,
            accountLease: accountLease
        )

        let payload: [String: Any] = [
            "userId": accountLease.subjectId,
            "voiceProfileId": finalSpeakerId,
            "sampleStatus": VoiceCloneSampleStatus.pending.rawValue,
            "sampleCount": 1,
            "authorizationConfirmed": authorizationConfirmed,
            "authorizationVersion": "voice-clone-consent-v1",
            "consentVersion": "voice-clone-consent-v1",
            "purpose": "training",
            "authorizationText": Self.authorizationCopy,
            "personaScope": target.personaScope,
            "digitalHumanId": target.digitalHumanId,
            "audioBase64": base64Audio,
            "audioFormat": format,
            "sampleVersion": "voice-sample-v1",
            "sampleAuthorizationReceiptId": sampleAuthorization.receiptId,
            "sampleAuthorizationStatementId": sampleAuthorization.statementId,
            "language": language,
            "privacyMetadata": ["scope": "generationAllowed"],
        ]

        let handleSubmission: (Result<VoiceCloneProfileContract, Error>) -> Void = { [weak self] result in
            guard let self,
                  self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .runtime) else {
                return
            }
            switch result {
            case .success(let profile):
                guard self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .commit) else {
                    return
                }
                self.persistBackendProfileIfUsable(
                    profile,
                    target: target,
                    accountLease: accountLease
                )
                guard self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .commit) else {
                    return
                }
                DDLogInfo("[VoiceClone] 后端已接收音色训练: \(profile.voiceProfileId), status=\(profile.sampleStatus.rawValue)")
                if self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .ui) {
                    onProfileAccepted?(VoiceCloneProfileSnapshot(backendContract: profile))
                }
                if profile.sampleStatus == .ready {
                    self.deliverTrainingResult(
                        .success(profile.voiceProfileId),
                        operation: trainingOperation,
                        primaryCompletion: completion
                    )
                } else if profile.sampleStatus == .failed {
                    self.deliverTrainingResult(
                        .failure(
                            .trainingFailed(
                                code: 3,
                                message: Self.trainingFailureMessage(from: profile.providerMessage)
                            )
                        ),
                        operation: trainingOperation,
                        primaryCompletion: completion
                    )
                } else {
                    self.startPollingStatus(
                        operation: trainingOperation,
                        completion: completion
                    )
                }
            case .failure(let error):
                DDLogError("[VoiceClone] 后端训练请求失败: \(error.localizedDescription)")
                self.deliverTrainingResult(
                    .failure(.networkError(error.localizedDescription)),
                    operation: trainingOperation,
                    primaryCompletion: completion
                )
            }
        }

        if let retryRequest {
            DDLogInfo("[VoiceClone] 通过后端重试音色训练: \(finalSpeakerId), retryGeneration=\(retryRequest.retryGeneration), scope=\(target.personaScope), digitalHumanId=\(target.digitalHumanId), 音频大小: \(audioData.count) bytes")
            DreamJourneyBackendClient.shared.retryVoiceCloneProfile(
                userId: accountLease.subjectId,
                profileId: finalSpeakerId,
                retryGeneration: retryRequest.retryGeneration,
                expectedProfileVersion: retryRequest.expectedProfileVersion,
                payload: payload,
                completion: handleSubmission
            )
        } else {
            DDLogInfo("[VoiceClone] 通过后端提交音色训练: \(finalSpeakerId), scope=\(target.personaScope), digitalHumanId=\(target.digitalHumanId), 音频大小: \(audioData.count) bytes")
            DreamJourneyBackendClient.shared.saveVoiceCloneProfile(
                payload: payload,
                completion: handleSubmission
            )
        }
    }

    /// Obtains a server-signed statement before showing the user's explicit
    /// confirmation prompt. The returned profile ID is passed back unchanged
    /// when the sample is submitted, so an initial attempt cannot accidentally
    /// switch to a different provider slot after confirmation.
    func prepareSampleAuthorization(
        speakerId: String? = nil,
        retryingProfile: VoiceCloneProfileSnapshot? = nil,
        completion: @escaping (Result<VoiceCloneSampleAuthorizationPreparation, VoiceCloneError>) -> Void
    ) {
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }
        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        let accountLease = operation.accountLease
        let target = operation.target
        let retryRequest: VoiceCloneTrainingRetryRequest?
        if let retryingProfile {
            guard let request = trainingRetryRequest(for: retryingProfile) else {
                completion(.failure(.retryNotAllowed))
                return
            }
            retryRequest = request
        } else {
            retryRequest = nil
        }
        let currentSnapshot = voiceCloneShellSnapshot(accountLease: accountLease, target: target)
        guard currentSnapshot.sampleStatus != .failed || retryRequest != nil else {
            completion(.failure(.retryNotAllowed))
            return
        }
        let finalSpeakerId = retryRequest?.voiceProfileId
            ?? speakerId
            ?? reusableSpeakerIdForTraining(target: target, accountLease: accountLease)
            ?? Self.makeSpeakerId()
        DreamJourneyBackendClient.shared.issueVoiceCloneSampleAuthorization(
            userId: accountLease.subjectId,
            profileId: finalSpeakerId
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed,
                  let currentOperation = self.activePersonaOperation(),
                  currentOperation.accountLease == accountLease,
                  currentOperation.target == target else {
                completion(.failure(.accountSessionChanged))
                return
            }
            switch result {
            case .success(let authorization):
                completion(.success(VoiceCloneSampleAuthorizationPreparation(
                    voiceProfileId: finalSpeakerId,
                    authorization: authorization
                )))
            case .failure(let error):
                DDLogError("[VoiceClone] 样本授权语句请求失败: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }

    /// 查询声音复刻训练状态
    func queryStatus(speakerId: String? = nil,
                     completion: @escaping (Result<VoiceCloneStatus, VoiceCloneError>) -> Void) {
        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        queryStatus(
            speakerId: speakerId,
            target: operation.target,
            accountLease: operation.accountLease,
            completion: completion
        )
    }

    private func queryStatus(
        speakerId: String? = nil,
        target: VoiceClonePersonaTarget,
        accountLease: AccountLease,
        trainingOperation: VoiceCloneTrainingRuntimeOperation? = nil,
        completion: @escaping (Result<VoiceCloneStatus, VoiceCloneError>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              accountLease.subjectId == target.userId,
              trainingOperation == nil
                || (trainingOperation?.accountLease == accountLease
                    && trainingOperation?.target == target) else {
            return
        }
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            deliver(.failure(.apiKeyMissing), accountLease: accountLease, completion: completion)
            return
        }

        let sid = speakerId
            ?? reusableSpeakerIdForTraining(target: target, accountLease: accountLease)
            ?? ""
        guard !sid.isEmpty else {
            deliver(.failure(.speakerIdNotFound), accountLease: accountLease, completion: completion)
            return
        }
        guard trainingOperation?.speakerId == nil || trainingOperation?.speakerId == sid else {
            return
        }

        DreamJourneyBackendClient.shared.refreshVoiceCloneProfile(
            userId: accountLease.subjectId,
            profileId: sid
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            guard let trainingOperation else {
                self.handleVoiceCloneStatusResult(
                    result,
                    target: target,
                    accountLease: accountLease,
                    completion: completion
                )
                return
            }
            guard self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .runtime) else {
                return
            }
            self.handleVoiceCloneStatusResult(
                result,
                target: target,
                accountLease: accountLease,
                trainingOperation: trainingOperation,
                completion: completion
            )
        }
    }

    private func handleVoiceCloneStatusResult(
        _ result: Result<VoiceCloneProfileContract, Error>,
        target: VoiceClonePersonaTarget,
        accountLease: AccountLease,
        trainingOperation: VoiceCloneTrainingRuntimeOperation? = nil,
        completion: @escaping (Result<VoiceCloneStatus, VoiceCloneError>) -> Void
    ) {
        switch result {
        case .success(let profile):
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
                  trainingOperation == nil
                    || isCurrentTrainingRuntimeOperation(trainingOperation!, at: .commit) else {
                return
            }
            persistBackendProfileIfUsable(
                profile,
                target: target,
                accountLease: accountLease
            )
            guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
                  trainingOperation == nil
                    || isCurrentTrainingRuntimeOperation(trainingOperation!, at: .commit) else {
                return
            }
            DDLogInfo("[VoiceClone] 后端查询状态: speakerId=\(profile.voiceProfileId), status=\(profile.sampleStatus.rawValue)")
            deliver(
                .success(Self.cloneStatus(from: profile)),
                accountLease: accountLease,
                completion: completion
            )
        case .failure(let error):
            DDLogError("[VoiceClone] 后端查询失败: \(error.localizedDescription)")
            guard trainingOperation == nil
                    || isCurrentTrainingRuntimeOperation(trainingOperation!, at: .runtime) else {
                return
            }
            deliver(
                .failure(.networkError(error.localizedDescription)),
                accountLease: accountLease,
                completion: completion
            )
        }
    }

    private static func cloneStatus(from profile: VoiceCloneProfileContract) -> VoiceCloneStatus {
        if isBackendProfileReadyForUse(profile) {
            return .success
        }
        return cloneStatus(from: profile.sampleStatus)
    }

    private static func cloneStatus(from sampleStatus: VoiceCloneSampleStatus) -> VoiceCloneStatus {
        switch sampleStatus {
        case .notProvided, .deleted:
            return .notFound
        case .pending:
            return .training
        case .ready:
            return .success
        case .disabled:
            return .notFound
        case .failed:
            return .failed
        }
    }

    private func reusableSpeakerIdForTraining(
        target: VoiceClonePersonaTarget,
        accountLease: AccountLease
    ) -> String? {
        if let memberId = target.familyMemberId,
           let member = FamilyRepository.shared.get(by: memberId),
           let voiceProfileId = member.normalizedVoiceProfileId {
            let storedStatus = VoiceCloneSampleStatus(rawValue: member.voiceSampleStatus)
            switch storedStatus {
            case .failed, .deleted, .disabled:
                return nil
            case .notProvided, .none:
                return nil
            case .pending, .ready:
                return voiceProfileId
            }
        }

        guard accountLease.subjectId == target.userId,
              let state = localStateStore.load(accountLease: accountLease),
              let speakerId = normalizedVoiceProfileId(state.speakerId),
              !speakerId.isEmpty else {
            return nil
        }
        switch state.sampleStatus {
        case .failed, .deleted, .disabled:
            return nil
        case .notProvided, .none:
            return nil
        case .pending, .ready:
            return speakerId
        }
    }

    private func trainingRetryRequest(for snapshot: VoiceCloneProfileSnapshot) -> VoiceCloneTrainingRetryRequest? {
        guard snapshot.canRetryTraining,
              let voiceProfileId = normalizedVoiceProfileId(snapshot.voiceProfileId),
              snapshot.profileVersion > 0 else {
            return nil
        }
        return VoiceCloneTrainingRetryRequest(
            voiceProfileId: voiceProfileId,
            retryGeneration: snapshot.retryGeneration + 1,
            expectedProfileVersion: snapshot.profileVersion
        )
    }

    private static func makeSpeakerId() -> String {
        "vp_\(UUID().uuidString.prefix(8))"
    }

    private static func trainingFailureMessage(from providerMessage: String) -> String {
        let trimmed = providerMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "音色训练失败"
        }
        if trimmed.localizedCaseInsensitiveContains("Invalid X-Api-Key") {
            return "服务器火山音色复刻 API Key 无效，请更新后端配置后重试。"
        }
        if trimmed.localizedCaseInsensitiveContains("resource not granted")
            || trimmed.localizedCaseInsensitiveContains("volc.megatts.timbre") {
            return "火山声音复刻资源未授权。请在服务器确认音色模式：预付费/免费音色需配置 consoleSpeakerId 和控制台生成的 S_ 音色 ID；后付费自定义音色需开通 volc.megatts.timbre 资源权限。"
        }
        return trimmed
    }

    /// 检查当前音色是否已就绪（可用）
    func isVoiceReady(speakerId: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let operation = activePersonaOperation() else {
            completion(false)
            return
        }
        isVoiceReady(
            speakerId: speakerId,
            accountLease: operation.accountLease,
            target: operation.target,
            completion: completion
        )
    }

    func isVoiceReady(
        speakerId: String? = nil,
        accountLease: AccountLease,
        completion: @escaping (Bool) -> Void
    ) {
        let target = currentPersonaTarget(userId: accountLease.subjectId)
        isVoiceReady(
            speakerId: speakerId,
            accountLease: accountLease,
            target: target,
            completion: completion
        )
    }

    private func isVoiceReady(
        speakerId: String?,
        accountLease: AccountLease,
        target: VoiceClonePersonaTarget,
        completion: @escaping (Bool) -> Void
    ) {
        queryStatus(
            speakerId: speakerId,
            target: target,
            accountLease: accountLease
        ) { result in
            switch result {
            case .success(let status):
                completion(status == .success || status == .active)
            case .failure:
                completion(false)
            }
        }
    }

    /// App 回到前台时检查是否有未完成的声音复刻训练
    /// VoiceCloneService 使用 Timer 轮询训练状态，App 进入后台后 Timer 会被挂起
    /// 此方法在 App 回前台时调用，如果训练已完成则直接回调等待方（而不是发通知）
    func checkPendingTraining() {
        guard (pendingCompletion != nil || pollTimer != nil),
              let operation = trainingRuntimeOperation else {
            return
        }
        guard isCurrentTrainingRuntimeOperation(operation, at: .timer) else {
            invalidateTrainingRuntime(expected: operation)
            return
        }
        queryStatus(
            speakerId: operation.speakerId,
            target: operation.target,
            accountLease: operation.accountLease,
            trainingOperation: operation
        ) { [weak self] result in
            guard let self,
                  self.isCurrentTrainingRuntimeOperation(operation, at: .runtime) else {
                return
            }
            guard case .success(let status) = result,
                  status == .success || status == .active else {
                return
            }
            DDLogInfo("[VoiceClone] 回前台检测到声音复刻已就绪: \(operation.speakerId)")
            DispatchQueue.main.async { [weak self] in
                self?.deliverPendingTrainingResult(
                    .success(operation.speakerId),
                    operation: operation
                )
            }
        }
    }

    /// 等待音色就绪（用于 FlowManager 流水线中有序等待）
    /// 如果音色已经就绪则立即回调，否则启动轮询等待
    /// - Parameters:
    ///   - speakerId: 要等待的音色 ID
    ///   - completion: 结果回调
    func waitForVoiceReady(speakerId: String, completion: @escaping (Result<String, VoiceCloneError>) -> Void) {
        guard let operation = activePersonaOperation() else {
            completion(.failure(.accountSessionChanged))
            return
        }
        let accountLease = operation.accountLease
        let target = operation.target
        if let activeOperation = trainingRuntimeOperation,
           activeOperation.speakerId == speakerId,
           activeOperation.target == target,
           activeOperation.accountLease == accountLease,
           isCurrentTrainingRuntimeOperation(activeOperation, at: .timer) {
            // A training request or poll for exactly this owner/persona is already
            // active. Attach the waiter instead of creating another provider poll.
            pendingCompletion = completion
            return
        }

        let trainingOperation = beginTrainingRuntime(
            speakerId: speakerId,
            target: target,
            accountLease: accountLease
        )
        // 先快速检查一次
        queryStatus(
            speakerId: speakerId,
            target: target,
            accountLease: accountLease,
            trainingOperation: trainingOperation
        ) { [weak self] result in
            guard let self,
                  self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .runtime) else {
                return
            }
            let ready: Bool
            switch result {
            case .success(let status):
                ready = status == .success || status == .active
            case .failure:
                ready = false
            }
            if ready {
                DDLogInfo("[VoiceClone] 音色已就绪，无需等待: \(speakerId)")
                self.deliverTrainingResult(
                    .success(speakerId),
                    operation: trainingOperation,
                    primaryCompletion: completion
                )
            } else {
                DDLogInfo("[VoiceClone] 音色尚未就绪，开始轮询等待: \(speakerId)")
                guard self.isCurrentTrainingRuntimeOperation(trainingOperation, at: .timer) else {
                    return
                }
                self.startPollingStatus(
                    operation: trainingOperation,
                    completion: completion
                )
            }
        }
    }

    // MARK: - 轮询训练状态

    private func startPollingStatus(
        operation: VoiceCloneTrainingRuntimeOperation,
        completion: @escaping (Result<String, VoiceCloneError>) -> Void
    ) {
        guard isCurrentTrainingRuntimeOperation(operation, at: .timer),
              operation.accountLease.subjectId == operation.target.userId else {
            return
        }
        var pollCount = 0
        let maxPolls = 30  // 最多轮询 30 次，约 2.5 分钟

        pollTimer?.invalidate()
        bindTrainingPrimaryCompletion(completion, to: operation)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard self.isCurrentTrainingRuntimeOperation(operation, at: .timer) else {
                self.invalidateTrainingRuntime(expected: operation, timer: timer)
                return
            }

            pollCount += 1
            if pollCount > maxPolls {
                self.deliverTrainingResult(
                    .failure(.trainingTimeout),
                    operation: operation,
                    primaryCompletion: completion,
                    timer: timer
                )
                return
            }

            self.queryStatus(
                speakerId: operation.speakerId,
                target: operation.target,
                accountLease: operation.accountLease,
                trainingOperation: operation
            ) { result in
                guard self.isCurrentTrainingRuntimeOperation(operation, at: .runtime) else {
                    return
                }
                switch result {
                case .success(let status):
                    switch status {
                    case .success, .active:
                        DDLogInfo("[VoiceClone] 音色训练完成: \(operation.speakerId)")
                        if !operation.target.isFamilyMember {
                            guard self.isCurrentTrainingRuntimeOperation(operation, at: .commit) else {
                                return
                            }
                            self.saveSampleStatus(
                                .ready,
                                accountLease: operation.accountLease
                            )
                        }
                        DispatchQueue.main.async { [weak self] in
                            self?.deliverTrainingResult(
                                .success(operation.speakerId),
                                operation: operation,
                                primaryCompletion: completion,
                                timer: timer
                            )
                        }
                    case .failed:
                        DispatchQueue.main.async { [weak self] in
                            let failure = VoiceCloneError.trainingFailed(
                                code: 3,
                                message: "音色训练失败"
                            )
                            self?.deliverTrainingResult(
                                .failure(failure),
                                operation: operation,
                                primaryCompletion: completion,
                                timer: timer
                            )
                        }
                    case .training:
                        // 继续轮询
                        DDLogInfo("[VoiceClone] 音色训练中... (\(pollCount)/\(maxPolls))")
                        break
                    case .notFound:
                        DispatchQueue.main.async { [weak self] in
                            let failure = VoiceCloneError.trainingFailed(
                                code: 0,
                                message: "音色未找到"
                            )
                            self?.deliverTrainingResult(
                                .failure(failure),
                                operation: operation,
                                primaryCompletion: completion,
                                timer: timer
                            )
                        }
                    }
                case .failure(let error):
                    // 网络错误不中断轮询，继续尝试
                    DDLogWarn("[VoiceClone] 轮询查询失败: \(error.localizedDescription)")
                    break
                }
            }
        }
    }

    // MARK: - 工具方法

    /// 从文件 URL 推断音频格式
    private func audioFormat(from url: URL) -> String? {
        url.pathExtension.lowercased() == "wav" ? "wav" : nil
    }
}

// MARK: - 错误类型

enum VoiceCloneError: LocalizedError {
    case apiKeyMissing
    case accountSessionChanged
    case authorizationRequired
    case retryNotAllowed
    case speakerIdNotFound
    case audioReadFailed
    case unsupportedAudioFormat
    case audioTooLarge          // > 10MB
    case networkError(String)
    case invalidResponse
    case trainingFailed(code: Int, message: String)
    case trainingTimeout        // 轮询超时

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "声音复刻后端未配置，请先在服务器环境变量中配置火山声音复刻凭证"
        case .accountSessionChanged:
            return "账号状态已变化，请重新进入声音复刻页面后重试"
        case .authorizationRequired:
            return "请先确认本人授权后再提交声音样本"
        case .retryNotAllowed:
            return "当前失败记录尚未获得重试许可，请先刷新训练状态。"
        case .speakerIdNotFound:
            return "未找到声音复刻音色 ID"
        case .audioReadFailed:
            return "音频文件读取失败，请确认文件已下载到本机后重试"
        case .unsupportedAudioFormat:
            return "当前声音复刻只支持可验证的 WAV 音频格式"
        case .audioTooLarge:
            return "音频文件过大（最大 10MB），请剪裁或压缩后重试"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .invalidResponse:
            return "声音复刻服务返回数据异常"
        case .trainingFailed(_, let msg):
            return "声音复刻训练失败: \(msg)"
        case .trainingTimeout:
            return "声音复刻训练超时，请稍后重试"
        }
    }
}
