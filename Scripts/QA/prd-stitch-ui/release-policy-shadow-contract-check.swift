import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
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

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let status = read("docs/superpowers/status/2026-07-16-wi-s0-06-01-release-policy-shadow.md")

for required in [
    "struct BackendReleasePolicyFeatureDecision",
    "struct BackendReleasePolicySnapshot",
    "let schemaVersion: Int",
    "let policyVersion: String",
    "let policyRevision: Int",
    "let issuedAt: Date",
    "let expiresAt: Date",
    "let minClient: Int",
    "let emergencyRevision: Int",
    "let shadowMode: Bool",
    "let features: [BackendReleasePolicyFeatureDecision]",
    "var isExpired: Bool",
    "func decision(for feature: DJFeature)",
    "reason: \"unknownFeature\"",
    "reason: \"expiredPolicy\"",
    "func fetchReleasePolicy(",
    "let path = \"/v2/release-policy\"",
    "knownPolicyRevision",
] {
    assertContains(backendClient, required, "iOS should consume the typed shadow release-policy contract")
}

for required in [
    "RUN_BACKEND_RELEASE_POLICY_SMOKE",
    "run-backend-release-policy-deployed-smoke.sh",
    "backend-release-policy-smoke",
] {
    assertContains(releaseRegression, required, "release regression should expose the deployed release-policy gate")
}

assertContains(
    releaseRegression,
    "release-policy-shadow-contract-check.swift",
    "release regression should enforce the release-policy shadow client contract"
)

for required in [
    "状态：`IMPLEMENTED_SHADOW / DEPLOYED`",
    "Authority lock：`RELEASE_POLICY`",
    "Gate：`G0=PASS`",
    "Backend commit：`a15123c`",
    "下一 Work Item：`WI-S0-06-02`",
] {
    assertContains(status, required, "WI-S0-06-01 status should preserve execution evidence")
}
assertContains(
    releasePackage,
    "release-policy-shadow-contract-check.swift",
    "release QA package should include the release-policy shadow client contract"
)

print("Release-policy shadow contract guard passed")
