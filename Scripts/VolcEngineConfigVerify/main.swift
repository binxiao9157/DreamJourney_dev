import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if condition() {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        exit(1)
    }
}

let modernOnly = VolcEngineCredentialProvider.apiKey(
    infoDictionary: [
        "VolcEngineAPIKey": "modern-key",
        "VoiceCloneAPIKey": "YOUR_VOICECLONE_API_KEY"
    ]
)
expect(modernOnly == "modern-key", "VolcEngineAPIKey has priority")

let legacyFallback = VolcEngineCredentialProvider.apiKey(
    infoDictionary: [
        "VolcEngineAPIKey": "YOUR_VOLCENGINE_API_KEY",
        "VoiceCloneAPIKey": "legacy-voice-key"
    ]
)
expect(legacyFallback == "legacy-voice-key", "VoiceCloneAPIKey remains fallback")

let missing = VolcEngineCredentialProvider.apiKey(
    infoDictionary: [
        "VolcEngineAPIKey": "YOUR_VOLCENGINE_API_KEY",
        "VoiceCloneAPIKey": "YOUR_VOICECLONE_API_KEY"
    ]
)
expect(missing == nil, "placeholders are ignored")

let configuredVoiceType = VolcEngineCredentialProvider.voiceType(
    infoDictionary: ["VolcEngineVoiceType": "S_clone_voice"]
)
expect(configuredVoiceType == "S_clone_voice", "VolcEngineVoiceType is configurable")

let placeholderVoiceType = VolcEngineCredentialProvider.voiceType(
    infoDictionary: ["VolcEngineVoiceType": "YOUR_VOLCENGINE_CLONE_VOICE_ID"]
)
expect(placeholderVoiceType == nil, "VolcEngineVoiceType placeholder is ignored")

print("VolcEngineConfig verification passed")
