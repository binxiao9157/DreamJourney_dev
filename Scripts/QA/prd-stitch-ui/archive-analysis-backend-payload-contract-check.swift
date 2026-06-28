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

let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "\"detectedPeople\": detectedPeople",
    "\"detectedLocations\": detectedLocationClues",
    "\"detectedScenes\": detectedSceneClues",
    "\"tags\": tags",
    "\"analysisFailureReason\"",
    "\"analysisRetryable\"",
] {
    assertContains(item, required, "archive backend payload should include structured AI analysis contract \(required)")
}

for required in [
    "metadataFromRemoteAnalysisContract(",
    "mergeRemoteMetadataList(object[\"detectedLocations\"], forKey: Self.analysisLocationCluesMetadataKey",
    "mergeRemoteMetadataList(object[\"detectedScenes\"], forKey: Self.analysisSceneCluesMetadataKey",
    "Self.stringValue(object[\"analysisFailureReason\"])",
    "Self.boolValue(object[\"analysisRetryable\"])",
] {
    assertContains(item, required, "archive remote JSON should restore structured AI analysis contract \(required)")
}

for required in [
    "let locations: [String]",
    "let scenes: [String]",
    "地点线索：",
    "场景线索：",
] {
    assertContains(repository, required, "archive echo context should include structured AI analysis clues \(required)")
}

assertContains(
    releaseRegression,
    "archive-analysis-backend-payload-contract-check.swift",
    "release regression should run archive analysis backend payload guard"
)
assertContains(
    releaseQA,
    "archive-analysis-backend-payload-contract-check.swift",
    "release QA package should include archive analysis backend payload guard"
)

print("Archive analysis backend payload contract guard passed")
