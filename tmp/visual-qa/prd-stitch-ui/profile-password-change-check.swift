import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
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
let readiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let profileSettings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let passwordVC = read("DreamJourney/Sources/Modules/Profile/ProfilePasswordChangeViewController.swift")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseMatrixCheck = read("tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let coverageMatrix = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")

assertContains(flags, "case accountPasswordChange", "Feature flag should declare hidden password change gate")
assertNotContains(flags, ".accountPasswordChange,", "Password change must stay out of default release flags")

assertContains(readiness, "passwordChangeCapability", "Profile readiness should document password change capability")
assertContains(readiness, "title: \"修改密码\"", "Password change capability should use product copy")
assertContains(readiness, "feature: .accountPasswordChange", "Password change capability should bind to feature flag")
assertContains(readiness, "static func isPasswordChangeVisible", "Readiness should expose password change visibility gate")
assertContains(readiness, "isHiddenBranchesEnabled || isPasswordChangeEnabled", "Password change should only show behind explicit gates")

assertContains(profileSettings, "private let featureFlags: FeatureFlagService", "Profile settings should accept feature flags")
assertContains(profileSettings, "isProfileHiddenBranchesEnabled", "Settings should support QA hidden branch launch argument")
assertContains(profileSettings, "ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument", "Settings should use shared profile hidden launch argument")
assertContains(profileSettings, "private var isPasswordChangeVisible", "Settings should centralize password visibility")
assertContains(profileSettings, "featureFlags.isEnabled(.accountPasswordChange)", "Settings should gate password change by feature flag")
assertContains(profileSettings, "profile-settings-password-change-row", "Password row should have stable QA identifier")
assertContains(profileSettings, "button.isAccessibilityElement = true", "Password row should be tappable through accessibility")
assertContains(profileSettings, "button.accessibilityTraits = .button", "Password row should expose button trait")
assertContains(profileSettings, "ProfilePasswordChangeViewController()", "Password route should push shell view controller")

assertContains(passwordVC, "final class ProfilePasswordChangeViewController", "Password change page should exist")
assertContains(passwordVC, "当前密码", "Password page should ask for current password")
assertContains(passwordVC, "新密码", "Password page should ask for new password")
assertContains(passwordVC, "确认新密码", "Password page should ask for confirmation")
assertContains(passwordVC, "当前密码不能为空。", "Password page should validate current password")
assertContains(passwordVC, "新密码至少 8 位。", "Password page should validate new password length")
assertContains(passwordVC, "确认新密码必须一致。", "Password page should validate confirmation")
assertContains(passwordVC, "当前环境暂不支持修改密码", "Password page should not pretend success without backend")
assertContains(passwordVC, "DreamJourneyBackendClient.shared.isPasswordChangeConfigured", "Password page should check backend configuration")
assertContains(passwordVC, "DreamJourneyBackendClient.shared.changePassword", "Password page should call backend-ready contract")
assertContains(passwordVC, "profile-password-current-field", "Current password field should be stable for QA")
assertContains(passwordVC, "profile-password-new-field", "New password field should be stable for QA")
assertContains(passwordVC, "profile-password-confirm-field", "Confirm password field should be stable for QA")
assertContains(passwordVC, "profile-password-save-button", "Password save action should be stable for QA")
assertContains(passwordVC, "profile-password-status", "Password status should be stable for QA")

assertContains(client, "var isPasswordChangeConfigured", "Backend client should expose password-change config state")
assertContains(client, "func changePassword", "Backend client should expose password change contract")
assertContains(client, "path: \"/auth/password\"", "Password change should use explicit backend endpoint")
assertContains(client, "\"oldPassword\": oldPassword", "Password change payload should include old password")
assertContains(client, "\"newPassword\": newPassword", "Password change payload should include new password")

assertContains(project, "ProfilePasswordChangeViewController.swift in Sources", "Password change page should be in app target")
assertContains(project, "ProfilePasswordChangeViewController.swift", "Password change page should have project file reference")

assertContains(releasePackage, "tmp/visual-qa/prd-stitch-ui/profile-password-change-check.swift", "release QA package should include password change guard")
assertContains(releaseRegression, "profile-password-change-check.swift", "release regression should run password change guard")
assertContains(releaseMatrixCheck, "\"accountPasswordChange\"", "release guard should keep password change hidden by default")
assertContains(releaseMatrixCheck, "isPasswordChangeVisible", "release guard should enforce hidden password gate")
assertNotContains(releaseMatrixCheck, "assertNotContains(settings, \"密码\"", "release guard should not rely on raw source absence after hidden shell exists")

assertContains(releaseMatrix, "修改密码", "release matrix should document password change state")
assertContains(releaseMatrix, "| account password change | `DJFeature.accountPasswordChange` or `DJEnableProfileHiddenBranches` | no | backend `/auth/password` implementation, auth/security review, true-device acceptance | `profile-password-change-check.swift`, release regression |", "release matrix should document hidden password change candidate")
assertContains(coverageMatrix, "password change hidden shell", "PRD coverage should record current password change state")

print("Profile password change checks passed")
