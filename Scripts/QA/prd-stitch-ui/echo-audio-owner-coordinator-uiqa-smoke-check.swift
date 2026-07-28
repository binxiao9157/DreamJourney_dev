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
        fputs("echo-audio-owner-coordinator-uiqa-smoke-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let runner = read("Scripts/QA/prd-stitch-ui/run-echo-audio-owner-coordinator-uiqa-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "DJRunEchoAudioOwnerCoordinatorSmoke",
    "echoAudioOwnerCoordinatorSmoke",
    "UI_QA_SIMULATOR && targetEnvironment(simulator)",
] {
    require(featureFlags.contains(required) || echo.contains(required), "missing QA-only coordinator scenario \(required)")
}

for required in [
    "UIQAEchoAudioOwnerDriver",
    "audioSessionCoordinator = AudioSessionCoordinator.shared",
    "runUIQAEchoAudioOwnerCoordinatorSmoke",
    "captureAcquired",
    "tencentPreemptedCapture",
    "staleCaptureReleaseIgnored",
    "captureRestored",
    "tencentFailurePreservedCapture",
    "staleRoleReleaseIgnored",
    "roleSwitchCoordinator",
    "audioSessionCoordinator = previousCoordinator",
] {
    require(echo.contains(required), "Echo coordinator UIQA contract missing \(required)")
}

for required in [
    "runEchoAudioOwnerCoordinatorSmoke",
    "writeEchoAudioOwnerCoordinatorSmokeResult",
    "echo-audio-owner-coordinator-smoke-result.json",
] {
    require(appDelegate.contains(required), "AppDelegate coordinator smoke wiring missing \(required)")
}

for required in [
    "run-installable-simulator-uiqa.sh",
    "DJRunEchoAudioOwnerCoordinatorSmoke",
    "echo-audio-owner-coordinator-smoke-result.json",
    "staleCaptureReleaseIgnored",
    "tencentFailurePreservedCapture",
    "staleRoleReleaseIgnored",
    "simctl io",
] {
    require(runner.contains(required), "runner contract missing \(required)")
}

require(
    releaseRegression.contains("RUN_ECHO_AUDIO_OWNER_COORDINATOR_UIQA_SMOKE"),
    "release regression should expose the optional coordinator UIQA smoke"
)
require(
    releaseRegression.contains("run-echo-audio-owner-coordinator-uiqa-smoke.sh"),
    "release regression should invoke the coordinator UIQA smoke"
)
require(
    releaseRegression.contains("echo-audio-owner-coordinator-uiqa-smoke-check.swift"),
    "release regression should run the coordinator static guard"
)
require(
    releaseQA.contains("echo-audio-owner-coordinator-uiqa-smoke-check.swift"),
    "release QA package should include the coordinator static guard"
)
require(
    releaseQA.contains("run-echo-audio-owner-coordinator-uiqa-smoke.sh"),
    "release QA package should include the coordinator runner"
)

print("echo-audio-owner-coordinator-uiqa-smoke-check passed")
