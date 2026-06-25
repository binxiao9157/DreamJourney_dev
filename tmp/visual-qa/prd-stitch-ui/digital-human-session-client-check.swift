import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("digital-human-session-client-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let client = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = try read("DreamJourney/Sources/AppDelegate.swift")
let runtime = try read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift")
let runtimeFactory = try read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntimeFactory.swift")
let releaseRegression = try read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let runtimeStubSmoke = try read("tmp/visual-qa/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh")
let statusDoc = try read("docs/superpowers/status/2026-06-25-tencent-digital-human-runtime-foundation.md")

require(client.contains("struct DigitalHumanRuntimeCapability"), "runtime capability parser is missing")
require(client.contains("struct DigitalHumanSessionContract"), "session contract model is missing")
require(client.contains("struct DigitalHumanSessionCredential"), "session credential model is missing")
require(client.contains("struct DigitalHumanSessionPolicy"), "session policy model is missing")
require(client.contains("fetchDigitalHumanRuntimeCapability"), "runtime capability fetch helper is missing")
require(client.contains("createDigitalHumanSession("), "create session client method is missing")
require(client.contains("\"/digital-human/sessions\""), "client must call /digital-human/sessions")
require(client.contains("DigitalHumanSessionContract(json:"), "client must parse session contract")
require(client.contains("toDigitalHumanProfile(displayName:"), "session contract must convert to DigitalHumanProfile")
require(client.contains("lifecycleMode: DigitalHumanMode"), "session lifecycle mode must parse to DigitalHumanMode")
require(client.contains("let sdkAdapterLinked: Bool"), "runtime capability should parse SDK adapter readiness")
require(client.contains("let sdkAuthMode: String"), "runtime capability should parse Tencent appkey/accesstoken auth mode")
require(client.contains("let requiredServerEnv: [String]"), "runtime capability should parse required server env")
require(client.contains("let requiredAssetEnv: [String]"), "runtime capability should parse avatar/project asset env")
require(client.contains("let optionalASREnv: [String]"), "runtime capability should parse ASR-only Tencent env")
require(client.contains("let providerFieldAliases: [String]"), "runtime capability should parse official provider field aliases")
require(client.contains("let sdkReadinessMessage: String"), "runtime capability should parse SDK readiness message")
require(client.contains("\"sdkAuthMode\""), "runtime capability should read sdkAuthMode")
require(client.contains("\"requiredAssetEnv\""), "runtime capability should read requiredAssetEnv")
require(client.contains("\"optionalASREnv\""), "runtime capability should read optionalASREnv")
require(client.contains("\"providerFieldAliases\""), "runtime capability should read providerFieldAliases")

require(runtime.contains("DigitalHumanSessionState"), "runtime abstraction must exist")
require(runtimeFactory.contains("makeRuntime(") && runtimeFactory.contains("for contract: DigitalHumanSessionContract"), "runtime factory should create runtime from backend session contract")
require(runtimeFactory.contains("isRealSDKBacked: false"), "runtime factory should not claim real SDK readiness without linked adapter")
require(echo.contains("digitalHumanRuntime: DigitalHumanRuntime?"), "Echo must hold a runtime abstraction")
require(echo.contains("runUIQADigitalHumanRuntimeStubSmoke"), "Echo QA runtime stub smoke is missing")
require(echo.contains("DigitalHumanRuntimeFactory.makeRuntime"), "Echo QA path must consume runtime factory")
require(echo.contains("createDigitalHumanSession("), "Echo QA path must request backend session contract")
require(echo.contains("AudioOnlyDigitalHumanRuntime"), "Echo QA path must verify audio-only fallback")

require(appDelegate.contains("DJRunDigitalHumanRuntimeStubSmoke"), "AppDelegate launch arg is missing")
require(appDelegate.contains("runDigitalHumanRuntimeStubSmoke"), "AppDelegate runner is missing")
require(appDelegate.contains("writeDigitalHumanRuntimeStubSmokeResult"), "AppDelegate result writer is missing")
require(appDelegate.contains("digital-human-runtime-stub-smoke-result.json"), "QA result file name is missing")

require(runtimeStubSmoke.contains("DJRunDigitalHumanRuntimeStubSmoke"), "runtime stub smoke must launch the QA harness")
require(runtimeStubSmoke.contains("STORE_BACKEND=memory"), "runtime stub smoke must start an isolated memory backend")
require(runtimeStubSmoke.contains("defaultReleaseVisible"), "runtime stub smoke must assert public default hidden state")
require(runtimeStubSmoke.contains("runtimeIsRealSDKBacked"), "runtime stub smoke must assert SDK is not falsely marked real")
require(runtimeStubSmoke.contains("runtimeFactoryFallbackReason"), "runtime stub smoke must assert factory fallback reason")
require(runtimeStubSmoke.contains("audioOnlyFallbackState"), "runtime stub smoke must assert audio-only fallback")
require(releaseRegression.contains("RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE"), "release regression optional runtime stub gate is missing")
require(releaseRegression.contains("run-digital-human-runtime-stub-smoke.sh"), "release regression must call runtime stub smoke")

require(statusDoc.contains("TENCENT_DIGITAL_HUMAN_APP_KEY"), "status doc should use Tencent appkey env")
require(statusDoc.contains("TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN"), "status doc should use Tencent accesstoken env")
require(statusDoc.contains("asset_virtualman_key"), "status doc should document official asset_virtualman_key")
require(statusDoc.contains("virtualman_project_id"), "status doc should document official virtualman_project_id")
require(statusDoc.contains("ASR-only"), "status doc should mark SecretId/SecretKey/AppId as ASR-only")

print("digital-human-session-client-check passed")
