import Foundation

let appRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = appRoot.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ url: URL) -> String {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let backendTokens = read(backendRoot.appendingPathComponent("app/services/tokens.py"))
let backendRuntime = read(backendRoot.appendingPathComponent("app/services/runtime_config.py"))
let backendBoundaryTests = read(backendRoot.appendingPathComponent("tests/test_credential_response_boundary.py"))
let backendClient = read(appRoot.appendingPathComponent("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"))
let dialogEngine = read(appRoot.appendingPathComponent("DreamJourney/Sources/Services/DialogEngineManager.swift"))
let echoView = read(appRoot.appendingPathComponent("DreamJourney/Sources/Modules/Echo/EchoViewController.swift"))
let releasePackage = read(appRoot.appendingPathComponent("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift"))
let releaseRegression = read(appRoot.appendingPathComponent("Scripts/QA/prd-stitch-ui/run-release-regression.sh"))

for required in ["\"status\": \"blocked\"", "\"credentialMode\": \"blockedStaticCredential\"", "\"providerReady\": False", "\"fallback\""] {
    require(backendTokens.contains(required), "realtime voice response must be value-free and blocked: missing \(required)")
}
require(!backendTokens.contains("\"expiresInSeconds\""), "blocked realtime voice must not invent a credential TTL")
require(!backendTokens.contains("\"expiresAt\""), "blocked realtime voice must not invent a credential expiry")
require(backendRuntime.contains("\"realtimeToken\": False"), "runtime capability must disable realtime tokens")
require(backendRuntime.contains("\"credentialMode\": \"blockedStaticCredential\""), "runtime must declare the blocked credential mode")
require(backendBoundaryTests.contains("test_realtime_voice_returns_blocked_value_free_capability"), "backend must test the blocked value-free contract")
require(backendBoundaryTests.contains("assert_no_store"), "backend must test no-store headers")

require(backendClient.contains("struct RealtimeVoiceRuntimeConfig"), "iOS must model realtime voice capability state")
require(backendClient.contains("var isBlocked: Bool"), "iOS must reject blocked capability responses")
require(backendClient.contains("fetchRealtimeVoiceConfig"), "iOS must fetch the backend capability contract")
require(!backendClient.contains("let appToken: String"), "iOS runtime model must not parse a Provider app token")
require(!backendClient.contains("let apiKey: String"), "iOS runtime model must not parse a Provider API key")

require(dialogEngine.contains("case providerCredentialBlocked"), "voice readiness must represent the credential boundary")
require(dialogEngine.contains("guard !runtimeConfig.isBlocked"), "DialogEngine must fail closed for a blocked contract")
require(!dialogEngine.contains("VolcEngineAppToken"), "DialogEngine must not read a packaged Provider token")
require(echoView.contains("handleBlockedRealtimeVoice"), "Echo must expose the safe blocked path")
require(echoView.contains("echoRealtimeVoiceCredentialBlocked"), "Echo must expose an accessible blocked status")
require(!echoView.contains("startDialogWithLocalVoiceFallback"), "Echo must not restore static local Provider fallback")

require(releasePackage.contains("backend-voice-runtime-contract-check.swift"), "release QA package must include this guard")
require(releaseRegression.contains("backend-voice-runtime-contract-check.swift"), "release regression must run this guard")

print("Backend voice runtime blocked-contract checks passed")
