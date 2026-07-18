import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("echo-audio-owner-lifecycle-guard-check failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(named functionName: String, in source: String) -> String {
    let privateSignature = source.range(of: "private func \(functionName)")
    let internalSignature = source.range(of: "func \(functionName)")
    guard let signature = privateSignature ?? internalSignature else {
        require(false, "\(functionName) is missing")
        return ""
    }
    guard let openBrace = source[signature.lowerBound...].firstIndex(of: "{") else {
        require(false, "\(functionName) body is missing")
        return ""
    }

    var depth = 0
    var index = openBrace
    while index < source.endIndex {
        let character = source[index]
        if character == "{" {
            depth += 1
        } else if character == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[openBrace...index])
            }
        }
        index = source.index(after: index)
    }
    require(false, "\(functionName) body is not balanced")
    return ""
}

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

let releaseBody = functionBody(named: "releaseDigitalHumanRuntime", in: echo)
require(releaseBody.contains("cancelDigitalHumanReplyPrewarm()"), "release helper should cancel pending reply prewarm")
require(releaseBody.contains("cancelTencentDigitalHumanTextOverTimeout()"), "release helper should cancel TextOver timeout")
require(releaseBody.contains("resetDigitalHumanReplyDispatchState()"), "release helper should clear provider conversation state")
require(releaseBody.contains("stopDigitalHumanAudioLevelMetering()"), "release helper should stop audio level metering")
require(releaseBody.contains("runtime?.interrupt()"), "release helper should interrupt provider playback before close")
require(releaseBody.contains("runtime?.close()"), "release helper should close provider runtime")
require(releaseBody.contains("digitalHumanRuntime = nil"), "release helper should nil out provider runtime")
require(releaseBody.contains("hasRequestedCloudDigitalHumanRuntime = false"), "release helper should clear session request latch")
require(releaseBody.contains("removeHostedProviderView(showFallbackMessage:"), "release helper should own failed provider view removal")
require(releaseBody.contains("setDialogEngineLocalTTSPlaybackEnabled(true)"), "ordinary fallback release should re-enable ordinary Echo audio through its owner-scoped binding")
require(releaseBody.contains("setEchoAudioOwner(.volcengineLocalTTS"), "ordinary fallback release should reset audio owner")
require(releaseBody.contains("recordEchoRuntimeDiagnosticsSnapshot"), "release helper should emit diagnostics")

let viewWillDisappearBody = functionBody(named: "viewWillDisappear", in: echo)
require(viewWillDisappearBody.contains("releaseDigitalHumanRuntime(reason: \"viewWillDisappear\""), "page exit should use unified release helper")
require(!viewWillDisappearBody.contains("digitalHumanRuntime?.close()"), "page exit must not close runtime inline")
require(!viewWillDisappearBody.contains("digitalHumanRuntime = nil"), "page exit must not nil runtime inline")

let degradeBody = functionBody(named: "degradeTencentDigitalHumanRoute", in: echo)
require(
    degradeBody.contains("releaseDigitalHumanRuntime(")
        && degradeBody.contains("reason: \"routeFailure"),
    "provider failure should use unified release helper"
)
require(degradeBody.contains("removeProviderViewMessage: message.panel"), "provider failure should still remove the selected fallback provider view")
require(degradeBody.contains("resetsAudioOwnerToOrdinaryEcho: true"), "provider failure should reset audio owner to ordinary Echo")
require(!degradeBody.contains("failedRuntime?.close()"), "provider failure must not close runtime inline")

require(echo.contains("reason=release:"), "release logs should have a searchable release reason")
require(releaseRegression.contains("echo-audio-owner-lifecycle-guard-check.swift"), "release regression should run audio owner lifecycle guard")
require(releaseQA.contains("echo-audio-owner-lifecycle-guard-check.swift"), "release QA package should include audio owner lifecycle guard")

print("echo-audio-owner-lifecycle-guard-check passed")
