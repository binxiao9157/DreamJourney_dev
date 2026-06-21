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

struct MemoirTTSCacheEntry: Codable {
    let memoirId: String
    let audioFileURL: URL
    let voiceProfileId: String
    let textHash: String
    let audioFormat: String
    let visemeTimeline: DigitalHumanLipSyncTimeline?
    let createdAt: Date
    let providerMode: String
}

struct MemoirTTSCacheResult {
    let audioFileURL: URL
    let cacheEntry: MemoirTTSCacheEntry

    var visemeTimeline: DigitalHumanLipSyncTimeline? {
        cacheEntry.visemeTimeline
    }
}

final class MemoirTTSService {

    static let shared = MemoirTTSService()

    // MARK: - 配置

    /// 音频存储目录
    private let audioDirectory: URL
    /// TTS 合成元数据缓存目录
    private let cacheDirectory: URL

    // MARK: - 合成状态

    private var isSynthesizing = false

    // MARK: - Init

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        audioDirectory = appSupport.appendingPathComponent("memoir_audio", isDirectory: true)
        cacheDirectory = appSupport.appendingPathComponent("memoir_tts_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
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
        if let cached = getCachedSynthesis(for: memoirId) {
            return cached.audioFileURL
        }
        let mp3Path = audioDirectory.appendingPathComponent("\(memoirId).mp3")
        let m4aPath = audioDirectory.appendingPathComponent("\(memoirId).m4a")
        if FileManager.default.fileExists(atPath: mp3Path.path) { return mp3Path }
        if FileManager.default.fileExists(atPath: m4aPath.path) { return m4aPath }
        return nil
    }

    /// 获取已缓存的 TTS 合成结果，包含本地音频和口型时间线。
    func getCachedSynthesis(for memoirId: String) -> MemoirTTSCacheResult? {
        guard let entry = loadCacheEntry(for: memoirId),
              FileManager.default.fileExists(atPath: entry.audioFileURL.path) else {
            return nil
        }
        return MemoirTTSCacheResult(audioFileURL: entry.audioFileURL, cacheEntry: entry)
    }

    /// 获取已缓存的 TTS 合成结果，并验证当前文本仍匹配缓存。
    func getCachedSynthesis(for memoir: MemoirModel) -> MemoirTTSCacheResult? {
        guard let result = getCachedSynthesis(for: memoir.id),
              result.cacheEntry.textHash == Self.textHash(for: memoir.prose) else {
            return nil
        }
        return result
    }

    /// 获取与当前文本匹配的口型时间线。Echo 的数字人优先使用真实 TTS timeline，
    /// 找不到同文本缓存时再降级到播放器音量/SDK fallback。
    func getCachedLipSyncTimeline(forText text: String) -> DigitalHumanLipSyncTimeline? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        let expectedTextHash = Self.textHash(for: text)
        guard let cacheFiles = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return cacheFiles
            .compactMap { fileURL -> MemoirTTSCacheEntry? in
                guard fileURL.pathExtension == "json",
                      let data = try? Data(contentsOf: fileURL) else {
                    return nil
                }
                return try? decoder.decode(MemoirTTSCacheEntry.self, from: data)
            }
            .filter { entry in
                entry.textHash == expectedTextHash
                    && entry.visemeTimeline?.frames.isEmpty == false
                    && FileManager.default.fileExists(atPath: entry.audioFileURL.path)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first?
            .visemeTimeline
    }

    /// 删除已合成的音频文件
    func deleteAudio(for memoirId: String) {
        if let cached = loadCacheEntry(for: memoirId) {
            try? FileManager.default.removeItem(at: cached.audioFileURL)
        }
        for audioFormat in ["mp3", "m4a", "aac", "wav"] {
            try? FileManager.default.removeItem(at: audioFileURL(for: memoirId, audioFormat: audioFormat))
        }
        try? FileManager.default.removeItem(at: cacheFileURL(for: memoirId))
    }

    // MARK: - 内部实现

    private func performSynthesis(memoir: MemoirModel,
                                   speakerId: String,
                                   speed: Int,
                                   volume: Int,
                                   completion: @escaping (Result<URL, TTSError>) -> Void) {

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
                let audioFormat = Self.normalizedAudioFormat(synthesis.audioFormat)
                let outputPath = self.audioFileURL(for: memoir.id, audioFormat: audioFormat)
                do {
                    try audioData.write(to: outputPath, options: .atomic)
                    let cacheEntry = MemoirTTSCacheEntry(
                        memoirId: memoir.id,
                        audioFileURL: outputPath,
                        voiceProfileId: synthesis.voiceProfileId,
                        textHash: Self.textHash(for: memoir.prose),
                        audioFormat: audioFormat,
                        visemeTimeline: synthesis.visemeTimeline,
                        createdAt: Date(),
                        providerMode: synthesis.providerMode
                    )
                    try self.saveCacheEntry(cacheEntry)
                    DDLogInfo("[MemoirTTS] 合成完成: \(outputPath.path), 大小=\(audioData.count) bytes, timeline=\(synthesis.visemeTimeline?.frames.count ?? 0)")
                    completion(.success(outputPath))
                } catch {
                    DDLogError("[MemoirTTS] 写入文件失败: \(error.localizedDescription)")
                    completion(.failure(.synthesisFailed("文件写入失败")))
                }
            case .failure(let error):
                DDLogError("[MemoirTTS] 后端合成请求失败: \(error.localizedDescription)")
                self.deleteAudio(for: memoir.id)
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }

    private func audioFileURL(for memoirId: String, audioFormat: String) -> URL {
        audioDirectory.appendingPathComponent("\(memoirId).\(Self.normalizedAudioFormat(audioFormat))")
    }

    private func cacheFileURL(for memoirId: String) -> URL {
        cacheDirectory.appendingPathComponent("\(memoirId).json")
    }

    private func saveCacheEntry(_ entry: MemoirTTSCacheEntry) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        try data.write(to: cacheFileURL(for: entry.memoirId), options: .atomic)
    }

    private func loadCacheEntry(for memoirId: String) -> MemoirTTSCacheEntry? {
        let fileURL = cacheFileURL(for: memoirId)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MemoirTTSCacheEntry.self, from: data)
    }

    private static func normalizedAudioFormat(_ value: String) -> String {
        let format = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch format {
        case "m4a", "aac", "wav":
            return format
        default:
            return "mp3"
        }
    }

    private static func textHash(for text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(format: "%016llx", hash)
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
