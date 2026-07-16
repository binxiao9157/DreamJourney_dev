import Foundation

@main
enum ReleasePolicyCacheModelSmoke {
    static func main() throws {
        let suiteName = "dj.release-policy-cache-smoke.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("failed to create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReleasePolicyStore(userDefaults: defaults)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let accountA = ReleasePolicyCacheScope(accountUserId: "account-a", appBuild: "100")
        let accountB = ReleasePolicyCacheScope(accountUserId: "account-b", appBuild: "100")
        let upgradedA = ReleasePolicyCacheScope(accountUserId: "account-a", appBuild: "101")
        let anonymous = ReleasePolicyCacheScope(accountUserId: nil, appBuild: "100")
        let unknownBuild = ReleasePolicyCacheScope(accountUserId: "account-a", appBuild: "0")
        let payload = Data(#"{"schemaVersion":1,"policyVersion":"closed-pilot-v1"}"#.utf8)

        require(!accountA.accountOrAnonymousScope.contains("account-a"), "raw account IDs must not enter cache scope")
        require(accountA != accountB, "accounts must have isolated cache scopes")
        require(accountA != upgradedA, "app upgrades must have isolated cache scopes")
        require(anonymous.accountOrAnonymousScope == "anonymous", "signed-out cache must use anonymous scope")
        require(
            store.evaluate(scope: unknownBuild, risk: .futureBeta, now: now).state == .invalidScope,
            "a missing app build must fail closed instead of sharing a cache"
        )

        try store.save(
            payload: payload,
            policySchemaVersion: 1,
            policyVersion: "closed-pilot-v1",
            policyRevision: 7,
            emergencyRevision: 3,
            scope: accountA,
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(600)
        )

        let fresh = store.evaluate(
            scope: accountA,
            risk: .providerEffect,
            now: now.addingTimeInterval(30),
            minimumEmergencyRevision: 3
        )
        require(fresh.state == .fresh, "matching fresh cache must be usable")
        require(fresh.accessMode == .useCachedPolicy, "fresh cache must use the cached policy")
        require(fresh.payload == payload, "fresh cache must return the original payload")

        require(
            store.evaluate(scope: accountB, risk: .futureBeta, now: now).state == .missing,
            "account switch must not reuse another account cache"
        )
        require(
            store.evaluate(scope: upgradedA, risk: .futureBeta, now: now).state == .missing,
            "app upgrade must not reuse an old-build cache"
        )
        require(
            store.evaluate(scope: anonymous, risk: .futureBeta, now: now).state == .missing,
            "anonymous scope must not reuse an account cache"
        )

        let expiredProvider = store.evaluate(
            scope: accountA,
            risk: .providerEffect,
            now: now.addingTimeInterval(601)
        )
        require(expiredProvider.state == .expired, "expired cache must be identified")
        require(expiredProvider.accessMode == .deny, "expired provider effects must deny")

        let expiredOwnerText = store.evaluate(
            scope: accountA,
            risk: .ownerTextCore,
            now: now.addingTimeInterval(601)
        )
        require(expiredOwnerText.accessMode == .readOnly, "owner text core may fall back to read-only")

        let clockSkew = store.evaluate(
            scope: accountA,
            risk: .futureBeta,
            now: now.addingTimeInterval(-301)
        )
        require(clockSkew.state == .clockSkew, "future fetchedAt beyond tolerance must fail closed")
        require(clockSkew.accessMode == .deny, "clock skew must deny future/beta features")

        let staleEmergency = store.evaluate(
            scope: accountA,
            risk: .providerEffect,
            now: now.addingTimeInterval(30),
            minimumEmergencyRevision: 4
        )
        require(staleEmergency.state == .emergencyRevisionStale, "emergency revision must invalidate cache")

        defaults.set(Data("corrupt".utf8), forKey: store.storageKey(for: accountA))
        let corrupt = store.evaluate(scope: accountA, risk: .futureBeta, now: now)
        require(corrupt.state == .corrupt, "undecodable cache must fail closed")
        require(corrupt.accessMode == .deny, "corrupt future/beta cache must deny")

        try store.save(
            payload: payload,
            policySchemaVersion: 99,
            policyVersion: "future-schema",
            policyRevision: 8,
            emergencyRevision: 3,
            scope: accountA,
            fetchedAt: now,
            expiresAt: now.addingTimeInterval(600)
        )
        let unsupported = store.evaluate(scope: accountA, risk: .futureBeta, now: now)
        require(unsupported.state == .unsupportedSchema, "unknown policy schema must fail closed")

        store.remove(scope: accountA)
        require(store.evaluate(scope: accountA, risk: .futureBeta, now: now).state == .missing, "remove must clear only the requested scope")

        print("Release policy cache model smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
