import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        exit(1)
    }
}

let body = VolcEngineTTSRequestFactory.requestBody(
    uid: "user-001",
    voiceType: "S_clone_voice",
    text: "豆包语音",
    speed: 0,
    requestID: "request-001"
)

let app = body["app"] as? [String: Any]
let user = body["user"] as? [String: Any]
let audio = body["audio"] as? [String: Any]
let request = body["request"] as? [String: Any]

expect(VolcEngineTTSRequestFactory.endpointURL == "https://openspeech.bytedance.com/api/v1/tts", "uses v1 TTS endpoint")
expect(app?["cluster"] as? String == "volcano_tts", "uses granted volcano_tts cluster")
expect(user?["uid"] as? String == "user-001", "uses memoir author id as uid")
expect(audio?["voice_type"] as? String == "S_clone_voice", "uses clone voice id as voice_type")
expect(audio?["encoding"] as? String == "mp3", "uses mp3 encoding")
expect(audio?["speed_ratio"] as? Double == 1.0, "maps neutral speed to ratio 1.0")
expect(request?["reqid"] as? String == "request-001", "uses provided request id")
expect(request?["text"] as? String == "豆包语音", "uses requested text")
expect(request?["operation"] as? String == "query", "uses query operation")

let wavBody = VolcEngineTTSRequestFactory.requestBody(
    uid: "user-001",
    voiceType: "S_clone_voice",
    text: "豆包语音",
    speed: 0,
    encoding: .wav,
    requestID: "request-002"
)
let wavAudio = wavBody["audio"] as? [String: Any]
expect(wavAudio?["encoding"] as? String == "wav", "supports wav encoding for digital human lip sync")

let audioBytes = Data([1, 2, 3, 4])
let responseJSON: [String: Any] = [
    "code": 3000,
    "message": "Success",
    "data": audioBytes.base64EncodedString()
]
let responseData = try JSONSerialization.data(withJSONObject: responseJSON)
let decoded = try VolcEngineTTSRequestFactory.audioData(from: responseData)
expect(decoded == audioBytes, "decodes v1 base64 audio data")

print("VolcEngineTTSRequest verification passed")
