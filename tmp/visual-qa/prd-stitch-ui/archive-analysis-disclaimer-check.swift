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

let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

assertContains(detail, "AI 分析为主，后端辅助处理", "Archive detail should disclose backend + AI assisted analysis")
assertContains(detail, "archive-analysis-disclaimer-label", "Archive detail disclaimer should be stable for QA")
assertContains(detail, "makeAnalysisDisclaimerLabel", "Archive detail should keep disclaimer rendering centralized")
assertContains(archive, "不会人为查看你的记忆内容", "Archive public copy should clarify privacy boundary")
assertContains(archive, "archive-analysis-privacy-disclaimer", "Archive public privacy copy should be stable for QA")
assertContains(archive, "override func textRect(forBounds bounds: CGRect", "Archive padded disclaimer should support multiline text")

assertContains(releaseQA, "archive-analysis-disclaimer-check.swift", "Release QA package should include archive analysis disclaimer guard")
assertContains(releaseRegression, "archive-analysis-disclaimer-check.swift", "Release regression should run archive analysis disclaimer guard")

print("Archive analysis disclaimer guard passed.")
