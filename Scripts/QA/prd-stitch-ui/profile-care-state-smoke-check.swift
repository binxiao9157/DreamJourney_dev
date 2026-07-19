import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: root.appendingPathComponent(relativePath).path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let profileView = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let dashboard = read("DreamJourney/Sources/Modules/Profile/ProfileElderCareDashboardViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertFileExists(
    "Scripts/QA/prd-stitch-ui/run-profile-care-state-smoke.sh",
    "profile care state UIQA smoke script"
)

let smokeScript = read("Scripts/QA/prd-stitch-ui/run-profile-care-state-smoke.sh")

for phrase in [
    "var actionTitle: String?",
    "var accessibilityIdentifier: String",
    "profileCareStateEmpty",
    "profileCareStateStale",
    "profileCareStateFailed",
    "重新同步",
] {
    assertContains(careModels, phrase, "care state model should expose stable state contract \(phrase)")
}

for phrase in [
    "runUIQAProfileCareStateSmoke",
    "setUIQACareSnapshot",
    "profileCareStateCard",
    "displaySnapshot.dataState.actionTitle",
    "displaySnapshot.dataState.accessibilityIdentifier",
    "profileCareRetryButton",
] {
    assertContains(profileView, phrase, "profile should expose care state UIQA hook \(phrase)")
}

for phrase in [
    "makeDataStateCard(_ state: ProfileCareDataState)",
    "card.accessibilityIdentifier = state.accessibilityIdentifier",
    "profileCareStateCard",
    "runUIQACareDashboardStateSmoke",
] {
    assertContains(dashboard, phrase, "care dashboard should expose state cards for UIQA \(phrase)")
}

for phrase in [
    "runProfileCareStateSmoke",
    "writeProfileCareStateSmokeResult",
    "profile-care-state-smoke-result.json",
    "ProfileCareSnapshot.emptyFallback()",
    "ProfileCareSnapshot.staleFallback()",
    "ProfileCareSnapshot.failedFallback()",
] {
    assertContains(appDelegate, phrase, "AppDelegate should wire care state smoke \(phrase)")
}

assertContains(
    featureFlags,
    "DJRunProfileCareStateSmoke",
    "QA scenario registry should expose the care state smoke launch argument"
)

assertContains(
    featureFlags,
    "static func selectRootProfileViewController() -> ProfileViewController?",
    "Profile UIQA runner should own Profile root lookup"
)
assertContains(
    appDelegate,
    "QAProfileScenarioRunner.selectRootProfileViewController()",
    "AppDelegate should delegate Profile root lookup to the shared runner"
)
assertContains(
    appDelegate,
    "QAProfileScenarioRunner.writeResult(",
    "AppDelegate should delegate Profile care state JSON persistence to the shared runner"
)

for phrase in [
    "DJRunProfileCareStateSmoke",
    "run-installable-simulator-uiqa.sh",
    "source \"$INSTALL_DIR/install.env\"",
    "profile-care-state-smoke-result.json",
    "profile-care-state-smoke",
    "profileCareStateEmpty",
    "profileCareStateStale",
    "profileCareStateFailed",
] {
    assertContains(smokeScript, phrase, "profile care state smoke script should include \(phrase)")
}

assertContains(
    releaseRegression,
    "profile-care-state-smoke-check.swift",
    "release regression should run profile care state smoke guard"
)
assertContains(
    releaseRegression,
    "RUN_PROFILE_CARE_STATE_SMOKE",
    "release regression should expose optional profile care state UIQA smoke"
)
assertContains(
    releasePackage,
    "Scripts/QA/prd-stitch-ui/profile-care-state-smoke-check.swift",
    "release QA package should include profile care state smoke guard"
)
assertContains(
    releasePackage,
    "Scripts/QA/prd-stitch-ui/run-profile-care-state-smoke.sh",
    "release QA package should include profile care state smoke script"
)

print("Profile care state smoke checks passed")
