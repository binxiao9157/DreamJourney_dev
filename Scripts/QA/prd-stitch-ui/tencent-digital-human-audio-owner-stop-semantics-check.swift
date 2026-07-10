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
    let privateSignature = source.range(of: "private func \(functionName)(")
    let internalSignature = source.range(of: "func \(functionName)(")
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
let conversationCoordinator = try read("DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift")
let dialogEngine = try read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let cloudRuntime = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let bridge = try read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let releaseRegression = try read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

let stopBody = functionBody(named: "stopVoiceCapture", in: echo)
require(echo.contains("private var shouldInterruptTencentDigitalHumanOnUserStop"), "Echo should explicitly include post-TextOver provider tail audio in the manual interrupt decision")
require(echo.contains("digitalHumanConversation.shouldInterruptOnUserStop"), "manual interrupt decision should be delegated to the digital-human conversation coordinator")
require(conversationCoordinator.contains("hasProviderSpeechInFlight ||") && conversationCoordinator.contains("shouldResumeAfterProviderSpeech"), "manual interrupt decision should cover both active provider speech and the post-TextOver resume handoff")
require(stopBody.contains("if hasTencentDigitalHumanProviderSpeechInFlight"), "manual stop should only use barge-in resume while Tencent provider speech is actively in flight")
require(stopBody.contains("if shouldInterruptTencentDigitalHumanOnUserStop"), "manual stop should distinguish interruptable Tencent provider audio from ordinary listening")
require(stopBody.contains("interruptDigitalHumanPlaybackForUserBargeIn()"), "manual stop during provider speech should use the user barge-in path")
require(stopBody.contains("interruptDigitalHumanPlayback(reason: \"userStop\")"), "manual stop during the post-TextOver resume handoff should interrupt Tencent tail audio and end the current conversation")
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
require(audioSessionBody.contains(".allowBluetoothHFP"), "Tencent playback prep should use the non-deprecated Bluetooth HFP audio-session option")
require(!audioSessionBody.contains(".allowBluetooth]") && !audioSessionBody.contains(".allowBluetooth,"), "Tencent playback prep must not use deprecated .allowBluetooth")
require(!audioSessionBody.contains("setCategory(.playback"), "Tencent playback prep must not switch to playback-only while the Tencent stream is open")

