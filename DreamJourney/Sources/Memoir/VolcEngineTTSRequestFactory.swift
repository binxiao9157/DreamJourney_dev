import Foundation

enum VolcEngineTTSRequestError: Error {
    case invalidResponse
    case serviceError(code: Int, message: String)
    case missingAudioData
    case invalidAudioData
}

enum VolcEngineTTSRequestFactory {
    static let endpointURL = "https://openspeech.bytedance.com/api/v1/tts"
    static let cluster = "volcano_tts"

    enum AudioEncoding: String {
        case mp3
        case wav
    }

    static func requestBody(
        uid: String,
        voiceType: String,
        text: String,
        speed: Int,
        encoding: AudioEncoding = .mp3,
        requestID: String = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    ) -> [String: Any] {
        [
            "app": [
                "cluster": cluster
            ],
            "user": [
                "uid": uid
            ],
            "audio": [
                "voice_type": voiceType,
                "encoding": encoding.rawValue,
                "speed_ratio": speedRatio(from: speed)
            ],
            "request": [
                "reqid": requestID,
                "text": text,
                "operation": "query"
            ]
        ]
    }

    static func speedRatio(from speed: Int) -> Double {
        let ratio = 1.0 + Double(speed) / 100.0
        return min(max(ratio, 0.5), 2.0)
    }

    static func audioData(from responseData: Data) throws -> Data {
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw VolcEngineTTSRequestError.invalidResponse
        }

        let code = json["code"] as? Int ?? 3000
        if code != 3000 && code != 0 {
            let message = json["message"] as? String ?? "未知错误"
            throw VolcEngineTTSRequestError.serviceError(code: code, message: message)
        }

        guard let base64Audio = json["data"] as? String, !base64Audio.isEmpty else {
            throw VolcEngineTTSRequestError.missingAudioData
        }

        guard let audioData = Data(base64Encoded: base64Audio), !audioData.isEmpty else {
            throw VolcEngineTTSRequestError.invalidAudioData
        }

        return audioData
    }
}
