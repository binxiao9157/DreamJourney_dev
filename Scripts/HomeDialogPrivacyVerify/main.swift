import Foundation

func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let selectedMemberVisibility = FamilyMemberVisibility.selectedMembers(["fm_daughter", "fm_daughter", " "])

let familyMetadata = HomeDialogPrivacyMetadataFactory.make(
    scope: .familyCircle,
    familyVisibility: selectedMemberVisibility,
    createdAt: Date(timeIntervalSince1970: 1_717_171_717)
)
assertCondition(familyMetadata.scope == .familyCircle, "family scope should be preserved")
assertCondition(familyMetadata.familyVisibility.includesAllMembers == false, "family selected members should not become all-family")
assertCondition(familyMetadata.familyVisibility.allowedMemberIDs == ["fm_daughter"], "family selected members should be cleaned and preserved")
assertCondition(familyMetadata.sourceRefs.first?.id == "home-dialog-familyCircle", "family source ref should be stable")

let generationMetadata = HomeDialogPrivacyMetadataFactory.make(
    scope: .generationAllowed,
    familyVisibility: selectedMemberVisibility
)
assertCondition(generationMetadata.scope == .generationAllowed, "generation scope should be preserved")
assertCondition(generationMetadata.familyVisibility == .allMembers, "non-family scope must not retain stale selected family members")

let localMetadata = HomeDialogPrivacyMetadataFactory.make(
    scope: .localOnly,
    familyVisibility: selectedMemberVisibility
)
assertCondition(localMetadata.scope == .localOnly, "local scope should be preserved")
assertCondition(localMetadata.familyVisibility == .allMembers, "local scope must not retain stale selected family members")

print("HomeDialogPrivacy verification passed")
