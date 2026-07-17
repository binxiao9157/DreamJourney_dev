import Foundation

@main
enum FamilyRelationshipAuthorizationPolicyModelSmoke {
    static func main() {
        let production = FamilyRelationshipAuthorizationContext(currentOwnerUserId: "owner-A")
        require(
            acceptedRelationship(
                relationshipId: "relationship-A",
                owner: "owner-A",
                status: .accepted,
                source: .backendInvitation,
                access: "active",
                invitation: "accepted",
                context: production
            ),
            "current-owner accepted backend relationship must be visible"
        )

        let denied: [(String, String, FamilyRelationshipStatus, FamilyRelationshipAuthoritySource)] = [
            ("", "owner-A", .accepted, .backendInvitation),
            ("relationship-A", "", .accepted, .backendInvitation),
            ("relationship-A", "owner-B", .accepted, .backendInvitation),
            ("relationship-A", "owner-A", .pending, .backendInvitation),
            ("relationship-A", "owner-A", .paused, .backendInvitation),
            ("relationship-A", "owner-A", .revoked, .backendInvitation),
            ("relationship-A", "owner-A", .accepted, .knowledgeCandidate),
            ("relationship-A", "owner-A", .accepted, .localInvitationAttempt),
            ("relationship-A", "owner-A", .accepted, .legacyUnverified),
            ("relationship-A", "owner-A", .accepted, .qaFixture),
        ]
        for value in denied {
            require(
                !acceptedRelationship(
                    relationshipId: value.0,
                    owner: value.1,
                    status: value.2,
                    source: value.3,
                    access: "active",
                    invitation: "accepted",
                    context: production
                ),
                "production policy must reject relationship authority mismatch"
            )
        }

        let qa = FamilyRelationshipAuthorizationContext(currentOwnerUserId: "owner-A", allowQAFixtures: true)
        require(
            acceptedRelationship(
                relationshipId: "",
                owner: "owner-A",
                status: .pending,
                source: .qaFixture,
                access: "active",
                invitation: "accepted",
                context: qa
            ),
            "explicit QA context may expose an accepted fixture relationship"
        )
        require(
            !acceptedRelationship(
                relationshipId: "relationship-A",
                owner: "owner-A",
                status: .accepted,
                source: .knowledgeCandidate,
                access: "active",
                invitation: "accepted",
                context: qa
            ),
            "knowledge candidates must remain non-authoritative even in QA"
        )

        print("Family relationship authorization policy model smoke passed")
    }

    private static func acceptedRelationship(
        relationshipId: String,
        owner: String,
        status: FamilyRelationshipStatus,
        source: FamilyRelationshipAuthoritySource,
        access: String,
        invitation: String,
        context: FamilyRelationshipAuthorizationContext
    ) -> Bool {
        FamilyRelationshipAuthorizationPolicy.isAcceptedRelationship(
            relationshipId: relationshipId,
            relationshipOwnerUserId: owner,
            relationshipStatus: status,
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
