import Foundation

func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let invite = FamilyAccessControlService.Invitation(
    id: "invite_001",
    familyMemberID: "fm_daughter",
    phone: " 18800000001 ",
    status: .pending,
    createdAt: Date(timeIntervalSince1970: 1_717_171_717)
)

let accepted = FamilyAccessControlService.acceptInvitation(
    invite,
    phone: "18800000001",
    acceptedAt: Date(timeIntervalSince1970: 1_717_172_000)
)
assertCondition(accepted?.status == .accepted, "matching phone should accept invitation")
assertCondition(accepted?.acceptedAt != nil, "accepted invitation should record acceptedAt")

let rejected = FamilyAccessControlService.acceptInvitation(invite, phone: "19900000001")
assertCondition(rejected == nil, "mismatched phone should not accept invitation")

let revokedInvite = FamilyAccessControlService.Invitation(
    id: "invite_002",
    familyMemberID: "fm_son",
    phone: "18800000002",
    status: .revoked,
    createdAt: Date()
)
assertCondition(
    FamilyAccessControlService.acceptInvitation(revokedInvite, phone: "18800000002") == nil,
    "revoked invitation should not be accepted"
)

let allFamily = MemoryPrivacyMetadata(scope: .familyCircle, familyVisibility: .allMembers)
let allAfterRevoke = FamilyAccessControlService.revokeMemberAccess(
    from: allFamily,
    revokedMemberID: "fm_son",
    allFamilyMemberIDs: ["fm_daughter", "fm_son", "fm_granddaughter"]
)
assertCondition(allAfterRevoke.scope == .familyCircle, "revocation should preserve family scope")
assertCondition(allAfterRevoke.familyVisibility.includesAllMembers == false, "all-family revoke should become explicit selected members")
assertCondition(
    allAfterRevoke.familyVisibility.allowedMemberIDs == ["fm_daughter", "fm_granddaughter"],
    "all-family revoke should exclude only revoked member"
)

let selected = MemoryPrivacyMetadata(
    scope: .familyCircle,
    familyVisibility: .selectedMembers(["fm_daughter", "fm_son"])
)
let selectedAfterRevoke = FamilyAccessControlService.revokeMemberAccess(
    from: selected,
    revokedMemberID: "fm_son",
    allFamilyMemberIDs: ["fm_daughter", "fm_son", "fm_granddaughter"]
)
assertCondition(
    selectedAfterRevoke.familyVisibility.allowedMemberIDs == ["fm_daughter"],
    "selected-member revoke should remove revoked member"
)

let generation = MemoryPrivacyMetadata(scope: .generationAllowed)
let unchangedGeneration = FamilyAccessControlService.revokeMemberAccess(
    from: generation,
    revokedMemberID: "fm_son",
    allFamilyMemberIDs: ["fm_daughter", "fm_son"]
)
assertCondition(unchangedGeneration == generation, "non-family metadata should not be changed by family revocation")

print("FamilyAccessControl verification passed")
