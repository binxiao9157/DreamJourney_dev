import Foundation

enum FamilyAccessIdentityResolver {
    struct UserRecord: Equatable {
        let id: String
        let phone: String?
    }

    struct MemberRecord: Equatable {
        let id: String
        let phone: String?
    }

    struct ViewerIdentity: Equatable {
        let familyMemberID: String
        let source: Source
    }

    enum Source: String, Equatable {
        case localOverride
        case currentUserPhone
    }

    static func resolveViewer(
        currentUser: UserRecord?,
        members: [MemberRecord],
        overrideFamilyMemberID: String? = nil
    ) -> ViewerIdentity? {
        if let overrideFamilyMemberID = normalized(overrideFamilyMemberID),
           members.contains(where: { $0.id == overrideFamilyMemberID }) {
            return ViewerIdentity(familyMemberID: overrideFamilyMemberID, source: .localOverride)
        }

        guard let userPhone = normalized(currentUser?.phone) else {
            return nil
        }

        guard let member = members.first(where: { normalized($0.phone) == userPhone }) else {
            return nil
        }

        return ViewerIdentity(familyMemberID: member.id, source: .currentUserPhone)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
