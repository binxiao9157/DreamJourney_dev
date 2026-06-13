import Foundation

enum VolcEngineCredentialProvider {
    static let apiKeyName = "VolcEngineAPIKey"
    static let voiceTypeName = "VolcEngineVoiceType"
    static let voiceCloneFallbackKeyName = "VoiceCloneAPIKey"

    private static let placeholders: Set<String> = [
        "YOUR_VOLCENGINE_API_KEY",
        "YOUR_VOLCENGINE_CLONE_VOICE_ID",
        "YOUR_VOICECLONE_API_KEY"
    ]

    static func apiKey(infoDictionary: [String: Any]? = nil) -> String? {
        let infoDictionary = infoDictionary ?? AppConfiguration.mergedInfoDictionary()
        return value(for: apiKeyName, in: infoDictionary)
            ?? value(for: voiceCloneFallbackKeyName, in: infoDictionary)
    }

    static func voiceType(infoDictionary: [String: Any]? = nil) -> String? {
        let infoDictionary = infoDictionary ?? AppConfiguration.mergedInfoDictionary()
        return value(for: voiceTypeName, in: infoDictionary)
    }

    private static func value(for key: String, in infoDictionary: [String: Any]?) -> String? {
        guard let rawValue = infoDictionary?[key] as? String else {
            return nil
        }

        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !placeholders.contains(value) else {
            return nil
        }

        return value
    }
}
