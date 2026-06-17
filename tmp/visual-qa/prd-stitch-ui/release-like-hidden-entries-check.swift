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

let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")

assertContains(archive, "DJEnableArchiveHiddenBranches", "QA-only hidden branch launch argument")
assertContains(archive, "isUIQAArchiveHiddenBranchesEnabled", "explicit QA hidden branch gate")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveAudioUpload)", "release audio flag")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveRemoteFetch)", "release remote fetch flag")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.timeLetters)", "release time-letter flag")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.personaSettings)", "release persona flag")
assertContains(archive, "makeArchiveCTASubtitle()", "dynamic archive CTA subtitle")
assertContains(archive, "let secondaryTiles = makeSecondaryFeatureTiles()", "feature tiles are release-filtered")
assertContains(archive, "guard !secondaryTiles.isEmpty else", "photo tile can stand alone when hidden entries are disabled")
assertNotContains(archive, "#if UI_QA_SIMULATOR && targetEnvironment(simulator)\n        return true", "UIQA must not expose hidden entries by default")
