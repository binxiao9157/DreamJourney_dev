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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let repository = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift")
let item = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift")
let archiveView = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")

assertContains(flags, "case archiveRemoteFetch", "archive remote fetch flag")
assertNotContains(flags, ".archiveRemoteFetch,", "archive remote fetch must remain disabled by default")

assertContains(item, "init?(remoteJSON object: [String: Any])", "remote JSON item initializer")
assertContains(item, "MemoryArchiveItemKind(remoteRawValue:", "remote kind normalization")
assertContains(item, "MemoryArchiveAnalysisStatus(remoteRawValue:", "remote status normalization")

assertContains(repository, "func refreshFromBackend(", "repository remote refresh entrypoint")
assertContains(repository, "DreamJourneyBackendClient.shared.listArchiveItems(userId: currentUserId)", "repository should use backend archive list API")
assertContains(repository, "Self.archiveItems(from: object)", "repository should parse backend list response")
assertContains(repository, "mergeRemoteItems(remoteItems)", "repository should merge remote items into local store")
assertContains(repository, "save(mergedItems)", "repository should persist merged remote items")

assertContains(archiveView, "FeatureFlagService.shared.isEnabled(.archiveRemoteFetch)", "archive remote fetch must be feature-gated")
assertContains(archiveView, "repository.refreshFromBackend", "archive view should trigger gated refresh")
assertContains(flags, "DJEnableArchiveRemoteFetch", "QA feature registry should expose an explicit launch flag for backend fetch verification")
assertContains(appDelegate, "configuration.shouldEnableArchiveRemoteFetch", "UIQA backend fetch flag should use centralized launch configuration")
assertContains(appDelegate, "FeatureFlagService.shared.enableForCurrentLaunch(.archiveRemoteFetch)", "UIQA backend fetch flag should enable the hidden feature only for the current launch")

print("Archive remote fetch checks passed")
