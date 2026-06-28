import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
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

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")

assertContains(appDelegate, "DJSeedPendingArchiveAnalysis", "QA pending analysis launch argument")
assertContains(appDelegate, "seedPendingArchiveAnalysisContext()", "QA pending analysis seed helper")
assertContains(appDelegate, "MemoryArchiveItemFactory.makePhotoItem(localPath: \"/tmp/uiqa-pending-photo.jpg\")", "QA pending analysis seed uses a pending photo")
assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "QA pending analysis seed skips backend sync")

assertContains(detail, "item.applyLocalAnalysisResult()", "detail action applies local analysis")
assertContains(detail, "repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)", "detail action persists analyzed item")
assertContains(detail, "showToast(didPersist ? \"已生成本地分析\"", "detail action confirms local analysis")

assertContains(repository, "case .analyzed, .manual:", "archive context accepts analyzed items")
assertContains(repository, "case .pending, .failed:", "archive context excludes pending items before analysis")
