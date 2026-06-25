import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: rootURL.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("tencent-digital-human-sdk-handoff-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let handoff = try read("docs/superpowers/status/2026-06-25-tencent-digital-human-sdk-handoff.md")
let bridge = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift")
let cloudRuntime = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let unavailable = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKRuntimeUnavailable.swift")
let factory = try read("DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntimeFactory.swift")
let client = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let project = try read("DreamJourney.xcodeproj/project.pbxproj")
let releaseMatrix = try read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

require(handoff.contains("VirtualmanStreamSDK.xcframework"), "handoff must name the Tencent xcframework")
require(handoff.contains("TXLiteAVSDK_TRTC_shuziren_13.0.20262"), "handoff must pin the custom TRTC podspec")
require(handoff.contains("asset_virtualman_key"), "handoff must document asset_virtualman_key")
require(handoff.contains("virtualman_project_id"), "handoff must document virtualman_project_id")
require(handoff.contains("appkey") && handoff.contains("accesstoken"), "handoff must use Tencent official appkey/accesstoken terms")
require(handoff.contains("virtualman-stream-demo-ios.zip"), "handoff must record the corrected demo download URL")
require(handoff.contains("3056d8caff1b542a5301b69e8a979608662d4a25502832f7d40477989aaa2d1f"), "handoff must record the downloaded package checksum")
require(handoff.contains("tmp/tencent-digital-human-sdk/"), "handoff must document ignored local SDK staging")
require(!handoff.contains("TENCENT_DIGITAL_HUMAN_SECRET_KEY 作为云渲染必填"), "handoff must not treat SecretKey as a cloud-rendering requirement")

require(bridge.contains("protocol TencentDigitalHumanSDKBridge"), "SDK bridge protocol is missing")
require(bridge.contains("struct TencentDigitalHumanSDKConfiguration"), "SDK configuration model is missing")
require(bridge.contains("assetVirtualmanKey"), "bridge must support AssetVirtualmanKey flow")
require(bridge.contains("virtualmanProjectId"), "bridge must support ProjectId flow")
require(bridge.contains("alphaChannelEnable"), "bridge must carry alpha channel option")
require(bridge.contains("func openByAsset"), "bridge must expose asset open")
require(bridge.contains("func openByProject"), "bridge must expose project open")
require(bridge.contains("func sendText"), "bridge must expose text drive")
require(bridge.contains("func close()"), "bridge must expose close")
require(!bridge.contains("Virtualman("), "bridge boundary must not instantiate SDK symbols before binary import")

require(cloudRuntime.contains("final class TencentDigitalHumanCloudRuntime"), "cloud runtime skeleton is missing")
require(cloudRuntime.contains("TencentDigitalHumanSDKBridge"), "cloud runtime must depend on bridge protocol")
require(cloudRuntime.contains("openByAsset"), "cloud runtime must choose asset flow when available")
require(cloudRuntime.contains("openByProject"), "cloud runtime must choose project flow when available")
require(cloudRuntime.contains("sendText("), "cloud runtime must forward text drive")
require(cloudRuntime.contains("sendPCMChunk"), "cloud runtime must reject or define PCM behavior")
require(!cloudRuntime.contains("Virtualman("), "cloud runtime skeleton must not instantiate SDK symbols directly")

require(unavailable.contains("TencentDigitalHumanSDKBridgeFactory"), "unavailable runtime must explain bridge factory absence")
require(factory.contains("TencentDigitalHumanSDKBridgeFactory.shared.makeBridge"), "factory must reserve bridge factory seam")
require(factory.contains("TencentDigitalHumanCloudRuntime"), "factory must reserve real cloud runtime")
require(client.contains("providerAssetId"), "client must parse provider asset id")
require(client.contains("assetKey"), "client must parse backend asset key")

require(project.contains("TencentDigitalHumanSDKBridge.swift in Sources"), "SDK bridge must be compiled into the app target")
require(project.contains("TencentDigitalHumanCloudRuntime.swift in Sources"), "cloud runtime must be compiled into the app target")
require(releaseMatrix.contains("digitalHumanLivePanel") && releaseMatrix.contains("hidden"), "release matrix must keep digital human hidden until explicit release")

print("tencent-digital-human-sdk-handoff-check passed")
