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
        fputs("Tencent digital-human provider stability check failed: \(message)\n", stderr)
        exit(1)
    }
}

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

require(echo.contains("lastTencentProviderAudioHandoffAt"), "Echo should remember provider audio handoff timing")
require(echo.contains("tencentProviderDialogErrorSuppressionWindow"), "Echo should suppress transient DialogEngine errors during provider handoff")
require(echo.contains("shouldSuppressDialogEngineErrorDuringTencentProviderSpeech"), "Echo should have a provider-specific DialogEngine error filter")
require(echo.contains("DialogEngineError") && echo.contains("case .sdkError"), "Echo filter should only suppress SDK errors, not all voice failures")
require(echo.contains("preserveTencentProviderSessionAfterLocalDialogStop(reason: \"dialogErrorSuppressedDuringProviderSpeech\")"), "suppressed SDK errors should preserve the Tencent provider session")
require(echo.contains("tencentDigitalHumanPCMDriveStartDelay"), "PCM-drive should wait briefly after DialogEngine stop before first audio chunk")
require(echo.contains("tencentDigitalHumanPCMDrivePrerollDuration"), "PCM-drive should send silent preroll before cloned audio")
require(echo.contains("tencentDigitalHumanPCMDriveFadeDuration"), "PCM-drive should fade cloned audio edges")
require(echo.contains("preparedAudioDrivePCMData()"), "PCM-drive chunks should use prepared audio-drive data")
require(echo.contains("strippedRIFFHeaderIfNeeded"), "PCM-drive should defensively strip WAV headers before sendAudio")
require(echo.contains("silenceByteCount"), "PCM-drive should prepend silence to reduce start pops")
require(echo.contains("fadeSampleCount"), "PCM-drive smoothing should fade PCM edges to reduce pops")
require(echo.contains("Double(index) * Self.tencentDigitalHumanPCMDriveChunkDuration + Self.tencentDigitalHumanPCMDriveStartDelay"), "PCM chunks should include start delay")
require(releaseRegression.contains("tencent-digital-human-provider-stability-check.swift"), "release regression should run provider stability guard")
require(releaseQA.contains("tencent-digital-human-provider-stability-check.swift"), "release QA package should include provider stability guard")

print("Tencent digital-human provider stability guard passed")
