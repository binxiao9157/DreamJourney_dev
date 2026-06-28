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
    let url = root.appendingPathComponent(relativePath)
    guard fileManager.fileExists(atPath: url.path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

assertFileExists(
    "Scripts/QA/prd-stitch-ui/run-release-like-backend-acceptance.sh",
    "release-like backend acceptance runner"
)
assertFileExists(
    "Scripts/QA/prd-stitch-ui/backend-postgres-persistence-check.py",
    "Postgres persistence contract check"
)
assertFileExists(
    "docs/superpowers/status/2026-06-18-release-like-backend-acceptance.md",
    "release-like backend acceptance status doc"
)

let runner = read("Scripts/QA/prd-stitch-ui/run-release-like-backend-acceptance.sh")
let persistence = read("Scripts/QA/prd-stitch-ui/backend-postgres-persistence-check.py")
let status = read("docs/superpowers/status/2026-06-18-release-like-backend-acceptance.md")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for phrase in [
    "BACKEND_BASE_URL",
    "BACKEND_API_TOKEN",
    "DreamJourneyBackend",
    "docker compose up -d --build",
    "store\") != \"postgres\"",
    "backend-postgres-persistence-check.py",
    "run-backend-env-smoke.sh",
    "RELEASE_LIKE_RESTART_COMMAND",
    "ios-backend-env-smoke",
    "BACKEND_API_TOKEN= ./scripts/verify_backend.sh",
    "IOS_USER_ID",
    "USER_ID=\"$IOS_USER_ID\"",
    "Persistence user ID",
    "iOS smoke user ID",
] {
    assertContains(runner, phrase, "runner should include \(phrase)")
}

for phrase in [
    "release-like backend must use Postgres",
    "/archive/items",
    "/profile",
    "/profile/{USER_ID}",
    "/auth/login",
    "/auth/password",
    "/devices/push-token",
    "/echo/delayed-replies",
    "/echo/delayed-replies/dispatch-due",
    "/kb/sync",
    "/family/invite",
    "/care/snapshots",
    "metadataOnly",
    "contentRedacted",
    "localPath",
    "personaScope",
    "digitalHumanId",
    "family_default",
    "nickname",
    "gender",
    "region",
    "avatarName",
    "PROFILE_NICKNAME = f\"RL Profile {MARKER[-12:]}\"",
    "PROFILE_REGION = f\"RL Region {MARKER[-12:]}\"",
    "PUSH_DEVICE_TOKEN",
    "PUSH_DEVICE_ID",
    "DELAYED_REPLY_ID",
    "push token response must not include raw token",
    "delayed reply list must not expose raw device token",
    "echoDelayedReplyState",
    "echoDelayedReplyDispatchState",
    "echoDelayedReplyPushProviderState",
    "echoDelayedReplyDeviceTokenId",
    "echoDelayedReplyProviderDeliveryAttempted",
    "readyForProvider",
    "providerDeliveryAttempted",
    "profileNickname",
    "profileRegion",
    "passwordConfigured",
    "passwordChangeStatus",
    "passwordOldLoginStatus",
    "passwordNewLoginConfigured",
    "old password should be rejected after password change",
    "new password should login after password change",
    "careActiveRiskLevel",
    "careMissingStatus",
    "careInvalidStatus",
    "careStaleWindowEnd",
    "missing_user",
    "invalid care snapshot should be rejected",
    "stale care snapshot should preserve stale window",
    "seed",
    "verify",
] {
    assertContains(persistence, phrase, "persistence check should include \(phrase)")
}

for phrase in [
    "Status: accepted",
    "Docker/Postgres runtime is not available on this machine",
    "deployed FastAPI/Postgres health check is reachable",
    "POST /archive/items",
    "POST /auth/login",
    "POST /auth/password",
    "POST /profile",
    "GET /profile/{user_id}",
    "POST /kb/sync",
    "HTTP 500",
    "rollback-on-exception",
    "aborted DB connection",
    "20260618-deployed-postgres-acceptance-after-deploy",
    "20260618-selected-backend-latest-contracts-after-deploy-r2",
    "20260618-deployed-push-device-token-contract-rerun-205018",
    "20260618-deployed-echo-dispatch-contract-accepted-211732",
    "20260618-deployed-echo-dispatch-contract-210536",
    "accepted for the latest selected deployed simulator release-like scope through push-token, delayed-reply scheduling, and delayed-reply dispatch-due",
    "release-like FastAPI/Postgres 后端验收：accepted",
    "线上/公网后端验收：accepted for simulator release-like scope",
    "run-release-like-backend-acceptance.sh",
    "backend-postgres-persistence-check.py",
    "passwordChangeStatus",
    "passwordOldLoginStatus",
    "passwordNewLoginConfigured",
    "archivePersonaScope=family",
    "archiveDigitalHumanId=family_default",
    "careActiveRiskLevel=watch",
    "echoDelayedReplyDeviceTokenId",
    "echoDelayedReplyPushProviderState=pending",
    "echoDelayedReplyDispatchState=readyForProvider",
    "echoDelayedReplyProviderDeliveryAttempted=false",
    "HTTP 405",
    "POST /echo/delayed-replies/dispatch-due",
    "token_hits=0",
    "accepted on deployed route parity by run `20260618-deployed-echo-dispatch-contract-accepted-211732`",
    "APNs provider delivery and true-device notification arrival remain separate external gates",
    "BACKEND_BASE_URL",
    "BACKEND_API_TOKEN",
    "真机验收：not accepted",
] {
    assertContains(status, phrase, "status doc should include \(phrase)")
}

assertContains(
    releasePackage,
    "docs/superpowers/status/2026-06-18-release-like-backend-acceptance.md",
    "release QA package should include release-like backend status doc"
)
assertContains(
    releasePackage,
    "Scripts/QA/prd-stitch-ui/run-release-like-backend-acceptance.sh",
    "release QA package should include release-like backend runner"
)
assertContains(
    releasePackage,
    "Scripts/QA/prd-stitch-ui/release-like-backend-acceptance-check.swift",
    "release QA package should include release-like backend guard"
)

print("Release-like backend acceptance checks passed")
