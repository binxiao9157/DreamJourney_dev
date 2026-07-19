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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): found \(needle)")
    }
}

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appCoordinator = read("DreamJourney/Sources/App/AppCoordinator.swift")
let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let profileView = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertFileExists(
    "Scripts/QA/prd-stitch-ui/backend-care-state-uiqa-fixtures.py",
    "backend care state UIQA fixture seeder"
)
assertFileExists(
    "Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh",
    "profile care backend state UIQA smoke script"
)
assertFileExists(
    "docs/superpowers/status/2026-06-19-profile-care-backend-state-smoke.md",
    "profile care backend state status doc"
)

let fixtureSeeder = read("Scripts/QA/prd-stitch-ui/backend-care-state-uiqa-fixtures.py")
let smokeScript = read("Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh")
let statusDoc = read("docs/superpowers/status/2026-06-19-profile-care-backend-state-smoke.md")

for phrase in [
    "runProfileCareBackendStateSmoke",
    "runProfileCareBackendFailureRetrySmoke",
    "writeProfileCareBackendStateSmokeResult",
    "writeProfileCareBackendFailureRetrySmokeResult",
    "profile-care-backend-state-smoke-result.json",
    "profile-care-backend-failure-retry-smoke-result.json",
    "DJCareCaseName=",
    "DJCareStateUserId=",
    "DJCareSessionUserId=",
    "DJCareFailureRetryUserId=",
    "QAAuthenticatedBackendSessionFixture.prepare",
    "careSessionUserMismatch",
] {
    assertContains(appDelegate, phrase, "AppDelegate should wire deployed backend care state smoke \(phrase)")
}

for phrase in [
    "DJRunProfileCareBackendStateSmoke",
    "DJRunProfileCareBackendFailureRetrySmoke",
    "requiresAuthenticatedBackendFixture",
    "QAAuthenticatedBackendSessionFixture",
    "uiqa-profile-care-auth-session.json",
    "Authenticated backend fixture prepared",
] {
    assertContains(featureFlags, phrase, "QA scenario registry should expose deployed backend care state smoke \(phrase)")
}

assertContains(
    appDelegate,
    "activateUIQAAuthenticatedBackendProfileSession",
    "AppDelegate should route authenticated care fixtures through the root coordinator"
)
assertContains(
    appCoordinator,
    "activateVerifiedLoginForUIQA",
    "AppCoordinator should expose a QA-only verified login bridge"
)
assertContains(
    appCoordinator,
    "verifiedLoginTransitionCancelled",
    "QA bridge should expose a deterministic coordinator activation result"
)
assertContains(
    appCoordinator,
    "requiresAuthenticatedBackendFixture",
    "AppCoordinator should defer cold-start validation for authenticated QA fixture scenarios"
)
assertContains(
    appDelegate,
    "uiqaCoordinatorActivationRejected",
    "AppDelegate should persist coordinator activation failures instead of relying on timing"
)

for phrase in [
    "QAProfileScenarioRunner.selectRootProfileViewController()",
    "QAProfileScenarioRunner.writeResult(",
] {
    assertContains(appDelegate, phrase, "AppDelegate should use shared Profile UIQA runner \(phrase)")
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
    "runUIQAProfileCareBackendFailureRetrySmoke",
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
    "retryFailureInitialState",
    "retryFailureFinalState",
    "retryFailureFinalRetryVisible",
] {
    assertContains(profileView, phrase, "ProfileViewController should render deployed backend care state fixture \(phrase)")
}

assertContains(
    backendClient,
    "path: \"/care/snapshots/latest/\\(pathComponent(userId))\"",
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
    "AuthSessionService",
    "PostgresStore",
    "stable_user_id",
    "ON CONFLICT (id) DO NOTHING",
    "qaFixtureMarker",
    "fixture collision changed existing user",
    "cleanup fixture marker mismatch",
    "cleanup fixture user still present",
    "cleanupVerification",
    "clean",
    "seed-failure-retry",
    "failureRetryOnly",
    "sessionFixtureSchemaVersion",
    "careDashboardNotApprovedForClosedPilot",
    "/v2/release-policy",
] {
    assertContains(fixtureSeeder, phrase, "fixture seeder should cover deployed backend care state \(phrase)")
}

for phrase in [
    "resolve_deployed_backend_config",
    "backend-care-state-uiqa-fixtures.py",
    "DJRunProfileCareBackendStateSmoke",
    "profile-care-backend-state-smoke-result.json",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "BACKEND_REMOTE_HOST",
    "docker compose exec",
    "sudo chown",
    "REMOTE_CONTAINER_PREFIX",
    "Mark cleanup as pending before the fixture command",
    "finalize_remote_fixture_cleanup",
    "backend-care-auth-cleanup-result.json",
    "cleanup contract mismatch",
    "DJCareCaseName=",
    "DJCareStateUserId=",
    "DJCareSessionUserId=",
    "uiqa-profile-care-auth-session.json",
    "DJEnableProfileHiddenBranches",
    "backend-private.xcconfig",
    "backend-unreachable.xcconfig",
    "RUN_PROFILE_CARE_FAILURE_RETRY_ONLY",
    "run_failure_retry_case",
    "run-installable-simulator-uiqa.sh",
    "source \"$INSTALL_DIR/install.env\"",
    "source \"$FAILURE_INSTALL_DIR/install.env\"",
    "LOCAL_BUNDLE_ID=\"$LOCAL_QA_BUNDLE_ID\"",
    "LOCAL_DEVELOPMENT_TEAM=\"$LOCAL_QA_TEAM_ID\"",
    "XCCONFIG_PATH=\"$PRIVATE_XCCONFIG\"",
    "XCCONFIG_PATH=\"$UNREACHABLE_PRIVATE_XCCONFIG\"",
    "profileCareStateAvailable",
    "profileCareStateEmpty",
    "profileCareStateStale",
    "profileCareStateFailed",
    "retryActionFired",
    "retryIntermediateState",
    "retryIntermediateSyncCaption",
    "retryInitialState",
    "retryFinalState",
    "DJRunProfileCareBackendFailureRetrySmoke",
    "profile-care-backend-failure-retry-smoke-result.json",
] {
    assertContains(smokeScript, phrase, "profile care backend state smoke script should include \(phrase)")
}
assertNotContains(
    smokeScript,
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "profile care smoke must not inject the server compatibility token into iOS"
)
assertNotContains(
    smokeScript,
    "BACKEND_API_TOKEN",
    "profile care smoke must not use a machine credential for user-owned care routes"
)
assertNotContains(
    fixtureSeeder,
    "BACKEND_API_TOKEN",
    "fixture seeder must issue isolated user sessions instead of accepting a machine credential"
)

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
    "Scripts/QA/prd-stitch-ui/profile-care-backend-state-smoke-check.swift",
    "release QA package should include backend care state guard"
)
assertContains(
    releasePackage,
    "Scripts/QA/prd-stitch-ui/run-profile-care-backend-state-smoke.sh",
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
    "失败态重试失败",
    "profile-care-backend-state-smoke-result.json",
    "profile-care-backend-failure-retry-smoke-result.json",
] {
    assertContains(statusDoc, phrase, "status doc should describe backend care state smoke \(phrase)")
}

print("Profile care backend state smoke checks passed")
