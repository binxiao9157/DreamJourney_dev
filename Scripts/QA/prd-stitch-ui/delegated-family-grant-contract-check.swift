import Foundation

enum DigitalHumanMode: String, Codable, Equatable {
    case sunlight
    case star
    case silent

    var displayName: String {
        switch self {
        case .sunlight: return "阳光"
        case .star: return "星辰"
        case .silent: return "静默"
        }
    }
}

protocol FamilyInvitationMessageSource {
    var familyMemberId: String { get }
    var familyMemberName: String { get }
    var familyMemberRelation: String { get }
    var familyMemberPhone: String? { get }
    var familyInvitationStatus: String { get }
    var familyAccessStatus: String { get }
    var familyInvitationError: String? { get }
    var familyLastUpdated: String { get }
    var isAcceptedFamilyMember: Bool { get }
}

@main
enum DelegatedFamilyGrantContractCheck {
    private static let ownerUserId = "owner-A"
    private static let memberId = "member-A"
    private static let memberSubjectId = "subject-member-A"
    private static let relationshipId = "relationship-A"
    private static let now = Date(timeIntervalSince1970: 2_000_000_000)

    static func main() throws {
        let activeGrant = makeGrant()
        require(
            activeGrant.isValid(
                at: now,
                purpose: "family.persona",
                operation: "read",
                resourceType: "familyMember",
                resourceId: memberId
            ),
            "active matching grant must be valid"
        )

        let relationshipOnly = makeMember(accessGrants: [])
        require(
            relationshipOnly.isAcceptedFamilyRelationship(for: ownerUserId),
            "accepted relationship should remain visible without a grant"
        )
        require(
            !relationshipOnly.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "relationship without grant must not authorize family capability"
        )

        let authorized = makeMember(accessGrants: [activeGrant])
        require(
            authorized.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "active family.persona/read/familyMember/member-id grant must authorize"
        )

        let expired = makeMember(accessGrants: [
            makeGrant(expiresAt: now.addingTimeInterval(-1)),
        ])
        require(
            !expired.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "expired grant must be denied"
        )

        let revoked = makeMember(accessGrants: [
            makeGrant(status: .revoked, revokedAt: now.addingTimeInterval(-10)),
        ])
        require(
            !revoked.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "revoked grant must be denied"
        )

        let purposeMismatch = makeMember(accessGrants: [
            makeGrant(purpose: "care.signal"),
        ])
        require(
            !purposeMismatch.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "purpose mismatch must be denied"
        )

        let subjectMismatch = makeMember(accessGrants: [
            makeGrant(granteeSubjectId: "subject-reused-phone"),
        ])
        require(
            !subjectMismatch.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "grant for a different verified subject must be denied"
        )

        let grantorMismatch = makeMember(accessGrants: [
            makeGrant(grantorSubjectId: "different-owner"),
        ])
        require(
            !grantorMismatch.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "grant from a different owner must be denied"
        )

        let oldPayload = try JSONDecoder().decode(FamilyMember.self, from: Data("""
        {
          "id": "legacy-member",
          "name": "旧家人",
          "relation": "家人",
          "relationshipOwnerUserId": "owner-A",
          "relationshipAuthoritySource": "backendInvitation",
          "accessStatus": "active",
          "invitationStatus": "accepted"
        }
        """.utf8))
        require(
            !oldPayload.isAcceptedFamilyRelationship(for: ownerUserId),
            "old payload without relationship contract must be denied"
        )
        require(
            !oldPayload.isAcceptedFamilyMember(for: ownerUserId, now: now),
            "old payload must not infer a grant from accepted invitation"
        )

        let backendParsed = FamilyMember.fromBackendJSON([
            "id": memberId,
            "name": "后端家人",
            "relation": "家人",
            "ownerUserId": ownerUserId,
            "relationshipId": relationshipId,
            "relationshipStatus": "accepted",
            "memberSubjectId": memberSubjectId,
            "relationshipEpoch": 4,
            "grantEpoch": 8,
            "accessGrants": [[
                "id": "grant-A",
                "relationshipId": relationshipId,
                "grantorSubjectId": ownerUserId,
                "granteeSubjectId": memberSubjectId,
                "purpose": "family.persona",
                "resourceType": "familyMember",
                "resourceId": memberId,
                "operations": ["read"],
                "status": "active",
                "expiresAt": "2099-01-01T00:00:00Z",
                "rowVersion": 3,
            ]],
        ])
        require(backendParsed?.relationshipEpoch == 4, "backend relationship epoch must parse")
        require(backendParsed?.grantEpoch == 8, "backend grant epoch must parse")
        require(backendParsed?.accessGrants.first?.rowVersion == 3, "backend grant row version must parse")

        try checkConsumerSources()
        print("Delegated family grant contract checks passed")
    }

    private static func makeMember(accessGrants: [FamilyAccessGrant]) -> FamilyMember {
        FamilyMember(
            id: memberId,
            name: "家人",
            relation: "家人",
            relationshipOwnerUserId: ownerUserId,
            relationshipAuthoritySource: .backendInvitation,
            relationshipId: relationshipId,
            memberSubjectId: memberSubjectId,
            relationshipStatus: .accepted,
            relationshipEpoch: 2,
            accessGrants: accessGrants,
            grantEpoch: 3,
            accessStatus: "active",
            invitationStatus: "accepted"
        )
    }

    private static func makeGrant(
        purpose: String = "family.persona",
        status: FamilyAccessGrantStatus = .active,
        expiresAt: Date? = nil,
        revokedAt: Date? = nil,
        grantorSubjectId: String = ownerUserId,
        granteeSubjectId: String = memberSubjectId
    ) -> FamilyAccessGrant {
        FamilyAccessGrant(
            id: "grant-A",
            relationshipId: relationshipId,
            grantorSubjectId: grantorSubjectId,
            granteeSubjectId: granteeSubjectId,
            purpose: purpose,
            resourceType: "familyMember",
            resourceId: memberId,
            operations: ["read"],
            status: status,
            expiresAt: expiresAt,
            revokedAt: revokedAt,
            rowVersion: 3
        )
    }

    private static func checkConsumerSources() throws {
        let root = URL(
            fileURLWithPath: CommandLine.arguments.dropFirst().first
                ?? FileManager.default.currentDirectoryPath
        )
        let repository = try read(root, "DreamJourney/Sources/Services/FamilyRepository.swift")
        let familyUI = try read(root, "DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift")
        let timeLetter = try read(root, "DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift")

        for required in [
            "member.relationshipEpoch",
            "member.grantEpoch",
            "activeFamilyPersonaReadGrants(at: now)",
        ] {
            require(repository.contains(required), "authorization key must include \(required)")
        }
        require(
            !repository.contains("FamilyAccessGrant("),
            "FamilyRepository must never create a local grant"
        )
        require(
            familyUI.contains("member.isAcceptedFamilyRelationship ? member.lastUpdated"),
            "family relationship display must not depend on persona grant"
        )
        require(
            familyUI.contains("member.familyPersonaAuthorizationDisplayName"),
            "family capability action must show grant boundary"
        )
        require(
            timeLetter.contains("filter(\\.isAcceptedFamilyRelationship)"),
            "time-letter recipients must use accepted relationship rather than persona grant"
        )
    }

    private static func read(_ root: URL, _ relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Delegated family grant contract check failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
