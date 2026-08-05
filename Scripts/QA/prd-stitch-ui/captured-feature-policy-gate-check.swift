import Foundation

let root = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? FileManager.default.currentDirectoryPath
)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ base: URL, _ relativePath: String) -> String {
    let url = base.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ content: String, _ needle: String, _ message: String) {
    guard content.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let policyStore = read(root, "DreamJourney/Sources/Services/ReleasePolicyStore.swift")
let client = read(root, "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let archive = read(root, "DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let echo = read(root, "DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let profile = read(root, "DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let backendPolicy = read(backendRoot, "app/services/release_policy.py")
let backendMain = read(backendRoot, "app/main.py")
let backendTests = read(backendRoot, "tests/test_release_policy.py")

for required in [
    "struct FeatureDecision: Equatable",
    "let decisionId: String",
    "let policyVersion: String?",
    "let accountGeneration: String",
    "let allowed: Bool",
    "let reason: String",
    "let expiresAt: Date?",
    "capturedPolicyExpired",
    "policyVersionChanged",
    "accountGenerationChanged",
    "struct FeatureDecisionEvidenceSummary: Codable, Equatable",
] {
    require(policyStore, required, "iOS must retain an immutable and explainable policy decision")
}

for required in [
    "private var routeDecisions: [DJFeature: FeatureDecision]",
    "private var latestDecisions: [DJFeature: FeatureDecision]",
    "func qaEvidenceSnapshot(features: [DJFeature])",
    "X-DreamJourney-Feature-Decision-Id",
    "X-DreamJourney-Account-Generation",
    "X-DreamJourney-Policy-Version",
    "X-DreamJourney-Policy-Revision",
    "featureDecision: preparedFeatureDecision",
    "normalizedPath == \"/profile\"",
    "normalizedPath == \"/context/build\"",
    "normalizedPath.hasPrefix(\"/echo/delayed-replies\")",
    "normalizedPath == \"/auth/delete\" || normalizedPath == \"/auth/restore\"",
    "method == .get, normalizedPath.hasPrefix(\"/archive/items/\")",
] {
    require(client, required, "iOS route and retry requests must share captured policy metadata")
}

for required in [
    ".archiveAudioUpload",
    ".archiveVideoUpload",
    ".timeLetters",
] {
    require(archive, required, "Archive controlled entry must use a feature route decision")
}
for required in [
    "captureServerPolicyManagedClosedPilotRoute(\n            .echoTextInput,",
    ".digitalHumanLivePanel",
    "featurePolicyDecisions: policyDecisions",
    "policy.\\(decision.feature)",
] {
    require(echo, required, "Echo must capture and expose policy evidence only through QA diagnostics")
}
for required in [
    ".familyManagement",
    ".voiceCloneShell",
    ".careDashboard",
] {
    require(profile, required, "Profile controlled entry must use a feature route decision")
}

for required in [
    "@dataclass(frozen=True)",
    "class ReleasePolicyCommandCapture",
    "decision_id: str",
    "class ReleasePolicyCommandGate",
    "not normalized_decision_id",
    "expected_account_generation",
    "accountGenerationMismatch",
    "def revalidate_effect(",
    "capturedPolicyExpiredBeforeEffect",
    "policyVersionChanged",
    "(\"/profile\", \"profileSettings\")",
    "(\"/context/build\", \"echoTextInput\")",
    "(\"/echo/delayed-replies\", \"echoTextInput\")",
    "(\"/auth/delete\", \"accountDeletion\")",
    "normalized_path.startswith(\"/archive/items/\")",
] {
    require(backendPolicy, required, "backend must independently authorize the same controlled command")
}

for required in [
    "RELEASE_POLICY_COMMAND_MODE",
    "RELEASE_POLICY_COMMAND_GATE.capture(",
    "client_decision_id=",
    "RELEASE_POLICY_COMMAND_GATE.revalidate_effect(captured)",
    "release_policy_denied",
    "observeDeny",
    "X-DreamJourney-Release-Policy-Reason",
] {
    require(backendMain, required, "backend middleware must observe/enforce immediately before command effects")
}

for required in [
    "test_effect_time_revalidation_rejects_emergency_revoke",
    "test_authenticated_account_generation_mismatch_fails_closed",
    "test_expired_capture_is_denied_before_effect",
    "test_route_inventory_covers_hidden_commands_and_dynamic_archive_payloads",
] {
    require(backendTests, required, "backend policy gate must retain deterministic regression coverage")
}

print("Captured feature-policy route/command gate passed")
