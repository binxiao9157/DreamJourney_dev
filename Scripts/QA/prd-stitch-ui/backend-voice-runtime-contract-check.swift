import Foundation

let appRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = appRoot.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ root: URL, _ path: String) -> String {
    let url = root.appendingPathComponent(path)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let backendTokens = read(backendRoot, "app/services/tokens.py")
let backendBroker = read(backendRoot, "app/services/realtime_voice_proxy.py")
let backendRuntime = read(backendRoot, "app/services/runtime_config.py")
let backendBoundaryTests = read(backendRoot, "tests/test_credential_response_boundary.py")
let backendProxyTests = read(backendRoot, "tests/test_realtime_voice_proxy.py")
let backendClient = read(appRoot, "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let dialogEngine = read(appRoot, "DreamJourney/Sources/Services/DialogEngineManager.swift")
let echoView = read(appRoot, "DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releasePackage = read(appRoot, "Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read(appRoot, "Scripts/QA/prd-stitch-ui/run-release-regression.sh")

require(backendTokens.contains("issue_realtime_config"), "backend must issue a session-bound runtime config")
for required in ["oneTimeBackendProxyTicket", "backendRealtimeProxy", "mobileDirectAllowed\": False", "ticket_hash", "X-DreamJourney-Voice-Session"] {
    require(backendBroker.contains(required), "backend realtime broker is missing \(required)")
}
require(backendRuntime.contains("bool(realtime_voice.get(\"providerReady\"))"), "runtime capability must reflect proxy readiness")
require(backendBoundaryTests.contains("test_realtime_voice_ready_contract_returns_only_one_time_proxy_ticket"), "backend must test the value-free ready contract")
require(backendProxyTests.contains("test_ticket_is_single_use_and_released_explicitly"), "backend must test single-use ticket semantics")
require(backendBoundaryTests.contains("assert_no_store"), "backend must test no-store headers")

require(backendClient.contains("struct RealtimeVoiceRuntimeConfig"), "iOS must model realtime voice capability state")
require(backendClient.contains("oneTimeBackendProxyTicket"), "iOS must require the one-time proxy mode")
require(!backendClient.contains("let appToken: String"), "iOS runtime model must not parse a Provider app token")
require(!backendClient.contains("let apiKey: String"), "iOS runtime model must not parse a Provider API key")
require(dialogEngine.contains("guard !runtimeConfig.mobileDirectAllowed"), "DialogEngine must keep direct mobile access closed")
require(dialogEngine.contains("SE_PARAMS_KEY_REQUEST_HEADERS_STRING"), "DialogEngine must pass the proxy ticket in the WebSocket handshake")
require(!dialogEngine.contains("VolcEngineAppToken"), "DialogEngine must not read a packaged Provider token")
require(echoView.contains("liveUserInactivityTimeout: TimeInterval = 60"), "Echo Live must implement the one-minute user inactivity boundary")
require(echoView.contains("finishLiveMemoryCaptureIfNeeded"), "Echo Live must finish through the pending-memory pipeline")

require(releasePackage.contains("backend-voice-runtime-contract-check.swift"), "release QA package must include this guard")
require(releaseRegression.contains("backend-voice-runtime-contract-check.swift"), "release regression must run this guard")

print("Backend voice runtime proxy-contract checks passed")
