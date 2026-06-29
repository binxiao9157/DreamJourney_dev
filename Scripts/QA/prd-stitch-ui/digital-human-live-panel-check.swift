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
        fatalError("\(message): unexpected \(needle)")
    }
}

func assertOccurrenceCount(_ haystack: String, _ needle: String, _ expectedCount: Int, _ message: String) {
    var searchRange = haystack.startIndex..<haystack.endIndex
    var count = 0
    while let range = haystack.range(of: needle, range: searchRange) {
        count += 1
        searchRange = range.upperBound..<haystack.endIndex
    }
    guard count == expectedCount else {
        fatalError("\(message): expected \(expectedCount), got \(count) for \(needle)")
    }
}

let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let dialogEngine = read("DreamJourney/Sources/Services/DialogEngineManager.swift")
let podfile = read("Podfile")
let podfileLock = read("Podfile.lock")
let podsDreamJourneyDebug = read("Pods/Target Support Files/Pods-DreamJourney/Pods-DreamJourney.debug.xcconfig")
let podsDreamJourneyRelease = read("Pods/Target Support Files/Pods-DreamJourney/Pods-DreamJourney.release.xcconfig")
let digitalHumanRuntime = read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift")
let tencentRuntime = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let tencentBridgeContract = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift")
let tencentBridge = read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let webHTML = read("DreamJourney/Resources/web/DigitalHumanLive.html")
let miniLive = read("DreamJourney/Resources/web/MiniLive2.js")
let panelView = read("DreamJourney/Sources/Modules/Echo/DigitalHumanLivePanelView.swift")
let audioMeter = read("DreamJourney/Sources/Modules/Echo/DigitalHumanAudioLevelMeter.swift")
let lipSyncTimeline = read("DreamJourney/Sources/Modules/Echo/DigitalHumanLipSyncTimeline.swift")
let memoirTTS = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")
let conversationCoordinator = read("DreamJourney/Sources/Modules/Echo/DigitalHumanConversationCoordinator.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")

let defaultEnabledStart = featureFlags.range(of: "private static let defaultEnabled")!.lowerBound
let defaultEnabledEnd = featureFlags.range(of: "private static let nonPersistentFeatures")!.lowerBound
let defaultEnabledBlock = String(featureFlags[defaultEnabledStart..<defaultEnabledEnd])

assertContains(featureFlags, "case digitalHumanLivePanel", "Digital human live panel should have an explicit feature flag")
assertContains(defaultEnabledBlock, ".digitalHumanLivePanel", "Digital human live panel should be visible in the default public release")

