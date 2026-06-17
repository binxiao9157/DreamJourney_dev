import Foundation

func read(_ path: String) -> String {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let detail = read("\(root)/DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let repository = read("\(root)/DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let flags = read("\(root)/DreamJourney/Sources/App/FeatureFlagService.swift")

assertContains(flags, "case archiveLocalAnalysis", "archive analysis flag")
assertContains(detail, "shouldShowLocalAnalysisAction", "detail guarded local analysis entry")
assertContains(detail, "#if DEBUG || UI_QA_SIMULATOR", "detail debug or QA visibility gate")
assertContains(detail, "FeatureFlagService.shared.isEnabled(.archiveLocalAnalysis)", "detail release feature flag gate")
assertContains(detail, "analyzeArchiveItemTapped", "detail analysis action")
assertContains(detail, "item.applyLocalAnalysisResult()", "detail applies local analysis")
assertContains(detail, "repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)", "detail persists local analysis with backend sync policy")
assertContains(detail, "reloadContent()", "detail refreshes cards after analysis")
assertContains(repository, "func update(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) -> Bool", "repository update method")
