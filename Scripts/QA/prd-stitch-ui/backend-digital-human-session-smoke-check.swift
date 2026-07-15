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
    "blocked",
    "realProviderReady",
    "sdkAuthMode",
    "credentialBrokerRequired",
    "sdkAdapterLinked",
    "blockedStaticCredential",
    "digital_human_credential_broker_unavailable",
    "assert_no_store",
    "assert_value_free",
    "silent mode",
    "repeatedRequestStayedBlocked",
    "value intentionally omitted",
] {
    assertContains(pythonContent, required, "Python smoke should cover \(required)")
}
for forbidden in [
    "credential.get(\"appkey\")",
    "credential.get(\"accesstoken\")",
    "backend-issued-tencent-cloud",
] {
    assertNotContains(pythonContent, forbidden, "Python smoke must not accept legacy static credential contract")
}

assertContains(backendConfig, "TENCENT_DIGITAL_HUMAN_SESSION_TTL_SECONDS", "backend settings should retain lease cleanup timing")
assertContains(backendRuntime, "credentialBrokerRequired", "runtime config should require a scoped credential broker")
assertContains(backendRuntime, "blockedStaticCredential", "runtime config should block static credential delivery")
assertNotContains(backendRuntime, "TENCENT_DIGITAL_HUMAN_APP_KEY", "runtime response code must not reference static appkey env labels")
assertNotContains(backendRuntime, "TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN", "runtime response code must not reference static access token env labels")

for required in [
    "DIGITAL_HUMAN_SESSION_CONTRACT_VERSION = 3",
    "digital_human_credential_broker_unavailable",
    "blockedStaticCredential",
    "fallbackMode",
    "DIGITAL_HUMAN_SESSION_LEASE_CONTRACT_VERSION",
    "heartbeat_digital_human_session",
    "release_digital_human_session",
] {
    assertContains(backendMain, required, "backend session endpoint should emit \(required)")
}
for forbidden in [
    "credential[\"appkey\"]",
    "credential[\"accesstoken\"]",
    "backend-issued-tencent-cloud",
] {
    assertNotContains(backendMain, forbidden, "backend session endpoint must not emit legacy static credentials")
}

for required in [
    "test_create_digital_human_session_is_blocked_without_scoped_broker",
    "test_blocked_session_requests_never_allocate_or_reuse_a_lease",
    "test_runtime_config_blocks_digital_human_without_scoped_broker",
    "test_static_provider_configuration_does_not_reenable_session_response",
    "digital_human_credential_broker_unavailable",
    "blockedStaticCredential",
    "test_session_lease_heartbeat_and_release_are_owner_scoped_and_idempotent",
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

print("Backend digital-human session smoke checks passed")
