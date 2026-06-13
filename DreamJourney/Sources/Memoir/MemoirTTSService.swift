import Foundation
import AVFoundation
import Alamofire
import CocoaLumberjack

// MARK: - 回忆录 TTS 朗读服务

/// 使用火山引擎新版 API Key TTS + 声音复刻音色，将回忆录散文合成为语音
/// 
/// 流程：
/// 1. 检查 speaker_id 是否就绪
/// 2. 调用 /api/v1/tts，传入 clone voice id + 文本
/// 3. 解码响应中的 base64 MP3 数据
/// 4. 保存到 ApplicationSupport/memoir_audio/{memoirId}.mp3
final class MemoirTTSService {

    static let shared = MemoirTTSService()

    // MARK: - 配置

    /// TTS API Key。新版控制台优先使用 VolcEngineAPIKey，旧配置 VoiceCloneAPIKey 作为兜底。
    private var apiKey: String?

    private let ttsURL = VolcEngineTTSRequestFactory.endpointURL
    private let safetyGuardClient = DeepSeekSafetyGuarding.makeDefaultClient()

    /// 音频存储目录
    private let audioDirectory: URL

    // MARK: - 合成状态

    private var isSynthesizing = false

    // MARK: - Init

    private init() {
        apiKey = VolcEngineCredentialProvider.apiKey()

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        audioDirectory = appSupport.appendingPathComponent("memoir_audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 公开 API

    /// 将回忆录散文合成为语音
    /// - Parameters:
    ///   - memoir: 回忆录模型
    ///   - speed: 语速（-50~100，默认 -10 稍慢适合老人听）
    ///   - volume: 音量（-50~100，默认 10 稍大声适合老人听）
    ///   - completion: 结果回调，成功返回本地音频文件 URL
    func synthesize(memoir: MemoirModel,
                    speed: Int = -10,
                    volume: Int = 10,
                    completion: @escaping (Result<URL, TTSError>) -> Void) {

        guard let apiKey = apiKey else {
            completion(.failure(.apiKeyMissing))
            return
        }

        guard let speakerId = memoir.speakerId ?? VoiceCloneService.shared.currentSpeakerId ?? VolcEngineCredentialProvider.voiceType(),
              !speakerId.isEmpty else {
            completion(.failure(.noSpeakerId))
            return
        }

        guard !memoir.prose.isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        guard canSendToTTS(text: memoir.prose) else {
            completion(.failure(.synthesisFailed("安全检查未通过")))
            return
        }

        guard !isSynthesizing else {
            completion(.failure(.alreadySynthesizing))
            return
        }

        isSynthesizing = true

        performSynthesis(memoir: memoir, speakerId: speakerId, apiKey: apiKey, speed: speed, volume: volume, completion: completion)
    }

    /// 获取已合成的音频文件 URL
    func getAudioURL(for memoirId: String) -> URL? {
        let mp3Path = audioDirectory.appendingPathComponent("\(memoirId).mp3")
        let m4aPath = audioDirectory.appendingPathComponent("\(memoirId).m4a")
        if FileManager.default.fileExists(atPath: mp3Path.path) { return mp3Path }
        if FileManager.default.fileExists(atPath: m4aPath.path) { return m4aPath }
        return nil
    }

    /// 删除已合成的音频文件
    func deleteAudio(for memoirId: String) {
        let mp3Path = audioDirectory.appendingPathComponent("\(memoirId).mp3")
        let m4aPath = audioDirectory.appendingPathComponent("\(memoirId).m4a")
        try? FileManager.default.removeItem(at: mp3Path)
        try? FileManager.default.removeItem(at: m4aPath)
    }

    // MARK: - 内部实现

    private func performSynthesis(memoir: MemoirModel,
                                   speakerId: String,
                                   apiKey: String,
                                   speed: Int,
                                   volume: Int,
                                   completion: @escaping (Result<URL, TTSError>) -> Void) {
        let body = VolcEngineTTSRequestFactory.requestBody(
            uid: memoir.authorId,
            voiceType: speakerId,
            text: memoir.prose,
            speed: speed
        )

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "x-api-key": apiKey
        ]

        let outputPath = audioDirectory.appendingPathComponent("\(memoir.id).mp3")

        DDLogInfo("[MemoirTTS] 开始合成: memoirId=\(memoir.id), speakerId=\(speakerId), 文本长度=\(memoir.prose.count)")

        AF.request(ttsURL, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { [weak self] response in
                guard let self = self else { return }
                self.isSynthesizing = false

                switch response.result {
                case .success(let responseData):
                    do {
                        let audioData = try VolcEngineTTSRequestFactory.audioData(from: responseData)
                        try audioData.write(to: outputPath, options: .atomic)
                        DDLogInfo("[MemoirTTS] 合成完成: \(outputPath.path), 大小=\(audioData.count) bytes")
                        completion(.success(outputPath))
                    } catch VolcEngineTTSRequestError.serviceError(let code, let message) {
                        DDLogError("[MemoirTTS] 合成错误: code=\(code), message=\(message)")
                        completion(.failure(.synthesisFailed("TTS错误(\(code)): \(message)")))
                    } catch {
                        DDLogError("[MemoirTTS] 响应解析失败: \(error.localizedDescription)")
                        completion(.failure(.synthesisFailed("响应解析失败")))
                    }

                case .failure(let error):
                    DDLogError("[MemoirTTS] 合成请求失败: \(error.localizedDescription)")
                    try? FileManager.default.removeItem(at: outputPath)
                    completion(.failure(.networkError(error.localizedDescription)))
                }
            }
    }

    // MARK: - 降级方案：系统 TTS

    /// 当声音复刻不可用时，使用系统 TTS 作为降级
    /// iOS 原生 AVSpeechSynthesizer，不需要网络，但音色不是老人的
    func synthesizeWithSystemTTS(memoir: MemoirModel,
                                  completion: @escaping (Result<URL, TTSError>) -> Void) {
        guard !memoir.prose.isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: memoir.prose)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = AVSpeechUtteranceMinimumSpeechRate + 0.1  // 稍慢
        utterance.pitchMultiplier = 0.85  // 低沉一些，模拟老人声音
        utterance.volume = 1.0

        // 系统TTS无法直接导出文件，这里用占位逻辑
        // 实际使用时建议直接用 AVSpeechSynthesizer 播放，不保存文件
        DDLogInfo("[MemoirTTS] 使用系统TTS降级播放（无法导出文件）")
        completion(.failure(.systemTTSNoExport))
    }

    private func canSendToTTS(text: String) -> Bool {
        let decision = DeepSeekSafetyGuarding.guardDecision(
            text: text,
            surface: .tts,
            stage: .ttsInputPreSynth,
            target: .volcengineTTS,
            guardClient: safetyGuardClient
        )
        return decision.canSendToTTS && (decision.action == .allow || decision.action == .allowWithCare)
    }
}

// MARK: - 错误类型

enum TTSError: LocalizedError {
    case apiKeyMissing
    case noSpeakerId
    case voiceNotReady         // 音色未训练完成
    case emptyText
    case alreadySynthesizing   // 正在合成中
    case networkError(String)
    case synthesisFailed(String)
    case systemTTSNoExport     // 系统 TTS 不支持导出

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "声音复刻 API Key 未配置"
        case .noSpeakerId:
            return "未找到声音复刻音色，请先完成声音复刻训练"
        case .voiceNotReady:
            return "声音复刻训练尚未完成，请稍后再试"
        case .emptyText:
            return "回忆录内容为空"
        case .alreadySynthesizing:
            return "正在合成中，请稍候"
        case .networkError(let msg):
            return "网络错误: \(msg)"
        case .synthesisFailed(let msg):
            return "语音合成失败: \(msg)"
        case .systemTTSNoExport:
            return "系统 TTS 仅支持在线播放"
        }
    }
}
