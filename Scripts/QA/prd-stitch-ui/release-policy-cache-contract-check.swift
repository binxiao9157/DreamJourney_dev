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

let store = read("DreamJourney/Sources/Services/ReleasePolicyStore.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let status = read("docs/superpowers/status/2026-07-16-wi-s0-06-02-release-policy-cache.md")

for required in [
    "struct ReleasePolicyCacheScope",
    "let accountOrAnonymousScope: String",
    "let appBuild: String",
    "struct ReleasePolicyCacheEnvelope",
    "let payloadHash: String",
    "let fetchedAt: Date",
    "let expiresAt: Date",
    "case clockSkew",
    "case corrupt",
    "case emergencyRevisionStale",
    "case ownerTextCore",
    "return .readOnly",
    "case .futureBeta, .providerEffect",
    "return .deny",
    "func evaluate(",
    "minimumEmergencyRevision",
] {
    assertContains(store, required, "ReleasePolicy store should fail closed with account/build scoped TTL metadata")
}

for required in [
    "private let releasePolicyStore = ReleasePolicyStore.shared",
    "authSessionStore.currentSession?.userId",
    "let requestedScope = releasePolicyCacheScope(clientBuild: clientBuild)",
    "guard requestedScope == self.releasePolicyCacheScope(clientBuild: clientBuild)",
    "throw BackendReleasePolicyContractError.accountScopeChanged",
    "try self.releasePolicyStore.save(",
    "JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])",
    "func cachedReleasePolicyEvaluation(",
    "cachedPolicyContractInvalid",
    "state = .corrupt",
] {
    assertContains(backendClient, required, "backend client should populate and consume the scoped shadow cache")
}

assertContains(project, "ReleasePolicyStore.swift in Sources", "ReleasePolicy store must belong to the iOS target")
assertContains(
    releaseRegression,
    "run-release-policy-cache-model-smoke.sh",
    "release regression should always execute cache isolation scenarios"
)
assertContains(
    releaseRegression,
    "release-policy-cache-contract-check.swift",
    "release regression should enforce cache wiring"
)
assertContains(
    releaseRegression,
    "RUN_RELEASE_POLICY_CACHE_DEPLOYED_SMOKE",
    "release regression should expose deployed-to-cache G2 evidence"
)
for required in [
    "ReleasePolicyStore.swift",
    "release-policy-cache-model-smoke.swift",
    "run-release-policy-cache-model-smoke.sh",
    "release-policy-cache-deployed-smoke.swift",
    "run-release-policy-cache-deployed-smoke.sh",
    "release-policy-cache-contract-check.swift",
] {
    assertContains(releasePackage, required, "release QA package should include policy-cache evidence")
}
for required in [
    "状态：`IMPLEMENTED_SHADOW / G2_VERIFIED`",
    "Authority lock：`RELEASE_POLICY`",
    "Gate：`G0=PASS / G2=PASS`",
    "下一 Work Item：`WI-S0-06-03`",
] {
    assertContains(status, required, "WI-S0-06-02 status should preserve cache and gate evidence")
}

print("Release-policy cache contract guard passed")
