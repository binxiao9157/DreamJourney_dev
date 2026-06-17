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
        fatalError("\(message): missing \(needle)")
    }
}

let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")

assertContains(detail, "static let analysisHeroIconSize: CGFloat = 42", "analysis state should have an explicit hero icon size")
assertContains(detail, "static let analysisSummaryInset: CGFloat = 16", "analysis summary panel should use explicit inset")
assertContains(detail, "static let analysisCardSpacing: CGFloat = 14", "analysis card rhythm should stay compact")
assertContains(detail, "private func makeAnalysisHeader() -> UIView", "analysis card should have a dedicated status header")
assertContains(detail, "private func makeAnalysisSummaryPanel(summary: String, isAnalyzed: Bool) -> UIView", "analysis card should render summary in a warm panel")
assertContains(detail, "private func makeInsightSection(", "analysis card should use dedicated insight sections")
assertContains(detail, "let isAnalyzed = item.analysisStatus == .analyzed", "analysis card should distinguish pending and analyzed states")
assertContains(detail, "makeAnalysisSummaryPanel(summary: summaryText, isAnalyzed: isAnalyzed)", "analysis card should route summary through the panel")
assertContains(detail, "makeInsightSection(title: \"标签\", iconName: \"tag\", values: item.tags", "analysis card should render tags as insights")
assertContains(detail, "makeInsightSection(title: \"人物线索\", iconName: \"person.2\", values: item.detectedPeople", "analysis card should render people as insights")
assertContains(detail, "analysisStatusLabel.text = item.analysisStatus == .analyzed ? \"已生成\" : \"待生成\"", "analysis header should expose clear generated state")
assertContains(detail, "summaryContainer.backgroundColor = isAnalyzed", "summary panel should visually differentiate analyzed state")

assertContains(item, "metadata[\"analysisSource\"] = \"local_rule\"", "local analysis should preserve source metadata")
assertContains(item, "metadata[\"analysisUpdatedAt\"]", "local analysis should preserve update timestamp")

print("Archive analysis state Stitch checks passed")
