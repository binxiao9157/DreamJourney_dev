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
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let archiveView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "var isArchiveImageAnalysisConfigured: Bool",
    "func requestArchiveImageAnalysis(",
    "path: \"/archive/image-analysis\"",
    "\"imageBase64\": imageBase64",
    "\"archiveItemId\": archiveItemId",
    "\"privacyMetadata\": [\"scope\": \"generationAllowed\"]",
] {
    assertContains(backendClient, required, "backend client should call live archive image analysis \(required)")
}

for required in [
    "mutating func applyRemoteImageAnalysisResult(",
    "metadataFromRemoteAnalysisContract(result",
    "MemoryArchiveAnalysisStatus(remoteRawValue:",
    "Self.stringValue(result[\"analysisSummary\"])",
    "Self.stringValue(result[\"description\"])",
    "metadata[\"analysisSource\"] = \"backend_image_analysis\"",
] {
    assertContains(item, required, "archive item should merge live image analysis result \(required)")
}

for required in [
    "analyzePhotoArchiveItemIfPossible(",
    "imageBase64ForArchiveAnalysis(",
    "DreamJourneyBackendClient.shared.requestArchiveImageAnalysis(",
    "repository.update(updatedItem, syncToBackend: true)",
    "updatedItem.markAnalysisFailed(reason:",
] {
    assertContains(archiveView, required, "photo import should request live backend analysis \(required)")
}

assertContains(
    releaseRegression,
    "archive-image-analysis-live-chain-check.swift",
    "release regression should run live image analysis chain guard"
)
assertContains(
    releaseQA,
    "archive-image-analysis-live-chain-check.swift",
    "release QA package should include live image analysis chain guard"
)

print("Archive image analysis live chain guard passed")
