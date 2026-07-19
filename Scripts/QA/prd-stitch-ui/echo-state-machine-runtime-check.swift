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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpectedly found \(needle)")
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
    "case awaitingReplyDelivery",
    "case speaking",
    "case replied",
    "case error(String)",
] {
    assertContains(echoViewModel, state, "Echo state machine should expose \(state)")
}

assertContains(echoViewModel, "func retryAfterError()", "Echo state machine should expose an explicit retry transition from error")
assertContains(echoViewModel, "case delayedReplyDue", "Echo reducer should distinguish a due timer from a delivered reply")
assertContains(echoViewModel, "state: .awaitingReplyDelivery", "Expired delayed replies should await a server receipt")
assertContains(echoViewModel, "return applyTurnIntent(.delayedReplyDue", "Expired delayed replies should transition without local completion")
assertNotContains(echoViewModel, "func markStoredDelayedReplyArrived", "A local timer must not fabricate an arrived reply")
assertContains(echoView, "case .awaitingReplyDelivery", "Echo UI should render a truthful awaiting-server state")

assertContains(echoView, "case .error:", "Echo UI should render recoverable error state")
assertContains(echoView, "viewModel.retryAfterError()", "Echo UI should explicitly retry after error before starting a new capture")
assertContains(echoView, "accessibilityLabel: \"重新开始语音\"", "Error retry control should be accessible")

assertContains(releasePackage, "echo-state-machine-runtime-check.swift", "release QA package should include Echo state machine runtime guard")
assertContains(releaseRegression, "echo-state-machine-runtime-check.swift", "release regression should run Echo state machine runtime guard")

print("Echo state machine runtime checks passed")
