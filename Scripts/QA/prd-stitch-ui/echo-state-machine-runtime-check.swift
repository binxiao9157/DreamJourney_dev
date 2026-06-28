import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let echoViewModel = read("DreamJourney/Sources/Modules/Echo/EchoViewModel.swift")
let echoView = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

for state in [
    "case starting",
    "case listening",
    "case thinking",
    "case waitingReply(minutes: Int)",
    "case speaking",
    "case replied",
    "case error(String)",
] {
    assertContains(echoViewModel, state, "Echo state machine should expose \(state)")
}

assertContains(echoViewModel, "func retryAfterError()", "Echo state machine should expose an explicit retry transition from error")
assertContains(echoViewModel, "func markStoredDelayedReplyArrived", "Echo should not silently drop overdue delayed replies on restore")
assertContains(echoViewModel, "markStoredDelayedReplyArrived(delayedReply)", "Expired delayed replies should move to an arrived state")
assertContains(echoViewModel, "updateState(.replied)", "Arrived delayed replies should render as replied")
assertContains(echoViewModel, "EchoDelayedReplyStore.shared.clear()", "Arrived delayed replies should clear persisted waiting state")

assertContains(echoView, "case .error:", "Echo UI should render recoverable error state")
assertContains(echoView, "viewModel.retryAfterError()", "Echo UI should explicitly retry after error before starting a new capture")
assertContains(echoView, "accessibilityLabel: \"重新开始语音\"", "Error retry control should be accessible")

assertContains(releasePackage, "echo-state-machine-runtime-check.swift", "release QA package should include Echo state machine runtime guard")
assertContains(releaseRegression, "echo-state-machine-runtime-check.swift", "release regression should run Echo state machine runtime guard")

print("Echo state machine runtime checks passed")
