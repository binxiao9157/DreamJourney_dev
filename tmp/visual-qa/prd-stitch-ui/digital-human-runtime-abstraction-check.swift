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
let featureFlags = try read("DreamJourney/Sources/App/FeatureFlagService.swift")
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
require(runtimeFactory.contains("Tencent SDK adapter is not linked"), "runtime factory must fail closed when real SDK is unavailable")
require(runtimeFactory.contains("AudioOnlyDigitalHumanRuntime"), "runtime factory must degrade to audio-only fallback")
require(runtimeFactory.contains("TencentDigitalHumanSDKRuntimeUnavailable"), "runtime factory must route future tencentSDK mode through the unavailable adapter until the SDK is linked")
require(project.contains("DigitalHumanRuntimeFactory.swift in Sources"), "runtime factory must be compiled into the app target")
require(project.contains("TencentDigitalHumanSDKRuntimeUnavailable.swift in Sources"), "unavailable Tencent SDK runtime must be compiled into the app target")

let defaultEnabledStart = featureFlags.range(of: "private static let defaultEnabled")!.lowerBound
let defaultEnabledEnd = featureFlags.range(of: "private var enabled")!.lowerBound
let defaultEnabledRange = defaultEnabledStart..<defaultEnabledEnd
let defaultEnabledBlock = String(featureFlags[defaultEnabledRange])
require(!defaultEnabledBlock.contains(".digitalHumanLivePanel"), "legacy local digital human panel must stay hidden by default")

print("digital-human-runtime-abstraction-check passed")
