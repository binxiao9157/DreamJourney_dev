import Foundation

@main
enum FamilyContextReconciliationModelSmoke {
    static func main() {
        require(
            !FamilyContextReconciliationPolicy.shouldFallbackToSelf(
                viewerUserId: "viewer",
                contextOwnerId: "viewer",
                isSelfAssistant: true,
                hasAuthorizedFamilyMember: false
            ),
            "self context must remain active"
        )
        require(
            !FamilyContextReconciliationPolicy.shouldFallbackToSelf(
                viewerUserId: "viewer",
                contextOwnerId: "family-A",
                isSelfAssistant: false,
                hasAuthorizedFamilyMember: true
            ),
            "an accepted family context must not reset"
        )
        require(
            FamilyContextReconciliationPolicy.shouldFallbackToSelf(
                viewerUserId: "viewer",
                contextOwnerId: "family-A",
                isSelfAssistant: false,
                hasAuthorizedFamilyMember: false
            ),
            "a revoked family context must fall back to self"
        )
        require(
            !FamilyContextReconciliationPolicy.shouldFallbackToSelf(
                viewerUserId: "",
                contextOwnerId: "family-A",
                isSelfAssistant: false,
                hasAuthorizedFamilyMember: false
            ),
            "signed-out state must not persist a fabricated self context"
        )
        print("Family context reconciliation model smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Family context reconciliation model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
