import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError(message)
    }
}

func assertFileExists(_ relativePath: String, _ message: String) {
    let url = rootURL.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        fatalError(message)
    }
}

assertFileExists(
    "tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh",
    "Backend environment smoke script should exist"
)

let script = read("tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh")

assertContains(script, "BACKEND_BASE_URL", "script should accept backend base URL")
assertContains(script, "BACKEND_API_TOKEN", "script should accept backend API token")
assertContains(script, "backend-auth-token-contract-check.py", "script should verify backend token auth contract")
assertContains(script, "backend-integration-contract-check.py", "script should verify backend integration contract")
assertContains(script, "DREAMJOURNEY_BACKEND_BASE_URL=\"$BACKEND_BASE_URL\"", "script should inject backend base URL into iOS build")
assertContains(script, "DREAMJOURNEY_BACKEND_API_TOKEN=\"$BACKEND_API_TOKEN\"", "script should inject backend token into iOS build")
assertContains(script, "DJSeedEchoArchiveContext", "script should seed archive context for UIQA")
assertContains(script, "DJEnableArchiveRemoteFetch", "script should enable hidden remote fetch only inside UIQA")
assertContains(script, "DJRunBackendEnvSmoke", "script should launch the app-side backend smoke harness")
assertContains(script, "archiveRemoteSyncStatus", "script should wait for archive remote sync status")
assertContains(script, "profileCareSyncCaption", "script should verify profile care sync caption")
assertContains(script, "\"familyRefreshSucceeded\"", "script should verify app-side family refresh")
assertContains(script, "\"containsBackendFamilyMember\"", "script should verify seeded backend family member")
assertContains(script, "\"backendFamilyMemberCount\"", "script should verify backend family count")
assertContains(script, "app-archive-store-summary.json", "script should capture merged archive store summary")
assertContains(script, "backend-env-smoke-result.json", "script should write machine-readable result")
assertContains(script, "report.md", "script should write a human-readable report")
assertContains(script, "simctl uninstall", "script should isolate simulator app container")

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
assertContains(appDelegate, "DJRunBackendEnvSmoke", "app should expose an app-side backend smoke launch argument")
assertContains(appDelegate, "runBackendEnvSmoke()", "app should run backend archive/profile smoke from the UIQA harness")
assertContains(appDelegate, "writeBackendEnvSmokeResult", "app should write a pollable backend smoke result")
assertContains(appDelegate, "backend-env-smoke-result.json", "app should use a stable backend smoke result filename")
assertContains(appDelegate, "FamilyRepository.shared.refreshFromBackend(userId: userId)", "app should exercise family backend from the UIQA harness")
assertContains(appDelegate, "backendFamilyMemberCount", "app backend smoke result should include family count")
assertContains(appDelegate, "containsBackendFamilyMember", "app backend smoke result should include seeded family member")

let familyAcceptanceCheck = read("tmp/visual-qa/prd-stitch-ui/backend-family-acceptance-check.swift")
assertContains(familyAcceptanceCheck, "familyRefreshSucceeded", "backend family acceptance guard should verify family refresh")

let packageCheck = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
assertContains(
    packageCheck,
    "run-backend-env-smoke.sh",
    "release QA package should include backend environment smoke script"
)

print("Backend environment smoke checks passed")
