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

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let runner = read("Scripts/QA/prd-stitch-ui/run-echo-digital-human-lifecycle-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

assertContains(
    featureFlags,
    "DJRunEchoDigitalHumanLifecycleSmoke",
    "centralized QA scenario registry should retain the Echo lifecycle launch argument"
)

for required in [
    "runEchoDigitalHumanLifecycleSmoke",
    "writeEchoDigitalHumanLifecycleSmokeResult",
    "echo-digital-human-lifecycle-smoke-result.json",
] {
    assertContains(appDelegate, required, "AppDelegate should expose Echo lifecycle UIQA smoke \(required)")
}

assertContains(
    featureFlags,
    "enum QAEchoScenarioRunner",
    "Echo lifecycle UIQA route should use the compile-isolated shared scenario runner"
)
assertContains(
    appDelegate,
    "QAEchoScenarioRunner.run(\n            retryCount: retryCount,\n            smokeName: \"EchoDigitalHumanLifecycleSmoke\"",
    "Echo lifecycle UIQA smoke should delegate root/Echo routing to the shared scenario runner"
)

for required in [
    "runUIQAEchoDigitalHumanLifecycleSmoke",
    "forwardUIQALifecycleEvent",
    "AppLifecycleEventReceipt(",
    "name: .djAppLifecycleEventForwarded",
    "forwardUIQALifecycleEvent(.willResignActive, sequence: 1)",
    "forwardUIQALifecycleEvent(.didEnterBackground, sequence: 2)",
    "forwardUIQALifecycleEvent(.willEnterForeground, sequence: 3)",
    "forwardUIQALifecycleEvent(.didBecomeActive, sequence: 4)",
    "\"appLifecycleSuspended\"",
    "\"appLifecycleRestored\"",
    "\"microphoneAutoStart\"",
    "\"providerViewPreserved\"",
    "\"backgroundLeaseScheduled\"",
    "\"backgroundLeaseCancelled\"",
    "\"backgroundLeaseExpired\"",
    "\"runtimeReleasedAfterGrace\"",
    "\"audioOwner\"",
] {
    assertContains(echo, required, "Echo should expose lifecycle UIQA behavior \(required)")
}

for required in [
    "run-installable-simulator-uiqa.sh",
    "DJRunEchoDigitalHumanLifecycleSmoke",
    "echo-digital-human-lifecycle-smoke-result.json",
    "\"completed\"",
    "\"lifecycleSuspended\"",
    "\"lifecycleRestored\"",
    "\"providerViewPreserved\"",
    "\"backgroundLeaseScheduled\"",
    "\"backgroundLeaseCancelled\"",
    "\"backgroundLeaseExpired\"",
    "\"runtimeReleasedAfterGrace\"",
    "\"microphoneAutoStart\"",
    "simctl io",
] {
    assertContains(runner, required, "Lifecycle UIQA runner should verify \(required)")
}

assertContains(
    releaseRegression,
    "RUN_ECHO_DIGITAL_HUMAN_LIFECYCLE_SMOKE",
    "release regression should expose optional Echo lifecycle UIQA smoke"
)
assertContains(
    releaseRegression,
    "run-echo-digital-human-lifecycle-smoke.sh",
    "release regression should call Echo lifecycle UIQA smoke"
)
assertContains(
    releaseRegression,
    "echo-digital-human-lifecycle-uiqa-smoke-check.swift",
    "release regression should run lifecycle smoke static guard"
)
assertContains(
    releaseQA,
    "echo-digital-human-lifecycle-uiqa-smoke-check.swift",
    "release QA package should include lifecycle smoke static guard"
)
assertContains(
    releaseQA,
    "run-echo-digital-human-lifecycle-smoke.sh",
    "release QA package should include lifecycle smoke runner"
)

print("Echo digital-human lifecycle UIQA smoke checks passed")
