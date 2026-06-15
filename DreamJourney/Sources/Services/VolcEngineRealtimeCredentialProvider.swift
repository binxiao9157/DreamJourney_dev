import Foundation

enum VolcEngineRealtimeAuthMode: Equatable {
    case apiKey(String)
    case legacy(appID: String, appKey: String, token: String)
}

struct VolcEngineRealtimeCredentials: Equatable {
    let authMode: VolcEngineRealtimeAuthMode
    let resourceID: String
    let address: String
    let uri: String
    let uid: String

    var isModernAPIKeyMode: Bool {
        if case .apiKey = authMode { return true }
        return false
    }

    func requestHeadersJSON() -> String? {
        guard case .apiKey(let apiKey) = authMode else { return nil }
        let headers = [
            "X-Api-Key": apiKey,
            "X-Api-Resource-Id": resourceID
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: headers, options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

struct VolcEngineRealtimeRemoteConfig: Decodable, Equatable {
    let authMode: String
    let address: String?
    let uri: String?
    let resourceID: String?
    let uid: String?
    let apiKey: String?
    let appID: String?
    let appKey: String?
    let appToken: String?

    func credentials(defaultUID: String) -> VolcEngineRealtimeCredentials? {
        var info: [String: Any] = [:]
        func put(_ key: String, _ value: String?) {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty else {
                return
            }
            info[key] = trimmed
        }
        put(VolcEngineRealtimeCredentialProvider.resourceIDName, resourceID)
        put(VolcEngineRealtimeCredentialProvider.addressName, address)
        put(VolcEngineRealtimeCredentialProvider.uriName, uri)

        switch authMode.lowercased() {
        case "legacy":
            put(VolcEngineRealtimeCredentialProvider.appIDName, appID)
            put(
                VolcEngineRealtimeCredentialProvider.appKeyName,
                appKey ?? VolcEngineRealtimeCredentialProvider.fixedRealtimeDialogAppKey
            )
            put(VolcEngineRealtimeCredentialProvider.appTokenName, appToken)
        case "api_key", "apikey", "api-key":
            put(VolcEngineRealtimeCredentialProvider.realtimeAPIKeyName, apiKey)
        default:
            put(VolcEngineRealtimeCredentialProvider.realtimeAPIKeyName, apiKey)
            put(VolcEngineRealtimeCredentialProvider.appIDName, appID)
            put(VolcEngineRealtimeCredentialProvider.appKeyName, appKey)
            put(VolcEngineRealtimeCredentialProvider.appTokenName, appToken)
        }

        let resolvedUID = uid?.trimmingCharacters(in: .whitespacesAndNewlines)
        return VolcEngineRealtimeCredentialProvider.credentials(
            from: info,
            defaultUID: resolvedUID?.isEmpty == false ? resolvedUID! : defaultUID
        )
    }
}

enum VolcEngineRealtimeCredentialProvider {
    static let fixedRealtimeDialogAppKey = "PlgvMymc7f3tQnJ6"
    static let realtimeAPIKeyName = "VolcEngineRealtimeAPIKey"
    static let sharedAPIKeyName = "VolcEngineAPIKey"
    static let appIDName = "VolcEngineAppID"
    static let appKeyName = "VolcEngineAppKey"
    static let appTokenName = "VolcEngineAppToken"
    static let resourceIDName = "VolcEngineRealtimeResourceID"
    static let addressName = "VolcEngineRealtimeAddress"
    static let uriName = "VolcEngineRealtimeURI"

    static func credentials(
        from info: [String: Any],
        defaultUID: String = UUID().uuidString
    ) -> VolcEngineRealtimeCredentials? {
        let resourceID = validString(info[resourceIDName] as? String) ?? "volc.speech.dialog"
        let address = validString(info[addressName] as? String) ?? "wss://openspeech.bytedance.com"
        let uri = validString(info[uriName] as? String) ?? "/api/v3/realtime/dialogue"

        if let apiKey = validString(info[realtimeAPIKeyName] as? String) {
            return VolcEngineRealtimeCredentials(
                authMode: .apiKey(apiKey),
                resourceID: resourceID,
                address: address,
                uri: uri,
                uid: defaultUID
            )
        }

        if let appID = validString(info[appIDName] as? String),
           let token = validString(info[appTokenName] as? String) {
            return VolcEngineRealtimeCredentials(
                authMode: .legacy(appID: appID, appKey: fixedRealtimeDialogAppKey, token: token),
                resourceID: resourceID,
                address: address,
                uri: uri,
                uid: defaultUID
            )
        }

        if let apiKey = validString(info[sharedAPIKeyName] as? String) {
            return VolcEngineRealtimeCredentials(
                authMode: .apiKey(apiKey),
                resourceID: resourceID,
                address: address,
                uri: uri,
                uid: defaultUID
            )
        }

        return nil
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
        let uppercased = value.uppercased()
        return uppercased.hasPrefix("YOUR_") ||
            uppercased.contains("PLACEHOLDER") ||
            uppercased.contains("填入") ||
            uppercased.contains("你的")
    }
}
