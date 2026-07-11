import Foundation

@main
enum FamilyRelationshipAuthorizationPolicyModelSmoke {
    static func main() {
        let production = FamilyRelationshipAuthorizationContext(currentOwnerUserId: "owner-A")
        require(
            authorized(owner: "owner-A", source: .backendInvitation, access: "active", invitation: "accepted", context: production),
            "current-owner accepted backend invitation must be authorized"
        )

        let denied: [(String, FamilyRelationshipAuthoritySource, String, String)] = [
            ("", .backendInvitation, "active", "accepted"),
            ("owner-B", .backendInvitation, "active", "accepted"),
            ("owner-A", .backendInvitation, "pending", "accepted"),
            ("owner-A", .backendInvitation, "active", "pending"),
            ("owner-A", .backendInvitation, "failed", "failed"),
            ("owner-A", .backendInvitation, "revoked", "revoked"),
            ("owner-A", .knowledgeCandidate, "active", "accepted"),
            ("owner-A", .localInvitationAttempt, "active", "accepted"),
            ("owner-A", .legacyUnverified, "active", "accepted"),
            ("owner-A", .qaFixture, "active", "accepted"),
        ]
        for value in denied {
            require(
                !authorized(owner: value.0, source: value.1, access: value.2, invitation: value.3, context: production),
                "production policy must reject owner/source/status mismatch"
            )
        }

        let qa = FamilyRelationshipAuthorizationContext(currentOwnerUserId: "owner-A", allowQAFixtures: true)
        require(
            authorized(owner: "owner-A", source: .qaFixture, access: "active", invitation: "accepted", context: qa),
            "explicit QA context may authorize a QA fixture"
        )
        require(
            !authorized(owner: "owner-A", source: .knowledgeCandidate, access: "active", invitation: "accepted", context: qa),
            "knowledge candidates must remain unauthorized even in QA"
        )

        print("Family relationship authorization policy model smoke passed")
    }

    private static func authorized(
        owner: String,
        source: FamilyRelationshipAuthoritySource,
        access: String,
        invitation: String,
        context: FamilyRelationshipAuthorizationContext
    ) -> Bool {
        FamilyRelationshipAuthorizationPolicy.isAuthorized(
            relationshipOwnerUserId: owner,
            authoritySource: source,
            accessStatus: access,
            invitationStatus: invitation,
            context: context
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Family relationship authorization policy model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
