import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func url(_ relativePath: String) -> URL {
    root.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: url(relativePath).path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let runner = "Scripts/QA/prd-stitch-ui/run-backend-digital-human-session-smoke.sh"
let pythonSmoke = "Scripts/QA/prd-stitch-ui/backend-digital-human-session-smoke.py"
let statusDoc = "docs/superpowers/status/2026-06-25-tencent-digital-human-sdk-handoff.md"

assertFileExists(runner, "backend digital-human session smoke runner")
assertFileExists(pythonSmoke, "backend digital-human session Python smoke")
assertFileExists(statusDoc, "Tencent digital-human handoff doc")

let runnerContent = read(runner)
let pythonContent = read(pythonSmoke)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let handoff = read(statusDoc)
let backendConfig = read("../DreamJourneyBackend/app/core/config.py")
let backendRuntime = read("../DreamJourneyBackend/app/services/runtime_config.py")
let backendMain = read("../DreamJourneyBackend/app/main.py")
let backendTests = read("../DreamJourneyBackend/tests/test_digital_human_sessions.py")

for required in [
    "BACKEND_DIGITAL_HUMAN_SESSION_SMOKE",
    "deployed-backend-access.md",
    "value intentionally omitted",
    "backend-digital-human-session-smoke.py",
    "backend-digital-human-session-smoke-result.json",
] {
    assertContains(runnerContent, required, "runner should include \(required)")
}
assertNotContains(runnerContent, "echo \"$BACKEND_API_TOKEN\"", "runner must not print raw token")
assertNotContains(runnerContent, "cat \"$ACCESS_DOC\"", "runner must not print the private access doc")

for required in [
    "/health",
    "/config/runtime",
    "/digital-human/sessions",
    "providerMode",
    "cloudRender",
    "realProviderReady",
    "sdkAuthMode",
    "appkeyAccessToken",
    "sdkAdapterLinked",
    "assetMode",
    "backend-issued-tencent-cloud",
    "providerAssetId",
    "providerProjectId",
    "credential",
    "appkey",
    "accesstoken",
    "silent mode",
    "value intentionally omitted",
] {
    assertContains(pythonContent, required, "Python smoke should cover \(required)")
}

for required in [
    "TENCENT_DIGITAL_HUMAN_APP_KEY",
    "TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN",
    "TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY",
    "TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID",
] {
    assertContains(backendConfig, required, "backend settings should read \(required)")
    assertContains(backendRuntime, required, "runtime config should document \(required)")
}

for required in [
    "DIGITAL_HUMAN_SESSION_CLOUD_PROVIDER_MODE = \"cloudRender\"",
    "provider_mode",
    "backend-issued-tencent-cloud",
    "credential[\"appkey\"]",
    "credential[\"accesstoken\"]",
    "providerAssetId",
    "providerProjectId",
] {
    assertContains(backendMain, required, "backend session endpoint should emit \(required)")
}

for required in [
    "test_create_digital_human_session_returns_cloud_render_contract_when_configured",
    "test_runtime_config_reports_cloud_render_ready_when_configured",
    "providerMode",
    "cloudRender",
    "appkey",
    "accesstoken",
] {
    assertContains(backendTests, required, "backend tests should cover \(required)")
}

assertContains(releaseRegression, "RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE", "release regression should expose optional digital-human backend smoke")
assertContains(releaseRegression, "run-backend-digital-human-session-smoke.sh", "release regression should call digital-human backend smoke")
assertContains(releaseRegression, "backend-digital-human-session-smoke", "release regression report should mention digital-human evidence")
assertContains(releaseRegression, "backend-digital-human-session-smoke-check.swift", "release regression should run the static guard")

for requiredPackageEntry in [
    "run-backend-digital-human-session-smoke.sh",
    "backend-digital-human-session-smoke.py",
    "backend-digital-human-session-smoke-check.swift",
] {
    assertContains(releasePackage, requiredPackageEntry, "release QA package should include \(requiredPackageEntry)")
}

assertContains(handoff, "RUN_BACKEND_DIGITAL_HUMAN_SESSION_SMOKE=1", "handoff should document deployed backend digital-human smoke")
assertContains(handoff, "providerMode=cloudRender", "handoff should document cloudRender acceptance")

print("Backend digital-human session smoke checks passed")
