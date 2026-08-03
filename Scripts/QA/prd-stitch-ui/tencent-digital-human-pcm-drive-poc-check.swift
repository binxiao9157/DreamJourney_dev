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

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let featureFlags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let sdkBridge = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKBridge.swift")
let cloudRuntime = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let realBridge = read("DreamJourney/Sources/Services/DigitalHuman/TencentVirtualmanSDKBridge.swift")
let livePanelCheck = read("Scripts/QA/prd-stitch-ui/digital-human-live-panel-check.swift")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let trueDevicePCMDriveSmoke = read("Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh")

assertContains(echo, "DJRunTencentDigitalHumanPCMDriveSmoke", "Echo should expose a QA-only Tencent PCM drive launch argument")
assertContains(featureFlags, "DJRunTencentDigitalHumanPCMDriveSmoke", "QA feature registry should retain the true-device PCM smoke launch argument")
assertContains(appDelegate, "configuration.shouldEnableDigitalHumanLivePanel", "AppDelegate should enable the digital human panel through the centralized QA capability")
assertContains(echo, "shouldRunTencentDigitalHumanPCMDriveSmoke", "Echo should keep PCM smoke separate from text-drive smoke")
assertContains(echo, "runTencentDigitalHumanPCMDriveSmokeIfNeeded", "Echo should trigger PCM smoke only after Tencent runtime is ready")
assertContains(echo, "makeTencentDigitalHumanPCMDriveTestSignal", "Echo should generate a deterministic local PCM test signal")
assertContains(echo, "sendPCMDriveTestSignalToDigitalHumanRuntime", "Echo should send generated PCM through the runtime")
assertContains(echo, "pcm16kMono", "PCM smoke should document 16k/16-bit/mono payload format")
assertContains(echo, "sampleRate: 16_000", "PCM smoke should use Tencent-required 16 kHz sample rate")
assertContains(echo, "bitsPerSample: 16", "PCM smoke should use Tencent-required 16-bit PCM")
assertContains(echo, "channelCount: 1", "PCM smoke should use Tencent-required mono PCM")
assertContains(echo, "sendPCMChunk(chunk, requestID: requestID, sequence: sequence, isFinal: false)", "PCM smoke should send audio chunks before the final marker")
assertContains(echo, "sendPCMChunk(Data(), requestID: requestID, sequence: sequence, isFinal: true)", "PCM smoke should end Tencent audio-drive with an empty final packet")
assertContains(echo, "source: \"trueDevicePCMDriveSmoke\"", "PCM smoke should tag logs separately from text-drive smoke")
assertContains(echo, "scheduleTencentDigitalHumanTextOverTimeout(", "PCM smoke should reuse provider TextOver timeout recovery")
assertContains(echo, "interruptDigitalHumanPlayback(reason: \"pcmDriveSmokeStopProbe\")", "PCM smoke should exercise stop/interrupt semantics")

assertContains(sdkBridge, "func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws", "SDK bridge should expose PCM audio-drive")
assertContains(sdkBridge, "case audioStart(requestID: String?)", "SDK bridge should expose Tencent AudioStart as a first-class event")
assertContains(sdkBridge, "case audioOver(requestID: String?)", "SDK bridge should expose Tencent AudioOver as a first-class event")
assertContains(realBridge, "AudioParams(reqId: requestID, audio: base64Audio, seq: sequence, isFinal: isFinal)", "real bridge should map PCM chunks to Tencent AudioParams")
assertContains(realBridge, "case \"AudioStart\"", "real bridge should parse Tencent AudioStart")
assertContains(realBridge, "case \"AudioOver\"", "real bridge should parse Tencent AudioOver")
assertContains(cloudRuntime, "func sendPCMChunk", "cloud runtime should expose PCM chunk drive")
assertContains(cloudRuntime, "setRemoteAudioMuted(false)", "PCM drive should unmute Tencent remote audio before sending")
assertContains(cloudRuntime, "case .audioStart(let requestID):", "cloud runtime should enter speaking on AudioStart")
assertContains(cloudRuntime, "case .audioOver:", "cloud runtime should complete provider request on AudioOver")

assertContains(livePanelCheck, "DJRunTencentDigitalHumanPCMDriveSmoke", "digital-human live-panel guard should cover PCM smoke launch argument")
assertContains(releasePackage, "tencent-digital-human-pcm-drive-poc-check.swift", "release QA package should include PCM drive POC guard")
assertContains(trueDevicePCMDriveSmoke, "$0 !~ /unavailable/", "true-device Tencent backend PCM smoke must not select unavailable devices from devicectl")

print("tencent-digital-human-pcm-drive-poc-check passed")
