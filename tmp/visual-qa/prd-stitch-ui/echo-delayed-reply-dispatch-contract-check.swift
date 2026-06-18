import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, root baseURL: URL = root) -> String {
    let fileURL = baseURL.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let backendMain = read("app/main.py", root: backendRoot)
let memoryStore = read("app/services/in_memory_store.py", root: backendRoot)
let postgresStore = read("app/services/postgres_store.py", root: backendRoot)
let backendTests = read("tests/test_core_services.py", root: backendRoot)
let postgresTests = read("tests/test_postgres_store.py", root: backendRoot)
let persistenceCheck = read("tmp/visual-qa/prd-stitch-ui/backend-postgres-persistence-check.py")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let policyDoc = read("docs/superpowers/status/2026-06-18-echo-waiting-reply-policy.md")
let backendMatrix = read("docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md")
let coverage = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")

for phrase in [
    "@app.post(\"/echo/delayed-replies/dispatch-due\")",
    "mark_due_echo_delayed_replies_for_dispatch",
    "providerDeliveryAttempted",
] {
    assertContains(backendMain, phrase, "backend dispatch endpoint should include \(phrase)")
}

assertContains(memoryStore, "def mark_due_echo_delayed_replies_for_dispatch", "memory store should support due dispatch marking")
assertContains(postgresStore, "def mark_due_echo_delayed_replies_for_dispatch", "Postgres store should support due dispatch marking")
assertContains(memoryStore, "readyForProvider", "memory dispatch should mark due replies ready for provider")
assertContains(memoryStore, "dispatchAttemptedAt", "memory dispatch should record dispatch attempt time")
assertContains(memoryStore, "pushProviderState", "memory dispatch should mark provider queue state")
assertContains(postgresStore, "readyForProvider", "Postgres dispatch should mark due replies ready for provider")
assertContains(postgresStore, "dispatchAttemptedAt", "Postgres dispatch should record dispatch attempt time")
assertContains(postgresStore, "pushProviderState", "Postgres dispatch should mark provider queue state")
assertContains(postgresStore, "payload->>'deliverAt' <= %s", "Postgres dispatch query should filter due deliverAt values")
assertContains(postgresStore, "payload->>'deliveryState' = 'scheduled'", "Postgres dispatch query should only queue scheduled replies")

assertContains(backendTests, "test_echo_delayed_reply_dispatch_due_marks_only_due_items", "backend API tests should cover due dispatch endpoint")
assertContains(postgresTests, "test_store_marks_due_echo_delayed_replies_for_dispatch", "Postgres tests should cover due dispatch persistence")

for phrase in [
    "/echo/delayed-replies/dispatch-due",
    "echoDelayedReplyDispatchState",
    "echoDelayedReplyPushProviderState",
    "providerDeliveryAttempted",
] {
    assertContains(persistenceCheck, phrase, "release-like persistence check should verify \(phrase)")
}

assertContains(releaseRegression, "echo-delayed-reply-dispatch-contract-check.swift", "release regression should run delayed reply dispatch guard")
assertContains(releasePackage, "echo-delayed-reply-dispatch-contract-check.swift", "release QA package should include delayed reply dispatch guard")

for phrase in [
    "POST /echo/delayed-replies/dispatch-due",
    "readyForProvider",
    "APNs provider delivery remains an external gate",
] {
    assertContains(policyDoc, phrase, "Echo wait policy should document dispatch contract \(phrase)")
}

assertContains(backendMatrix, "Echo delayed reply dispatch", "backend matrix should track delayed reply dispatch")
assertContains(backendMatrix, "accepted on selected release-like backend by run `20260618-deployed-echo-dispatch-contract-accepted-211732`", "backend matrix should record accepted deployed dispatch route parity")
assertContains(backendMatrix, "were blocked with HTTP 405 before redeploy", "backend matrix should preserve recovered dispatch drift")
assertContains(coverage, "deployed backend dispatch-due contract", "PRD coverage should record deployed dispatch-due contract")
assertContains(coverage, "20260618-deployed-echo-dispatch-contract-accepted-211732", "PRD coverage should track accepted dispatch deployed run")
assertContains(coverage, "APNs provider delivery and true-device notification acceptance remain open", "PRD coverage should keep APNs and true-device gates open")

print("Echo delayed reply dispatch contract checks passed")
