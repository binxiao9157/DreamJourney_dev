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
        fputs("Tencent digital-human voice-clone route check failed: \(message)\n", stderr)
        exit(1)
    }
}

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let voiceClone = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

require(voiceClone.contains("currentUsableSpeakerId"), "VoiceCloneService must expose only quality-accepted speaker IDs")
require(backendClient.contains("outputMode") && backendClient.contains("tencentAudioDrive"), "backend client must support Tencent audio-drive synthesis")
require(echo.contains("sendEchoReplyViaTencentVoiceClonePCMDrive"), "Echo must have a production voice-clone PCM-drive reply path")
require(echo.contains("private var voiceCloneRuntimeCapability"), "Echo must cache backend voice-clone runtime capability")
require(echo.contains("loadVoiceCloneRuntimeCapabilityIfNeeded"), "Echo must load voice-clone runtime capability for status and diagnostics")
require(echo.contains("capability.canSynthesize") && echo.contains("capability.tencentAudioDrive.supported"), "Echo must use runtime capability to diagnose cloned speech readiness")
require(echo.contains("VoiceCloneService.shared.currentUsableSpeakerId"), "Echo must read the quality-accepted voice profile ID")
require(echo.contains("DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis"), "Echo must request backend cloned TTS for digital-human speech")
require(echo.contains("outputMode: \"tencentAudioDrive\""), "Echo must request Tencent audio-drive compatible PCM")
require(echo.contains("sendTencentAudioDriveSynthesisToDigitalHumanRuntime"), "Echo must feed cloned PCM into the Tencent runtime")
require(echo.contains("source: \"voiceClonePCMDrive\""), "Echo logs/source markers must distinguish production voice-clone PCM-drive from QA smokes")
require(echo.contains("handleVoiceClonePCMDriveFailureWithoutDefaultVoice"), "Echo must keep a dedicated cloned-PCM failure path")
require(echo.contains("复刻声音生成失败，未切换默认音色"), "Echo must report cloned PCM failure without switching to Tencent default text voice")
require(!echo.contains("fallbackToTencentText"), "Echo must not keep the old cloned PCM fallbackToTencentText path")
require(releaseRegression.contains("tencent-digital-human-voice-clone-route-check.swift"), "release regression should run the voice-clone route guard")
require(releaseQA.contains("tencent-digital-human-voice-clone-route-check.swift"), "release QA package should include the voice-clone route guard")

print("Tencent digital-human voice-clone route guard passed")
