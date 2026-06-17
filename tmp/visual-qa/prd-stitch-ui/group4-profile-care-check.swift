import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
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

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let settings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let legal = read("DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .careDashboard,\n        .profileSettings,\n        .legalCenter,\n    ]", "profile release defaults should stay narrow")
assertNotContains(flags, ".familyManagement,\n        .legalCenter,\n        .accountDeletion", "unfinished profile flows must not be enabled by default")

assertContains(profile, "private static func profileScrollBottomInset(safeAreaBottomInset: CGFloat) -> CGFloat", "profile root should reserve bottom scroll space for floating tabbar")
assertContains(profile, "scrollView.contentInsetAdjustmentBehavior = .never", "profile root should not rely on inherited safe area timing")
assertContains(profile, "scrollView.contentInset.bottom = bottomInset", "profile root should apply explicit bottom content inset")
assertContains(profile, "scrollView.verticalScrollIndicatorInsets.bottom = bottomInset", "profile root should apply explicit bottom indicator inset")
assertContains(profile, "DJEnableProfileHiddenBranches", "profile hidden branches need explicit UIQA launch argument")
assertContains(profile, "private func makeSettingsRows() -> [ProfileRowAction]", "profile rows should be centralized")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.profileSettings)", "profile settings row should be gated")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.familyManagement)", "family management row should be gated")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.legalCenter)", "legal center row should be gated")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.accountDeletion)", "account deletion row should be gated")
assertContains(profile, "rows.append(.logout)", "logout should remain a stable public action")
assertContains(profile, "isCareDoctorContactVisible", "doctor contact should have an explicit visibility gate")
assertContains(profile, "if isCareDoctorContactVisible {", "doctor contact button should not be unconditional")
assertContains(profile, "careSnapshot = .offlineFallback()", "care dashboard should fall back safely when backend is unavailable")
assertContains(profile, "makeCareSyncCaption(snapshot:", "care dashboard should render sync state")
assertContains(profile, "case .profileSettings:\n            showProfileSettings()", "profile settings row should push a real page")
assertContains(profile, "case .legalCenter:\n            showLegalCenter()", "legal center row should push a real page")
assertContains(profile, "case .familyManagement:\n            openFamilyManagement()", "family row should remain routed through guarded family flow")
assertContains(profile, "case .accountDeletion:\n            showAccountDeletionConfirmation()", "account deletion should use a safe confirmation shell")
assertContains(profile, "deleteAction.isEnabled = false", "account deletion destructive action should remain disabled")

assertContains(settings, "final class ProfileSettingsViewController", "settings page view controller")
assertContains(settings, "hidesBottomBarWhenPushed = true", "settings page should hide floating tabbar when pushed")
assertContains(settings, "title = \"个人资料设置\"", "settings page title")
assertContains(settings, "昵称", "settings nickname row")
assertContains(settings, "头像", "settings avatar row")
assertContains(settings, "手机号", "settings phone row")
assertContains(settings, "UserManager.shared.updateProfile(nickname:", "settings should persist through UserManager")
assertNotContains(settings, "密码", "password change should stay hidden")

assertContains(legal, "final class ProfileLegalViewController", "legal page view controller")
assertContains(legal, "hidesBottomBarWhenPushed = true", "legal page should hide floating tabbar when pushed")
assertContains(legal, "title = \"法律法规\"", "legal page title")
assertContains(legal, "AI 辅助说明", "legal page AI assistance section")
assertContains(legal, "心理支持边界", "legal page mental health boundary section")
assertContains(legal, "隐私与数据", "legal page privacy section")
assertContains(legal, "数字人与伦理", "legal page ethics section")
assertContains(legal, "紧急情况", "legal page emergency section")
assertContains(legal, "不是医疗诊断", "legal page medical disclaimer")
assertContains(legal, "不展示聊天原文", "legal page care privacy promise")

assertContains(userManager, "func updateProfile(nickname: String)", "profile update should stay centralized in UserManager")
assertContains(userManager, "NotificationCenter.default.post(name: .djUserDidUpdate", "profile updates should notify visible screens")

assertContains(project, "ProfileSettingsViewController.swift in Sources", "settings page should be in target")
assertContains(project, "ProfileLegalViewController.swift in Sources", "legal page should be in target")
