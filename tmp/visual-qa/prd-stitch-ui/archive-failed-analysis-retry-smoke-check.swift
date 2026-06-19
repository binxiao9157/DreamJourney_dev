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
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertFileExists(
    "tmp/visual-qa/prd-stitch-ui/run-archive-failed-analysis-retry-smoke.sh",
    "failed analysis retry UIQA smoke script"
)

let smokeScript = read("tmp/visual-qa/prd-stitch-ui/run-archive-failed-analysis-retry-smoke.sh")

for phrase in [
    "DJRunArchiveFailedAnalysisRetrySmoke",
    "seedFailedArchiveAnalysisRetryContext",
    "runArchiveFailedAnalysisRetrySmoke",
    "writeArchiveFailedAnalysisRetrySmokeResult",
    "archive-failed-analysis-retry-smoke-result.json",
    "reason: \"provider_unavailable\"",
    ".synced,",
] {
    assertContains(appDelegate, phrase, "AppDelegate should wire failed analysis retry smoke \(phrase)")
}

for phrase in [
    "private weak var analysisRetryButton",
    "analysisRetryButton = button",
    "runUIQAArchiveFailedAnalysisRetrySmoke",
    "sendActions(for: .touchUpInside)",
    "archiveAnalysisAvailabilityDisplayName",
    "archiveBackendSyncDisplayName",
] {
    assertContains(detail, phrase, "Archive detail should expose retry UIQA smoke \(phrase)")
}

for phrase in [
    "DJRunArchiveFailedAnalysisRetrySmoke",
    "archive-failed-analysis-retry-smoke-result.json",
    "archive-failed-analysis-retry-smoke",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "backend-private.xcconfig",
    "analysis retry button was not visible",
    "backendConfigured",
    "retryActionFired",
] {
    assertContains(smokeScript, phrase, "failed retry smoke script should include \(phrase)")
}

assertContains(
    releaseRegression,
    "archive-failed-analysis-retry-smoke-check.swift",
    "release regression should run failed retry smoke guard"
)
assertContains(
    releaseRegression,
    "RUN_ARCHIVE_FAILED_ANALYSIS_RETRY_SMOKE",
    "release regression should expose optional failed retry UIQA smoke"
)
assertContains(
    releasePackage,
    "tmp/visual-qa/prd-stitch-ui/archive-failed-analysis-retry-smoke-check.swift",
    "release QA package should include failed retry smoke guard"
)
assertContains(
    releasePackage,
    "tmp/visual-qa/prd-stitch-ui/run-archive-failed-analysis-retry-smoke.sh",
    "release QA package should include failed retry smoke script"
)

print("Archive failed analysis retry smoke checks passed")
