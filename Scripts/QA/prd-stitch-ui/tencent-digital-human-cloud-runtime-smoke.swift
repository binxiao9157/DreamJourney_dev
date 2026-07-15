import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-cloud-runtime-smoke failed: \(message)\n", stderr)
        exit(1)
    }
}

let bridge = try read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let sdkBoundary = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift")
let cloudRuntime = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let backendClient = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let appDelegate = try read("DreamJourney/Sources/AppDelegate.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")

require(sdkBoundary.contains("let appKey: String"), "SDK adapter configuration must retain a future scoped appKey input")
require(sdkBoundary.contains("let accessToken: String"), "SDK adapter configuration must retain a future scoped accessToken input")
require(backendClient.contains("let scopedSessionReady: Bool"), "session credential must expose only scoped broker readiness")
require(!backendClient.contains("let appKey: String?"), "session credential must not parse a static appKey")
require(!backendClient.contains("let accessToken: String?"), "session credential must not parse a static accessToken")
require(cloudRuntime.contains("credential_broker_unavailable"), "cloud runtime must fail closed until a scoped credential broker exists")
require(cloudRuntime.contains("credentialBrokerUnavailable"), "cloud runtime must report the broker boundary")
require(!cloudRuntime.contains("appKey: appKey"), "cloud runtime must not pass a static appKey into the SDK")
require(!cloudRuntime.contains("accessToken: accessToken"), "cloud runtime must not pass a static accessToken into the SDK")

require(bridge.contains("import VirtualmanStreamSDK"), "real bridge must import Tencent SDK")
require(bridge.contains("import TXLiteAVSDK_TRTC"), "real bridge must import dedicated TRTC SDK")
require(bridge.contains("final class TencentVirtualmanSDKBridge"), "real bridge class is missing")
require(bridge.contains("Virtualman(frame:"), "real bridge must create Virtualman view")
require(bridge.contains("VirtualmanParams(appkey: configuration.appKey, accesstoken: configuration.accessToken)"), "real bridge must initialize SDK with backend-issued appkey/accesstoken")
require(bridge.contains("AssetVirtualmanParams(assetVirtualmanKey:"), "real bridge must support AssetVirtualmanKey")
require(bridge.contains("VirtualmanProjectParams(virtualmanProjectId:"), "real bridge must support ProjectId")
require(bridge.contains("ExtraInfo(alphaChannelEnable:"), "real bridge must preserve alpha channel")
require(bridge.contains("openByAsset"), "real bridge must support asset open")
require(bridge.contains("virtualman.open"), "real bridge must support project open")
require(bridge.contains("sendText(TextParams"), "real bridge must map non-stream text drive")
require(bridge.contains("reqId: requestID"), "real bridge must forward requestID to Tencent text/audio params")
require(bridge.contains("sendStreamText"), "real bridge must map stream text")
require(bridge.contains("sendAudio"), "real bridge must map audio drive")
require(bridge.contains("stop()"), "real bridge must map interrupt")
require(bridge.contains("close()"), "real bridge must map close")
require(bridge.contains("registerFactory"), "real bridge must expose a factory registration hook")
require(appDelegate.contains("TencentVirtualmanSDKBridge.registerFactory()"), "AppDelegate must register the real Tencent bridge")
require(project.contains("TencentVirtualmanSDKBridge.swift in Sources"), "real bridge must be compiled into app target")

print("tencent-digital-human-cloud-runtime-smoke passed")
