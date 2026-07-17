import Foundation
import CocoaLumberjack

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
        providerSlotState: String = ""
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
            providerSlotState: backendContract.providerSlotState
        )
    }

    var isReadyForUse: Bool {
        sampleStatus == .ready && isEnabled && realCloneProviderReady && !qualityAcceptanceRequired
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

private struct VoiceClonePersonaTarget {
    let userId: String
    let personaScope: String
    let digitalHumanId: String
    let familyMemberId: String?

    var isFamilyMember: Bool {
        familyMemberId != nil
    }
}

/// 封装 DreamJourney 后端声音复刻合同：
/// 1. iOS 只提交授权后的声音样本给后端
/// 2. 后端持有火山引擎声音复刻 API Key 并代理训练/查询
/// 3. 训练成功后 voiceProfileId/speaker_id 可用于后端代理合成
final class VoiceCloneService {

    static let shared = VoiceCloneService()

    // MARK: - 配置

    /// 当前用户的 speaker_id（持久化到 UserDefaults）
    private let speakerIdKey = "dj.voiceclone.speakerId"
    private let sampleStatusKey = "dj.voiceclone.sampleStatus"
    private let isEnabledKey = "dj.voiceclone.isEnabled"
    private let realCloneProviderReadyKey = "dj.voiceclone.realCloneProviderReady"
    private let qualityAcceptanceRequiredKey = "dj.voiceclone.qualityAcceptanceRequired"
    private let providerModeKey = "dj.voiceclone.providerMode"
    private let providerStatusKey = "dj.voiceclone.providerStatus"
    private let providerMessageKey = "dj.voiceclone.providerMessage"
    private static let emptyVoiceProfileId = "voiceProfileId_not_created"
    static let backendContractEndpoint = "/voice/profiles"
    private static let authorizationCopy = "音色复刻必须由用户主动授权，仅使用用户确认提交的声音样本；训练、查询、合成、禁用和删除都通过 DreamJourney 后端代理执行，iOS 不保存火山语音密钥。"
    private static let disableContract = "禁用音色会调用后端撤销该 voiceProfileId 的合成权限，并在本地记录样本已禁用。"
    private static let deleteContract = "删除音色会调用后端删除样本、训练产物和关联授权记录，并清理本地 voiceProfileId。"

    /// 训练轮询定时器
    private var pollTimer: Timer?

    /// 正在等待音色就绪的回调（用于 checkPendingTraining 加速完成）
    /// 当 App 从后台回到前台时，如果训练已完成，通过此回调通知等待方
    private var pendingCompletion: ((Result<String, VoiceCloneError>) -> Void)?

    /// 训练中的 speakerId（用于 checkPendingTraining 匹配）
    private var trainingSpeakerId: String?
    private var trainingPersonaTarget: VoiceClonePersonaTarget?
    private var trainingAccountLease: AccountLease?
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    // MARK: - Init

    private init(accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared) {
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    // MARK: - 公开 API

    /// 获取当前保存的 speaker_id
    var currentSpeakerId: String? {
        return UserDefaults.standard.string(forKey: speakerIdKey)
    }

    var currentUsableSpeakerId: String? {
        let snapshot = voiceCloneShellSnapshot()
        guard snapshot.isReadyForUse,
              let speakerId = normalizedVoiceProfileId(snapshot.voiceProfileId) else {
            return nil
        }
        return speakerId
    }

    func voiceCloneShellSnapshot() -> VoiceCloneProfileSnapshot {
        let userId = UserManager.shared.currentUser?.id ?? "default"
        let target = currentPersonaTarget(userId: userId)
        if let familySnapshot = familyVoiceCloneShellSnapshot(for: target) {
            return familySnapshot
        }

        let storedStatus = UserDefaults.standard.string(forKey: sampleStatusKey)
            .flatMap(VoiceCloneSampleStatus.init(rawValue:))
        let profileId = currentSpeakerId ?? Self.emptyVoiceProfileId
        let sampleStatus = storedStatus ?? (currentSpeakerId == nil ? .notProvided : .pending)
        let storedProviderMode = UserDefaults.standard.string(forKey: providerModeKey) ?? "localFallback"
        let storedProviderStatus = UserDefaults.standard.string(forKey: providerStatusKey) ?? ""
        let storedProviderMessage = UserDefaults.standard.string(forKey: providerMessageKey) ?? ""
        return VoiceCloneProfileSnapshot(
            voiceProfileId: profileId,
            sampleStatus: sampleStatus,
            authorizationCopy: Self.authorizationCopy,
            isEnabled: storedBool(forKey: isEnabledKey) ?? false,
            realCloneProviderReady: storedBool(forKey: realCloneProviderReadyKey) ?? false,
            qualityAcceptanceRequired: storedBool(forKey: qualityAcceptanceRequiredKey) ?? true,
            disableContract: Self.disableContract,
            deleteContract: Self.deleteContract,
            providerMode: storedProviderMode,
            providerStatus: storedProviderStatus,
            providerMessage: storedProviderMessage
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
        let userId = UserManager.shared.currentUser?.id ?? "default"
        let target = currentPersonaTarget(userId: userId)
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
        let userId = UserManager.shared.currentUser?.id ?? "default"
        persistSnapshot(snapshot, target: currentPersonaTarget(userId: userId))
    }

    private func persistSnapshot(_ snapshot: VoiceCloneProfileSnapshot, target: VoiceClonePersonaTarget) {
        if let memberId = target.familyMemberId {
            FamilyRepository.shared.updateVoiceProfile(
                memberId: memberId,
                voiceProfileId: normalizedVoiceProfileId(snapshot.voiceProfileId),
                sampleStatus: snapshot.sampleStatus.rawValue,
                voiceEnabled: snapshot.isEnabled
            )
            return
        }

        if let speakerId = normalizedVoiceProfileId(snapshot.voiceProfileId),
           snapshot.sampleStatus != .notProvided,
           snapshot.sampleStatus != .deleted {
            UserDefaults.standard.set(speakerId, forKey: speakerIdKey)
        } else if snapshot.sampleStatus == .notProvided || snapshot.sampleStatus == .deleted {
            clearStoredSpeakerId()
        }
        saveSampleStatus(snapshot.sampleStatus)
        saveBackendState(snapshot)
    }

    @discardableResult
    func disableVoiceProfile(profileId: String) -> VoiceCloneProfileSnapshot {
        guard !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return voiceCloneShellSnapshot()
        }
        UserDefaults.standard.set(VoiceCloneSampleStatus.disabled.rawValue, forKey: sampleStatusKey)
        UserDefaults.standard.set(false, forKey: isEnabledKey)
        return voiceCloneShellSnapshot()
    }

    @discardableResult
    func deleteVoiceProfile(profileId: String) -> VoiceCloneProfileSnapshot {
        guard !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return voiceCloneShellSnapshot()
        }
        UserDefaults.standard.removeObject(forKey: speakerIdKey)
        UserDefaults.standard.set(VoiceCloneSampleStatus.deleted.rawValue, forKey: sampleStatusKey)
        UserDefaults.standard.set(false, forKey: isEnabledKey)
        UserDefaults.standard.set(false, forKey: realCloneProviderReadyKey)
        return voiceCloneShellSnapshot()
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
                self.persistBackendProfileIfUsable(profile, target: target)
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
                self.persistBackendProfileIfUsable(profile, target: target)
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
        DreamJourneyBackendClient.shared.acceptVoiceCloneQuality(
            userId: accountLease.subjectId,
            profileId: trimmedProfileId
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
                self.persistSnapshot(snapshot, target: target)
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

    /// 保存 speaker_id
    private func saveSpeakerId(_ id: String) {
        UserDefaults.standard.set(id, forKey: speakerIdKey)
        UserDefaults.standard.set(VoiceCloneSampleStatus.pending.rawValue, forKey: sampleStatusKey)
        UserDefaults.standard.set(false, forKey: isEnabledKey)
    }

    private func saveSampleStatus(_ status: VoiceCloneSampleStatus) {
        UserDefaults.standard.set(status.rawValue, forKey: sampleStatusKey)
    }

    private func clearStoredSpeakerId() {
        UserDefaults.standard.removeObject(forKey: speakerIdKey)
    }

    private func persistBackendProfileIfUsable(_ profile: VoiceCloneProfileContract, target: VoiceClonePersonaTarget? = nil) {
        let snapshot = VoiceCloneProfileSnapshot(backendContract: profile)
        let userId = UserManager.shared.currentUser?.id ?? "default"
        let resolvedTarget = target ?? personaTarget(from: profile, fallbackUserId: userId) ?? currentPersonaTarget(userId: userId)
        persistSnapshot(snapshot, target: resolvedTarget)
    }

    private static func isBackendProfileReadyForUse(_ profile: VoiceCloneProfileContract) -> Bool {
        profile.sampleStatus == .ready && profile.isEnabled && profile.realCloneProviderReady && !profile.qualityAcceptanceRequired
    }

    private func storedBool(forKey key: String) -> Bool? {
        guard UserDefaults.standard.object(forKey: key) != nil else {
            return nil
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func saveBackendState(_ snapshot: VoiceCloneProfileSnapshot) {
        UserDefaults.standard.set(snapshot.isEnabled, forKey: isEnabledKey)
        UserDefaults.standard.set(snapshot.realCloneProviderReady, forKey: realCloneProviderReadyKey)
        UserDefaults.standard.set(snapshot.qualityAcceptanceRequired, forKey: qualityAcceptanceRequiredKey)
        UserDefaults.standard.set(snapshot.providerMode, forKey: providerModeKey)
        UserDefaults.standard.set(snapshot.providerStatus, forKey: providerStatusKey)
        UserDefaults.standard.set(snapshot.providerMessage, forKey: providerMessageKey)
    }

    private func normalizedVoiceProfileId(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != Self.emptyVoiceProfileId else {
            return nil
        }
        return trimmed
    }

    private func activePersonaOperation() -> (accountLease: AccountLease, target: VoiceClonePersonaTarget)? {
        guard let userId = UserManager.shared.currentUser?.id,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        return (accountLease, currentPersonaTarget(userId: accountLease.subjectId))
    }

    private func deliver<T>(
        _ result: Result<T, VoiceCloneError>,
        accountLease: AccountLease,
        completion: @escaping (Result<T, VoiceCloneError>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
        completion(result)
    }

    private func clearTrainingStateIfOwned(
        speakerId: String,
        accountLease: AccountLease,
        timer: Timer? = nil
    ) {
        guard trainingSpeakerId == speakerId,
              trainingAccountLease == accountLease else {
            timer?.invalidate()
            return
        }
        timer?.invalidate()
        pollTimer?.invalidate()
        pollTimer = nil
        trainingSpeakerId = nil
        trainingPersonaTarget = nil
        trainingAccountLease = nil
    }

    private func currentPersonaTarget(userId: String) -> VoiceClonePersonaTarget {
        let context = DigitalHumanContextStore.shared.current
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
    ///   - audioURL: 本地音频文件 URL（wav/mp3/m4a/aac，建议 ≥10秒，≤10MB）
    ///   - speakerId: 指定的音色 ID，为空则自动生成
    ///   - language: 语种，0=中文（默认）
    ///   - authorizationConfirmed: 用户已主动确认本人授权
    ///   - onProfileAccepted: 后端接收 pending/ready profile 后的即时回调，用于 UI 回显 voiceProfileId
    ///   - completion: 结果回调
    func trainVoice(audioURL: URL,
                    speakerId: String? = nil,
                    language: Int = 0,
                    authorizationConfirmed: Bool,
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

        // 失败/删除/禁用后的重试不能复用旧 speakerId，否则 provider 侧可能继续命中
        // 已经失败或归属错误的音色资源，导致 resource mismatch 一直存在。
        let finalSpeakerId = speakerId ?? reusableSpeakerIdForTraining(target: target) ?? Self.makeSpeakerId()

        // 确定音频格式
        guard let format = audioFormat(from: audioURL) else {
            completion(.failure(.unsupportedAudioFormat))
            return
        }

        let payload: [String: Any] = [
            "userId": accountLease.subjectId,
            "voiceProfileId": finalSpeakerId,
            "sampleStatus": VoiceCloneSampleStatus.pending.rawValue,
            "sampleCount": 1,
            "authorizationConfirmed": authorizationConfirmed,
            "authorizationVersion": "voice-clone-consent-v1",
            "authorizationText": Self.authorizationCopy,
            "personaScope": target.personaScope,
            "digitalHumanId": target.digitalHumanId,
            "audioBase64": base64Audio,
            "audioFormat": format,
            "language": language,
            "privacyMetadata": ["scope": "generationAllowed"],
        ]

        DDLogInfo("[VoiceClone] 通过后端提交音色训练: \(finalSpeakerId), scope=\(target.personaScope), digitalHumanId=\(target.digitalHumanId), 音频大小: \(audioData.count) bytes")
        DreamJourneyBackendClient.shared.saveVoiceCloneProfile(payload: payload) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            switch result {
            case .success(let profile):
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.persistBackendProfileIfUsable(profile, target: target)
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                DDLogInfo("[VoiceClone] 后端已接收音色训练: \(profile.voiceProfileId), status=\(profile.sampleStatus.rawValue)")
                if self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed {
                    onProfileAccepted?(VoiceCloneProfileSnapshot(backendContract: profile))
                }
                if profile.sampleStatus == .ready {
                    self.deliver(
                        .success(profile.voiceProfileId),
                        accountLease: accountLease,
                        completion: completion
                    )
                } else if profile.sampleStatus == .failed {
                    self.deliver(
                        .failure(
                            .trainingFailed(
                                code: 3,
                                message: Self.trainingFailureMessage(from: profile.providerMessage)
                            )
                        ),
                        accountLease: accountLease,
                        completion: completion
                    )
                } else {
                    self.startPollingStatus(
                        speakerId: profile.voiceProfileId,
                        target: target,
                        accountLease: accountLease,
                        completion: completion
                    )
                }
            case .failure(let error):
                DDLogError("[VoiceClone] 后端训练请求失败: \(error.localizedDescription)")
                self.deliver(
                    .failure(.networkError(error.localizedDescription)),
                    accountLease: accountLease,
                    completion: completion
                )
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
        completion: @escaping (Result<VoiceCloneStatus, VoiceCloneError>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              accountLease.subjectId == target.userId else {
            return
        }
        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            deliver(.failure(.apiKeyMissing), accountLease: accountLease, completion: completion)
            return
        }

        let sid = speakerId ?? reusableSpeakerIdForTraining(target: target) ?? currentSpeakerId ?? ""
        guard !sid.isEmpty else {
            deliver(.failure(.speakerIdNotFound), accountLease: accountLease, completion: completion)
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
            switch result {
            case .success(let profile):
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                self.persistBackendProfileIfUsable(profile, target: target)
                guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    return
                }
                DDLogInfo("[VoiceClone] 后端查询状态: speakerId=\(sid), status=\(profile.sampleStatus.rawValue)")
                self.deliver(
                    .success(Self.cloneStatus(from: profile)),
                    accountLease: accountLease,
                    completion: completion
                )
            case .failure(let error):
                DDLogError("[VoiceClone] 后端查询失败: \(error.localizedDescription)")
                self.deliver(
                    .failure(.networkError(error.localizedDescription)),
                    accountLease: accountLease,
                    completion: completion
                )
            }
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

    private func reusableSpeakerIdForTraining(target: VoiceClonePersonaTarget? = nil) -> String? {
        if let target,
           let memberId = target.familyMemberId,
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

        guard let speakerId = currentSpeakerId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !speakerId.isEmpty else {
            return nil
        }
        let storedStatus = UserDefaults.standard.string(forKey: sampleStatusKey)
            .flatMap(VoiceCloneSampleStatus.init(rawValue:))
        switch storedStatus {
        case .failed, .deleted, .disabled:
            return nil
        case .notProvided, .none:
            return nil
        case .pending, .ready:
            return speakerId
        }
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
        guard let speakerId = trainingSpeakerId ?? currentSpeakerId else { return }
        // 只有在有 pendingCompletion 时才检查（说明有等待方）
        guard pendingCompletion != nil || pollTimer != nil else { return }
        guard let accountLease = trainingAccountLease,
              accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
              let target = trainingPersonaTarget else {
            pollTimer?.invalidate()
            pollTimer = nil
            pendingCompletion = nil
            trainingSpeakerId = nil
            trainingPersonaTarget = nil
            trainingAccountLease = nil
            return
        }
        queryStatus(
            speakerId: speakerId,
            target: target,
            accountLease: accountLease
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            guard case .success(let status) = result,
                  status == .success || status == .active else {
                return
            }
            DDLogInfo("[VoiceClone] 回前台检测到声音复刻已就绪: \(speakerId)")
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed,
                      self.trainingSpeakerId == speakerId,
                      self.trainingAccountLease == accountLease else {
                    return
                }
                let pending = self.pendingCompletion
                self.pendingCompletion = nil
                self.clearTrainingStateIfOwned(
                    speakerId: speakerId,
                    accountLease: accountLease
                )
                pending?(.success(speakerId))
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
        // 先快速检查一次
        queryStatus(
            speakerId: speakerId,
            target: target,
            accountLease: accountLease
        ) { [weak self] result in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
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
                self.deliver(
                    .success(speakerId),
                    accountLease: accountLease,
                    completion: completion
                )
            } else {
                DDLogInfo("[VoiceClone] 音色尚未就绪，开始轮询等待: \(speakerId)")
                guard self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
                    return
                }
                // 如果已有轮询在进行（比如 trainVoice 启动的），保存 completion 等轮询完成时回调
                if self.pollTimer != nil,
                   self.trainingSpeakerId == speakerId,
                   self.trainingAccountLease == accountLease {
                    // 轮询已在进行，只需注册回调
                    self.pendingCompletion = completion
                    self.trainingSpeakerId = speakerId
                    self.trainingPersonaTarget = target
                    self.trainingAccountLease = accountLease
                } else {
                    // 没有轮询在进行，启动新的轮询
                    self.startPollingStatus(
                        speakerId: speakerId,
                        target: target,
                        accountLease: accountLease,
                        completion: completion
                    )
                    self.pendingCompletion = nil  // startPollingStatus 自己管理 completion
                    self.trainingSpeakerId = speakerId
                    self.trainingPersonaTarget = target
                    self.trainingAccountLease = accountLease
                }
            }
        }
    }

    // MARK: - 轮询训练状态

    private func startPollingStatus(
        speakerId: String,
        target: VoiceClonePersonaTarget,
        accountLease: AccountLease,
        completion: @escaping (Result<String, VoiceCloneError>) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
              accountLease.subjectId == target.userId else {
            return
        }
        var pollCount = 0
        let maxPolls = 30  // 最多轮询 30 次，约 2.5 分钟

        pollTimer?.invalidate()
        trainingSpeakerId = speakerId
        trainingPersonaTarget = target
        trainingAccountLease = accountLease
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                  self.trainingSpeakerId == speakerId,
                  self.trainingAccountLease == accountLease else {
                self.clearTrainingStateIfOwned(
                    speakerId: speakerId,
                    accountLease: accountLease,
                    timer: timer
                )
                self.pendingCompletion = nil
                return
            }

            pollCount += 1
            if pollCount > maxPolls {
                let pending = self.pendingCompletion
                self.pendingCompletion = nil
                self.clearTrainingStateIfOwned(
                    speakerId: speakerId,
                    accountLease: accountLease,
                    timer: timer
                )
                self.deliver(
                    .failure(.trainingTimeout),
                    accountLease: accountLease,
                    completion: completion
                )
                if let pending {
                    self.deliver(
                        .failure(.trainingTimeout),
                        accountLease: accountLease,
                        completion: pending
                    )
                }
                return
            }

            self.queryStatus(
                speakerId: speakerId,
                target: target,
                accountLease: accountLease
            ) { result in
                guard self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                    return
                }
                switch result {
                case .success(let status):
                    switch status {
                    case .success, .active:
                        DDLogInfo("[VoiceClone] 音色训练完成: \(speakerId)")
                        if !target.isFamilyMember {
                            guard self.accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                                return
                            }
                            self.saveSampleStatus(.ready)
                        }
                        DispatchQueue.main.async { [weak self] in
                            guard let self,
                                  self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
                                return
                            }
                            let pending = self.pendingCompletion
                            self.pendingCompletion = nil
                            self.clearTrainingStateIfOwned(
                                speakerId: speakerId,
                                accountLease: accountLease,
                                timer: timer
                            )
                            completion(.success(speakerId))
                            pending?(.success(speakerId))
                        }
                    case .failed:
                        DispatchQueue.main.async { [weak self] in
                            guard let self,
                                  self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
                                return
                            }
                            let pending = self.pendingCompletion
                            self.pendingCompletion = nil
                            self.clearTrainingStateIfOwned(
                                speakerId: speakerId,
                                accountLease: accountLease,
                                timer: timer
                            )
                            let failure = VoiceCloneError.trainingFailed(
                                code: 3,
                                message: "音色训练失败"
                            )
                            completion(.failure(failure))
                            pending?(.failure(failure))
                        }
                    case .training:
                        // 继续轮询
                        DDLogInfo("[VoiceClone] 音色训练中... (\(pollCount)/\(maxPolls))")
                        break
                    case .notFound:
                        DispatchQueue.main.async { [weak self] in
                            guard let self,
                                  self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
                                return
                            }
                            let pending = self.pendingCompletion
                            self.pendingCompletion = nil
                            self.clearTrainingStateIfOwned(
                                speakerId: speakerId,
                                accountLease: accountLease,
                                timer: timer
                            )
                            let failure = VoiceCloneError.trainingFailed(
                                code: 0,
                                message: "音色未找到"
                            )
                            completion(.failure(failure))
                            pending?(.failure(failure))
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
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": return "wav"
        case "mp3": return "mp3"
        case "m4a": return "m4a"
        case "aac": return "aac"
        default: return nil
        }
    }
}

// MARK: - 错误类型

enum VoiceCloneError: LocalizedError {
    case apiKeyMissing
    case accountSessionChanged
    case authorizationRequired
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
        case .speakerIdNotFound:
            return "未找到声音复刻音色 ID"
        case .audioReadFailed:
            return "音频文件读取失败，请确认文件已下载到本机后重试"
        case .unsupportedAudioFormat:
            return "暂只支持 wav、mp3、m4a、aac 音频样本"
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
