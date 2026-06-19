import Foundation

let appRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let workspaceRoot = appRoot.deletingLastPathComponent()
let backendRoot = workspaceRoot.appendingPathComponent("DreamJourneyBackend")

func read(_ url: URL) -> String {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let backendTokens = read(backendRoot.appendingPathComponent("app/services/tokens.py"))
let backendRuntime = read(backendRoot.appendingPathComponent("app/services/runtime_config.py"))
let backendTests = read(backendRoot.appendingPathComponent("tests/test_core_services.py"))
let backendClient = read(appRoot.appendingPathComponent("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"))
let dialogEngine = read(appRoot.appendingPathComponent("DreamJourney/Sources/Services/DialogEngineManager.swift"))
let echoView = read(appRoot.appendingPathComponent("DreamJourney/Sources/Modules/Echo/EchoViewController.swift"))
let releasePackage = read(appRoot.appendingPathComponent("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift"))
let releaseRegression = read(appRoot.appendingPathComponent("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh"))

assertContains(backendTokens, "\"expiresInSeconds\"", "realtime token contract should include an explicit TTL")
assertContains(backendTokens, "\"expiresAt\"", "realtime token contract should include an absolute expiry")
assertContains(backendTokens, "\"fallback\"", "realtime token contract should document client fallback")
assertContains(backendRuntime, "\"runtimeConfigEndpoint\": \"/voice/realtime-token\"", "runtime config should point iOS to the voice runtime endpoint")
assertContains(backendRuntime, "\"fallback\"", "runtime config should document the local voice fallback strategy")
assertContains(backendTests, "test_runtime_config_documents_realtime_token_endpoint_and_fallback", "backend tests should guard runtime voice fallback")
assertContains(backendTests, "expiresInSeconds", "backend tests should guard voice token TTL")
assertContains(backendTests, "expiresAt", "backend tests should guard voice token expiry")

assertContains(backendClient, "struct RealtimeVoiceRuntimeConfig", "iOS should model realtime voice runtime config")
assertContains(backendClient, "func fetchRuntimeConfig", "iOS should be able to fetch /config/runtime")
assertContains(backendClient, "func fetchRealtimeVoiceConfig", "iOS should be able to fetch /voice/realtime-token")
assertContains(backendClient, "path: \"/config/runtime\"", "runtime config should use the documented backend endpoint")
assertContains(backendClient, "path: \"/voice/realtime-token\"", "voice token should use the documented backend endpoint")
assertContains(backendClient, "var isExpired", "iOS should understand token expiry before applying runtime config")
assertContains(backendClient, "fallbackMode", "iOS should keep fallback metadata from the backend")

assertContains(dialogEngine, "func configure(runtimeConfig: RealtimeVoiceRuntimeConfig)", "DialogEngine should accept backend voice runtime config")
assertContains(dialogEngine, "runtimeConfig.authMode == \"legacy\"", "DialogEngine should only apply runtime configs compatible with the current SDK wrapper")
assertContains(dialogEngine, "runtimeConfig.expiresAt > Date()", "DialogEngine should reject expired runtime configs")

assertContains(echoView, "configureVoiceRuntimeThenStart()", "Echo should resolve voice runtime config before starting the SDK")
assertContains(echoView, "fetchRealtimeVoiceConfig", "Echo should prefer backend voice runtime config")
assertContains(echoView, "startDialogWithLocalVoiceFallback", "Echo should keep local build-settings fallback when backend runtime config is unavailable")

assertContains(releasePackage, "backend-voice-runtime-contract-check.swift", "release QA package should include backend voice runtime guard")
assertContains(releaseRegression, "backend-voice-runtime-contract-check.swift", "release regression should run backend voice runtime guard")

print("Backend voice runtime contract checks passed")
