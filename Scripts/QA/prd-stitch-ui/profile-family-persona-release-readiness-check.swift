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

let readiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let script = read("Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh")
let status = read("docs/superpowers/status/2026-06-18-profile-family-persona-switcher.md")
let project = read("DreamJourney.xcodeproj/project.pbxproj")

assertContains(readiness, "enum ProfileFamilyPersonaReleaseReadiness", "family/persona release readiness contract must exist")
assertContains(readiness, "static let hiddenBranchesLaunchArgument = \"DJEnableProfileHiddenBranches\"", "family/persona contract must name hidden QA launch argument")
assertContains(readiness, "static func isFamilyManagementRowVisible", "contract must own family management row visibility")
assertContains(readiness, "static func canOpenFamilyPersonaSwitcher", "contract must own hidden persona route visibility")
assertContains(readiness, "feature: .familyManagement", "family management row must stay behind familyManagement")
assertContains(readiness, "feature: .familySpace", "family persona switcher must stay behind familySpace")
assertContains(readiness, "家人管理暂未开放", "contract must retain safe unavailable copy")

assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument", "profile hidden branch arg should use shared family/persona contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.isFamilyManagementRowVisible", "profile row gate should use family/persona contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher", "profile route gate should use family/persona contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.unavailableTitle", "profile unavailable alert should use contract copy")

assertContains(featureFlags, "DJRunProfileFamilyPersonaReleaseSmoke", "QA scenario registry should retain the family/persona release smoke launch argument")
assertContains(appDelegate, "case .profileFamilyPersonaReleaseSmoke", "AppDelegate should dispatch family/persona release smoke through the scenario registry")
assertContains(appDelegate, "runProfileFamilyPersonaReleaseSmoke()", "family/persona release smoke runner")
assertContains(appDelegate, "writeProfileFamilyPersonaReleaseSmokeResult", "family/persona smoke should write pollable JSON")
assertContains(appDelegate, "profile-family-persona-release-smoke-result.json", "family/persona smoke result file")
assertContains(appDelegate, "[UI_QA] ProfileFamilyPersonaReleaseSmoke completed", "family/persona smoke completion log")
assertContains(appDelegate, "ProfileFamilyPersonaReleaseReadiness.isFamilyManagementRowVisible", "smoke must verify shared row contract")
assertContains(appDelegate, "ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher", "smoke must verify shared route contract")
assertContains(appDelegate, "selectProfileTabForFamilyPersonaSmoke", "smoke should navigate to profile tab before screenshot evidence")
assertContains(appDelegate, "tabBarController.selectedIndex = 2", "smoke should select the profile tab for visual evidence")
assertContains(appDelegate, "\"profileTabSelected\": profileTabSelected", "smoke result should record profile tab evidence")

assertContains(script, "DJRunProfileFamilyPersonaReleaseSmoke", "script should launch family/persona release smoke")
assertContains(script, "SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR'", "script must build UIQA variant")
assertContains(script, "profile-family-persona-release-smoke-result.json", "script must poll result JSON")
assertContains(script, "\"releaseRowVisible\"[[:space:]]*:[[:space:]]*false", "script must validate default release row hidden")
assertContains(script, "\"familyManagementOnlyCanOpenSwitcher\"[[:space:]]*:[[:space:]]*false", "script must validate familyManagement alone cannot open switcher")
assertContains(script, "\"hiddenBranchesCanOpenSwitcher\"[[:space:]]*:[[:space:]]*true", "script must validate hidden QA can open switcher")
assertContains(script, "\"profileTabSelected\"[[:space:]]*:[[:space:]]*true", "script must validate profile tab visual evidence")
assertContains(script, "\"familyMemberCount\"", "script must validate family repository data")
assertContains(script, "simctl io", "script should save simulator screenshot evidence")

assertContains(status, "run-profile-family-persona-release-smoke.sh", "status doc must document the family/persona release smoke")
assertContains(project, "ProfileFamilyPersonaReleaseReadiness.swift in Sources", "readiness contract must be added to Xcode target")
