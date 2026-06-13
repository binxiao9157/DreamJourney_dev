import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    print("PASS: \(message)")
}

let modern = VolcEngineRealtimeCredentialProvider.credentials(
    from: [
        "VolcEngineRealtimeAPIKey": "realtime-key",
        "VolcEngineAPIKey": "shared-key",
        "VolcEngineRealtimeResourceID": "custom.resource",
        "VolcEngineRealtimeAddress": "wss://example.com",
        "VolcEngineRealtimeURI": "/custom/realtime"
    ],
    defaultUID: "verify-user"
)
expect(modern?.authMode == .apiKey("realtime-key"), "realtime API key has priority")
expect(modern?.resourceID == "custom.resource", "resource id is configurable")
expect(modern?.address == "wss://example.com", "address is configurable")
expect(modern?.uri == "/custom/realtime", "uri is configurable")
expect(modern?.requestHeadersJSON()?.contains("\"X-Api-Key\":\"realtime-key\"") == true, "modern headers include X-Api-Key")
expect(modern?.requestHeadersJSON()?.contains("\"X-Api-Resource-Id\":\"custom.resource\"") == true, "modern headers include resource id")
expect(modern?.requestHeadersJSON()?.contains("X-Api-App-Key") == false, "modern headers must not include legacy X-Api-App-Key")

let sharedFallback = VolcEngineRealtimeCredentialProvider.credentials(
    from: [
        "VolcEngineRealtimeAPIKey": "YOUR_VOLCENGINE_REALTIME_API_KEY",
        "VolcEngineAPIKey": "shared-key"
    ],
    defaultUID: "verify-user"
)
expect(sharedFallback?.authMode == .apiKey("shared-key"), "shared VolcEngineAPIKey is realtime fallback")

let legacy = VolcEngineRealtimeCredentialProvider.credentials(
    from: [
        "VolcEngineRealtimeAPIKey": "YOUR_VOLCENGINE_REALTIME_API_KEY",
        "VolcEngineAPIKey": "shared-key",
        "VolcEngineAppID": "app-id",
        "VolcEngineAppKey": "secret-key-from-console-should-not-be-used",
        "VolcEngineAppToken": "token"
    ],
    defaultUID: "verify-user"
)
let fixedRealtimeAppKey = "PlgvMymc7f3tQnJ6"
expect(legacy?.authMode == .legacy(appID: "app-id", appKey: fixedRealtimeAppKey, token: "token"), "complete legacy credentials use fixed realtime X-Api-App-Key")
expect(legacy?.requestHeadersJSON() == nil, "legacy mode does not inject modern headers")

let appIDAndTokenOnly = VolcEngineRealtimeCredentialProvider.credentials(
    from: [
        "VolcEngineAppID": "app-id",
        "VolcEngineAppToken": "token"
    ],
    defaultUID: "verify-user"
)
expect(appIDAndTokenOnly?.authMode == .legacy(appID: "app-id", appKey: fixedRealtimeAppKey, token: "token"), "legacy realtime dialog should not require console Secret Key as VolcEngineAppKey")

let missing = VolcEngineRealtimeCredentialProvider.credentials(
    from: [
        "VolcEngineRealtimeAPIKey": "YOUR_REALTIME_KEY",
        "VolcEngineAPIKey": "YOUR_VOLCENGINE_API_KEY",
        "VolcEngineAppID": "YOUR_VOLCENGINE_APP_ID",
        "VolcEngineAppKey": "YOUR_VOLCENGINE_APP_KEY",
        "VolcEngineAppToken": "YOUR_VOLCENGINE_APP_TOKEN"
    ],
    defaultUID: "verify-user"
)
expect(missing == nil, "placeholders are ignored")

print("VolcEngineRealtimeConfig verification passed")
