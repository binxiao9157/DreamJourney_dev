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

let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let webHTML = read("DreamJourney/Resources/web/DigitalHumanLive.html")
let miniLive = read("DreamJourney/Resources/web/MiniLive2.js")
let panelView = read("DreamJourney/Sources/Modules/Echo/DigitalHumanLivePanelView.swift")
let audioMeter = read("DreamJourney/Sources/Modules/Echo/DigitalHumanAudioLevelMeter.swift")
let lipSyncTimeline = read("DreamJourney/Sources/Modules/Echo/DigitalHumanLipSyncTimeline.swift")
let memoirTTS = read("DreamJourney/Sources/Memoir/MemoirTTSService.swift")

assertContains(featureFlags, "case digitalHumanLivePanel", "Digital human live panel should have an explicit feature flag")
assertContains(featureFlags, ".digitalHumanLivePanel,", "Digital human live panel should be enabled in the default public release")

assertContains(echo, "DigitalHumanLivePanelView", "Echo should own the live panel view")
assertContains(echo, "return FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "Echo should show the digital human panel from the public feature flag, not from QA-only launch args")
assertContains(echo, "数字人回响", "Echo should expose a public digital-human entry/status label")
assertContains(echo, "素材已授权", "Echo should explain digital-human asset authorization")
assertContains(echo, "自动回到普通回响", "Echo should explain fallback to ordinary Echo when the renderer is unavailable")
assertContains(echo, "cachedLipSyncTimelineForEchoReply", "Echo should prefer cached real TTS viseme timeline before playback fallback")
assertContains(echo, "MemoirTTSService.shared.getCachedLipSyncTimeline", "Echo should consume MemoirTTSService cached viseme timelines")
assertContains(echo, "DJShowDigitalHumanLivePanel", "Echo should keep legacy QA launch argument compatibility")
assertContains(echo, "DJRunDigitalHumanLivePanelSmoke", "Echo should support smoke launch argument")
assertContains(echo, "FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "Echo should require the feature flag")
assertContains(echo, "runUIQADigitalHumanLivePanelSmoke", "Echo should expose UIQA smoke driver")
assertContains(echo, "setInteractionState", "Echo should forward state to digital human panel")
assertContains(echo, "digitalHumanAudioLevelMeter", "Echo should own a digital human audio level meter")
assertContains(echo, "startSDKTTSPlaybackFallback", "Echo should connect SDK TTS started events to the panel without claiming player metering")
assertContains(echo, "stopDigitalHumanAudioLevelMetering", "Echo should stop panel metering when TTS finishes")
assertContains(echo, "startUIQAMeteredPlayback", "Echo smoke should drive real AVAudioPlayer metering")
assertContains(echo, "startUIQAMockVisemeTimeline", "Echo smoke should drive mock provider viseme timeline")
assertContains(echo, "DJDigitalHumanLipSyncProviderVisemeTimeline", "Echo smoke should expose provider timeline QA mode")
assertNotContains(echo, "return requested && FeatureFlagService.shared.isEnabled(.digitalHumanLivePanel)", "Digital human panel must not remain QA-only")
assertNotContains(echo, "startSimulatedAudioLevels", "Echo must not drive mouth movement with simulated amplitude")
assertNotContains(echo, "stopSimulatedAudioLevels", "Echo must not depend on simulated audio timers")

assertContains(appDelegate, "DJRunDigitalHumanLivePanelSmoke", "AppDelegate should wire the smoke launch argument")
assertContains(appDelegate, "FeatureFlagService.shared.set(.digitalHumanLivePanel, enabled: true)", "Smoke should enable flag only in QA path")
assertContains(appDelegate, "runDigitalHumanLivePanelSmoke", "AppDelegate should run the digital human smoke")

assertContains(project, "DigitalHumanLive.html in Resources", "Digital human HTML wrapper should be bundled")
assertContains(project, "DigitalHumanLivePanelView.swift", "Digital human panel Swift source should be in target")
assertContains(project, "DigitalHumanAudioLevelMeter.swift in Sources", "Digital human audio meter should be compiled into the app target")
assertContains(project, "DigitalHumanLipSyncTimeline.swift in Sources", "Digital human lip-sync timeline contract should be compiled into the app target")

assertContains(webHTML, "window.DreamJourneyDigitalHuman", "HTML wrapper should expose a stable bridge")
assertContains(webHTML, "setState", "HTML bridge should accept state")
assertContains(webHTML, "setAudioLevel", "HTML bridge should accept audio level")
assertContains(webHTML, "setVisemeTimeline", "HTML bridge should accept provider viseme timelines")
assertContains(webHTML, "setMouthShape", "HTML bridge should accept direct mouth shape updates")
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
assertNotContains(panelView, "startSimulatedAudioLevels", "Panel view must not own simulated audio amplitude")
assertNotContains(panelView, "simulatedAudioTimer", "Panel view must not keep simulated audio timers")

assertContains(audioMeter, "AVAudioPlayer", "Audio meter should use AVAudioPlayer for real playback metering")
assertContains(audioMeter, "isMeteringEnabled = true", "Audio meter should enable AVAudioPlayer metering")
assertContains(audioMeter, "averagePower", "Audio meter should read player average power")
assertContains(audioMeter, "avAudioPlayerMetering", "Audio meter should label real player metering source")
assertContains(audioMeter, "sdkTTSPlaybackFallback", "Audio meter should label SDK fallback separately")
assertContains(audioMeter, "makeUIQAMeteringProbeAudioURL", "Audio meter should provide deterministic UIQA metered audio")

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
