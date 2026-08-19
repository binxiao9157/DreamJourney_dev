import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ url: URL) -> String {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func app(_ relativePath: String) -> String {
    read(root.appendingPathComponent(relativePath))
}

func backend(_ relativePath: String) -> String {
    read(backendRoot.appendingPathComponent(relativePath))
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let flags = app("DreamJourney/Sources/App/FeatureFlagService.swift")
let backendClient = app("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let familyModel = app("DreamJourney/Sources/Services/MemoryModel.swift")
let familyRepository = app("DreamJourney/Sources/Services/FamilyRepository.swift")
let familyView = app("DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift")
let profileView = app("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let accountLifecycleRegistry = app("DreamJourney/Sources/App/AccountLifecycleRuntimeRegistry.swift")
let ownerTruthTests = app("DreamJourneyTests/OwnerTruthContractsTests.swift")
let appDelegate = app("DreamJourney/Sources/AppDelegate.swift")
let ownerExportDeletionUIQA = app("Scripts/QA/product-v4/run-ios-owner-export-deletion-surface-uiqa-smoke.sh")
let timeLetterEntry = app("DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift")
let backendMain = backend("app/main.py")
let backendStore = backend("app/services/in_memory_store.py")
let backendPostgres = backend("app/services/postgres_store.py")
let backendTests = backend("tests/test_core_services.py")
let backendExternalEffectReconciler = backend("app/services/data_rights_external_effect_reconciler.py")
let releaseRegression = app("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

assertContains(flags, "private static let currentStorageVersion", "feature flag schema should keep a migration version without pinning a stale exact value")
assertContains(flags, ".accountDeletion", "account deletion should be default-enabled after PRD clarification")

for required in [
    "func inviteFamilyMember(",
    "path: \"/family/invite\"",
    "func terminateFamilyRelationship(",
    "func listFamilyRelationshipMemberships(",
    "FamilyRelationshipMembershipContract",
    "FamilyRelationshipTerminationReceiptContract",
    #"path: "/family/relationships/\(pathComponent(relationshipId))/terminate""#,
    "\"secondConfirmation\": true",
    "\"publicationGrantAction\": \"preserve\"",
    "func softDeleteAccount(",
    "path: \"/auth/delete\"",
    "func restoreAccount(",
    "path: \"/auth/restore\"",
    "func exportAccountData(",
    "path: \"/auth/data-export\"",
    "AccountDataExportContract",
    "AccountDataExportJobContract",
    "AccountDataExportPackageContract",
    "AccountDataRightsExternalDomainSnapshot",
    "externalCleanupSummaryMessage",
    "func createAccountDataExportJob(",
    "func readAccountDataExportJob(",
    "func retryAccountDataExportJob(",
    "func downloadAccountDataExportJob(",
    "path: \"/auth/data-export/jobs\"",
    "isAccountDeletionConfigured",
] {
    assertContains(backendClient, required, "iOS backend client should expose family/account lifecycle contract \(required)")
}

for required in [
    "var accessStatus: String",
    "var invitationStatus: String",
    "familyInvitationDisplayName",
    "isAcceptedFamilyMember",
    "invitationStatus: stringValue(in: object, for: \"invitationStatus\") ?? \"pending\"",
] {
    assertContains(familyModel, required, "FamilyMember should parse invite states \(required)")
}

for required in [
    "func inviteByPhone(",
    "DreamJourneyBackendClient.shared.inviteFamilyMember",
    "invitationStatus: \"failed\"",
    "func terminateRelationship(",
    "DreamJourneyBackendClient.shared.terminateFamilyRelationship",
    "DigitalHumanContextStore.shared.reconcileFamilyAuthorization()",
] {
    assertContains(familyRepository, required, "FamilyRepository should invite and terminate relationships safely \(required)")
}

for required in [
    "输入手机号邀请家人",
    "发送手机号邀请",
    "presentFamilyInviteSheet",
    "member.familyInvitationDisplayName",
    "option.lastUpdated",
    "解除家庭关系",
    "退出家庭",
    "不会删除任何账号",
    "已发布分享不会自动撤销",
    "familyRelationshipTerminateButton",
    "leaveFamilyButton.isHidden = activeMemberRelationships.isEmpty",
] {
    assertContains(familyView, required, "Family UI should expose invite and termination states \(required)")
}
assertNotContains(familyView, "复制邀请邮票", "Family UI should not keep old stamp-copy invite copy")
assertNotContains(familyView, "退出或解除关系暂未开放", "Family UI must not retain the old unavailable relationship copy")
assertNotContains(familyView, "家人创建后不可删除", "Family detail must explain relationship termination instead of account deletion")

for required in [
    "FamilyRelationshipTerminationCommand",
    "FamilyRelationshipTerminationService",
    "@app.post(\"/family/relationships/{relationship_id}/terminate\")",
    "publicationGrantAction",
] {
    assertContains(backendMain, required, "Backend should expose participant relationship termination \(required)")
}
for required in [
    "def terminate_family_relationship(",
    "preservedRequiresOwnerAction",
    "retainedWithProvenance",
    "family_contribution_disposal_queue",
] {
    let aggregate = backendStore + backendPostgres
    assertContains(aggregate, required, "Backend stores should atomically dispose family authority \(required)")
}

for required in [
    "showFinalAccountDeletionConfirmation",
    "submitAccountDeletion",
    "数据会保留 30 天",
    "恢复机会只有 1 次",
    "确认注销账户",
    "DreamJourneyBackendClient.shared.softDeleteAccount",
    "externalCleanupDomainStates",
    "isAccountDataExportVisible",
] {
    assertContains(profileView, required, "Profile should implement two-step account deletion UI \(required)")
}
assertNotContains(profileView, "提交注销申请（未开放）", "Account deletion should no longer be blocked shell")
assertContains(
    profileView,
    "private var isAccountDataExportVisible: Bool {\n        false\n    }",
    "Full-account export must have no client entry"
)
assertNotContains(profileView, "注销前可导出个人数据副本", "Deletion copy must not advertise full-account export")
assertNotContains(
    profileView,
    "if isFeatureRouteAllowed(.accountDeletion, risk: .ownerTextCore) {\n            rows.append(.dataExport)",
    "Data export must not reuse the account-deletion visibility gate"
)
assertContains(
    accountLifecycleRegistry,
    "AccountDataExportJobStatusStore.teardownForAccountLifecycle",
    "Account lifecycle must clear the owner-scoped export resume state"
)
for testName in [
    "testAccountDataExportJobStatusStoreIsOwnerScopedAndResumable",
    "testAccountDataExportJobStatusPresentationKeepsFailuresExplicit",
    "testAccountDataExportRemainsDefaultOffAndFailsClosedWithoutServerPolicy",
] {
    assertContains(ownerTruthTests, testName, "iOS tests should cover export resume state \(testName)")
}
for required in [
    "runProfileDataExportStatusSmoke",
    "DJProfileDataExportStatusSmoke",
    "profile-data-export-status-smoke-result.json",
] {
    assertContains(appDelegate, required, "Profile data-export UIQA harness should keep \(required)")
}
for required in [
    "DJEnableProfileHiddenBranches",
    "数据副本生成中",
    "03-profile-data-export-status.png",
] {
    assertContains(ownerExportDeletionUIQA, required, "Profile data-export UIQA should keep \(required)")
}

assertContains(
    timeLetterEntry,
    "FamilyRepository.shared.getAll().filter(\\.isAcceptedFamilyRelationship)",
    "Time-letter recipient selection should require an accepted relationship without inferring persona access"
)

for required in [
    "@app.post(\"/auth/delete\")",
    "@app.post(\"/auth/restore\")",
    "@app.post(\"/auth/purge-expired-deletions\")",
    "@app.post(\"/auth/data-export/jobs\"",
    "@app.get(\"/auth/data-export/jobs/{job_id}\")",
    "@app.post(\"/auth/data-export/jobs/{job_id}/retry\"",
    "@app.get(\"/auth/data-export/jobs/{job_id}/download\")",
    "ACCOUNT_DELETION_RETENTION_DAYS = 30",
    "ACCOUNT_RESTORE_LIMIT = 1",
    "family member removal is not supported",
] {
    assertContains(backendMain, required, "Backend should expose account deletion and block family removal \(required)")
}

for required in [
    "soft_delete_user",
    "restore_user",
    "purge_expired_deleted_users",
    "create_data_export_job",
    "complete_data_export_job",
    "retry_data_export_job",
    "expire_data_export_job",
    "\"dataExportSupported\"] = True",
    "\"dataExportState\"] = \"availableBeforeDeletionOnly\"",
    "\"restoreLimit\"] = 1",
] {
    assertContains(backendStore, required, "In-memory store should implement soft delete lifecycle \(required)")
    assertContains(backendPostgres, required, "Postgres store should implement soft delete lifecycle \(required)")
}

let backendDataRightsTests = backend("tests/test_data_rights_module_inventory.py")
for required in [
    "test_export_route_requires_active_owner_session_and_disables_response_caching",
    "/auth/data-export",
    "raw-device-token-should-not-export",
] {
    assertContains(backendDataRightsTests, required, "Backend data export tests should preserve the V4 privacy boundary \(required)")
}

let backendDataExportJobTests = backend("tests/test_data_export_jobs.py")
for required in [
    "test_job_is_owner_scoped_idempotent_and_downloads_partial_manifest",
    "test_failed_job_can_retry_without_changing_job_identity",
    "test_account_must_be_active_when_creating_job",
] {
    assertContains(backendDataExportJobTests, required, "Backend async export jobs should preserve lifecycle and owner boundaries \(required)")
}

for required in [
    "AccountDeletionAPITests",
    "test_account_delete_soft_deletes_and_login_restores_once_by_phone",
    "test_account_delete_requires_two_confirmations_and_restore_rejects_expired_window",
    "test_family_member_revoke_api_is_blocked_by_product_rule",
] {
    assertContains(backendTests, required, "Backend tests should cover new family/account rules \(required)")
}

for required in [
    "class DataRightsExternalEffectReconciler",
    "blockedAccessNotRevoked",
    "externalEffectManualReviewRequired",
    "record_manual_resolution",
] {
    assertContains(backendExternalEffectReconciler, required, "Backend should reconcile external deletion effects safely \(required)")
}

for required in [
    "externalCleanup",
    "verifiedComplete",
] {
    assertContains(backendMain, required, "Backend account deletion response should expose only redacted cleanup evidence \(required)")
}

for required in [
    "backend-family-account-lifecycle-smoke.py",
    "RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE",
    "RUN_BACKEND_DATA_RIGHTS_EXTERNAL_EFFECT_RECEIPTS_POSTGRES_SMOKE",
] {
    assertContains(releaseRegression, required, "Release regression should include optional family/account lifecycle gate \(required)")
}

print("Profile family/account lifecycle checks passed")
