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
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "analysisLocationCluesMetadataKey",
    "analysisSceneCluesMetadataKey",
    "analysisFailureReasonMetadataKey",
    "var detectedLocationClues: [String]",
    "var detectedSceneClues: [String]",
    "mutating func markAnalysisFailed(",
    "mutating func retryLocalAnalysis(",
    "extractLocationClues",
    "extractSceneClues",
] {
    assertContains(item, required, "archive item should expose AI analysis insight contract \(required)")
}

for required in [
    "makeInsightSection(title: \"地点线索\", iconName: \"mappin.and.ellipse\", values: item.detectedLocationClues",
    "makeInsightSection(title: \"场景线索\", iconName: \"camera.viewfinder\", values: item.detectedSceneClues",
    "makeAnalysisRetryButton",
    "analysisStatusLabel.text = analysisStatusDisplayText",
    "analysisStatusDisplayText",
    "分析失败，可稍后重试",
    "重新分析",
] {
    assertContains(detail, required, "archive detail should render AI analysis insight UI \(required)")
}

for required in [
    "DJSeedArchiveAnalysisInsights",
    "seedArchiveAnalysisInsightsContext()",
    "detectedLocationClues",
    "detectedSceneClues",
    "markAnalysisFailed(reason:",
] {
    assertContains(appDelegate, required, "QA seed should cover analysis insights/failure \(required)")
}

assertContains(
    releaseRegression,
    "archive-analysis-insights-contract-check.swift",
    "release regression should run archive analysis insights guard"
)
assertContains(
    releaseQA,
    "archive-analysis-insights-contract-check.swift",
    "release QA package should include archive analysis insights guard"
)

print("Archive analysis insights contract guard passed")
