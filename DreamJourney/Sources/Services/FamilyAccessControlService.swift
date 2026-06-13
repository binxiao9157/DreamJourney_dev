import Foundation

enum FamilyAccessControlService {
    struct Invitation: Codable, Equatable, Hashable {
        let id: String
        let familyMemberID: String
        let phone: String
        let status: Status
        let createdAt: Date
        let acceptedAt: Date?

        init(
            id: String,
            familyMemberID: String,
            phone: String,
            status: Status = .pending,
            createdAt: Date = Date(),
            acceptedAt: Date? = nil
        ) {
            self.id = id
            self.familyMemberID = familyMemberID
            self.phone = phone
            self.status = status
            self.createdAt = createdAt
            self.acceptedAt = acceptedAt
        }
    }

    enum Status: String, Codable, Equatable, Hashable {
        case pending
        case accepted
        case revoked
    }

    static func acceptInvitation(
        _ invitation: Invitation,
        phone: String,
        acceptedAt: Date = Date()
    ) -> Invitation? {
        guard invitation.status == .pending else {
            return nil
        }
        guard normalizedPhone(invitation.phone) == normalizedPhone(phone) else {
            return nil
        }
        return Invitation(
            id: invitation.id,
            familyMemberID: invitation.familyMemberID,
            phone: normalizedPhone(invitation.phone) ?? invitation.phone,
            status: .accepted,
            createdAt: invitation.createdAt,
            acceptedAt: acceptedAt
        )
    }

    static func revokeMemberAccess(
        from metadata: MemoryPrivacyMetadata,
        revokedMemberID: String,
        allFamilyMemberIDs: [String]
    ) -> MemoryPrivacyMetadata {
        guard metadata.scope == .familyCircle,
              let revokedMemberID = normalizedID(revokedMemberID) else {
            return metadata
        }

        let nextVisibility: FamilyMemberVisibility
        if metadata.familyVisibility.includesAllMembers {
            let remainingIDs = cleanedIDs(allFamilyMemberIDs).filter { $0 != revokedMemberID }
            nextVisibility = .selectedMembers(remainingIDs)
        } else {
            guard metadata.familyVisibility.allowedMemberIDs.contains(revokedMemberID) else {
                return metadata
            }
            let remainingIDs = metadata.familyVisibility.allowedMemberIDs.filter { $0 != revokedMemberID }
            nextVisibility = .selectedMembers(remainingIDs)
        }

        return metadata.replacingFamilyVisibility(nextVisibility)
    }

    private static func normalizedPhone(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        return digits.isEmpty ? nil : digits
    }

    private static func normalizedID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func cleanedIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { rawID in
            guard let id = normalizedID(rawID), !seen.contains(id) else {
                return nil
            }
            seen.insert(id)
            return id
        }
    }
}

extension MemoryPrivacyMetadata {
    func replacingFamilyVisibility(_ familyVisibility: FamilyMemberVisibility) -> MemoryPrivacyMetadata {
        MemoryPrivacyMetadata(
            scope: scope,
            sourceRefs: sourceRefs,
            createdBySurface: createdBySurface,
            createdAt: createdAt,
            familyVisibility: familyVisibility
        )
    }
}
