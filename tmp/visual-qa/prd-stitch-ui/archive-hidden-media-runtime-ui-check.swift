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

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let hiddenShellRunner = read("tmp/visual-qa/prd-stitch-ui/run-archive-hidden-shell-smoke.sh")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-hidden-media-combo-gate.md")

for required in [
    "struct ArchiveMediaRuntimeCapability",
    "let storageProvider: String",
    "let supportedMediaKinds: [String]",
    "let audioFileSizeLimitMB: Int",
    "let videoFileSizeLimitMB: Int",
    "let uploadIntentTTLSeconds: Int",
    "func fetchArchiveMediaRuntimeCapability(",
] {
    assertContains(backendClient, required, "backend client should parse archive media runtime capability \(required)")
}

for required in [
    "archiveMediaRuntimeCapability",
    "fetchArchiveMediaRuntimeCapability",
    "makeArchiveMediaRuntimeCapabilityCard",
    "archive-hidden-media-runtime-card",
    "archive-hidden-media-runtime-state",
    "archive-hidden-media-runtime-provider",
    "archive-hidden-media-runtime-limit",
] {
    assertContains(detail, required, "hidden media detail should render backend runtime capability \(required)")
}

assertContains(
    backendClient,
    "mockObjectStorage",
    "backend client fallback should preserve mockObjectStorage provider"
)

for required in [
    "hiddenMediaRuntimeCardVisible",
    "hiddenMediaRuntimeProviderVisible",
    "hiddenMediaRuntimeLimitVisible",
] {
    assertContains(appDelegate, required, "hidden shell UIQA should verify runtime capability \(required)")
    assertContains(hiddenShellRunner, "\"\(required)\"", "hidden shell runner should assert runtime capability \(required)")
}

assertContains(
    releaseRegression,
    "archive-hidden-media-runtime-ui-check.swift",
    "release regression should run hidden media runtime UI guard"
)
assertContains(
    releaseQA,
    "archive-hidden-media-runtime-ui-check.swift",
    "release QA package should include hidden media runtime UI guard"
)
assertContains(
    statusDoc,
    "archiveMedia runtime capability",
    "status doc should document archive media runtime capability UI"
)

print("Archive hidden media runtime UI checks passed")
