import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    print("PASS: \(message)")
}

let modernInfo: [String: Any] = [
    "VolcEngineAPIKey": "secret-modern-api-key",
    "VolcEngineVoiceType": "zh_female_cancan_mars_bigtts",
    "VolcEngineRealtimeAPIKey": "secret-realtime-api-key",
    "VolcEngineRealtimeResourceID": "volc.speech.dialog",
    "DreamJourneyBackendBaseURL": "https://www.mmdd10.tech/dreamjourney-api"
]
let modern = DigitalHumanReadinessReport.make(
    infoDictionary: modernInfo,
    arguments: [],
    environment: [:]
)
expect(modern.primaryStatus == .ready, "modern API key setup is ready")
expect(modern.subtitle.contains("真实语音链路"), "modern setup explains real voice path")
expect(modern.copyableText.contains("secret-modern-api-key") == false, "copyable text hides shared API key")
expect(modern.copyableText.contains("secret-realtime-api-key") == false, "copyable text hides realtime API key")
expect(modern.copyableText.contains("X-Api-Key") == false, "copyable text does not expose request headers")
expect(modern.copyableText.contains("Token") == true, "copyable text states token is hidden without exposing a value")
expect(modern.copyableText.contains("修复建议"), "copyable text includes remediation section")
expect(modern.copyableText.contains("音频链路验收"), "copyable text includes playback evidence checklist")
expect(modern.copyableText.contains("可演示") == false, "real-device diagnostics should not use roadshow/demo readiness wording")
expect(modern.evidenceJSONText.contains("roadshow") == false, "real-device diagnostics JSON should not expose roadshow terminology")
expect(modern.copyableText.contains("playback_finished source=native_audio"), "copyable text includes native audio evidence log")
expect(modern.copyableText.contains("playback_finished source=system_tts"), "copyable text includes system TTS evidence log")
expect(modern.copyableText.contains("playback_finished source=timeout"), "copyable text includes timeout evidence log")
expect(modern.evidenceJSONText.contains("secret-modern-api-key") == false, "evidence JSON hides shared API key")
expect(modern.evidenceJSONText.contains("secret-realtime-api-key") == false, "evidence JSON hides realtime API key")
expect(modern.evidenceJSONText.contains("recommendation"), "evidence JSON includes remediation field")
expect(modern.evidenceJSONText.contains("playbackEvidenceChecks"), "evidence JSON includes playback evidence checks")
expect(modern.evidenceJSONText.contains("native_audio"), "evidence JSON includes native audio source")
expect(modern.evidenceJSONText.contains("system_tts"), "evidence JSON includes system TTS source")
expect(modern.evidenceJSONText.contains("timeout"), "evidence JSON includes timeout source")
expect(modern.evidenceJSONText.contains("No API Key, Token, Secret"), "evidence JSON records redaction policy")

let legacyInfo: [String: Any] = [
    "VolcEngineAPIKey": "secret-modern-api-key",
    "VolcEngineVoiceType": "zh_female_cancan_mars_bigtts",
    "VolcEngineAppID": "test-app-id",
    "VolcEngineAppKey": "secret-app-key",
    "VolcEngineAppToken": "secret-access-token",
    "DreamJourneyBackendBaseURL": "https://www.mmdd10.tech/dreamjourney-api"
]
let legacy = DigitalHumanReadinessReport.make(
    infoDictionary: legacyInfo,
    arguments: [],
    environment: [:]
)
expect(legacy.primaryStatus == .ready, "legacy realtime setup is ready")
expect(legacy.copyableText.contains("旧式三件套模式"), "legacy auth mode is summarized")
expect(legacy.copyableText.contains("secret-app-key") == false, "legacy app key is hidden")
expect(legacy.copyableText.contains("secret-access-token") == false, "legacy token is hidden")

let mock = DigitalHumanReadinessReport.make(
    infoDictionary: [
        "VolcEngineAPIKey": "YOUR_VOLCENGINE_API_KEY",
        "VolcEngineVoiceType": "zh_female_cancan_mars_bigtts",
        "DreamJourneyBackendBaseURL": "http://localhost:3100"
    ],
    arguments: ["--use-mock-dialog-engine"],
    environment: [:]
)
expect(mock.primaryStatus == .missing, "missing TTS/realtime credentials remain visible even in mock")
expect(mock.items.contains(where: { $0.title == "当前对话引擎" && $0.status == .warning }), "mock engine is marked as a warning for real-device validation")
expect(mock.copyableText.contains("可演示") == false, "mock warning path should still use real-device validation wording")
expect(mock.evidenceJSONText.contains("可演示") == false, "mock warning JSON should still use real-device validation wording")
expect(mock.items.contains(where: { $0.title == "DreamJourney 后端" && $0.status == .warning && $0.detail.contains("真机需改为局域网") }), "localhost backend warns for device testing")
expect(mock.copyableText.contains("移除 mock 启动参数"), "mock diagnostic explains how to test real voice")
expect(mock.copyableText.contains("DreamJourneyBackendBaseURL 改成 HTTPS 后端地址"), "localhost diagnostic explains device fix")

let missing = DigitalHumanReadinessReport.make(
    infoDictionary: [
        "VolcEngineAPIKey": "YOUR_VOLCENGINE_API_KEY",
        "VolcEngineVoiceType": "YOUR_VOLCENGINE_CLONE_VOICE_ID",
        "VolcEngineRealtimeAPIKey": "YOUR_REALTIME_KEY"
    ],
    arguments: [],
    environment: [:]
)
expect(missing.primaryStatus == .missing, "missing production credentials are surfaced")
expect(missing.copyableText.contains("YOUR_") == false, "placeholder values are not echoed")
expect(missing.copyableText.contains("API Key") == true, "diagnostic text names required config types")
expect(missing.copyableText.contains("补齐 VolcEngineAPIKey 和 VolcEngineVoiceType"), "missing TTS diagnostic names required keys")
expect(missing.copyableText.contains("补齐 VolcEngineAppID"), "missing realtime diagnostic names legacy credentials")

print("DigitalHumanReadiness verification passed")
