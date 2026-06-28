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
let displayMetadata = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct ArchiveImageAnalysisRuntimeCapability",
    "let archiveImageAnalysis: ArchiveImageAnalysisRuntimeCapability",
    "json[\"archiveImageAnalysis\"] as? [String: Any]",
    "let provider: String",
    "let supportsVision: Bool",
    "let fallbackMode: String",
    "let statuses: [String]",
    "var canRunVisionAnalysis: Bool",
    "\"provider\"",
    "\"supportsVision\"",
    "\"fallbackMode\"",
] {
    assertContains(backendClient, required, "BackendRuntimeConfig should parse archive image-analysis runtime capability")
}

for required in [
    "case analyzing",
    "case retryable",
    "case \"analyzing\"",
    "case \"retryable\"",
    "case .analyzing:",
    "case .retryable:",
] {
    assertContains(archiveItem, required, "archive analysis status enum should cover backend contract \(required)")
}

for required in [
    "case .analyzing:",
    "case .retryable:",
] {
    assertContains(displayMetadata, required, "display metadata should label new archive analysis status \(required)")
    assertContains(repository, required, "archive context should handle new archive analysis status \(required)")
}

assertContains(
    releaseRegression,
    "archive-image-analysis-runtime-contract-check.swift",
    "release regression should run archive image-analysis runtime contract guard"
)
assertContains(
    releasePackage,
    "archive-image-analysis-runtime-contract-check.swift",
    "release QA package should include archive image-analysis runtime contract guard"
)

print("Archive image-analysis runtime contract guard passed")
