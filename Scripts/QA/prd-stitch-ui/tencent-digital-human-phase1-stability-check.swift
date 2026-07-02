import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Tencent digital-human Phase 1 stability check failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let runtime = read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let trueDevicePCMDriveSmoke = read("Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh")
let nonDeviceGate = read("Scripts/QA/prd-stitch-ui/run-tencent-digital-human-phase1-non-device-gate.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

func substring(_ text: String, from startMarker: String, to endMarker: String) -> String {
    guard let start = text.range(of: startMarker),
          let end = text[start.upperBound...].range(of: endMarker) else {
        return ""
    }
    return String(text[start.lowerBound..<end.lowerBound])
}

func functionBody(_ signature: String, in source: String) -> String {
    guard let signatureRange = source.range(of: signature),
          let openBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
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
    return ""
}

let stopVoiceCapture = substring(
    echo,
    from: "private func stopVoiceCapture()",
    to: "private func flushPendingAIReplyIfNeeded()"
)
let viewDidAppear = functionBody("override func viewDidAppear", in: echo)
let viewWillDisappear = functionBody("override func viewWillDisappear", in: echo)
let releaseRuntime = functionBody("private func releaseDigitalHumanRuntime", in: echo)
let prepareRuntime = functionBody("private func prepareCloudDigitalHumanRuntimeIfNeeded", in: echo)
let handleSession = functionBody("private func handleCloudDigitalHumanSession", in: echo)
let fallbackRoute = functionBody("private func degradeTencentDigitalHumanRoute", in: echo)

require(
    backendClient.contains("shouldUseLocalAssetVirtualmanKeyOverride"),
    "local digital-human asset override must be gated behind an explicit QA/debug launch arg"
)
require(
    backendClient.contains("DJUseLocalDigitalHumanAssetOverride"),
    "local digital-human asset override launch arg should be named and searchable"
)
require(
    backendClient.contains("assetSource"),
    "session contract should expose assetSource for QA logs"
)
require(
    !backendClient.contains("self.assetKey = localAssetVirtualmanKey ?? json[\"assetKey\"] as? String"),
    "backend session asset must be primary; local Info.plist key must not silently override release sessions"
)
require(
    echo.contains("EchoDigitalHumanAudioOwner"),
    "Echo should model the active digital-human audio owner explicitly"
)
require(
    echo.contains("audioOwner=tencentDigitalHuman"),
    "Echo logs must identify Tencent as the provider audio owner"
)
require(
    echo.contains("audioOwner=volcengineLocalTTS"),
    "Echo logs must identify ordinary Echo fallback audio owner"
)
require(
    echo.contains("audioOwner=fallbackMuted"),
    "Echo logs must identify muted provider capture handoff state"
)
require(
    echo.contains("assetSource=\\(contract.assetSource)"),
    "Echo session logs should include digital-human asset source"
)
require(
    stopVoiceCapture.contains("interruptDigitalHumanPlayback(reason: \"userStop\")"),
    "user stop should interrupt playback without closing/removing the Tencent provider view"
)
require(
    !stopVoiceCapture.contains(".close()") &&
        !stopVoiceCapture.contains("digitalHumanRuntime = nil") &&
        !stopVoiceCapture.contains("removeHostedProviderView"),
    "user stop path must not close and nil out the digital-human runtime"
)
require(
    viewDidAppear.contains("prepareCloudDigitalHumanRuntimeIfNeeded()"),
    "Echo page appearance should create or restore the Tencent session"
)
require(
    prepareRuntime.contains("digitalHumanRuntime == nil") &&
        prepareRuntime.contains("hasRequestedCloudDigitalHumanRuntime == false") &&
        prepareRuntime.contains("createCloudDigitalHumanSession"),
    "Tencent runtime preparation should be idempotent and session-backed"
)
require(
    handleSession.contains("hostProviderView(runtime.contentView)") &&
        handleSession.contains("try runtime.open()") &&
        handleSession.contains("removeHostedProviderView(showFallbackMessage: \"数字人暂不可用\")"),
    "Tencent session handling should host the provider view on success and fallback cleanly on provider failure"
)
require(
    viewWillDisappear.contains("releaseDigitalHumanRuntime(reason: \"viewWillDisappear\"") &&
        releaseRuntime.contains("runtime?.close()") &&
        releaseRuntime.contains("digitalHumanRuntime = nil") &&
        releaseRuntime.contains("hasRequestedCloudDigitalHumanRuntime = false") &&
        releaseRuntime.contains("released provider session reason=release:"),
    "Echo page exit should use the unified path that releases the Tencent session"
)
require(
    fallbackRoute.contains("releaseDigitalHumanRuntime(reason: \"routeFailure:") &&
        fallbackRoute.contains("removeProviderViewMessage: \"数字人暂不可用\"") &&
        fallbackRoute.contains("resetsAudioOwnerToOrdinaryEcho: true") &&
        releaseRuntime.contains("removeHostedProviderView(showFallbackMessage:") &&
        releaseRuntime.contains("DialogEngineManager.shared.setLocalTTSPlaybackEnabled(true)") &&
        releaseRuntime.contains("setEchoAudioOwner(.volcengineLocalTTS") &&
        fallbackRoute.contains("route fallback after runtime failure"),
    "Tencent provider failure should explicitly degrade to ordinary Echo fallback"
)
require(
    runtime.contains("func setRemoteAudioMuted(_ muted: Bool)") &&
        runtime.contains("setRemoteAudioMuted(false)") &&
        echo.contains("setRemoteAudioMuted(true)"),
    "Tencent runtime must keep explicit remote audio mute controls for playback/capture handoff"
)
require(
    trueDevicePCMDriveSmoke.contains("assetSource=backendSession") &&
        trueDevicePCMDriveSmoke.contains("assetSource=localQAOverride") &&
        trueDevicePCMDriveSmoke.contains("audioOwner=tencentDigitalHuman") &&
        trueDevicePCMDriveSmoke.contains("audioOwner=fallbackMuted"),
    "true-device Tencent smoke should assert backend asset source and audio owner handoff"
)
require(
    releaseRegression.contains("tencent-digital-human-phase1-stability-check.swift"),
    "release regression should run the Phase 1 digital-human stability guard"
)
require(
    releaseQA.contains("tencent-digital-human-phase1-stability-check.swift"),
    "release QA package should include the Phase 1 digital-human stability guard"
)
require(
    nonDeviceGate.contains("This gate intentionally does not run true-device validation") &&
        nonDeviceGate.contains("run-digital-human-runtime-stub-smoke.sh") &&
        nonDeviceGate.contains("run-tencent-backend-pcm-drive-mock-smoke.sh") &&
        nonDeviceGate.contains("RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE=0") &&
        nonDeviceGate.contains("xcodebuild") &&
        nonDeviceGate.contains("git diff --check"),
    "Phase 1 non-device gate should combine runtime stub, PCM-drive mock, release regression, build, and diff check without true-device validation"
)
require(
    releaseRegression.contains("RUN_TENCENT_DIGITAL_HUMAN_PHASE1_NON_DEVICE_GATE") &&
        releaseRegression.contains("run-tencent-digital-human-phase1-non-device-gate.sh"),
    "release regression should expose the optional Phase 1 non-device gate"
)
require(
    releaseQA.contains("run-tencent-digital-human-phase1-non-device-gate.sh"),
    "release QA package should include the Phase 1 non-device gate"
)

print("Tencent digital-human Phase 1 stability guard passed")
