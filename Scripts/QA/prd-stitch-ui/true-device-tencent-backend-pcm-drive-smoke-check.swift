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
require(script.contains("DJUseLocalDigitalHumanAssetOverride"), "true-device script should document that local asset override is intentionally not passed")
require(script.contains("assetSource=backendSession"), "true-device script should verify backend digital-human asset source")
require(script.contains("assetSource=localQAOverride"), "true-device script should fail when local QA asset override is used")
require(script.contains("audioOwner=tencentDigitalHuman"), "true-device script should verify Tencent owns Echo playback")
require(script.contains("audioOwner=fallbackMuted"), "true-device script should verify muted provider handoff before capture resumes")
require(script.contains("PCM-drive stop probe fired"), "true-device script should verify provider interruption was triggered")
require(script.contains("resume voice capture after provider speech reason=pcmDriveSmokeStopProbe"), "true-device script should verify mic capture resumes after stop probe")
require(script.contains("provider playback completed"), "true-device script should record normal provider completion when AudioOver is observed")
require(script.contains("Manual visual checks"), "true-device script should separate human visual/audio checks from automated logs")
require(script.contains("Human confirmation required"), "true-device script should not claim audible sound or lip movement without human confirmation")
require(script.contains("RUN_SECONDS"), "true-device script should keep runtime configurable")
require(script.contains("$0 !~ /unavailable/"), "true-device script must not select unavailable devicectl devices")
require(script.contains("$0 !~ /Devices Offline/"), "true-device script must not select xctrace offline devices")

require(echo.contains("reason == \"pcmDriveSmokeStopProbe\""), "Echo should special-case QA stop probe resume")
require(echo.contains("resumeVoiceCaptureAfterTencentProviderSpeech(reason: reason)"), "Echo stop probe should resume voice capture after interrupting provider playback")
require(echo.contains("[TencentDigitalHuman][QA] PCM-drive stop probe fired"), "Echo should log stop probe with a QA marker")
require(echo.contains("assetSource=\\(contract.assetSource)"), "Echo should log backend/local asset source for true-device verification")
require(echo.contains("audioOwner=tencentDigitalHuman"), "Echo should log Tencent playback ownership")
require(echo.contains("audioOwner=fallbackMuted"), "Echo should log provider muted handoff ownership")
require(echo.contains("DJRunTencentDigitalHumanBackendPCMDriveSmoke"), "Echo should keep backend PCM-drive launch argument")

require(releasePackage.contains("true-device-tencent-backend-pcm-drive-smoke-check.swift"), "release package should include this true-device smoke guard")
require(releaseRegression.contains("true-device-tencent-backend-pcm-drive-smoke-check.swift"), "release regression static guard should include this smoke check")

print("true-device-tencent-backend-pcm-drive-smoke-check passed")
