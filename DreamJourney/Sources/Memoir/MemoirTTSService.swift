import Foundation
import AVFoundation
import CocoaLumberjack

// MARK: - 回忆录 TTS 朗读服务

/// 使用后端代理的火山引擎大模型 TTS V3 + 声音复刻音色，将回忆录散文合成为语音
///
/// 流程：
/// 1. 检查 speaker_id 是否就绪
/// 2. 调用 DreamJourney 后端 `/voice/synthesis`，传入 speaker_id + 文本
/// 3. 后端代理火山 TTS V3 并返回 base64 音频
/// 4. 保存到 ApplicationSupport/memoir_audio/{memoirId}.mp3
final class MemoirTTSService {

    static let shared = MemoirTTSService()

    // MARK: - 配置

    /// 音频存储目录
    private let audioDirectory: URL

    // MARK: - 合成状态

    private var isSynthesizing = false

    // MARK: - Init

    private init() {
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

        guard DreamJourneyBackendClient.shared.isVoiceCloneSynthesisConfigured else {
            completion(.failure(.apiKeyMissing))
            return
        }

        guard let speakerId = memoir.speakerId ?? VoiceCloneService.shared.currentSpeakerId,
              !speakerId.isEmpty else {
            completion(.failure(.noSpeakerId))
            return
        }

        guard !memoir.prose.isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        guard !isSynthesizing else {
            completion(.failure(.alreadySynthesizing))
            return
        }

        isSynthesizing = true

        // 先检查音色是否就绪
        VoiceCloneService.shared.isVoiceReady(speakerId: speakerId) { [weak self] ready in
            guard let self = self else { return }
            if !ready {
                self.isSynthesizing = false
                completion(.failure(.voiceNotReady))
                return
            }
            self.performSynthesis(memoir: memoir, speakerId: speakerId, speed: speed, volume: volume, completion: completion)
        }
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
                                   speed: Int,
                                   volume: Int,
                                   completion: @escaping (Result<URL, TTSError>) -> Void) {

        let outputPath = audioDirectory.appendingPathComponent("\(memoir.id).mp3")

        DDLogInfo("[MemoirTTS] 通过后端合成: memoirId=\(memoir.id), speakerId=\(speakerId), 文本长度=\(memoir.prose.count)")
        DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis(
            userId: memoir.authorId,
            voiceProfileId: speakerId,
            text: memoir.prose,
            audioFormat: "mp3",
            sampleRate: 24000,
            speechRate: speed,
            loudnessRate: volume
        ) { [weak self] result in
            guard let self = self else { return }
            self.isSynthesizing = false
            switch result {
            case .success(let synthesis):
                guard let audioData = synthesis.audioData, !audioData.isEmpty else {
                    DDLogError("[MemoirTTS] 后端合成音频为空或无法解码")
                    completion(.failure(.synthesisFailed("合成音频解码失败")))
                    return
                }
                do {
                    try audioData.write(to: outputPath, options: .atomic)
                    DDLogInfo("[MemoirTTS] 合成完成: \(outputPath.path), 大小=\(audioData.count) bytes")
                    completion(.success(outputPath))
                } catch {
                    DDLogError("[MemoirTTS] 写入文件失败: \(error.localizedDescription)")
                    completion(.failure(.synthesisFailed("文件写入失败")))
                }
            case .failure(let error):
                DDLogError("[MemoirTTS] 后端合成请求失败: \(error.localizedDescription)")
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
            return "声音复刻合成后端未配置"
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