require(echo.contains("tencentDigitalHumanAudioRouteReserved"), "Echo must reserve Tencent audio ownership before the provider reaches ready")
require(echo.contains("case .preparing, .connecting, .ready, .buffering, .speaking"), "Tencent audio route must be reserved during preparing/connecting/ready/buffering/speaking states")
let routePolicyBody = functionBody(named: "applyEchoAudioRoutePolicy", in: echo)
require(routePolicyBody.contains("tencentDigitalHumanAudioRouteReserved"), "Echo route policy must use the reserved Tencent audio owner state")
require(routePolicyBody.contains("if !tencentDigitalHumanAudioRouteReserved"), "Echo route policy must not enable Fire/Volcengine local TTS while Tencent runtime is reserved")
let providerSpeechFinishBody = functionBody(named: "resumeDialogEngineAfterTencentProviderSpeechIfNeeded", in: echo)
require(
    providerSpeechFinishBody.contains("resumeVoiceCaptureAfterTencentProviderSpeech(")
        && providerSpeechFinishBody.contains("reason: reason")
        && providerSpeechFinishBody.contains("lifecycleToken: lifecycleToken"),
    "Tencent TextOver should hand off to the generation-guarded continuous-listening resume path"
)
require(!providerSpeechFinishBody.contains("resetToIdle()"), "Tencent TextOver should not return Echo to idle while the user has not tapped stop")
require(providerSpeechFinishBody.contains("resumed DialogEngine listening after provider speech"), "Tencent provider speech finish should log the continuous conversation decision")
let providerSpeechResumeBody = functionBody(named: "resumeVoiceCaptureAfterTencentProviderSpeech", in: echo)
require(providerSpeechResumeBody.contains("startDialog(sendsGreeting: false)"), "Tencent TextOver should reopen Fire/Volcengine ASR capture without a Fire greeting")
require(providerSpeechResumeBody.contains("viewModel.beginVoiceInteraction()"), "Tencent TextOver resume should put Echo back into listening state")
require(providerSpeechResumeBody.contains("muteTencentProviderRemoteAudioForUserCapture(reason: reason)"), "Tencent TextOver auto-resume must mute remote provider audio before reopening Fire/Volcengine ASR")
let muteProviderRemoteAudioBody = functionBody(named: "muteTencentProviderRemoteAudioForUserCapture", in: echo)
require(muteProviderRemoteAudioBody.contains("setRemoteAudioMuted(true)"), "Tencent user-capture mute helper must mute provider remote audio")
require(!muteProviderRemoteAudioBody.contains("interrupt()"), "Tencent TextOver auto-resume should not interrupt a ready provider session")
require(!muteProviderRemoteAudioBody.contains("close()"), "Tencent TextOver auto-resume must not close the provider session")
let textOverCompletionBody = functionBody(named: "completeTencentDigitalHumanReplyIfNeeded", in: echo)
require(textOverCompletionBody.contains("completion.replyText"), "Tencent TextOver completion must preserve reply text for speech-duration based resume delay")
require(textOverCompletionBody.contains("tencentDigitalHumanDialogResumeDelay(for: completion.replyText)"), "Tencent TextOver completion must wait based on estimated provider speech duration")
require(textOverCompletionBody.contains("resumeDelay="), "Tencent TextOver logs must expose the computed resume delay for true-device diagnosis")
require(echo.contains("tencentDigitalHumanPostTextOverResumeDelay: TimeInterval = 1.2"), "Tencent TextOver should use a short post-audio settle delay, not a full reply-duration delay")
require(!echo.contains("tencentDigitalHumanEstimatedCharactersPerSecond"), "Tencent TextOver auto-resume must not wait for the full estimated speech duration after TextOver")
require(!echo.contains("tencentDigitalHumanDialogResumeDelay: TimeInterval = 0.8"), "Tencent TextOver must not resume capture after a fixed 0.8s delay")
let renderBody = functionBody(named: "render", in: echo)
if let repliedStart = renderBody.range(of: "case .replied:")?.lowerBound,
   let errorStart = renderBody.range(of: "case .error", options: [], range: repliedStart..<renderBody.endIndex)?.lowerBound {
    let repliedBody = String(renderBody[repliedStart..<errorStart])
    require(repliedBody.contains("digitalHumanConversation.shouldResumeAfterProviderSpeech"), "Auto-resume replied UI should distinguish the short handoff state")
    require(repliedBody.contains("正在恢复聆听"), "Auto-resume replied UI should communicate that the conversation is still active")
    require(repliedBody.contains("systemName: \"stop.fill\""), "Auto-resume replied UI should show the active stop control, not a start-mic control")
    require(repliedBody.contains("accessibilityLabel: \"停止语音\""), "Auto-resume replied UI stop control should end the current continuous conversation")
    require(repliedBody.contains("setMicPulse(active: true)"), "Auto-resume replied UI should keep the active listening pulse during handoff")
} else {
    require(false, "render replied state could not be parsed")
}
let micTappedBody = functionBody(named: "micTapped", in: echo)
require(micTappedBody.contains("case .replied where digitalHumanConversation.shouldResumeAfterProviderSpeech"), "Tapping during Tencent auto-resume handoff should stop the conversation instead of looking like a fresh start")
require(micTappedBody.contains("stopVoiceCapture()"), "Auto-resume handoff stop action should reuse the normal stop path")
let chatStreamingBody = functionBody(named: "onChatStreaming", in: echo)
require(chatStreamingBody.contains("skipped streaming prewarm; waiting for SDK TTS sentence text"), "Tencent route should wait for SDK TTS/final sentence before provider speech")
require(!chatStreamingBody.contains("streaming complete sentence prewarm"), "Tencent route must not prewarm provider speech from streaming text")
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
let cloudForceInterruptBody = functionBody(named: "interruptPlaybackIfNeeded", in: cloudRuntime)
require(cloudForceInterruptBody.contains("case .ready, .buffering, .speaking"), "Tencent runtime must be able to stop audible provider tail audio after TextOver")
require(cloudForceInterruptBody.contains("bridge.interrupt()"), "Tencent forced playback interrupt must call provider stop")
let echoInterruptBody = functionBody(named: "interruptDigitalHumanPlayback", in: echo)
require(echoInterruptBody.contains("interruptPlaybackIfNeeded(reason: reason)"), "Echo manual stop must use Tencent forced playback interrupt for post-TextOver tail audio")
let echoUserBargeInBody = functionBody(named: "interruptDigitalHumanPlaybackForUserBargeIn", in: echo)
require(echoUserBargeInBody.contains("interruptDigitalHumanPlayback(reason: \"userBargeIn\")"), "User barge-in must interrupt Tencent provider speech")
require(
    echoUserBargeInBody.contains("resumeVoiceCaptureAfterTencentProviderSpeech(")
        && echoUserBargeInBody.contains("reason: \"userBargeIn\"")
        && echoUserBargeInBody.contains("lifecycleToken: lifecycleToken"),
    "User barge-in must resume microphone capture with the current lifecycle token"
)
require(echoUserBargeInBody.contains("asyncAfter(deadline: .now() + 0.45)"), "User barge-in should wait briefly for Tencent audio stop before reopening Fire/Volcengine capture")
let pcmSignalBody = functionBody(named: "sendPCMDriveSignalToDigitalHumanRuntime", in: echo)
require(!pcmSignalBody.contains("} catch {"), "PCM-drive scheduling must not keep an unreachable outer catch block")
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
