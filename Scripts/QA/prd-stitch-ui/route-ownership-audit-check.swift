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

let registry = read(backendRoot.appendingPathComponent("app/services/route_ownership.py"))
let registryTests = read(backendRoot.appendingPathComponent("tests/test_route_ownership_registry.py"))
let policy = read(backendRoot.appendingPathComponent("app/services/authorization_policy.py"))
let middleware = read(backendRoot.appendingPathComponent("app/main.py"))
let runtime = read(backendRoot.appendingPathComponent("app/services/runtime_config.py"))
let repository = read(root.appendingPathComponent("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift"))
let backendClient = read(root.appendingPathComponent("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift"))
let releaseRegression = read(root.appendingPathComponent("Scripts/QA/prd-stitch-ui/run-release-regression.sh"))

for category in [
    "PUBLIC",
    "AUTHENTICATED_SERVICE",
    "USER_SESSION",
    "OWNER_BODY",
    "OWNER_PATH",
    "DELEGATED",
    "SYSTEM_ONLY",
] {
    require(registry.contains(category), "Route ownership registry must define \(category)")
}
require(registry.contains("class RouteOwnershipRegistry"), "Route ownership registry is missing")
require(registry.contains("owner_body_field=\"userId\""), "Body-owned routes must bind userId")
require(registry.contains("owner_path_parameter=parameter"), "Path-owned routes must bind their owner parameter")
require(registryTests.contains("self.assertEqual(len(app_routes), 54)"), "Route audit must pin the current route count")
require(registryTests.contains("self.assertEqual(registry_routes, app_routes)"), "Route audit must fail for unclassified routes")
require(registryTests.contains("len(self.registry.rules), len(registry_routes)"), "Route audit must fail for duplicates")

require(policy.contains("RouteOwnershipRegistry()"), "Authorization policy must consume the route registry")
require(policy.contains("principal_bound: bool = False"), "Authorization decisions must identify principal-bound routes")
require(policy.contains("ownerPrincipalMismatch"), "Owner mismatch policy is missing")
require(policy.contains("systemPrincipalRequired"), "System-only policy is missing")
require(policy.contains("delegatedPolicyUnavailable"), "Unhandled delegated routes must fail closed")
require(
    middleware.contains("principal_bound or AUTH_OWNERSHIP_MODE == \"enforce\""),
    "Principal-bound denies must block even while global mode remains shadow"
)
require(runtime.contains("\"principalBoundRouteEnforcement\": True"), "Runtime must publish principal-bound enforcement")
require(runtime.contains("\"productionEnforceReady\": False"), "Global enforce must remain disabled")
require(runtime.contains("\"routeOwnershipAudit\""), "Runtime must publish a redacted route audit summary")

require(
    !repository.contains("DreamJourneyBackendClient.shared.dispatchDueTimeLetters"),
    "Public iOS mailbox refresh must not invoke system-only time-letter dispatch"
)
require(backendClient.contains("func dispatchDueTimeLetters("), "QA/system client contract should remain available")
require(
    releaseRegression.contains("RUN_BACKEND_ROUTE_OWNERSHIP_AUDIT_SMOKE"),
    "Release regression must expose the deployed ownership audit gate"
)

print("Route ownership audit checks passed")
