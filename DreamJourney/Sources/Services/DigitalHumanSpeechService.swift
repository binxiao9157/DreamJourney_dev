import Foundation
import Alamofire
import CocoaLumberjack

// MARK: - Digital Human Speech Service

/// 合成数字人口型同步需要的 16kHz mono PCM16 WAV 音频。
/// DHLiveMini 的 `_setAudioBuffer` 上游用法要求完整 WAV bytes，而不是裸 PCM。
final class DigitalHumanSpeechService {
    static let shared = DigitalHumanSpeechService()

    private let ttsURL = VolcEngineTTSRequestFactory.endpointURL
    private let safetyGuardClient = DeepSeekSafetyGuarding.makeDefaultClient()

    private init() {}

    func synthesizeWAV(
        text: String,
        uid: String,
        speed: Int = -10,
        completion: @escaping (Result<String, DigitalHumanSpeechError>) -> Void
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            completion(.failure(.emptyText))
            return
        }

        guard let apiKey = VolcEngineCredentialProvider.apiKey() else {
            completion(.failure(.apiKeyMissing))
            return
        }

        guard let voiceType = VolcEngineCredentialProvider.voiceType(), !voiceType.isEmpty else {
            completion(.failure(.voiceTypeMissing))
            return
        }

        guard canSendToTTS(text: trimmedText) else {
            completion(.failure(.safetyRejected))
            return
        }

        let body = VolcEngineTTSRequestFactory.requestBody(
            uid: uid,
            voiceType: voiceType,
            text: trimmedText,
            speed: speed,
            encoding: .wav
        )

        let headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "x-api-key": apiKey
        ]

        DDLogInfo("[DigitalHumanSpeech] 开始合成 WAV: textLength=\(trimmedText.count), voiceType=\(voiceType)")

        AF.request(ttsURL, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseData { response in
                switch response.result {
                case .success(let responseData):
                    do {
                        let audioData = try VolcEngineTTSRequestFactory.audioData(from: responseData)
                        guard Self.looksLikeWAV(audioData) else {
                            completion(.failure(.invalidWAV))
                            return
                        }
                        completion(.success(audioData.base64EncodedString()))
                    } catch VolcEngineTTSRequestError.serviceError(let code, let message) {
                        completion(.failure(.serviceError("TTS错误(\(code)): \(message)")))
                    } catch {
                        completion(.failure(.serviceError("响应解析失败: \(error.localizedDescription)")))
                    }

                case .failure(let error):
                    completion(.failure(.networkError(error.localizedDescription)))
                }
            }
    }

    private func canSendToTTS(text: String) -> Bool {
        let decision = DeepSeekSafetyGuarding.guardDecision(
            text: text,
            surface: .tts,
            stage: .ttsInputPreSynth,
            target: .volcengineTTS,
            guardClient: safetyGuardClient
        )
        return DigitalHumanSpeechPlaybackPolicy.canSendAssistantSpeechToTTS(decision)
    }

    private static func looksLikeWAV(_ data: Data) -> Bool {
        guard data.count > 44 else { return false }
        let riff = String(data: data.prefix(4), encoding: .ascii)
        let waveRange = data.index(data.startIndex, offsetBy: 8)..<data.index(data.startIndex, offsetBy: 12)
        let wave = String(data: data[waveRange], encoding: .ascii)
        return riff == "RIFF" && wave == "WAVE"
    }
}

enum DigitalHumanSpeechError: LocalizedError {
    case apiKeyMissing
    case voiceTypeMissing
    case emptyText
    case safetyRejected
    case invalidWAV
    case networkError(String)
    case serviceError(String)

    var errorDescription: String? {
        switch self {
        case .apiKeyMissing:
            return "数字人语音 API Key 未配置"
        case .voiceTypeMissing:
            return "数字人音色未配置"
        case .emptyText:
            return "数字人语音文本为空"
        case .safetyRejected:
            return "数字人语音安全检查未通过"
        case .invalidWAV:
            return "数字人语音合成未返回 WAV 音频"
        case .networkError(let message):
            return "数字人语音网络错误: \(message)"
        case .serviceError(let message):
            return "数字人语音合成失败: \(message)"
        }
    }

    var diagnosticSummary: String {
        switch self {
        case .apiKeyMissing:
            return "api_key_missing"
        case .voiceTypeMissing:
            return "voice_type_missing"
        case .emptyText:
            return "empty_text"
        case .safetyRejected:
            return "safety_rejected"
        case .invalidWAV:
            return "invalid_wav"
        case .networkError(let message):
            return "network_error:\(DigitalHumanPlaybackEvidenceStore.sanitize(message))"
        case .serviceError(let message):
            return "service_error:\(DigitalHumanPlaybackEvidenceStore.sanitize(message))"
        }
    }
}
