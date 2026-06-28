import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-audio-owner-stop-semantics-check failed: \(message)\n", stderr)
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
let cloudRuntime = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let bridge = try read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let releaseRegression = try read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")

let stopBody = functionBody(named: "stopVoiceCapture", in: echo)
require(!stopBody.contains("interruptDigitalHumanPlayback"), "manual stop must not interrupt Tencent provider playback")
require(!stopBody.contains("digitalHumanRuntime?.interrupt"), "manual stop must not call provider interrupt")
require(!stopBody.contains("digitalHumanRuntime?.close"), "manual stop must not close Tencent provider")
require(!stopBody.contains("removeHostedProviderView"), "manual stop must not remove the hosted Tencent provider view")
require(stopBody.contains("stopDialog()"), "manual stop should still stop Fire/Volcengine DialogEngine")
require(stopBody.contains("isStoppingVoiceCaptureManually"), "manual stop must be tracked so DialogEngine ended callback preserves the provider view")

let dialogEndedBodyStart = echo.range(of: "func onDialogEnded(reason: DialogEndReason)")?.lowerBound
let dialogEndedBodyEnd = echo.range(of: "\n    }\n}\n\n#if UI_QA_SIMULATOR", options: [], range: dialogEndedBodyStart!..<echo.endIndex)?.lowerBound
if let start = dialogEndedBodyStart, let end = dialogEndedBodyEnd {
    let dialogEndedBody = String(echo[start..<end])
    require(dialogEndedBody.contains("isStoppingVoiceCaptureManually"), "dialog-ended path must preserve provider when manual stop caused the end event")
    require(!dialogEndedBody.contains("interruptDigitalHumanPlayback(reason: \"dialogEnded\")"), "dialog-ended path must not stop Tencent provider by default")
} else {
    require(false, "onDialogEnded body could not be parsed")
}

let audioSessionBody = functionBody(named: "prepareAudioSessionForTencentProviderPlayback", in: echo)
require(audioSessionBody.contains("preserveRecordingCategory"), "Tencent playback prep must keep an explicit preserve-recording path")
require(audioSessionBody.contains("setActive(true)") && !audioSessionBody.contains("overrideOutputAudioPort"), "Tencent playback prep should avoid route override churn")
require(audioSessionBody.contains("setCategory(") && audioSessionBody.contains(".playAndRecord"), "Tencent playback prep must keep a record-capable session for half-duplex Echo turns")
require(!audioSessionBody.contains("setCategory(.playback"), "Tencent playback prep must not switch to playback-only while the Tencent stream is open")

