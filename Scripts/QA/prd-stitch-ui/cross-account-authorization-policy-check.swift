import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot: URL = {
    if let configured = ProcessInfo.processInfo.environment["BACKEND_ROOT"], !configured.isEmpty {
        return URL(fileURLWithPath: configured)
    }
    return root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")
}()

func read(_ url: URL) -> String {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let policy = read(backendRoot.appendingPathComponent("app/services/authorization_policy.py"))
let registry = read(backendRoot.appendingPathComponent("app/services/route_ownership.py"))
let middleware = read(backendRoot.appendingPathComponent("app/main.py"))
let runtime = read(backendRoot.appendingPathComponent("app/services/runtime_config.py"))
let client = read(root.appendingPathComponent("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"))
let task = read(root.appendingPathComponent("docs/plans/task_10_p0-cross-account-authorization-policy-shadow.md"))

for policyID in [
    "careSnapshotRead",
    "careSnapshotWrite",
    "timeLetterDetail",
    "familyInvitationAccept",
    "familyMemberAccept",
] {
    require(policy.contains(policyID), "Cross-account policy must cover \(policyID)")
}
require(registry.contains("SYSTEM_ONLY = \"systemOnly\""), "Route registry must classify system-only routes")
for decision in ["allowOwner", "allowFamily", "allowRecipient", "deny", "fallback"] {
    require(policy.contains(decision), "Cross-account policy must define \(decision)")
}
require(policy.contains("stable_user_id(phone)"), "Family/invitation principal must bind to normalized phone identity")
require(middleware.contains("CrossAccountAuthorizationPolicy(store).evaluate"), "Auth middleware must evaluate cross-account policy")
require(middleware.contains("X-DreamJourney-Authorization-Policy"), "Policy diagnostic header is required")
require(middleware.contains("X-DreamJourney-Authorization-Decision"), "Decision diagnostic header is required")
require(middleware.contains("X-DreamJourney-Authorization-Reason"), "Reason diagnostic header is required")
require(middleware.contains("ownership_decision = \"delegated\""), "Legitimate cross-account access must be distinguishable")
require(runtime.contains("\"crossAccountPolicy\""), "Runtime must publish the policy capability")
require(runtime.contains("\"productionEnforceReady\": False"), "Runtime must not claim production enforce readiness")
require(client.contains("X-DreamJourney-User-Id"), "iOS requests must continue sending authenticated actor hints")
require(client.contains("URLQueryItem(name: \"viewerUserId\", value: viewerUserId)"), "Time-letter detail must bind the viewer claim")
require(task.contains("默认继续运行 `shadow`"), "Task boundary must retain production shadow mode")

for relativePath in [
    "Scripts/QA/prd-stitch-ui/backend-cross-account-authorization-shadow-smoke.py",
    "Scripts/QA/prd-stitch-ui/run-backend-cross-account-authorization-shadow-smoke.sh",
] {
    require(FileManager.default.fileExists(atPath: root.appendingPathComponent(relativePath).path), "Missing QA artifact \(relativePath)")
}

print("Cross-account authorization policy checks passed")
