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
let readiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

assertContains(flags, ".profileSettings", "profile settings should remain a public MVP feature")
assertContains(profile, "case .profileSettings:\n            showProfileSettings()", "profile settings route should remain public")
assertContains(profile, "ProfileSettingsViewController()", "profile settings page should still be reachable from profile")

assertContains(settings, "private enum ProfileSaveState", "settings should render explicit save states")
assertContains(settings, "case idle", "save state should include idle")
assertContains(settings, "case saving", "save state should include saving")
assertContains(settings, "case saved", "save state should include saved")
assertContains(settings, "case failed(String)", "save state should include generic failure")
assertContains(settings, "case networkUnavailable", "save state should include network fallback")
assertContains(settings, "case invalid(String)", "save state should include validation failure")

for copy in [
    "保存中...",
    "已保存",
    "保存失败",
    "网络异常，已先保存到本机",
    "名称不能为空",
    "名称不能超过24个字",
] {
    assertContains(settings, copy, "profile settings save-state copy should exist")
}

assertContains(settings, "private let statusLabel = UILabel()", "settings should use inline save status instead of only modal alerts")
assertContains(settings, "renderSaveState", "settings should centralize save-state rendering")
assertContains(settings, "validateProfile", "settings should validate account profile before saving")
assertContains(settings, "maxNameLength = 24", "settings should cap name length")
assertContains(settings, "UserManager.shared.saveProfile", "settings should use the backend-ready profile save API")
assertNotContains(settings, "UIAlertController(title: \"已保存\"", "save success should not rely on a blocking alert")

assertContains(settings, "头像上传暂未开放", "avatar strategy should be an explicit placeholder")
assertContains(settings, "暂不开放相册选择", "avatar copy should avoid exposing photo-library selection")
assertContains(settings, "showAvatarPlaceholder", "avatar edit entry should only show a placeholder")
assertNotContains(settings, "UIImagePickerController", "profile settings must not open image picker")
assertNotContains(settings, "PHPickerViewController", "profile settings must not open photo picker")
assertContains(readiness, "isPasswordChangeVisible", "password change visibility should be centralized")
assertContains(settings, "isPasswordChangeVisible", "password shell should stay behind a visibility gate")
assertContains(settings, "featureFlags.isEnabled(.accountPasswordChange)", "password shell should stay behind a feature flag")
assertContains(settings, "ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument", "password shell should stay behind explicit QA launch argument")

assertContains(userManager, "enum UserProfileSaveResult", "UserManager should expose profile save result contract")
assertContains(userManager, "case saved", "UserManager save result should include saved")
assertContains(userManager, "case savedWithRemoteWarning", "UserManager save result should include local fallback warning")
assertContains(userManager, "case failed", "UserManager save result should include failure")
assertContains(userManager, "func saveProfile(nickname: String", "UserManager should own nickname persistence and backend fallback")
assertContains(userManager, "DreamJourneyBackendClient.shared.upsertUser", "UserManager should use existing backend auth/user upsert when available")

assertContains(backendClient, "func upsertUser(phone: String, nickname: String", "backend client should expose existing /auth/login user upsert")
assertContains(backendClient, "path: \"/auth/login\"", "profile sync should reuse existing backend endpoint")
assertContains(backendClient, "var isProfileSyncConfigured", "backend client should expose whether remote profile sync should run")

assertContains(releasePackage, "tmp/visual-qa/prd-stitch-ui/profile-settings-save-state-check.swift", "release QA package should include profile save-state guard")
assertContains(releaseRegression, "profile-settings-save-state-check.swift", "release regression should run profile save-state guard")

print("Profile settings save-state checks passed")
