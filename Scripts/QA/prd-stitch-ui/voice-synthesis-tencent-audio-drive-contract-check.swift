import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: root)
let backendRootURL = rootURL.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, from baseURL: URL = rootURL) throws -> String {
    let url = baseURL.appendingPathComponent(relativePath)
    return try String(contentsOf: url, encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Tencent audio-drive contract check failed: \(message)\n", stderr)
        exit(1)
    }
}

let backendMain = try read("app/main.py", from: backendRootURL)
let backendTTS = try read("app/services/tts.py", from: backendRootURL)
let backendRuntime = try read("app/services/runtime_config.py", from: backendRootURL)
let backendTests = try read("tests/test_core_services.py", from: backendRootURL)
let client = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let echo = try read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let runtime = try read("DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanCloudRuntime.swift")
let trueDeviceScript = try read("Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh")

require(backendTTS.contains("class TencentAudioDrivePCMAdapter"), "backend must define a Tencent PCM adapter")
require(backendTTS.contains("audio_format = \"pcm16kMono\""), "backend adapter must output pcm16kMono")
require(backendTTS.contains("sample_rate = 16000"), "backend adapter must target 16k sample rate")
require(backendTTS.contains("bits_per_sample = 16"), "backend adapter must target 16-bit PCM")
require(backendTTS.contains("channel_count = 1"), "backend adapter must target mono PCM")
require(backendTTS.contains("wave.open"), "backend adapter must parse WAV provider audio")
require(backendTTS.contains("audioop.ratecv"), "backend adapter must convert sample rate when needed")
require(backendMain.contains("output_mode = str(payload.get(\"outputMode\")"), "voice synthesis endpoint must accept outputMode")
require(backendMain.contains("output_mode == \"tencentAudioDrive\""), "voice synthesis endpoint must branch for Tencent audio-drive")
require(backendMain.contains("provider_audio_format = \"wav\""), "Tencent output mode must request WAV from provider")
require(backendMain.contains("provider_sample_rate = TencentAudioDrivePCMAdapter.sample_rate"), "Tencent output mode must request 16k provider sample rate")
require(backendMain.contains("TencentAudioDrivePCMAdapter().adapt"), "voice synthesis endpoint must convert provider audio through the PCM adapter")
require(backendRuntime.contains("\"tencentAudioDrive\""), "runtime config must expose Tencent audio-drive capability")
require(backendRuntime.contains("\"requestOutputMode\": \"tencentAudioDrive\""), "runtime config must document request outputMode")
require(backendRuntime.contains("\"audioFormat\": \"pcm16kMono\""), "runtime config must document PCM audio format")
require(backendTests.contains("test_voice_clone_synthesis_can_return_tencent_audio_drive_pcm_contract"), "backend test must cover Tencent PCM output")

require(client.contains("let outputMode: String?"), "iOS synthesis result must parse outputMode")
require(client.contains("let sampleRate: Int?"), "iOS synthesis result must parse sampleRate")
require(client.contains("let bitsPerSample: Int?"), "iOS synthesis result must parse bitsPerSample")
require(client.contains("let channelCount: Int?"), "iOS synthesis result must parse channelCount")
require(client.contains("var isTencentAudioDrivePCMCompatible"), "iOS synthesis result must expose PCM compatibility")
require(client.contains("var tencentAudioDrivePCMData"), "iOS synthesis result must expose decoded Tencent PCM data")
require(client.contains("outputMode: String? = nil"), "iOS synthesis request must support optional outputMode")
require(client.contains("\"outputMode\""), "iOS synthesis payload must send outputMode when requested")
require(echo.contains("sendTencentAudioDriveSynthesisToDigitalHumanRuntime"), "Echo should expose a backend synthesis -> Tencent PCM drive bridge")
require(echo.contains("makeTencentDigitalHumanPCMDriveSignal(from synthesis: VoiceCloneSynthesisResult)"), "Echo should convert backend synthesis results into PCM drive signals")
require(echo.contains("synthesis.tencentAudioDrivePCMData"), "Echo must only drive Tencent with compatible PCM synthesis audio")
require(echo.contains("scheduleTencentDigitalHumanPCMDriveChunks("), "Echo backend PCM bridge must reuse the existing sendPCMChunk scheduler")
require(echo.contains("DJRunTencentDigitalHumanBackendPCMDriveSmoke"), "Echo should expose a QA-only deployed backend PCM-drive launch argument")
require(echo.contains("DJTencentBackendPCMDriveVoiceProfileId="), "Echo backend PCM smoke should allow an explicit voiceProfileId launch argument")
require(echo.contains("runTencentDigitalHumanBackendPCMDriveSmokeIfNeeded"), "Echo should trigger deployed backend PCM smoke after Tencent runtime is ready")
require(echo.contains("DreamJourneyBackendClient.shared.requestVoiceCloneSynthesis("), "Echo backend PCM smoke should call /voice/synthesis through the backend client")
require(echo.contains("outputMode: \"tencentAudioDrive\""), "Echo backend PCM smoke must request Tencent audio-drive output mode")
require(echo.contains("source: \"trueDeviceBackendPCMDriveSmoke\""), "Echo backend PCM smoke should tag logs separately from local PCM smoke")
require(runtime.contains("func sendPCMChunk(_ data: Data"), "Tencent runtime must keep the reusable PCM chunk path")
require(trueDeviceScript.contains("DJRunTencentDigitalHumanBackendPCMDriveSmoke"), "true-device script must launch backend PCM-drive smoke")
require(trueDeviceScript.contains("DJ_TENCENT_BACKEND_PCM_VOICE_PROFILE_ID"), "true-device script must allow explicit voiceProfileId without code changes")
require(trueDeviceScript.contains("DJTencentBackendPCMDriveVoiceProfileId="), "true-device script must pass voiceProfileId as a QA launch argument")
require(trueDeviceScript.contains("backend PCM-drive smoke synthesis ready"), "true-device script must verify backend synthesis completion")
require(trueDeviceScript.contains("sent PCM chunk"), "true-device script must verify PCM chunks were sent")
require(trueDeviceScript.contains("AudioStart"), "true-device script must verify Tencent started audio playback")
require(trueDeviceScript.contains("DreamJourney/Config/YXJ.local.xcconfig is required"), "true-device script must avoid printing backend/signing secrets as command-line build settings")

print("Tencent audio-drive contract check passed")
