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
let timeLetterEntry = app("DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift")
let backendMain = backend("app/main.py")
let backendStore = backend("app/services/in_memory_store.py")
let backendPostgres = backend("app/services/postgres_store.py")
let backendTests = backend("tests/test_core_services.py")
let releaseRegression = app("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

for required in [
    "private static let currentStorageVersion = 7",
    ".accountDeletion",
] {
    assertContains(flags, required, "account deletion should be default-enabled after PRD clarification \(required)")
}

for required in [
    "func inviteFamilyMember(",
    "path: \"/family/invite\"",
    "func softDeleteAccount(",
    "path: \"/auth/delete\"",
    "func restoreAccount(",
    "path: \"/auth/restore\"",
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
    "PRD: 家庭成员通过手机号邀请后不可删除",
] {
    assertContains(familyRepository, required, "FamilyRepository should invite by phone and avoid deletion \(required)")
}

for required in [
    "输入手机号邀请家人",
    "发送手机号邀请",
    "presentFamilyInviteSheet",
    "member.familyInvitationDisplayName",
    "option.lastUpdated",
    "家人加入后不可删除",
] {
    assertContains(familyView, required, "Family UI should expose phone invite states \(required)")
}
assertNotContains(familyView, "复制邀请邮票", "Family UI should not keep old stamp-copy invite copy")

for required in [
    "showFinalAccountDeletionConfirmation",
    "submitAccountDeletion",
    "不支持数据导出",
    "数据会保留 30 天",
    "恢复机会只有 1 次",
    "确认注销账户",
    "DreamJourneyBackendClient.shared.softDeleteAccount",
] {
    assertContains(profileView, required, "Profile should implement two-step account deletion UI \(required)")
}
assertNotContains(profileView, "提交注销申请（未开放）", "Account deletion should no longer be blocked shell")

assertContains(
    timeLetterEntry,
    "FamilyRepository.shared.getAll().filter(\\.isAcceptedFamilyMember)",
    "Time-letter recipients should only include accepted family members"
)

for required in [
    "@app.post(\"/auth/delete\")",
    "@app.post(\"/auth/restore\")",
    "@app.post(\"/auth/purge-expired-deletions\")",
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
    "\"dataExportSupported\"] = False",
    "\"restoreLimit\"] = 1",
] {
    assertContains(backendStore, required, "In-memory store should implement soft delete lifecycle \(required)")
    assertContains(backendPostgres, required, "Postgres store should implement soft delete lifecycle \(required)")
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
    "backend-family-account-lifecycle-smoke.py",
    "RUN_BACKEND_FAMILY_ACCOUNT_LIFECYCLE_SMOKE",
] {
    assertContains(releaseRegression, required, "Release regression should include optional family/account lifecycle gate \(required)")
}

print("Profile family/account lifecycle checks passed")