assertContains(echo, "DigitalHumanLivePanelView", "Echo should own the live panel view")
assertContains(echo, "FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "Echo should show the digital human panel from the public feature flag")
assertContains(backendClient, "var isDigitalHumanSessionConfigured", "Backend client should expose an explicit digital-human session configuration gate")
assertContains(echo, "DreamJourneyBackendClient.shared.isDigitalHumanSessionConfigured", "Echo should not fetch digital-human runtime config without an explicit backend")
assertContains(echo, "skipped cloud runtime; backend not configured", "Echo release smoke should log quiet digital-human fallback when backend is not configured")
assertContains(echo, "DJDisableDigitalHumanLivePanel", "Echo should keep an explicit troubleshooting launch argument to suppress the public panel")
assertContains(echo, "数字人回响", "Echo should preserve digital-human entry/status label copy")
assertContains(echo, "素材已授权", "Echo should explain digital-human asset authorization")
assertContains(echo, "自动回到普通回响", "Echo should explain fallback to ordinary Echo when the renderer is unavailable")
assertContains(echo, "cachedLipSyncTimelineForEchoReply", "Echo should prefer cached real TTS viseme timeline before playback fallback")
assertContains(echo, "MemoirTTSService.shared.getCachedLipSyncTimeline", "Echo should consume MemoirTTSService cached viseme timelines")
assertContains(echo, "DJShowDigitalHumanLivePanel", "Echo should keep legacy QA launch argument compatibility")
assertContains(echo, "DJRunDigitalHumanLivePanelSmoke", "Echo should support smoke launch argument")
assertContains(echo, "DJRunTencentDigitalHumanTextDriveSmoke", "Echo should support true-device Tencent text-drive smoke launch argument")
assertContains(echo, "DJRunTencentDigitalHumanPCMDriveSmoke", "Echo should support true-device Tencent PCM audio-drive smoke launch argument")
assertContains(echo, "DJRunTencentDigitalHumanBackendPCMDriveSmoke", "Echo should support true-device backend Tencent PCM audio-drive smoke launch argument")
assertContains(echo, "FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "Echo should keep the public feature flag as the default visibility source")
assertContains(echo, "runUIQADigitalHumanLivePanelSmoke", "Echo should expose UIQA smoke driver")
assertOccurrenceCount(echo, "setLocalPreviewEnabled(true)", 1, "Legacy local digital-human preview should only be enabled by the explicit UIQA smoke path")
assertContains(echo, "setInteractionState", "Echo should forward state to digital human panel")
assertContains(echo, "digitalHumanAudioLevelMeter", "Echo should own a digital human audio level meter")
assertContains(echo, "startSDKTTSPlaybackFallback", "Echo should connect SDK TTS started events to the panel without claiming player metering")
assertContains(echo, "stopDigitalHumanAudioLevelMetering", "Echo should stop panel metering when TTS finishes")
assertContains(echo, "scheduleDigitalHumanReplyPrewarm", "Echo should prewarm Tencent digital human reply text from chat streaming before TTS starts only when Tencent owns audible audio")
assertContains(echo, "cancelDigitalHumanReplyPrewarm", "Echo should cancel pending digital human prewarm work on turn changes")
assertContains(echo, "digitalHumanConversation.isDuplicateReply", "Echo should dedupe digital human reply text across streaming prewarm and TTS fallback through the coordinator")
assertContains(conversationCoordinator, "lastReplyTextSent", "Digital human coordinator should own provider reply dedupe state")
assertContains(echo, "source: \"chatStreamingPrewarm\"", "Echo should label digital human prewarm source for true-device log ordering")
assertContains(echo, "source: \"ttsStartedFallback\"", "Echo should keep TTS-started digital human fallback source for true-device log ordering")
assertContains(echo, "skipped streaming prewarm; waiting for SDK TTS sentence text", "Tencent-owned digital human speech should not pause DialogEngine during chat streaming")
assertNotContains(echo, "streaming complete sentence prewarm", "Tencent-owned digital human speech must not prewarm from chat streaming because that pauses upstream generation")
assertContains(echo, "routeEchoAudioThroughDigitalHuman", "Echo should centralize the decision for whether a digital-human provider owns audio")
assertContains(echo, "shouldDriveTencentVisualLipSync", "Echo should let Tencent render visual lip-sync even when local Echo TTS owns audible audio")
assertContains(echo, "shouldDispatchEchoReplyToTencentProvider", "Echo should send reply text to Tencent only when Tencent owns proven audible provider routing")
assertNotContains(echo, "shouldDriveTencentLipSyncWithLocalAudio", "Tencent local-audio visual-only mode is not the chosen route")
assertNotContains(echo, "sendEchoAudioChunkToDigitalHumanRuntimeIfReady", "Echo should not feed Volcengine TTS chunks into Tencent sendAudio")
assertNotContains(echo, "digitalHumanAudioDriveRequestID", "Echo should not keep Tencent audio-drive request state for the text-drive route")
assertContains(echo, "tencentCloudRenderProvidesAudibleTTS", "Echo should keep Tencent audio routing behind an explicit audible TTS capability gate")
assertContains(echo, "return true", "Echo should make Tencent cloud-render the single audible owner in digital-human mode")
assertContains(echo, "tencentDigitalHumanProviderCanOwnAudio", "Echo should route audio to Tencent only after the provider is ready or already speaking")
assertContains(echo, "case .ready, .buffering, .speaking", "Echo should keep Tencent audio ownership during ready/buffering/speaking states only")
assertContains(echo, "腾讯数智人负责声音与口型同步", "Echo should tell QA that Tencent owns digital-human voice and lip-sync")
assertContains(echo, "digitalHumanConversation.beginProviderRequest", "Echo should track provider-owned speech through the digital-human coordinator until Tencent TextOver")
assertContains(conversationCoordinator, "pendingReplyText", "Digital human coordinator should own provider-owned pending reply text")
assertContains(conversationCoordinator, "activeRequestID", "Digital human coordinator should own Tencent stream text ReqId until provider TextOver")
assertContains(conversationCoordinator, "currentTurnID", "Digital human coordinator should keep a per-turn trace id for Tencent digital-human logs")
assertContains(echo, "turnID=", "Tencent digital-human logs should include the Echo turn id")
assertContains(echo, "requestID=", "Tencent digital-human logs should include the provider request id")
assertContains(echo, "digitalHumanProviderTextOverTimeoutWorkItem", "Echo should own a cancellable Tencent TextOver timeout")
assertContains(echo, "tencentDigitalHumanTextOverTimeout", "Echo should keep an explicit Tencent TextOver timeout duration")
assertContains(echo, "scheduleTencentDigitalHumanTextOverTimeout(requestID:", "Echo should schedule a timeout after sending provider text")
assertContains(echo, "cancelTencentDigitalHumanTextOverTimeout", "Echo should cancel provider TextOver timeout on normal completion or cleanup")
assertContains(echo, "handleTencentDigitalHumanTextOverTimeout(requestID:", "Echo should recover if Tencent TextOver never arrives")
assertContains(echo, "digitalHumanConversation.activeRequestID == requestID", "Tencent TextOver timeout should only recover the still-active request")
assertContains(echo, "TextOver timeout", "Tencent TextOver timeout should be visible in true-device logs")
assertContains(echo, "runTencentDigitalHumanTextDriveSmokeIfNeeded", "Echo should provide a deterministic true-device Tencent text-drive smoke")
assertContains(echo, "source: \"trueDeviceTextDriveSmoke\"", "True-device Tencent smoke should tag provider text logs")
assertContains(echo, "degradeTencentDigitalHumanRoute(reason:", "Echo should have a single hard-fallback path that removes the failed Tencent runtime")
assertContains(echo, "digitalHumanRuntime = nil", "Tencent fallback should remove the failed runtime so routeEchoAudioThroughDigitalHuman becomes false")
assertContains(echo, "digitalHumanLivePanelView?.removeHostedProviderView(showFallbackMessage:", "Tencent fallback should remove the provider view without re-exposing bundled preview assets")
assertContains(echo, "completeTencentDigitalHumanReplyIfNeeded", "Echo should finish provider-owned replies from Tencent runtime state")
assertContains(echo, "interruptDigitalHumanPlayback(reason:", "Echo should stop Tencent provider audio together with Echo stop")
assertContains(echo, "pauseDialogEngineForTencentProviderSpeechIfNeeded", "Echo should pause DialogEngine before Tencent provider-owned speech")
assertContains(echo, "prepareAudioSessionForTencentProviderPlayback(preserveRecordingCategory:", "Echo should prepare an AVAudioSession route before Tencent provider speech")
assertContains(echo, "preserveRecordingCategory", "Echo should preserve the recording category after pausing DialogEngine to avoid Tencent TRTC audio restarts")
assertContains(echo, "AVAudioSession prepared for provider playback", "Echo true-device logs should show the provider playback audio route handoff")
assertContains(echo, "resumeDialogEngineAfterTencentProviderSpeechIfNeeded", "Echo should centralize Tencent TextOver cleanup")
assertContains(echo, "resumed DialogEngine listening after provider speech", "Echo should reopen listening after Tencent TextOver until the user taps stop")
assertContains(echo, "DialogEngine paused for provider speech", "Echo should suppress ordinary dialog-ended cleanup while Tencent owns speech playback")
assertContains(echo, "tencentDigitalHumanDialogResumeDelay", "Echo should delay resumed listening until Tencent audio playback has time to settle")
assertContains(echo, "skipped new request while provider is speaking", "Echo should not send a new Tencent stream text ReqId while the previous provider speech is still active")
assertContains(echo, "preserveTencentProviderSessionAfterLocalDialogStop(reason: \"userSpeechFinal\")", "Echo should preserve the Tencent provider session when a new user turn arrives")
assertContains(echo, "self.hasTencentDigitalHumanProviderSpeechInFlight", "Echo should interrupt Tencent provider speech on a new user turn whenever a stream ReqId is still active")
assertContains(conversationCoordinator, "hasProviderSpeechInFlight", "Digital human coordinator should expose provider speech in-flight state")
assertContains(echo, "waiting for provider TextOver before finishing Echo reply", "Echo should not finish provider-owned replies on local TTS end")
assertContains(echo, "setLocalTTSPlaybackEnabled(false)", "Echo should disable Volcengine local TTS playback when Tencent owns audible speech")
assertContains(echo, "setLocalTTSPlaybackEnabled(true)", "Echo should restore Volcengine local TTS playback outside the Tencent digital-human route")
assertContains(echo, "startUIQAMeteredPlayback", "Echo smoke should drive real AVAudioPlayer metering")
assertContains(echo, "startUIQAMockVisemeTimeline", "Echo smoke should drive mock provider viseme timeline")
assertContains(echo, "DJDigitalHumanLipSyncProviderVisemeTimeline", "Echo smoke should expose provider timeline QA mode")
assertContains(echo, "DJShowDigitalHumanLivePanel", "Digital human panel should keep QA launch argument compatibility")
assertNotContains(echo, "startSimulatedAudioLevels", "Echo must not drive mouth movement with simulated amplitude")
assertNotContains(echo, "stopSimulatedAudioLevels", "Echo must not depend on simulated audio timers")

assertContains(appDelegate, "DJRunDigitalHumanLivePanelSmoke", "AppDelegate should wire the smoke launch argument")
assertContains(appDelegate, "DJRunTencentDigitalHumanTextDriveSmoke", "AppDelegate should wire the true-device Tencent text-drive smoke launch argument")
assertContains(appDelegate, "DJRunTencentDigitalHumanPCMDriveSmoke", "AppDelegate should wire the true-device Tencent PCM audio-drive smoke launch argument")
assertContains(appDelegate, "DJRunTencentDigitalHumanBackendPCMDriveSmoke", "AppDelegate should wire the true-device backend Tencent PCM audio-drive smoke launch argument")
assertContains(featureFlags, "func enableForCurrentLaunch(_ feature: DJFeature)", "Feature flags should support launch-scoped QA enabling")
assertContains(appDelegate, "FeatureFlagService.shared.enableForCurrentLaunch(.digitalHumanLivePanel)", "Smoke should enable the digital human flag only for the current launch")
assertContains(appDelegate, "runDigitalHumanLivePanelSmoke", "AppDelegate should run the digital human smoke")

assertContains(project, "DigitalHumanLive.html in Resources", "Digital human HTML wrapper should be bundled")
assertContains(project, "DigitalHumanLivePanelView.swift", "Digital human panel Swift source should be in target")
assertContains(project, "DigitalHumanAudioLevelMeter.swift in Sources", "Digital human audio meter should be compiled into the app target")
assertContains(project, "DigitalHumanLipSyncTimeline.swift in Sources", "Digital human lip-sync timeline contract should be compiled into the app target")
assertContains(project, "DigitalHumanConversationCoordinator.swift in Sources", "Digital human conversation coordinator should be compiled into the app target")

assertContains(webHTML, "window.DreamJourneyDigitalHuman", "HTML wrapper should expose a stable bridge")
assertContains(webHTML, "setState", "HTML bridge should accept state")
assertContains(webHTML, "setAudioLevel", "HTML bridge should accept audio level")
assertContains(webHTML, "setVisemeTimeline", "HTML bridge should accept provider viseme timelines")
assertContains(webHTML, "setMouthShape", "HTML bridge should accept direct mouth shape updates")
assertContains(webHTML, "setProviderMode", "HTML bridge should disable local renderer while a real provider view is hosted")
assertContains(webHTML, "setLocalPreviewEnabled", "HTML bridge should keep bundled preview assets opt-in so public startup never flashes the local placeholder avatar")
assertContains(webHTML, "localPreviewEnabled", "HTML bridge should track whether local preview assets are explicitly enabled")
assertContains(webHTML, "state.providerMode", "HTML bridge should track provider mode")
assertContains(webHTML, "audioLevelSource", "HTML snapshot should report the audio level source")
assertContains(webHTML, "lipSyncSource", "HTML snapshot should report the lip-sync source")
assertContains(webHTML, "currentMouthShape", "HTML snapshot should report the current mouth shape")
assertContains(webHTML, "lipSyncFrameCount", "HTML snapshot should report timeline frame count")
assertContains(webHTML, "snapshot", "HTML bridge should expose snapshot")
assertContains(webHTML, "MiniLive2.js", "HTML wrapper should load existing renderer script")
assertContains(webHTML, "DHLiveMini.js", "HTML wrapper should load existing wasm loader script")
assertContains(webHTML, "01.mp4", "HTML wrapper should declare the bundled real digital human video asset")
assertContains(webHTML, "combined_data.json.gz", "HTML wrapper should declare the bundled real digital human motion data")
assertContains(miniLive, "videoSrc: \"01.mp4\"", "Renderer config should match Xcode's flattened app bundle resource path")
assertContains(miniLive, "dataSrc: \"combined_data.json.gz\"", "Renderer motion config should match Xcode's flattened app bundle resource path")
assertContains(webHTML, "hasRealDigitalHumanAsset", "HTML snapshot should report that the real digital human asset is available")
assertNotContains(webHTML, "fallbackAvatar", "HTML wrapper must not render a fake fallback avatar")
assertNotContains(webHTML, "class=\"head\"", "HTML wrapper must not draw a fake avatar head")
assertNotContains(webHTML, "class=\"mouth\"", "HTML wrapper must not draw fake mouth graphics")

assertContains(panelView, "audioLevelSource", "Panel snapshot should carry audio level source")
assertContains(panelView, "lipSyncSource", "Panel snapshot should carry lip-sync source")
assertContains(panelView, "currentMouthShape", "Panel snapshot should carry current mouth shape")
assertContains(panelView, "lipSyncFrameCount", "Panel snapshot should carry timeline frame count")
assertContains(panelView, "setVisemeTimeline", "Panel should forward provider viseme timelines")
assertContains(panelView, "setMouthShape", "Panel should forward direct mouth shape updates")
assertContains(panelView, "setProviderModeEnabled(true)", "Panel should disable the local HTML renderer when Tencent provider view is hosted")
assertContains(panelView, "setLocalPreviewEnabled(_ enabled: Bool)", "Panel should expose local preview as an explicit QA-only opt-in")
assertContains(panelView, "showProviderPlaceholder", "Panel should show a neutral placeholder while Tencent connects instead of exposing local preview assets")
assertContains(panelView, "webView.alpha = 0", "Panel should make the local Web renderer fully transparent while provider view is hosted")
assertContains(panelView, "isUserInteractionEnabled = false", "Full-screen digital human render layer must pass touches through to Echo controls")
assertContains(panelView, "providerView.isUserInteractionEnabled = false", "Hosted Tencent provider view must not intercept Echo controls")
assertContains(panelView, "fallbackLabel.isUserInteractionEnabled = false", "Fullscreen digital human placeholder must not intercept Echo controls")
assertNotContains(panelView, "webView.isUserInteractionEnabled = enabled", "Local preview must not re-enable touch interception inside the fullscreen digital human render layer")
assertNotContains(panelView, "startSimulatedAudioLevels", "Panel view must not own simulated audio amplitude")
assertNotContains(panelView, "simulatedAudioTimer", "Panel view must not keep simulated audio timers")

assertContains(audioMeter, "AVAudioPlayer", "Audio meter should use AVAudioPlayer for real playback metering")
assertContains(audioMeter, "isMeteringEnabled = true", "Audio meter should enable AVAudioPlayer metering")
assertContains(audioMeter, "averagePower", "Audio meter should read player average power")
assertContains(audioMeter, "avAudioPlayerMetering", "Audio meter should label real player metering source")
assertContains(audioMeter, "sdkTTSPlaybackFallback", "Audio meter should label SDK fallback separately")
assertContains(audioMeter, "makeUIQAMeteringProbeAudioURL", "Audio meter should provide deterministic UIQA metered audio")

assertContains(dialogEngine, "func setLocalTTSPlaybackEnabled", "DialogEngine should expose a local TTS playback switch for digital human sync")
assertContains(dialogEngine, "SE_PARAMS_KEY_DIALOG_ENABLE_PLAYER_BOOL", "DialogEngine should wire the playback switch into SpeechEngine player config")
assertContains(dialogEngine, "config.enablePlayer = enabled", "DialogEngine playback switch should update the active configuration")
assertContains(dialogEngine, "SE_PARAMS_KEY_PREVENT_PLAYER_CREATION_BOOL", "DialogEngine should prevent SpeechEngine player creation when Tencent owns audible digital-human playback")
assertContains(dialogEngine, "AudioSession active for external digital-human TTS playback", "DialogEngine should keep AVAudioSession active even when Tencent cloud render owns audio")
assertContains(dialogEngine, "try session.setActive(true)", "DialogEngine should explicitly activate AVAudioSession for Tencent remote audio playback")
assertContains(dialogEngine, "skip AudioSession restore; external digital-human TTS owns playback", "DialogEngine should not restore AVAudioSession while Tencent cloud render may still be speaking")
assertContains(dialogEngine, "startDialog(sendsGreeting: Bool = true)", "DialogEngine should support resumed listening without a greeting after Tencent provider speech")
assertContains(dialogEngine, "suppressGreetingForNextStart", "DialogEngine should remember when the next resumed start must skip greeting")
assertContains(dialogEngine, "skipped greeting for resumed digital-human listening", "DialogEngine should log skipped greeting on resumed digital-human listening")
assertContains(dialogEngine, "case SEEventTTSSentenceEnd", "DialogEngine should forward real TTS sentence text from SpeechEngine 3009 events")
assertContains(dialogEngine, "数字人主音频模式依赖这里的文本转交给腾讯云渲染", "DialogEngine should document why SentenceEnd text is used for Tencent-owned audio")
assertNotContains(dialogEngine, "func onTTSAudioChunk(data: Data, isFinal: Bool)", "DialogEngine should not expose Volcengine TTS chunks to Tencent in the text-drive route")
assertNotContains(dialogEngine, "forwardTTSAudioChunkIfNeeded", "DialogEngine should not forward binary TTS response chunks into Tencent sendAudio")

assertContains(digitalHumanRuntime, "var onStateChange", "Digital human runtime should expose state changes to Echo")
assertContains(tencentRuntime, "handleBridgeEvent", "Tencent runtime should translate SDK bridge events into runtime state")
assertContains(tencentRuntime, "case .webSocketOpen", "Tencent runtime should become ready only after WebSocket open")
assertContains(tencentRuntime, "case .textStart", "Tencent runtime should mark TextStart as speaking")
assertContains(tencentRuntime, "case .textOver", "Tencent runtime should mark TextOver as ready")
assertContains(tencentBridge, "TencentDigitalHumanSDKBridgeEvent", "Tencent bridge should emit provider speech events")
assertContains(tencentBridgeContract, "case webSocketOpen", "Tencent bridge should expose WebSocket open before Echo sends text")
assertContains(tencentBridge, "SpeakStatus", "Tencent bridge should parse WebSocket speech status")
assertContains(tencentBridge, "TextStart", "Tencent bridge should detect provider speech start")
assertContains(tencentBridge, "TextOver", "Tencent bridge should detect provider speech end")
assertContains(tencentBridge, "eventHandler?(.webSocketOpen)", "Tencent bridge should notify runtime when WebSocket is open")
assertContains(tencentBridge, "import TXLiteAVSDK_TRTC", "Tencent bridge should compile against TRTC controls for remote-audio muting")
assertContains(tencentBridge, "setRemoteAudioMuted", "Tencent bridge should expose remote-audio mute without closing the provider view")
assertContains(tencentBridge, "muteRemoteAudio", "Tencent bridge should be able to mute the tracked remote provider user")
assertContains(tencentBridge, "muteAllRemoteAudio", "Tencent bridge should fall back to all-remote mute before the remote user id is known")
assertNotContains(tencentBridge, "enforceVisualOnlyAudioPolicy", "Tencent bridge should not rely on app-level visual-only TRTC muting")
assertNotContains(tencentBridge, "virtualman.chat(ChatParams", "Echo reply text should not enter Tencent project chat mode")
assertContains(tencentBridge, "virtualman.sendText(TextParams", "Complete Echo reply text should use Tencent exact text drive instead of Tencent project chat")
assertContains(tencentBridge, "sendStreamText", "Tencent bridge should retain direct stream text drive for true incremental text")
assertContains(tencentBridge, "Tencent text was rejected", "Tencent bridge should fail fast if complete text is rejected")
assertContains(tencentBridge, "Tencent stream text was rejected", "Tencent bridge should fail fast if stream text is rejected")
assertContains(tencentBridge, "virtualman.stop()", "Tencent bridge should stop provider playback before closing")
assertContains(podfile, "TXLiteAVSDK_TRTC", "VirtualmanStreamSDK requires TXLiteAVSDK_TRTC as a Swift module dependency")
assertContains(podfile, "stripTencentDigitalHumanRuntimeLinkage", "Pod install should strip the duplicate TXLiteAVSDK_TRTC runtime linkage from the app target")
assertContains(podfile, "TXLiteAVSDK_TRTC is compile-time only", "Podfile should document why the Tencent TRTC pod must not be linked into the app binary")
assertContains(podfileLock, "TXLiteAVSDK_TRTC", "Podfile.lock should keep the TRTC module required by VirtualmanStreamSDK")
assertNotContains(podsDreamJourneyDebug, "-framework \"TXLiteAVSDK_TRTC\"", "Debug app target must not link TXLiteAVSDK_TRTC because VirtualmanStreamSDK already contains those runtime classes")
assertNotContains(podsDreamJourneyRelease, "-framework \"TXLiteAVSDK_TRTC\"", "Release app target must not link TXLiteAVSDK_TRTC because VirtualmanStreamSDK already contains those runtime classes")

assertContains(lipSyncTimeline, "struct DigitalHumanLipSyncFrame", "Lip-sync contract should define frames")
assertContains(lipSyncTimeline, "struct DigitalHumanLipSyncTimeline", "Lip-sync contract should define timelines")
assertContains(lipSyncTimeline, "enum DigitalHumanPlaybackEvent", "Lip-sync contract should define playback events")
assertContains(lipSyncTimeline, "case avAudioPlayerMetering", "Lip-sync contract should support player metering source")
assertContains(lipSyncTimeline, "case sdkTTSPlaybackFallback", "Lip-sync contract should support SDK fallback source")
assertContains(lipSyncTimeline, "case providerVisemeTimeline", "Lip-sync contract should support provider viseme timelines")
assertContains(lipSyncTimeline, "makeUIQAMockProviderTimeline", "Lip-sync contract should provide deterministic mock timeline")
assertContains(lipSyncTimeline, "javaScriptLiteral", "Lip-sync timeline should safely serialize for the Web bridge")

assertContains(memoirTTS, "func getCachedLipSyncTimeline(forText text: String)", "Memoir TTS cache should expose text-matched viseme timelines for public Echo digital human playback")
assertContains(memoirTTS, "textHash(for: text)", "Memoir TTS cache lookup should match cached timelines by text hash")

let realAssetFiles = [
    "DreamJourney/Resources/web/assets/01.mp4",
    "DreamJourney/Resources/web/assets/combined_data.json.gz",
    "DreamJourney/Resources/web/common/bs_texture_halfFace.png"
]

for relativePath in realAssetFiles {
    let url = root.appendingPathComponent(relativePath)
    guard FileManager.default.fileExists(atPath: url.path) else {
        fatalError("Real digital human asset is missing: \(relativePath)")
    }
}

print("Digital human live panel checks passed")
