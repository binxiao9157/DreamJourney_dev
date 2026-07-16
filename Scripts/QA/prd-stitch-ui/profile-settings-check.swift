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
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .echoTextInput,\n        .profileSettings,\n        .legalCenter,\n        .accountDeletion,\n    ]", "profile settings should remain in the V4 owner-core defaults")

assertContains(profile, "case .profileSettings:\n            showProfileSettings()", "profile settings should push a real page")
assertContains(profile, "private func showProfileSettings()", "profile should expose a settings route")
assertContains(profile, "ProfileSettingsViewController()", "profile should instantiate settings page")
assertNotContains(profile, "case .profileSettings:\n            showUnavailableAlert()", "profile settings must not be an unavailable placeholder")

assertContains(userManager, "func updateProfile(nickname: String)", "UserManager should own nickname persistence")
assertContains(userManager, "static let djUserDidUpdate", "profile updates should notify interested screens")

assertContains(settings, "final class ProfileSettingsViewController", "settings page view controller")
assertContains(settings, "title = \"个人资料设置\"", "settings page title")
assertContains(settings, "名称", "profile name field")
assertContains(settings, "头像", "avatar display")
assertContains(settings, "手机号", "phone display")
assertContains(settings, "保存", "save action")
assertContains(settings, "UserManager.shared.saveProfile(nickname:", "settings page should persist through UserManager")
assertContains(settings, "isPasswordChangeVisible", "password entry should remain behind an explicit release gate")
assertContains(settings, "featureFlags.isEnabled(.accountPasswordChange)", "password entry should consume its feature flag")

assertContains(project, "ProfileSettingsViewController.swift in Sources", "settings page added to app target")
assertContains(project, "ProfileSettingsViewController.swift", "settings page file reference")
