import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("True-device Tencent backend PCM-drive smoke check failed: \(message)\n", stderr)
        exit(1)
    }
}

let script = read("Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

require(script.contains("DJRunTencentDigitalHumanPCMDriveStopProbe"), "true-device script should pass the stop probe launch argument")
require(script.contains("DJTencentBackendPCMDriveUserId="), "true-device script should pass the persisted voice profile owner")
require(script.contains("VOICE_CLONE_READY_PROFILE_USER_ID"), "true-device script should accept the deployed profile owner environment")
require(script.contains("DJUseLocalDigitalHumanAssetOverride"), "true-device script should document that local asset override is intentionally not passed")
require(script.contains("assetSource=backendSession"), "true-device script should verify backend digital-human asset source")
require(script.contains("assetSource=localQAOverride"), "true-device script should fail when local QA asset override is used")
require(script.contains("audioOwner=tencentDigitalHuman"), "true-device script should verify Tencent owns Echo playback")
require(script.contains("audioOwner=fallbackMuted"), "true-device script should verify muted provider handoff before capture resumes")
require(script.contains("event=pcmDriveStopProbeFired"), "true-device script should verify provider interruption was triggered")
require(script.contains("event=voiceCaptureResumed.*reason=pcmDriveSmokeStopProbe"), "true-device script should verify mic capture resumes after stop probe")
require(script.contains("event=providerPlaybackCompleted"), "true-device script should record normal provider completion when AudioOver is observed")
require(script.contains("[TencentDigitalHuman][QA_RESULT]"), "true-device script should extract the structured QA result")
require(script.contains("providerLogIdHash"), "true-device script should report a hashed provider log ID for support lookup")
require(script.contains("sentChunkCount"), "true-device script should report sentChunkCount")
require(script.contains("Manual visual checks"), "true-device script should separate human visual/audio checks from automated logs")
require(script.contains("Human confirmation required"), "true-device script should not claim audible sound or lip movement without human confirmation")
require(script.contains("RUN_SECONDS"), "true-device script should keep runtime configurable")
require(script.contains("$0 !~ /unavailable/"), "true-device script must not select unavailable devicectl devices")
require(script.contains("$0 !~ /Devices Offline/"), "true-device script must not select xctrace offline devices")

require(echo.contains("reason == \"pcmDriveSmokeStopProbe\""), "Echo should special-case QA stop probe resume")
require(
    echo.contains("resumeVoiceCaptureAfterTencentProviderSpeech(")
        && echo.contains("reason: reason,")
        && echo.contains("lifecycleToken: lifecycleToken"),
    "Echo stop probe should resume voice capture with the current lifecycle token"
)
require(echo.contains("event: \"pcmDriveStopProbeFired\""), "Echo should emit a redacted stop-probe diagnostic event")
require(echo.contains("[TencentDigitalHuman][QA_RESULT]"), "Echo should emit structured true-device backend PCM-drive QA result")
require(echo.contains("TencentBackendPCMDriveTrueDeviceTrace"), "Echo should keep a structured trace for backend PCM-drive true-device smoke")
for field in [
    "redactionPolicyVersion",
    "voiceProfileIdHash",
    "outputMode",
    "providerLogIdHash",
    "providerRequestIdHash",
    "providerMode",
    "rawByteCount",
    "preparedByteCount",
    "expectedChunkCount",
    "sentChunkCount",
    "sentFinalChunk",
    "providerSpeakingObserved",
    "providerPlaybackCompleted",
    "stopProbeFired",
    "resumedVoiceCapture",
    "audioOwner",
] {
    require(echo.contains("\"\(field)\""), "Echo QA result should include \(field)")
}
require(
    echo.contains("event: \"sessionContractReceived\"")
        && echo.contains("\"assetSource\": contract.assetSource"),
    "Echo should emit backend/local asset source through the redacted session diagnostic"
)
require(
    echo.contains("event: \"audioOwnerUpdated\"")
        && echo.contains("\"audioOwner\": owner.rawValue"),
    "Echo should emit a redacted audio-owner transition diagnostic"
)
require(
    echo.contains("setEchoAudioOwner(.tencentDigitalHuman")
        && echo.contains("setEchoAudioOwner(.fallbackMuted"),
    "Echo should retain Tencent playback ownership and muted-handoff transitions"
)
require(echo.contains("DJRunTencentDigitalHumanBackendPCMDriveSmoke"), "Echo should keep backend PCM-drive launch argument")
require(echo.contains("DJTencentBackendPCMDriveUserId="), "Echo QA smoke should accept a voice profile owner override")

require(releasePackage.contains("true-device-tencent-backend-pcm-drive-smoke-check.swift"), "release package should include this true-device smoke guard")
require(releaseRegression.contains("true-device-tencent-backend-pcm-drive-smoke-check.swift"), "release regression static guard should include this smoke check")

print("true-device-tencent-backend-pcm-drive-smoke-check passed")
