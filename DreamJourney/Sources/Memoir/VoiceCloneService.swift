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
    let disableContract: String
    let deleteContract: String
    let providerMode: String
    let contractVersion: Int
    let defaultReleaseVisible: Bool

    init(
        voiceProfileId: String,
        sampleStatus: VoiceCloneSampleStatus,
        authorizationCopy: String,
        isEnabled: Bool,
        disableContract: String,
        deleteContract: String,
        providerMode: String = "localFallback",
        contractVersion: Int = 1,
        defaultReleaseVisible: Bool = true
    ) {
        self.voiceProfileId = voiceProfileId
        self.sampleStatus = sampleStatus
        self.authorizationCopy = authorizationCopy
        self.isEnabled = isEnabled
        self.disableContract = disableContract
        self.deleteContract = deleteContract
        self.providerMode = providerMode
        self.contractVersion = contractVersion
        self.defaultReleaseVisible = defaultReleaseVisible
    }

    init(backendContract: VoiceCloneProfileContract) {
        self.init(
            voiceProfileId: backendContract.voiceProfileId,
            sampleStatus: backendContract.sampleStatus,
            authorizationCopy: backendContract.authorizationCopy,
            isEnabled: backendContract.isEnabled,
            disableContract: backendContract.disableContract,
            deleteContract: backendContract.deleteContract,
            providerMode: backendContract.providerMode,
            contractVersion: backendContract.contractVersion,
            defaultReleaseVisible: backendContract.defaultReleaseVisible
        )
    }
}

