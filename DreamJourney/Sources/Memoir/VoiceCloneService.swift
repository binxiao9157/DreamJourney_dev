import Foundation
import Alamofire
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
        defaultReleaseVisible: Bool = false
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

// MARK: - 声音复刻服务（火山引擎 Voice Clone V3）

/// 封装火山引擎声音复刻 API：
/// 1. 上传音频训练音色 → 获得 speaker_id
/// 2. 查询训练状态
/// 3. 训练成功后 speaker_id 可用于大模型 TTS 合成
final class VoiceCloneService {

    static let shared = VoiceCloneService()

    // MARK: - 配置

    /// 火山引擎声音复刻 API Key
    /// 获取方式：火山引擎控制台 → 语音技术 → 声音复刻 → API Key 管理
    private static let placeholderAPIKey = "YOUR_VOICECLONE_API_KEY"

    private var apiKey: String

    /// 训练 API
    private let cloneURL = "https://openspeech.bytedance.com/api/v3/tts/voice_clone"
    /// 状态查询 API
    private let queryURL = "https://openspeech.bytedance.com/api/v3/tts/get_voice"

    /// 当前用户的 speaker_id（持久化到 UserDefaults）
    private let speakerIdKey = "dj.voiceclone.speakerId"
    private let sampleStatusKey = "dj.voiceclone.sampleStatus"
    private static let emptyVoiceProfileId = "voiceProfileId_not_created"
    static let backendContractEndpoint = "/voice/profiles"
    private static let authorizationCopy = "声音克隆必须由用户主动授权，仅使用用户确认提交的声音样本；未完成授权和样本质量验收前不会公开训练或合成功能。"
    private static let disableContract = "disableVoiceProfile(profileId:) 只更新本地禁用状态，真实后端接入后应撤销该 voiceProfileId 的合成权限。"
    private static let deleteContract = "deleteVoiceProfile(profileId:) 只清理本地 voiceProfileId，真实后端接入后应删除样本、训练产物和关联授权记录。"

    /// 训练轮询定时器
    private var pollTimer: Timer?

    /// 正在等待音色就绪的回调（用于 checkPendingTraining 加速完成）
    /// 当 App 从后台回到前台时，如果训练已完成，通过此回调通知等待方
    private var pendingCompletion: ((Result<String, VoiceCloneError>) -> Void)?

    /// 训练中的 speakerId（用于 checkPendingTraining 匹配）
    private var trainingSpeakerId: String?

    // MARK: - Init

    private init() {
        // 优先从 Info.plist 读取，其次用硬编码
        if let key = Bundle.main.infoDictionary?["VoiceCloneAPIKey"] as? String,
           !key.isEmpty, key != Self.placeholderAPIKey {
            apiKey = key
        } else {
            apiKey = Self.placeholderAPIKey
        }
    }

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

    /// 保存 speaker_id
    private func saveSpeakerId(_ id: String) {
        UserDefaults.standard.set(id, forKey: speakerIdKey)
        UserDefaults.standard.set(VoiceCloneSampleStatus.pending.rawValue, forKey: sampleStatusKey)
    }

    private func saveSampleStatus(_ status: VoiceCloneSampleStatus) {
        UserDefaults.standard.set(status.rawValue, forKey: sampleStatusKey)
    }

    /// 上传音频训练声音复刻
    /// - Parameters:
    ///   - audioURL: 本地音频文件 URL（wav/mp3/m4a/aac，建议 ≥10秒，≤10MB）
    ///   - speakerId: 指定的音色 ID，为空则自动生成
    ///   - language: 语种，0=中文（默认）
    ///   - completion: 结果回调
    func trainVoice(audioURL: URL,
                    speakerId: String? = nil,
                    language: Int = 0,
                    completion: @escaping (Result<String, VoiceCloneError>) -> Void) {

        guard apiKey != Self.placeholderAPIKey else {
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

        // 构建请求体
        let body: [String: Any] = [
            "speaker_id": finalSpeakerId,
            "audio": [
                "data": base64Audio,
                "format": format
            ],
            "language": language,
            "extra_params": [
                "enable_audio_denoise": true
            ] as [String: Any]
        ]

        // 如果有提示文本可传入（可选，提高复刻质量）
        // body["audio"]["text"] = "用户念的文本"

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "X-Api-Key": apiKey,
            "X-Api-Request-Id": UUID().uuidString
        ]

        DDLogInfo("[VoiceClone] 开始训练音色: \(finalSpeakerId), 音频大小: \(audioData.count) bytes")

        AF.request(cloneURL, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { [weak self] response in
                switch response.result {
                case .success(let data):
                    guard let self = self else { return }
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        DDLogInfo("[VoiceClone] 训练响应: \(json)")

                        // 检查是否有错误码
                        if let code = json["code"] as? Int, code != 0 {
                            let msg = json["message"] as? String ?? "未知错误"
                            completion(.failure(.trainingFailed(code: code, message: msg)))
                            return
                        }

                        // 成功
                        let returnedSpeakerId = json["speaker_id"] as? String ?? finalSpeakerId
                        let status = json["status"] as? Int ?? 0

                        self.saveSpeakerId(returnedSpeakerId)
                        DDLogInfo("[VoiceClone] 音色已提交训练: \(returnedSpeakerId), status=\(status)")

                        // 如果训练已完成（小概率），直接返回
                        if status == 2 || status == 4 {
                            self.saveSampleStatus(.ready)
                            completion(.success(returnedSpeakerId))
                        } else {
                            // 开始轮询状态
                            self.startPollingStatus(speakerId: returnedSpeakerId, completion: completion)
                        }
                    } else {
                        completion(.failure(.invalidResponse))
                    }

                case .failure(let error):
                    DDLogError("[VoiceClone] 训练请求失败: \(error.localizedDescription)")
                    completion(.failure(.networkError(error.localizedDescription)))
                }
            }
    }

    /// 查询声音复刻训练状态
    func queryStatus(speakerId: String? = nil,
                     completion: @escaping (Result<VoiceCloneStatus, VoiceCloneError>) -> Void) {

        guard apiKey != Self.placeholderAPIKey else {
            completion(.failure(.apiKeyMissing))
            return
        }

        let sid = speakerId ?? currentSpeakerId ?? ""
        guard !sid.isEmpty else {
            completion(.failure(.speakerIdNotFound))
            return
        }

        let body: [String: Any] = ["speaker_id": sid]
        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "X-Api-Key": apiKey,
            "X-Api-Request-Id": UUID().uuidString
        ]

        AF.request(queryURL, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let status = json["status"] as? Int ?? 0
                        let cloneStatus = VoiceCloneStatus(rawValue: status) ?? .notFound
                        DDLogInfo("[VoiceClone] 查询状态: speakerId=\(sid), status=\(status)")
                        completion(.success(cloneStatus))
                    } else {
                        completion(.failure(.invalidResponse))
                    }

                case .failure(let error):
                    DDLogError("[VoiceClone] 查询失败: \(error.localizedDescription)")
                    completion(.failure(.networkError(error.localizedDescription)))
                }
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
            return "声音复刻 API Key 未配置，请在 Info.plist 中设置 VoiceCloneAPIKey"
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
