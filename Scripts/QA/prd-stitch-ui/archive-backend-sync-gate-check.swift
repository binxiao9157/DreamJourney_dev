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

func assertOrder(_ haystack: String, _ first: String, _ second: String, _ message: String) {
    guard let firstRange = haystack.range(of: first),
          let secondRange = haystack.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fatalError("\(message): expected \(first) before \(second)")
    }
}

let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")

assertContains(repository, "func add(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true)", "archive add keeps default backend sync")
assertContains(repository, "if shouldSyncToBackend {", "archive add can skip backend sync")
assertContains(repository, "syncToBackend(item)", "archive add still supports backend sync")
assertOrder(
    repository,
    "save(items)",
    "if shouldSyncToBackend {",
    "archive add should persist locally before optional backend sync"
)

assertContains(repository, "func update(_ item: MemoryArchiveItem, syncToBackend shouldSyncToBackend: Bool = true) -> Bool", "archive update keeps default backend sync")
assertContains(detail, "repository.update(item, syncToBackend: shouldSyncArchiveUpdateToBackend)", "detail analysis can skip backend sync in QA")
assertContains(detail, "private var shouldSyncArchiveUpdateToBackend: Bool", "detail has explicit backend sync policy")
assertContains(detail, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)", "detail backend sync policy has QA gate")

assertContains(appDelegate, "MemoryArchiveRepository.shared.add(item, syncToBackend: false)", "QA seed skips backend sync")