// MARK: - 声音复刻服务（后端代理火山引擎 Voice Clone V3）

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

    // MARK: - Init

    private init() {}

    // MARK: - 公开 API

    /// 获取当前保存的 speaker_id
    var currentSpeakerId: String? {
        return UserDefaults.standard.string(forKey: speakerIdKey)
    }

    func voiceCloneShellSnapshot() -> VoiceCloneProfileSnapshot {
        let storedStatus = UserDefaults.standard.string(forKey: sampleStatusKey)
            .flatMap(VoiceCloneSampleStatus.init(rawValue:))
        let profileId = currentSpeakerId ?? Self.emptyVoiceProfileId
        let sampleStatus = storedStatus ?? (currentSpeakerId == nil ? .notProvided : .pending)
        return VoiceCloneProfileSnapshot(
            voiceProfileId: profileId,
            sampleStatus: sampleStatus,
            authorizationCopy: Self.authorizationCopy,
            isEnabled: sampleStatus == .ready,
            disableContract: Self.disableContract,
            deleteContract: Self.deleteContract
        )
    }

    func voiceCloneShellSnapshot(from backendContract: VoiceCloneProfileContract) -> VoiceCloneProfileSnapshot {
        VoiceCloneProfileSnapshot(backendContract: backendContract)
    }

    @discardableResult
    func disableVoiceProfile(profileId: String) -> VoiceCloneProfileSnapshot {
        guard !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return voiceCloneShellSnapshot()
        }
        UserDefaults.standard.set(VoiceCloneSampleStatus.disabled.rawValue, forKey: sampleStatusKey)
        return voiceCloneShellSnapshot()
    }

    @discardableResult
    func deleteVoiceProfile(profileId: String) -> VoiceCloneProfileSnapshot {
        guard !profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return voiceCloneShellSnapshot()
        }
        UserDefaults.standard.removeObject(forKey: speakerIdKey)
        UserDefaults.standard.set(VoiceCloneSampleStatus.deleted.rawValue, forKey: sampleStatusKey)
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

        let userId = UserManager.shared.currentUser?.id ?? "default"
        DreamJourneyBackendClient.shared.disableVoiceCloneProfile(userId: userId, profileId: trimmedProfileId) { [weak self] result in
            switch result {
            case .success(let profile):
                self?.saveSpeakerId(profile.voiceProfileId)
                self?.saveSampleStatus(profile.sampleStatus)
                completion(.success(VoiceCloneProfileSnapshot(backendContract: profile)))
            case .failure(let error):
                DDLogError("[VoiceClone] 后端禁用失败: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
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

        let userId = UserManager.shared.currentUser?.id ?? "default"
        DreamJourneyBackendClient.shared.deleteVoiceCloneProfile(userId: userId, profileId: trimmedProfileId) { [weak self] result in
            switch result {
            case .success(let profile):
                self?.clearStoredSpeakerId()
                self?.saveSampleStatus(profile.sampleStatus)
                completion(.success(VoiceCloneProfileSnapshot(backendContract: profile)))
            case .failure(let error):
                DDLogError("[VoiceClone] 后端删除失败: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }

    /// 保存 speaker_id
    private func saveSpeakerId(_ id: String) {
        UserDefaults.standard.set(id, forKey: speakerIdKey)
        UserDefaults.standard.set(VoiceCloneSampleStatus.pending.rawValue, forKey: sampleStatusKey)
    }

    private func saveSampleStatus(_ status: VoiceCloneSampleStatus) {
        UserDefaults.standard.set(status.rawValue, forKey: sampleStatusKey)
    }

    private func clearStoredSpeakerId() {
        UserDefaults.standard.removeObject(forKey: speakerIdKey)
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

        // 读取音频文件并 base64 编码
        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(.audioReadFailed))
            return
        }

        guard audioData.count <= 10 * 1024 * 1024 else {
            completion(.failure(.audioTooLarge))
            return
        }

        let base64Audio = audioData.base64EncodedString()

        // 确定 speaker_id
        let finalSpeakerId = speakerId ?? currentSpeakerId ?? "S_\(UUID().uuidString.prefix(8))"

        // 确定音频格式
        let format = audioFormat(from: audioURL)

        let userId = UserManager.shared.currentUser?.id ?? "default"
        let payload: [String: Any] = [
            "userId": userId,
            "voiceProfileId": finalSpeakerId,
            "sampleStatus": VoiceCloneSampleStatus.pending.rawValue,
            "sampleCount": 1,
            "authorizationConfirmed": authorizationConfirmed,
            "authorizationVersion": "voice-clone-consent-v1",
            "authorizationText": Self.authorizationCopy,
            "personaScope": "personal",
            "digitalHumanId": userId,
            "audioBase64": base64Audio,
            "audioFormat": format,
            "language": language,
            "privacyMetadata": ["scope": "generationAllowed"],
        ]

        DDLogInfo("[VoiceClone] 通过后端提交音色训练: \(finalSpeakerId), 音频大小: \(audioData.count) bytes")
        DreamJourneyBackendClient.shared.saveVoiceCloneProfile(payload: payload) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let profile):
                self.saveSpeakerId(profile.voiceProfileId)
                self.saveSampleStatus(profile.sampleStatus)
                DDLogInfo("[VoiceClone] 后端已接收音色训练: \(profile.voiceProfileId), status=\(profile.sampleStatus.rawValue)")
                onProfileAccepted?(VoiceCloneProfileSnapshot(backendContract: profile))
                if profile.sampleStatus == .ready {
                    completion(.success(profile.voiceProfileId))
                } else if profile.sampleStatus == .failed {
                    completion(.failure(.trainingFailed(code: 3, message: "音色训练失败")))
                } else {
                    self.startPollingStatus(speakerId: profile.voiceProfileId, completion: completion)
                }
            case .failure(let error):
                DDLogError("[VoiceClone] 后端训练请求失败: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }

    /// 查询声音复刻训练状态
    func queryStatus(speakerId: String? = nil,
                     completion: @escaping (Result<VoiceCloneStatus, VoiceCloneError>) -> Void) {

        guard DreamJourneyBackendClient.shared.isVoiceCloneProfileConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let sid = speakerId ?? currentSpeakerId ?? ""
        guard !sid.isEmpty else {
            completion(.failure(.speakerIdNotFound))
            return
        }

        let userId = UserManager.shared.currentUser?.id ?? "default"
        DreamJourneyBackendClient.shared.refreshVoiceCloneProfile(userId: userId, profileId: sid) { [weak self] result in
            switch result {
            case .success(let profile):
                self?.saveSampleStatus(profile.sampleStatus)
                DDLogInfo("[VoiceClone] 后端查询状态: speakerId=\(sid), status=\(profile.sampleStatus.rawValue)")
                completion(.success(Self.cloneStatus(from: profile.sampleStatus)))
            case .failure(let error):
                DDLogError("[VoiceClone] 后端查询失败: \(error.localizedDescription)")
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
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

    /// 检查当前音色是否已就绪（可用）
    func isVoiceReady(speakerId: String? = nil, completion: @escaping (Bool) -> Void) {
        queryStatus(speakerId: speakerId) { result in
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
        isVoiceReady(speakerId: speakerId) { [weak self] ready in
            guard let self = self, ready else { return }
            DDLogInfo("[VoiceClone] 回前台检测到声音复刻已就绪: \(speakerId)")
            // 在主线程停止轮询（Timer 注册在主线程 RunLoop）
            DispatchQueue.main.async {
                self.pollTimer?.invalidate()
                self.pollTimer = nil
            }
            // 直接回调等待方，不通过通知
            let completion = self.pendingCompletion
            self.pendingCompletion = nil
            self.trainingSpeakerId = nil
            completion?(.success(speakerId))
        }
    }

    /// 等待音色就绪（用于 FlowManager 流水线中有序等待）
    /// 如果音色已经就绪则立即回调，否则启动轮询等待
    /// - Parameters:
    ///   - speakerId: 要等待的音色 ID
    ///   - completion: 结果回调
    func waitForVoiceReady(speakerId: String, completion: @escaping (Result<String, VoiceCloneError>) -> Void) {
        // 先快速检查一次
        isVoiceReady(speakerId: speakerId) { [weak self] ready in
            guard let self = self else { return }
            if ready {
                DDLogInfo("[VoiceClone] 音色已就绪，无需等待: \(speakerId)")
                completion(.success(speakerId))
            } else {
                DDLogInfo("[VoiceClone] 音色尚未就绪，开始轮询等待: \(speakerId)")
                // 如果已有轮询在进行（比如 trainVoice 启动的），保存 completion 等轮询完成时回调
                if self.pollTimer != nil {
                    // 轮询已在进行，只需注册回调
                    self.pendingCompletion = completion
                    self.trainingSpeakerId = speakerId
                } else {
                    // 没有轮询在进行，启动新的轮询
                    self.startPollingStatus(speakerId: speakerId, completion: completion)
                    self.pendingCompletion = nil  // startPollingStatus 自己管理 completion
                    self.trainingSpeakerId = speakerId
                }
            }
        }
    }

    // MARK: - 轮询训练状态

    private func startPollingStatus(speakerId: String, completion: @escaping (Result<String, VoiceCloneError>) -> Void) {
        var pollCount = 0
        let maxPolls = 30  // 最多轮询 30 次，约 2.5 分钟

        pollTimer?.invalidate()
        trainingSpeakerId = speakerId
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            pollCount += 1
            if pollCount > maxPolls {
                timer.invalidate()
                self.pollTimer = nil
                self.trainingSpeakerId = nil
                let pending = self.pendingCompletion
                self.pendingCompletion = nil
                // 通知两个回调方
                completion(.failure(.trainingTimeout))
                pending?(.failure(.trainingTimeout))
                return
            }

            self.queryStatus(speakerId: speakerId) { result in
                switch result {
                case .success(let status):
                    switch status {
                    case .success, .active:
                        DDLogInfo("[VoiceClone] 音色训练完成: \(speakerId)")
                        self.saveSampleStatus(.ready)
                        DispatchQueue.main.async {
                            timer.invalidate()
                            self.pollTimer = nil
                            self.trainingSpeakerId = nil
                        }
                        // 回调原始调用方 + 等待方（如果有）
                        let pending = self.pendingCompletion
                        self.pendingCompletion = nil
                        completion(.success(speakerId))
                        pending?(.success(speakerId))
                    case .failed:
                        DispatchQueue.main.async {
                            timer.invalidate()
                            self.pollTimer = nil
                            self.trainingSpeakerId = nil
                        }
                        let pending = self.pendingCompletion
                        self.pendingCompletion = nil
                        completion(.failure(.trainingFailed(code: 3, message: "音色训练失败")))
                        pending?(.failure(.trainingFailed(code: 3, message: "音色训练失败")))
                    case .training:
                        // 继续轮询
                        DDLogInfo("[VoiceClone] 音色训练中... (\(pollCount)/\(maxPolls))")
                        break
                    case .notFound:
                        DispatchQueue.main.async {
                            timer.invalidate()
                            self.pollTimer = nil
                            self.trainingSpeakerId = nil
                        }
                        let pending = self.pendingCompletion
                        self.pendingCompletion = nil
                        completion(.failure(.trainingFailed(code: 0, message: "音色未找到")))
                        pending?(.failure(.trainingFailed(code: 0, message: "音色未找到")))
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
    private func audioFormat(from url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": return "wav"
        case "mp3": return "mp3"
        case "m4a": return "m4a"
        case "aac": return "aac"
        case "ogg": return "ogg"
        case "pcm": return "pcm"
        default: return "wav"
        }
    }
}

// MARK: - 错误类型

enum VoiceCloneError: LocalizedError {
    case apiKeyMissing
    case authorizationRequired
    case speakerIdNotFound
    case audioReadFailed
    case audioTooLarge          // > 10MB
    case networkError(String)
    case invalidResponse
    case trainingFailed(code: Int, message: String)
    case trainingTimeout        // 轮询超时

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "声音复刻后端未配置，请先在服务器环境变量中配置火山声音复刻凭证"
        case .authorizationRequired:
            return "请先确认本人授权后再提交声音样本"
        case .speakerIdNotFound:
            return "未找到声音复刻音色 ID"
        case .audioReadFailed:
            return "音频文件读取失败"
        case .audioTooLarge:
            return "音频文件过大（最大 10MB）"
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
