import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("digital-human-runtime-abstraction-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let runtime = try read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift")
let audioOnly = try read("DreamJourney/Sources/Services/DigitalHuman/AudioOnlyDigitalHumanRuntime.swift")
let tencentStub = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanRuntimeStub.swift")
let tencentUnavailable = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKRuntimeUnavailable.swift")
let runtimeFactory = try read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntimeFactory.swift")
let tencentBridge = try read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let featureFlags = try read("DreamJourney/Sources/App/FeatureFlagService.swift")
let appDelegate = try read("DreamJourney/Sources/AppDelegate.swift")
let echoViewController = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let livePanel = try read("DreamJourney/Sources/Modules/Echo/DigitalHumanLivePanelView.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(runtime.contains("protocol DigitalHumanRuntime"), "DigitalHumanRuntime protocol is missing")
require(runtime.contains("var contentView: UIView"), "runtime must expose a UIView contentView")
require(runtime.contains("DigitalHumanSessionState"), "session state enum is missing")
require(runtime.contains("DigitalHumanProfile"), "profile model is missing")
require(runtime.contains("func configure("), "configure contract is missing")
require(runtime.contains("func open()"), "open contract is missing")
require(runtime.contains("func sendTextChunk("), "stream text contract is missing")
require(runtime.contains("func sendPCMChunk("), "PCM audio contract is missing")
require(runtime.contains("func interrupt()"), "interrupt contract is missing")
require(runtime.contains("func close()"), "close contract is missing")
require(runtime.contains("case degraded"), "degraded state is required for Tencent fallback")
require(runtime.contains("case failed(code: String)"), "failed state must carry a code")

require(audioOnly.contains("final class AudioOnlyDigitalHumanRuntime"), "AudioOnly runtime is missing")
require(audioOnly.contains("DigitalHumanRuntime"), "AudioOnly runtime must implement protocol")
require(audioOnly.contains("state = .degraded"), "AudioOnly runtime should represent fallback/degraded mode")

require(tencentStub.contains("final class TencentDigitalHumanRuntimeStub"), "Tencent stub runtime is missing")
require(tencentStub.contains("DigitalHumanRuntime"), "Tencent stub must implement protocol")
require(tencentStub.contains("provider = \"tencent\""), "Tencent stub should identify provider")
require(!tencentStub.contains("Virtualman("), "stub must not instantiate Tencent SDK directly")

require(tencentUnavailable.contains("final class TencentDigitalHumanSDKRuntimeUnavailable"), "unavailable Tencent SDK runtime placeholder is missing")
require(tencentUnavailable.contains("DigitalHumanRuntime"), "unavailable Tencent SDK runtime must implement protocol")
require(tencentUnavailable.contains("Tencent SDK adapter is not linked"), "unavailable Tencent SDK runtime must explain missing adapter")
require(tencentUnavailable.contains("state = .degraded"), "unavailable Tencent SDK runtime should fail closed into degraded mode")
require(tencentUnavailable.contains("DigitalHumanRuntimeError.unsupportedOperation"), "unavailable Tencent SDK runtime should throw explicit unsupported errors")
require(!tencentUnavailable.contains("Virtualman"), "unavailable Tencent SDK runtime must not reference Tencent SDK symbols")
require(!tencentUnavailable.contains("TRTC"), "unavailable Tencent SDK runtime must not reference TRTC symbols")

require(runtimeFactory.contains("struct DigitalHumanRuntimeSelection"), "runtime factory must expose selection metadata")
require(runtimeFactory.contains("final class DigitalHumanRuntimeFactory"), "runtime factory is missing")
require(runtimeFactory.contains("sdkAdapterLinked"), "runtime factory must account for SDK adapter readiness")
require(runtimeFactory.contains("tencentSDK"), "runtime factory must reserve the real Tencent SDK provider mode")
require(runtimeFactory.contains("cloudRender"), "runtime factory must route deployed Tencent cloudRender sessions through the real SDK")
require(runtimeFactory.contains("realTencentProviderModes"), "runtime factory should keep Tencent real SDK provider modes explicit")
require(runtimeFactory.contains("Tencent SDK adapter is not linked"), "runtime factory must fail closed when real SDK is unavailable")
require(runtimeFactory.contains("AudioOnlyDigitalHumanRuntime"), "runtime factory must degrade to audio-only fallback")
require(runtimeFactory.contains("TencentDigitalHumanSDKRuntimeUnavailable"), "runtime factory must route future tencentSDK mode through the unavailable adapter until the SDK is linked")
require(project.contains("DigitalHumanRuntimeFactory.swift in Sources"), "runtime factory must be compiled into the app target")
require(project.contains("TencentDigitalHumanSDKRuntimeUnavailable.swift in Sources"), "unavailable Tencent SDK runtime must be compiled into the app target")
require(tencentBridge.contains("TextStart"), "Tencent bridge should translate provider TextStart into runtime speaking state")
require(tencentBridge.contains("WaitingTextOver"), "Tencent bridge should keep the runtime in speaking state while provider audio is waiting for TextOver")
require(tencentBridge.contains("SentenceStart"), "Tencent bridge should keep the runtime in speaking state during provider sentence playback")
require(tencentBridge.contains("SentenceNext"), "Tencent bridge should keep the runtime in speaking state between provider sentences")
require(tencentBridge.contains("TextOver"), "Tencent bridge should translate provider TextOver into runtime ready state")
require(appDelegate.contains("configureLaunchArgumentFeatureFlagsIfNeeded()"), "app delegate must process QA launch args outside the simulator-only harness")
require(appDelegate.contains("#if DEBUG || UI_QA_SIMULATOR"), "device QA launch args must be debug-gated")
require(appDelegate.contains("DJShowDigitalHumanLivePanel"), "device QA launch args should enable the digital human panel")
require(featureFlags.contains("private var transientEnabled"), "feature flags must support launch-scoped transient flags")
require(featureFlags.contains("private static let nonPersistentFeatures"), "feature flags must define non-persistent QA-only features")
require(featureFlags.contains("nonPersistentFeatures") && featureFlags.contains(".digitalHumanLivePanel"), "digital human panel must be classified as non-persistent")
require(featureFlags.contains("subtracting(Self.nonPersistentFeatures)"), "feature flag init must clean stale persisted QA-only flags")
require(featureFlags.contains("func enableForCurrentLaunch(_ feature: DJFeature)"), "feature flags must expose non-persistent QA launch enabling")
require(featureFlags.contains("enabled.contains(feature) || transientEnabled.contains(feature)"), "isEnabled must include transient launch flags")
let launchArgStart = appDelegate.range(of: "private func configureLaunchArgumentFeatureFlagsIfNeeded()")!.lowerBound
let launchArgEnd = appDelegate.range(of: "@objc private func handleUserDidLoginForPushDeviceToken")!.lowerBound
let launchArgBlock = String(appDelegate[launchArgStart..<launchArgEnd])
require(launchArgBlock.contains("FeatureFlagService.shared.enableForCurrentLaunch(.digitalHumanLivePanel)"), "device QA digital human launch arg must be transient")
require(!launchArgBlock.contains("FeatureFlagService.shared.set(.digitalHumanLivePanel"), "device QA digital human launch arg must not persist into UserDefaults")
require(echoViewController.contains("prepareCloudDigitalHumanRuntimeIfNeeded"), "Echo must prepare the backend-issued Tencent cloud runtime when the panel is enabled")
require(echoViewController.contains("fetchDigitalHumanRuntimeCapability"), "Echo should use /config/runtime capability before creating a Tencent SDK runtime")
require(echoViewController.contains("createDigitalHumanSession"), "Echo should create a backend-issued Tencent digital-human session")
require(echoViewController.contains("hostProviderView"), "Echo should attach the Tencent SDK provider view to the visible panel")
require(livePanel.contains("func hostProviderView"), "live panel should be able to host a real provider view")
require(livePanel.contains("digitalHumanLiveProviderView"), "hosted provider view should be identifiable for device QA")

let defaultEnabledStart = featureFlags.range(of: "private static let defaultEnabled")!.lowerBound
let defaultEnabledEnd = featureFlags.range(of: "private static let nonPersistentFeatures")!.lowerBound
let defaultEnabledRange = defaultEnabledStart..<defaultEnabledEnd
let defaultEnabledBlock = String(featureFlags[defaultEnabledRange])
require(defaultEnabledBlock.contains(".digitalHumanLivePanel"), "public Tencent digital human panel must be enabled by default")

print("digital-human-runtime-abstraction-check passed")
