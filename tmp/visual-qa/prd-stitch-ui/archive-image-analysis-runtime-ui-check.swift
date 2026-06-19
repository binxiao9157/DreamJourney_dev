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
let archiveItem = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let archiveView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let detailView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertContains(
    backendClient,
    "func fetchArchiveImageAnalysisRuntimeCapability(",
    "backend client should expose focused archive image-analysis runtime fetch"
)

for required in [
    "mutating func markAnalysisUnavailableFromRuntime(",
    "analysisProvider",
    "analysisFallbackMode",
] {
    assertContains(archiveItem, required, "archive item should persist runtime unavailable analysis metadata")
}

for required in [
    "fetchArchiveImageAnalysisRuntimeCapability",
    "guard capability.canRunVisionAnalysis else",
    "markArchiveImageAnalysisUnavailable(",
    "capability.availabilityDisplayText",
] {
    assertContains(archiveView, required, "album import should gate image analysis UI by runtime capability")
    assertContains(detailView, required, "detail retry should gate image analysis UI by runtime capability")
}

assertContains(
    releaseRegression,
    "archive-image-analysis-runtime-ui-check.swift",
    "release regression should run archive image-analysis runtime UI guard"
)
assertContains(
    releasePackage,
    "archive-image-analysis-runtime-ui-check.swift",
    "release QA package should include archive image-analysis runtime UI guard"
)

print("Archive image-analysis runtime UI guard passed")