require(echo.contains("tencentDigitalHumanAudioRouteReserved"), "Echo must reserve Tencent audio ownership before the provider reaches ready")
require(echo.contains("case .preparing, .connecting, .ready, .buffering, .speaking"), "Tencent audio route must be reserved during preparing/connecting/ready/buffering/speaking states")
let routePolicyBody = functionBody(named: "applyEchoAudioRoutePolicy", in: echo)
require(routePolicyBody.contains("tencentDigitalHumanAudioRouteReserved"), "Echo route policy must use the reserved Tencent audio owner state")
require(routePolicyBody.contains("if !tencentDigitalHumanAudioRouteReserved"), "Echo route policy must not enable Fire/Volcengine local TTS while Tencent runtime is reserved")
let providerSpeechFinishBody = functionBody(named: "resumeDialogEngineAfterTencentProviderSpeechIfNeeded", in: echo)
require(!providerSpeechFinishBody.contains("startDialog"), "Tencent TextOver must not auto-restart Fire/Volcengine DialogEngine; the next user turn should explicitly start capture")
require(providerSpeechFinishBody.contains("resetToIdle()"), "Tencent TextOver should return Echo to idle instead of immediately reopening capture")
require(providerSpeechFinishBody.contains("without DialogEngine auto-resume"), "Tencent provider speech finish should log the half-duplex audio-owner decision")
let startVoiceCaptureBody = functionBody(named: "startVoiceCapture", in: echo)
require(startVoiceCaptureBody.contains("prepareTencentProviderForUserCaptureIfNeeded()"), "starting a new user turn must clear Tencent provider audio before Fire/Volcengine opens the microphone")
require(startVoiceCaptureBody.contains("asyncAfter(deadline: .now() + 0.35)"), "Fire/Volcengine capture should be delayed briefly after Tencent provider audio is interrupted")
let prepareUserCaptureBody = functionBody(named: "prepareTencentProviderForUserCaptureIfNeeded", in: echo)
require(prepareUserCaptureBody.contains("tencentDigitalHumanAudioRouteReserved"), "Tencent provider capture prep must only run while Tencent owns the audio route")
require(prepareUserCaptureBody.contains("setRemoteAudioMuted(true)"), "Tencent provider capture prep must mute remote provider audio before Fire/Volcengine opens the microphone")
require(prepareUserCaptureBody.contains("digitalHumanRuntime.interrupt()"), "Tencent provider capture prep should interrupt only remote provider playback before opening the microphone")
require(prepareUserCaptureBody.contains("provider view preserved"), "Tencent provider capture prep should log that the provider view/session is preserved")
require(!prepareUserCaptureBody.contains("digitalHumanRuntime.close"), "Tencent provider capture prep must not close the provider session")
require(!prepareUserCaptureBody.contains("removeHostedProviderView"), "Tencent provider capture prep must not remove the hosted provider view")
let configureVoiceRuntimeBody = functionBody(named: "configureVoiceRuntimeThenStart", in: echo)
require(configureVoiceRuntimeBody.contains("sendsGreeting: !self.routeEchoAudioThroughDigitalHuman"), "Tencent mode must start Fire/Volcengine capture without a Fire greeting")
let localFallbackBody = functionBody(named: "startDialogWithLocalVoiceFallback", in: echo)
require(localFallbackBody.contains("sendsGreeting: !routeEchoAudioThroughDigitalHuman"), "Tencent local fallback capture must also skip Fire greeting while Tencent owns audio")
let viewWillAppearBody = functionBody(named: "viewWillAppear", in: echo)
require(viewWillAppearBody.contains("shouldShowDigitalHumanLivePanel"), "Echo view appearance should explicitly account for digital-human audio ownership before DialogEngine setup")
require(viewWillAppearBody.contains("setLocalTTSPlaybackEnabled(false)"), "Echo must disable Fire/Volcengine local TTS before prewarming DialogEngine on the digital-human page")
let cloudOpenBody = functionBody(named: "open", in: cloudRuntime)
require(cloudOpenBody.contains("case .connecting, .ready, .buffering, .speaking"), "Tencent runtime open must be idempotent while a stream is connecting or active")
require(cloudOpenBody.contains("ignored duplicate open"), "Tencent runtime must log duplicate open suppression for stream-in-progress diagnosis")
let cloudInterruptBody = functionBody(named: "interrupt", in: cloudRuntime)
require(cloudInterruptBody.contains("case .buffering, .speaking"), "Tencent runtime must only send provider interrupt while text/audio is actually in flight")
require(cloudInterruptBody.contains("ignored provider interrupt"), "Tencent runtime must ignore interrupt requests in ready/TextOver states instead of failing the route")
let cloudRemoteMuteBody = functionBody(named: "setRemoteAudioMuted", in: cloudRuntime)
require(cloudRemoteMuteBody.contains("bridge.setRemoteAudioMuted(muted)"), "Tencent runtime must delegate remote audio mute to the SDK bridge")
require(cloudRuntime.contains("setRemoteAudioMuted(false)") && cloudRuntime.contains("sendTextChunk"), "Tencent runtime must unmute remote audio before provider speech")
let cloudBridgeEventBody = functionBody(named: "handleBridgeEvent", in: cloudRuntime)
require(cloudBridgeEventBody.contains("isNonFatalInterruptRejection"), "Tencent runtime must treat TextOver interrupt rejection as non-fatal")
let cloudInterruptRejectionBody = functionBody(named: "isNonFatalInterruptRejection", in: cloudRuntime)
require(cloudInterruptRejectionBody.contains("110015") && cloudInterruptRejectionBody.contains("interrupt"), "Tencent runtime must identify provider interrupt timing rejection by provider code/message")

require(dialogEngine.contains("SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL"), "DialogEngine must be able to disable local player creation when Tencent owns audio")
require(dialogEngine.contains("SE_PARAMS_KEY_FULLLINK_DISABLE_TTS_BOOL"), "DialogEngine must disable Fire/Volcengine full-link TTS when Tencent owns audio")
require(dialogEngine.contains("fullLinkDisableTTS=\\(!config.enablePlayer)"), "DialogEngine logs must expose the full-link TTS ownership switch")
require(dialogEngine.contains("StartEngine omits Fire TTS config"), "DialogEngine must omit Fire TTS config when Tencent owns audible playback")
require(dialogEngine.contains("if config.enablePlayer") && dialogEngine.contains("startConfig[\"tts\"]"), "DialogEngine must only request Fire TTS when local Fire playback is enabled")
require(dialogEngine.contains("skipped Fire TTS sentence start") && dialogEngine.contains("skipped Fire TTS ended"), "DialogEngine must suppress Fire TTS callbacks when Tencent owns playback")
let configureAudioSessionBody = functionBody(named: "configureAudioSession", in: dialogEngine)
require(configureAudioSessionBody.contains("session.category != .playAndRecord") && configureAudioSessionBody.contains("session.mode != .voiceChat"), "DialogEngine audio session setup must avoid category churn when Tencent stream is open")
require(dialogEngine.contains("skip AudioSession restore; external digital-human TTS owns playback"), "DialogEngine stop must avoid restoring the audio session while Tencent may speak")
require(bridge.contains("virtualman.sendText(TextParams"), "Tencent bridge must use exact text driving for Echo replies")
require(bridge.contains("virtualman.stop()"), "Tencent bridge still needs a hard provider interrupt for timeout/page-exit cases")
require(bridge.contains("setRemoteAudioMuted") && bridge.contains("muteRemoteAudio") && bridge.contains("muteAllRemoteAudio"), "Tencent bridge must expose TRTC remote audio mute without closing the provider view")
require(releaseRegression.contains("tencent-digital-human-audio-owner-stop-semantics-check.swift"), "release regression should run Tencent audio owner stop semantics guard")

print("tencent-digital-human-audio-owner-stop-semantics-check passed")
