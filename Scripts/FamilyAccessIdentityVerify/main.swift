import Foundation

func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let members = [
    FamilyAccessIdentityResolver.MemberRecord(id: "fm_001", phone: nil),
    FamilyAccessIdentityResolver.MemberRecord(id: "fm_002", phone: "13800000002"),
    FamilyAccessIdentityResolver.MemberRecord(id: "fm_003", phone: " 13800000003 ")
]

let matched = FamilyAccessIdentityResolver.resolveViewer(
    currentUser: FamilyAccessIdentityResolver.UserRecord(id: "user_0002", phone: "13800000002"),
    members: members
)
assertCondition(matched?.familyMemberID == "fm_002", "phone match should resolve viewer member")
assertCondition(matched?.source == .currentUserPhone, "phone match should record source")

let trimmed = FamilyAccessIdentityResolver.resolveViewer(
    currentUser: FamilyAccessIdentityResolver.UserRecord(id: "user_0003", phone: "13800000003"),
    members: members
)
assertCondition(trimmed?.familyMemberID == "fm_003", "member phone should be normalized")

let override = FamilyAccessIdentityResolver.resolveViewer(
    currentUser: FamilyAccessIdentityResolver.UserRecord(id: "user_9999", phone: "13999999999"),
    members: members,
    overrideFamilyMemberID: "fm_001"
)
assertCondition(override?.familyMemberID == "fm_001", "valid override should win")
assertCondition(override?.source == .localOverride, "override should record source")

let invalidOverride = FamilyAccessIdentityResolver.resolveViewer(
    currentUser: FamilyAccessIdentityResolver.UserRecord(id: "user_0002", phone: "13800000002"),
    members: members,
    overrideFamilyMemberID: "missing"
)
assertCondition(invalidOverride?.familyMemberID == "fm_002", "invalid override should fall back to phone match")

let anonymous = FamilyAccessIdentityResolver.resolveViewer(
    currentUser: nil,
    members: members
)
assertCondition(anonymous == nil, "anonymous user should not resolve a family member")

print("FamilyAccessIdentity verification passed")
