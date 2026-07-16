import Foundation

@main
enum ReleasePolicyCacheDeployedSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("usage: release-policy-cache-deployed-smoke <payload.json> <app-build>")
        }

        let payload = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let appBuild = CommandLine.arguments[2]
        guard let json = try JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            fatalError("deployed release policy must be a JSON object")
        }

        let schemaVersion = requireInt(json["schemaVersion"], "schemaVersion")
        let policyVersion = requireString(json["policyVersion"], "policyVersion")
        let policyRevision = requireInt(json["policyRevision"], "policyRevision")
        let emergencyRevision = requireInt(json["emergencyRevision"], "emergencyRevision")
        let expiresAt = requireDate(json["expiresAt"], "expiresAt")
        require(requireString(json["source"], "source") == "server", "deployed policy source must be server")
        require(json["shadowMode"] as? Bool == true, "WI-S0-06-02 expects the deployed policy to remain shadow-only")
        require(expiresAt > Date(), "deployed policy must have a future expiry")

        let suiteName = "dj.release-policy-deployed-smoke.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("failed to create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReleasePolicyStore(userDefaults: defaults)
        let fetchedAt = Date()
        let scope = ReleasePolicyCacheScope(accountUserId: "deployed-smoke-owner", appBuild: appBuild)
        try store.save(
            payload: payload,
            policySchemaVersion: schemaVersion,
            policyVersion: policyVersion,
            policyRevision: policyRevision,
            emergencyRevision: emergencyRevision,
            scope: scope,
            fetchedAt: fetchedAt,
            expiresAt: expiresAt
        )

        let fresh = store.evaluate(
            scope: scope,
            risk: .providerEffect,
            now: fetchedAt,
            minimumEmergencyRevision: emergencyRevision
        )
        require(fresh.state == .fresh, "deployed payload should produce a fresh scoped cache")
        require(fresh.accessMode == .useCachedPolicy, "fresh deployed payload should be usable in shadow mode")
        require(fresh.payload == payload, "cache should preserve the deployed payload")

        let switched = ReleasePolicyCacheScope(accountUserId: "other-owner", appBuild: appBuild)
        require(
            store.evaluate(scope: switched, risk: .providerEffect, now: fetchedAt).state == .missing,
            "a switched account must not reuse deployed policy cache"
        )
        let upgraded = ReleasePolicyCacheScope(accountUserId: "deployed-smoke-owner", appBuild: "\(appBuild)-next")
        require(
            store.evaluate(scope: upgraded, risk: .providerEffect, now: fetchedAt).state == .missing,
            "an upgraded build must not reuse deployed policy cache"
        )

        print(
            "Release policy deployed cache smoke passed: "
                + "policyVersion=\(policyVersion) revision=\(policyRevision) emergencyRevision=\(emergencyRevision)"
        )
    }

    private static func requireString(_ value: Any?, _ name: String) -> String {
        guard let value = value as? String, !value.isEmpty else {
            fatalError("missing \(name)")
        }
        return value
    }

    private static func requireInt(_ value: Any?, _ name: String) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String, let parsed = Int(value) { return parsed }
        fatalError("missing \(name)")
    }

    private static func requireDate(_ value: Any?, _ name: String) -> Date {
        let raw = requireString(value, name)
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
            return parsed
        }
        fatalError("invalid \(name)")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
