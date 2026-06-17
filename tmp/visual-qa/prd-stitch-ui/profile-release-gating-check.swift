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

assertContains(flags, "case profileSettings", "profile settings must be independently gateable")
assertContains(flags, "case careDoctorContact", "doctor contact must be independently gateable")
assertContains(flags, "private static let defaultEnabled: Set<DJFeature> = [\n        .careDashboard,\n        .profileSettings,\n        .legalCenter,\n    ]", "care dashboard, profile settings, and legal center should be visible by default")
assertNotContains(flags, ".familyManagement,\n        .legalCenter,\n        .accountDeletion", "placeholder profile flows must not be enabled by default")

assertContains(profile, "DJEnableProfileHiddenBranches", "QA-only profile hidden branch launch argument")
assertContains(profile, "isProfileHiddenBranchesEnabled", "profile rows must use a unified hidden branch gate")
assertContains(profile, "isCareDoctorContactVisible", "doctor contact button must use an explicit visibility gate")
assertContains(profile, "private func makeSettingsRows() -> [ProfileRowAction]", "profile settings rows should be centralized")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.profileSettings)", "profile settings row must be gated")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.familyManagement)", "family management row must be gated")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.legalCenter)", "legal center row must be gated")
assertContains(profile, "if isProfileHiddenBranchesEnabled || featureFlags.isEnabled(.accountDeletion)", "account deletion row must be gated")
assertContains(profile, "if isCareDoctorContactVisible {", "doctor contact button must not be added unconditionally")
assertContains(profile, "rows.append(.logout)", "logout should remain the stable public settings action")
assertNotContains(profile, "var rows: [ProfileRowAction] = [.profileSettings]", "profile settings must not be always visible")
assertNotContains(profile, "UIStackView(arrangedSubviews: [avatar, nameLabel, UIView(), callButton])", "doctor contact button must not be always visible")
