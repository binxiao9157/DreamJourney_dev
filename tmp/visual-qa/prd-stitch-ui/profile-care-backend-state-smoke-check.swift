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

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let profileView = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertFileExists(
    "tmp/visual-qa/prd-stitch-ui/backend-care-state-uiqa-fixtures.py",
    "backend care state UIQA fixture seeder"
)
assertFileExists(
    "tmp/visual-qa/prd-stitch-ui/run-profile-care-backend-state-smoke.sh",
    "profile care backend state UIQA smoke script"
)
assertFileExists(
    "docs/superpowers/status/2026-06-19-profile-care-backend-state-smoke.md",
    "profile care backend state status doc"
)

let fixtureSeeder = read("tmp/visual-qa/prd-stitch-ui/backend-care-state-uiqa-fixtures.py")
let smokeScript = read("tmp/visual-qa/prd-stitch-ui/run-profile-care-backend-state-smoke.sh")
let statusDoc = read("docs/superpowers/status/2026-06-19-profile-care-backend-state-smoke.md")

for phrase in [
    "DJRunProfileCareBackendStateSmoke",
    "runProfileCareBackendStateSmoke",
    "writeProfileCareBackendStateSmokeResult",
    "profile-care-backend-state-smoke-result.json",
    "DJCareActiveUserId=",
    "DJCareEmptyUserId=",
    "DJCareStaleUserId=",
] {
    assertContains(appDelegate, phrase, "AppDelegate should wire deployed backend care state smoke \(phrase)")
}

for phrase in [
    "static func retryingPlaceholder()",
    "正在重新同步关怀信号",
] {
    assertContains(careModels, phrase, "ProfileCareModels should expose retrying placeholder \(phrase)")
}

for phrase in [
    "ProfileCareBackendStateSmokeCase",
    "runUIQAProfileCareBackendStateSmoke",
    "runUIQAProfileCareBackendRetrySmoke",
    "isCareSnapshotRetrying",
    "DreamJourneyBackendClient.shared.latestCareSnapshot",
    "careSnapshotFallback(for: error)",
    "expectedState",
    "profileState",
    "backendErrorFallback",
    "profileCareRetryButton",
    "sendActions(for: .touchUpInside)",
    "retryActionFired",
    "retryIntermediateState",
    "retryIntermediateSyncCaption",
    "retryInitialState",
    "retryFinalState",
] {
    assertContains(profileView, phrase, "ProfileViewController should render deployed backend care state fixture \(phrase)")
}

assertContains(
    backendClient,
    "requestJSON(path: \"/care/snapshots/latest/\\(pathComponent(userId))\"",
    "backend client should keep latest care snapshot endpoint"
)

for phrase in [
    "/health",
    "/care/snapshots",
    "/care/snapshots/latest/",
    "activeUserId",
    "staleUserId",
    "missingUserId",
    "careActiveRiskLevel",
    "careStaleWindowEnd",
    "careMissingStatus",
] {
    assertContains(fixtureSeeder, phrase, "fixture seeder should cover deployed backend care state \(phrase)")
}

for phrase in [
    "resolve_deployed_backend_config",
    "backend-care-state-uiqa-fixtures.py",
    "DJRunProfileCareBackendStateSmoke",
    "profile-care-backend-state-smoke-result.json",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "backend-private.xcconfig",
    "profileCareStateAvailable",
    "profileCareStateEmpty",
    "profileCareStateStale",
    "retryActionFired",
    "retryIntermediateState",
    "retryIntermediateSyncCaption",
    "retryInitialState",
    "retryFinalState",
] {
    assertContains(smokeScript, phrase, "profile care backend state smoke script should include \(phrase)")
}

assertContains(
    releaseRegression,
    "RUN_PROFILE_CARE_BACKEND_STATE_SMOKE",
    "release regression should expose optional deployed backend care state UIQA smoke"
)
assertContains(
    releaseRegression,
    "profile-care-backend-state-smoke-check.swift",
    "release regression should run backend care state UIQA guard"
)
assertContains(
    releasePackage,
    "tmp/visual-qa/prd-stitch-ui/profile-care-backend-state-smoke-check.swift",
    "release QA package should include backend care state guard"
)
assertContains(
    releasePackage,
    "tmp/visual-qa/prd-stitch-ui/run-profile-care-backend-state-smoke.sh",
    "release QA package should include backend care state smoke"
)
assertContains(
    releasePackage,
    "docs/superpowers/status/2026-06-19-profile-care-backend-state-smoke.md",
    "release QA package should include backend care state doc"
)

for phrase in [
    "真实后端",
    "active / empty / stale",
    "failed",
    "重新同步",
    "正在重新同步关怀信号",
    "profile-care-backend-state-smoke-result.json",
] {
    assertContains(statusDoc, phrase, "status doc should describe backend care state smoke \(phrase)")
}

print("Profile care backend state smoke checks passed")
