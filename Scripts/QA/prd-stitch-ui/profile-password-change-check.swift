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

let readiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let profileSettings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let passwordVC = read("DreamJourney/Sources/Modules/Profile/ProfilePasswordChangeViewController.swift")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseMatrixCheck = read("Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift")

assertContains(readiness, "passwordChangeCapability", "Profile readiness should document password change capability")
assertContains(readiness, "title: \"密码与安全\"", "Password management capability should use product copy")
assertContains(readiness, "static func isPasswordChangeVisible", "Readiness should expose password change visibility gate")
assertContains(readiness, "passwordAuthentication.canManagePassword", "Password change visibility must be controlled by runtime readiness")

assertContains(profileSettings, "private var isPasswordChangeVisible", "Settings should centralize password visibility")
assertContains(profileSettings, "loadPasswordAuthenticationCapability", "Settings should fetch server runtime readiness")
assertContains(profileSettings, "passwordCapability", "Settings should retain the typed runtime capability")
assertContains(profileSettings, "profile-settings-password-change-row", "Password row should have stable QA identifier")
assertContains(profileSettings, "button.isAccessibilityElement = true", "Password row should be tappable through accessibility")
assertContains(profileSettings, "button.accessibilityTraits = .button", "Password row should expose button trait")
assertContains(profileSettings, "ProfilePasswordChangeViewController(capability:", "Password route should pass the verified runtime capability")

assertContains(passwordVC, "final class ProfilePasswordChangeViewController", "Password change page should exist")
assertContains(passwordVC, "当前密码", "Password page should ask for current password")
assertContains(passwordVC, "新密码", "Password page should ask for new password")
assertContains(passwordVC, "确认新密码", "Password page should ask for confirmation")
assertContains(passwordVC, "设置密码", "Password page should support first-time password setup")
assertContains(passwordVC, "sensitiveOperation", "Password setup should require OTP reauthentication")
assertContains(passwordVC, "BackendPasswordActionTokenContract", "Password setup should retain only a typed reauthentication token")
assertContains(passwordVC, "当前密码不能为空。", "Password page should validate current password")
assertContains(passwordVC, "新密码需为 \\(capability.minimumPasswordLength) 至 \\(capability.maximumPasswordLength) 位。", "Password page should validate the runtime password length range")
assertContains(passwordVC, "确认新密码必须一致。", "Password page should validate confirmation")
assertContains(passwordVC, "capability.canManagePassword", "Password page should not pretend success without runtime readiness")
assertContains(passwordVC, "capability.canSetupPassword", "Password setup mode must require setup and reauthentication readiness")
assertContains(passwordVC, "capability.canChangePassword", "Password change mode must require login/change readiness")
assertContains(passwordVC, "modeControl.isHidden = !(capability.canChangePassword && capability.canSetupPassword)", "Unavailable setup/change modes must not remain as page-only entries")
assertContains(passwordVC, "DreamJourneyBackendClient.shared.changePassword", "Password page should call backend-ready contract")
assertContains(passwordVC, "DreamJourneyBackendClient.shared.setupPassword", "Password page should call typed setup contract")
assertContains(passwordVC, "profile-password-current-field", "Current password field should be stable for QA")
assertContains(passwordVC, "profile-password-new-field", "New password field should be stable for QA")
assertContains(passwordVC, "profile-password-confirm-field", "Confirm password field should be stable for QA")
assertContains(passwordVC, "profile-password-save-button", "Password save action should be stable for QA")
assertContains(passwordVC, "profile-password-status", "Password status should be stable for QA")
assertContains(passwordVC, "case locked", "Password page should render account lockout")
assertContains(passwordVC, "case reauthenticating", "Password setup should render reauthentication")

assertContains(client, "let passwordAuthentication: BackendPasswordAuthenticationCapability", "Runtime config should expose typed password readiness")
assertContains(client, "func setupPassword", "Backend client should expose password setup contract")
assertContains(client, "path: \"/v2/auth/password/setup\"", "Password setup should use the PC-A0 endpoint")
assertContains(client, "func changePassword", "Backend client should expose password change contract")
assertContains(client, "path: \"/v2/auth/password/change\"", "Password change should use the PC-A0 endpoint")
assertContains(client, "\"currentPassword\": currentPassword", "Password change payload should include current password")
assertContains(client, "\"newPassword\": newPassword", "Password change payload should include new password")

assertContains(project, "ProfilePasswordChangeViewController.swift in Sources", "Password change page should be in app target")
assertContains(project, "ProfilePasswordChangeViewController.swift", "Password change page should have project file reference")

assertContains(releasePackage, "Scripts/QA/prd-stitch-ui/profile-password-change-check.swift", "release QA package should include password change guard")
assertContains(releaseRegression, "profile-password-change-check.swift", "release regression should run password change guard")
assertContains(releaseMatrixCheck, "isPasswordChangeVisible", "release guard should retain an explicit password readiness boundary")
assertContains(releaseMatrixCheck, "isPasswordChangeVisible", "release guard should enforce hidden password gate")
assertNotContains(releaseMatrixCheck, "assertNotContains(settings, \"密码\"", "release guard should not rely on raw source absence after hidden shell exists")

print("Profile password change checks passed")
