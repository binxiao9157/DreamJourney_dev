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

let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let releasePackageCheck = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertContains(echoViewModel, "var onArchiveContextStatusChange", "echo view model should notify UI when archive context availability changes")
assertContains(echoViewModel, "func refreshArchiveContextStatus()", "echo view model should expose refresh for view appearance")
assertContains(echoViewModel, "onArchiveContextStatusChange?(archiveContextStatus)", "echo view model should emit refreshed context status")

assertContains(echoView, "private let archiveContextStatusView", "echo screen should have a visible archive context indicator container")
assertContains(echoView, "private let archiveContextStatusLabel", "echo screen should have a visible archive context indicator label")
assertContains(echoView, "label.accessibilityIdentifier = \"echoArchiveContextStatus\"", "indicator should be stable for UI QA")
assertContains(echoView, "viewModel.onArchiveContextStatusChange", "echo screen should bind archive context status changes")
assertContains(echoView, "viewModel.refreshArchiveContextStatus()", "echo screen should refresh archive context on appearance")
assertContains(echoView, "private func renderArchiveContextStatus", "echo screen should isolate indicator rendering")
assertContains(echoView, "archiveContextStatusView.isHidden = !status.shouldShowArchiveContextIndicator", "indicator should stay hidden when no archive context is available or mode suppresses display")
assertContains(echoView, "status.indicatorText", "indicator copy should come from mode-aware status")
assertContains(echoView, "档案线索正在参与回响", "indicator copy should explicitly connect archive context to echo")
assertContains(echoView, "archiveContextStatusView.bottomAnchor.constraint(equalTo: quoteBubble.topAnchor", "indicator should live near the bottom echo conversation area without changing the tab bar")

assertContains(releasePackageCheck, "echo-archive-context-indicator-check.swift", "release QA package should include the echo archive context indicator guard")
