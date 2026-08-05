import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError(message)
    }
}

func section(_ source: String, from start: String, to end: String) -> String {
    guard let startRange = source.range(of: start),
          let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
        fatalError("Unable to locate section \(start)")
    }
    return String(source[startRange.lowerBound..<endRange.lowerBound])
}

let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let runner = read("Scripts/QA/prd-stitch-ui/run-echo-continuous-turn-uiqa-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "case echoContinuousTurnSmoke = \"DJRunEchoContinuousTurnSmoke\"",
    ".echoContinuousTurnSmoke,",
] {
    require(featureFlags.contains(required), "QA scenario registry is missing \(required)")
}

let livePanelRequirement = section(
    featureFlags,
    from: "var requiresDigitalHumanLivePanel: Bool",
    to: "var requiresAuthenticatedBackendFixture: Bool"
)
require(
    !livePanelRequirement.contains(".echoContinuousTurnSmoke"),
    "continuous Echo UIQA must stay provider-free and must not enable the digital-human panel"
)

for required in [
    "case .echoContinuousTurnSmoke:",
    "runEchoContinuousTurnSmoke",
    "QAScenarioResultWriter.writeAndLog",
    "echo-continuous-turn-smoke-result.json",
] {
    require(appDelegate.contains(required), "AppDelegate continuous-turn UIQA wiring is missing \(required)")
}

for required in [
    "runUIQAEchoContinuousTurnSmoke",
    "viewModel.prepareVoiceInteraction()",
    "viewModel.beginVoiceInteraction()",
    "viewModel.finishUserVoice(",
    "viewModel.markReplyDelivered(",
    "self.stopVoiceCapture()",
    "staleReplyRejected",
    "leftEchoTab",
    "reenteredEchoTab",
    "transcriptEntryCountBeforeLeave",
    "digitalHumanPanelVisible",
] {
    require(echo.contains(required), "Echo continuous-turn UIQA behavior is missing \(required)")
}

for required in [
    "run-installable-simulator-uiqa.sh",
    "DJRunEchoContinuousTurnSmoke",
    "01-cold-start",
    "02-process-restart",
    "echo-continuous-turn-smoke-result.json",
    "staleReplyRejected",
    "xcrun simctl terminate",
    "simctl io",
] {
    require(runner.contains(required), "continuous-turn UIQA runner is missing \(required)")
}

for required in [
    "RUN_ECHO_CONTINUOUS_TURN_UIQA_SMOKE",
    "run-echo-continuous-turn-uiqa-smoke.sh",
    "echo-continuous-turn-uiqa-smoke-check.swift",
] {
    require(releaseRegression.contains(required), "release regression is missing \(required)")
}

for required in [
    "run-echo-continuous-turn-uiqa-smoke.sh",
    "echo-continuous-turn-uiqa-smoke-check.swift",
] {
    require(releaseQA.contains(required), "release QA package is missing \(required)")
}

print("Echo continuous-turn UIQA smoke checks passed")
