import Foundation

enum AppConfiguration {
    private static let localConfigName = "LocalConfig"

    static func string(forKey key: String, infoDictionary: [String: Any]? = nil) -> String? {
        environmentString(forKey: key)
            ?? validString(localConfigDictionary()[key] as? String)
            ?? validString((infoDictionary ?? Bundle.main.infoDictionary)?[key] as? String)
    }

    static func mergedInfoDictionary(infoDictionary: [String: Any]? = nil) -> [String: Any] {
        var merged = infoDictionary ?? Bundle.main.infoDictionary ?? [:]
        localConfigDictionary().forEach { key, value in
            merged[key] = value
        }
        environmentDictionary().forEach { key, value in
            merged[key] = value
        }
        return merged
    }

    private static func environmentString(forKey key: String) -> String? {
        let environment = ProcessInfo.processInfo.environment
        return validString(environment[key])
            ?? validString(environment["DREAMJOURNEY_\(snakeCase(key))"])
    }

    private static func environmentDictionary() -> [String: String] {
        let knownKeys = [
            "AMapAPIKey",
            "AMapWebServiceKey",
            "DeepSeekAPIKey",
            "DeepSeekAPIBaseURL",
            "VolcEngineAPIKey",
            "VoiceCloneAPIKey",
            "VolcEngineVoiceType",
            "VolcEngineRealtimeAPIKey",
            "VolcEngineAppID",
            "VolcEngineAppKey",
            "VolcEngineAppToken",
            "VolcEngineRealtimeResourceID",
            "VolcEngineRealtimeAddress",
            "VolcEngineRealtimeURI",
            "SafetyGuardBaseURL",
            "SafetyGuardAPIKey",
            "DreamJourneyBackendBaseURL",
            "DreamJourneyBackendAPIToken",
            "OpenAvatarChatBaseURL"
        ]
        return Dictionary(uniqueKeysWithValues: knownKeys.compactMap { key in
            guard let value = environmentString(forKey: key) else { return nil }
            return (key, value)
        })
    }

    private static func localConfigDictionary() -> [String: Any] {
        guard let url = Bundle.main.url(forResource: localConfigName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any] else {
            return [:]
        }
        return plist
    }

    private static func validString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !isPlaceholder(trimmed) else {
            return nil
        }
        return trimmed
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let upper = value.uppercased()
        return upper.hasPrefix("YOUR_") ||
            upper.hasPrefix("$(") ||
            upper.contains("PLACEHOLDER") ||
            upper.contains("填入") ||
            upper.contains("你的")
    }

    private static func snakeCase(_ key: String) -> String {
        var result = ""
        for scalar in key.unicodeScalars {
            let char = Character(scalar)
            if CharacterSet.uppercaseLetters.contains(scalar), !result.isEmpty {
                result.append("_")
            }
            result.append(String(char).uppercased())
        }
        return result
    }
}
