import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let backendRoot = ProcessInfo.processInfo.environment["BACKEND_ROOT"]
    .map(URL.init(fileURLWithPath:))
    ?? root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ base: URL, _ relativePath: String) -> String {
    let url = base.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fputs("Missing file: \(url.path)\n", stderr)
        exit(1)
    }
    return content
}

func require(_ source: String, _ token: String, _ message: String) {
    guard source.contains(token) else {
        fputs("Release-policy capability/cohort check failed: \(message)\n", stderr)
        exit(1)
    }
}

let flags = read(root, "DreamJourney/Sources/App/FeatureFlagService.swift")
let client = read(root, "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let backendPolicy = read(backendRoot, "app/services/release_policy.py")
let backendMain = read(backendRoot, "app/main.py")
let backendTests = read(backendRoot, "tests/test_release_policy.py")

for feature in ["ownerMediaCaptureV1", "ownerMediaProcessingV1", "accountDataExport"] {
    require(flags, "case \(feature)", "iOS must model \(feature) independently")
    require(client, ".\(feature)", "iOS request policy must consume \(feature)")
    require(backendPolicy, "\"\(feature)\"", "backend policy must define \(feature)")
}

for token in [
    "let requiredCapability: String?",
    "let capabilityReady: Bool",
    "requiredCapability = json[\"requiredCapability\"] as? String",
    "capabilityReady = json[\"capabilityReady\"] as? Bool",
    "pathComponents[5] == \"processing-retries\"",
    "return .ownerMediaProcessingV1",
    "return .accountDataExport",
    "pathSuffix == \"/processing-retries\"",
] {
    require(client, token, "iOS must fail closed on the typed capability-bound decision")
}

for token in [
    "_FEATURE_CAPABILITIES",
    "\"ownerMediaCaptureV1\": \"ownerTruthMediaStorage\"",
    "\"ownerMediaProcessingV1\": \"ownerTruthMediaProcessing\"",
    "reason = \"capabilityUnavailable\"",
    "capability_resolver",
    "feature = \"ownerMediaProcessingV1\"",
] {
    let source = token == "feature = \"ownerMediaProcessingV1\"" ? backendMain : backendPolicy
    require(source, token, "backend must bind each route to its runtime capability")
}

for token in [
    "test_media_capture_and_processing_fail_closed_without_runtime_capability",
    "test_m0_data_export_has_an_independent_server_cohort_decision",
    "test_route_inventory_covers_hidden_commands_and_dynamic_archive_payloads",
] {
    require(backendTests, token, "backend tests must preserve server-owned admission behavior")
}

require(backendMain, "_release_policy_server_cohort", "cohort must be resolved by the server")
require(backendMain, "RELEASE_POLICY_CLOSED_PILOT_OWNER_IDS", "cohort admission must use the server allowlist")

print("Release-policy capability/cohort checks passed")
