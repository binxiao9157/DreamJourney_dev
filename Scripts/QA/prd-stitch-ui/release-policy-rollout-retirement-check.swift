import Foundation

let root = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? FileManager.default.currentDirectoryPath
)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let value = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return value
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let runner = read("Scripts/QA/prd-stitch-ui/run-release-policy-rollout-gate.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let manifest = read("docs/superpowers/status/2026-07-16-wi-s0-06-08-legacy-retirement-manifest.json")
let status = read("docs/superpowers/status/2026-07-16-wi-s0-06-08-release-policy-rollout.md")
let backendPolicy = read("../DreamJourneyBackend/app/services/release_policy.py")
let backendMain = read("../DreamJourneyBackend/app/main.py")
let backendEnv = read("../DreamJourneyBackend/.env.example")
let backendSmoke = read("../DreamJourneyBackend/scripts/backend-release-policy-rollout-deployed-smoke.py")

for required in [
    "X-DreamJourney-Runtime-Contract-Version\": \"2",
    "X-DreamJourney-Client-Build",
    "let rolloutContractVersion: Int",
    "let runtimeContractVersion: Int",
    "let canaryFeatures: [String]",
    "let killSwitchFeatures: [String]",
] {
    require(client.contains(required), "iOS typed rollout contract missing \(required)")
}
require(
    flags.contains("subtracting(Self.nonPersistentFeatures)"),
    "legacy persisted flags must remain contained until the zero-use window closes"
)
require(
    flags.contains("#if DEBUG || UI_QA_SIMULATOR"),
    "QA feature overrides must remain process-only"
)

for required in [
    "class ReleasePolicyDecisionRecorder",
    "def command_mode_for",
    "canaryFeatures",
    "killSwitchFeatures",
    "legacyRuntimeAliasHitCount",
] {
    require(backendPolicy.contains(required), "backend rollout contract missing \(required)")
}
for required in [
    "/ops/release-policy/observations",
    "X-DreamJourney-Release-Policy-Mode",
    "client_upgrade_required",
] {
    require(backendMain.contains(required), "backend route contract missing \(required)")
}
for required in [
    "RELEASE_POLICY_ENFORCED_FEATURES=",
    "RELEASE_POLICY_EMERGENCY_REVISION=",
    "RELEASE_POLICY_EMERGENCY_DISABLED_FEATURES=",
] {
    require(backendEnv.contains(required), "backend env contract missing \(required)")
}
require(
    backendSmoke.contains("typedRuntimeContractHitCount"),
    "deployed smoke must verify the typed runtime observation"
)
require(
    backendSmoke.contains("release_policy_denied"),
    "deployed smoke must verify stable server denial"
)
require(
    runner.contains("run-backend-release-policy-rollout-deployed-smoke.sh"),
    "cross-repository gate must call the deployed rollout smoke"
)
require(
    releaseRegression.contains("RUN_RELEASE_POLICY_ROLLOUT_GATE"),
    "release regression must expose the rollout gate"
)
require(manifest.contains("\"status\": \"OBSERVING\""), "retirement manifest must not claim completion early")
require(manifest.contains("\"requiredObservationWindowHours\": 168"), "zero-use window must be explicit")
require(status.contains("G4_OPEN"), "true-device gate must remain explicit")

let runtimeClients = [
    "Scripts/QA/prd-stitch-ui/backend-archive-image-analysis-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-auth-session-shadow-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-auth-token-contract-check.py",
    "Scripts/QA/prd-stitch-ui/backend-cross-account-authorization-shadow-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-digital-human-session-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-family-voice-contract-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-hidden-media-sync-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-integration-contract-check.py",
    "Scripts/QA/prd-stitch-ui/backend-route-ownership-audit-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-voice-clone-deployed-smoke.py",
    "Scripts/QA/prd-stitch-ui/backend-voice-synthesis-viseme-smoke.py",
    "Scripts/QA/prd-stitch-ui/echo-readiness-report.py",
    "../DreamJourneyBackend/scripts/backend-credential-response-deployed-smoke.py",
    "../DreamJourneyBackend/scripts/backend-release-policy-command-deployed-smoke.py",
    "../DreamJourneyBackend/scripts/backend-release-policy-rollout-deployed-smoke.py",
    "../DreamJourneyBackend/scripts/backend-runtime-capability-deployed-smoke.py",
]
for path in runtimeClients {
    let source = read(path)
    require(source.contains("/config/runtime"), "runtime client fixture missing in \(path)")
    require(
        source.contains("X-DreamJourney-Runtime-Contract-Version"),
        "runtime client must declare contract v2: \(path)"
    )
    require(
        source.contains("X-DreamJourney-Client-Build"),
        "runtime client must declare its build: \(path)"
    )
}

print("Release policy rollout/retirement contract passed")
