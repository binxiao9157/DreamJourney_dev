import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("echo-digital-human-lifecycle-audio-route-check failed: \(message)\n", stderr)
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

let echo = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let dialogEngine = try read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let releaseRegression = try read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = try read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

require(echo.contains("private var isSuspendedByAppLifecycle"), "Echo should track app lifecycle suspension explicitly")
require(echo.contains("private var isStoppingVoiceCaptureForAppLifecycle"), "Echo should distinguish lifecycle stop from manual user stop")
require(echo.contains("observeEchoAppLifecycle()"), "Echo viewDidLoad should install app lifecycle observers")
require(echo.contains("name: .djAppLifecycleEventForwarded"), "Echo should consume the root lifecycle event")
require(echo.contains("@objc private func echoAppLifecycleEventForwarded"), "Echo should map root lifecycle events to its existing lifecycle behavior")
for directObserver in [
    "UIApplication.willResignActiveNotification",
    "UIApplication.didEnterBackgroundNotification",
    "UIApplication.willEnterForegroundNotification",
    "UIApplication.didBecomeActiveNotification",
] {
    require(!echo.contains(directObserver), "Echo must not duplicate the root lifecycle observer: \(directObserver)")
}

let suspendBody = functionBody(named: "suspendEchoForAppLifecycle", in: echo)
require(suspendBody.contains("isSuspendedByAppLifecycle = true"), "lifecycle suspend should mark suspended state")
require(suspendBody.contains("interruptDigitalHumanPlayback(reason: \"appLifecycle:"), "lifecycle suspend should interrupt provider audio without destroying the provider")
require(suspendBody.contains("preserveTencentProviderSessionAfterLocalDialogStop(reason: \"appLifecycle:"), "lifecycle suspend should preserve Tencent provider session")
require(suspendBody.contains("DialogEngineManager.shared.stopDialog()"), "lifecycle suspend should stop active microphone capture")
require(suspendBody.contains("isStoppingVoiceCaptureForAppLifecycle = true"), "lifecycle DialogEngine stop should be marked for lifecycle handling")
require(suspendBody.contains("resetToLifecyclePausedIdle()"), "lifecycle suspend should leave UI in an explicit idle/restart state")
require(suspendBody.contains("recordEchoRuntimeDiagnosticsSnapshot(reason: \"appLifecycleSuspended:"), "lifecycle suspend should be traceable in Echo diagnostics")
require(!suspendBody.contains("digitalHumanRuntime?.close()"), "lifecycle suspend must not close Tencent runtime")
require(!suspendBody.contains("digitalHumanRuntime = nil"), "lifecycle suspend must not nil out Tencent runtime")
require(!suspendBody.contains("removeHostedProviderView"), "lifecycle suspend must not remove the provider view")

let restoreBody = functionBody(named: "restoreEchoAfterAppLifecycleIfNeeded", in: echo)
require(restoreBody.contains("isSuspendedByAppLifecycle = false"), "foreground restore should clear lifecycle suspension")
require(restoreBody.contains("prepareCloudDigitalHumanRuntimeIfNeeded()"), "foreground restore should recreate provider session only if it was actually lost")
require(restoreBody.contains("applyEchoAudioRoutePolicy()"), "foreground restore should reapply audio-owner policy")
require(restoreBody.contains("loadVoiceCloneRuntimeCapabilityIfNeeded"), "foreground restore should refresh voice-clone runtime capability")
require(restoreBody.contains("resetToLifecyclePausedIdle()"), "foreground restore should keep paused UI copy after idle render")
require(restoreBody.contains("recordEchoRuntimeDiagnosticsSnapshot(reason: \"appLifecycleRestored:"), "foreground restore should be traceable in Echo diagnostics")
require(!restoreBody.contains("startDialog("), "foreground restore must not auto-start the microphone")

let dialogEndedBody = functionBody(named: "onDialogEnded", in: echo)
require(dialogEndedBody.contains("isStoppingVoiceCaptureForAppLifecycle"), "DialogEngine ended callback should handle lifecycle stops separately")
require(dialogEndedBody.contains("dialogEndedAfterAppLifecycle"), "lifecycle stop should preserve provider session with a searchable reason")
require(dialogEndedBody.contains("resetToLifecyclePausedIdle()"), "DialogEngine lifecycle stop should keep paused UI copy after idle render")

let configureAudioSessionBody = functionBody(named: "configureAudioSession", in: dialogEngine)
require(configureAudioSessionBody.contains(".allowBluetoothHFP"), "DialogEngine should use non-deprecated Bluetooth HFP audio-session option")
require(!configureAudioSessionBody.contains(".allowBluetooth]") && !configureAudioSessionBody.contains(".allowBluetooth,"), "DialogEngine configureAudioSession must not use deprecated .allowBluetooth")

require(releaseRegression.contains("echo-digital-human-lifecycle-audio-route-check.swift"), "release regression should run lifecycle/audio-route guard")
require(releaseQA.contains("echo-digital-human-lifecycle-audio-route-check.swift"), "release QA package should include lifecycle/audio-route guard")

print("echo-digital-human-lifecycle-audio-route-check passed")
