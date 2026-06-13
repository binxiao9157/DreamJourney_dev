import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FamilyMemberAccessState verification failed: \(message)\n", stderr)
        exit(1)
    }
}

let legacyLocalMember = FamilyMember(
    id: "local_member",
    name: "陈岚",
    relation: "女儿",
    phone: "13900001111"
)
require(legacyLocalMember.isCareDashboardAccessible, "legacy local members should remain accessible")
require(legacyLocalMember.isSelectableForFamilyVisibility, "legacy local members should remain selectable")

let pendingMember = FamilyMember(
    id: "pending_member",
    name: "陈海",
    relation: "儿子",
    phone: "13900002222",
    accessStatus: .pending,
    invitationStatus: .pending
)
require(!pendingMember.isCareDashboardAccessible, "pending invitations should not open care dashboard")
require(!pendingMember.isSelectableForFamilyVisibility, "pending invitations should not be selectable")

let acceptedMember = FamilyMember(
    id: "accepted_member",
    name: "陈一",
    relation: "女儿",
    phone: "13900003333",
    accessStatus: .active,
    invitationStatus: .accepted
)
require(acceptedMember.isCareDashboardAccessible, "active accepted members should open care dashboard")
require(acceptedMember.isSelectableForFamilyVisibility, "active accepted members should be selectable")

let revokedMember = FamilyMember(
    id: "revoked_member",
    name: "陈远",
    relation: "亲友",
    phone: "13900004444",
    accessStatus: .revoked,
    invitationStatus: .revoked
)
require(!revokedMember.isCareDashboardAccessible, "revoked members should not open care dashboard")
require(!revokedMember.isSelectableForFamilyVisibility, "revoked members should not be selectable")
require(revokedMember.isAccessRevoked, "revoked members should expose revoked state")

print("FamilyMemberAccessState verification passed")
