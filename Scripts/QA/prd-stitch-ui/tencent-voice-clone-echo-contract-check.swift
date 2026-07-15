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
        fputs("Tencent voice-clone Echo contract check failed: \(message)\n", stderr)
        exit(1)
    }
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

let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

let voiceClonePCMDriveBody = functionBody(
    "private func sendEchoReplyViaTencentVoiceClonePCMDrive(",
    in: echo
)

require(
    backendClient.contains("let providerLogId: String?") &&
        backendClient.contains("let providerRequestId: String?") &&
        backendClient.contains("let durationSeconds: Double?") &&
        backendClient.contains("self.providerLogId = json[\"providerLogIdHash\"] as? String") &&
        backendClient.contains("self.providerRequestId = json[\"providerRequestIdHash\"] as? String") &&
        backendClient.contains("self.durationSeconds = Self.doubleValue(audioJSON[\"durationSeconds\"])"),
    "iOS synthesis result should parse durationSeconds and value-free provider reference hashes for QA support"
)
require(
    echo.contains("暂未启用复刻音色"),
    "Echo should clearly show when cloned voice is not enabled"
)
require(
    voiceClonePCMDriveBody.contains("outputMode: \"tencentAudioDrive\""),
    "Echo cloned voice path must request Tencent audio-drive output"
)
require(
    !voiceClonePCMDriveBody.contains("fallbackToTencentText(\"voiceClonePCMDriveFallbackToTencentText\")"),
    "Echo cloned voice provider failure must not silently fall back to Tencent default text voice"
)
require(
    echo.contains("复刻声音生成失败") &&
        voiceClonePCMDriveBody.contains("voice-clone PCM-drive request failed; no default voice fallback") &&
        voiceClonePCMDriveBody.contains("voice-clone PCM-drive incompatible; no default voice fallback"),
    "Echo should surface cloned voice synthesis failure instead of default voice fallback"
)
require(
        voiceClonePCMDriveBody.contains("providerLogId=\\(synthesis.providerLogId ?? \"none\")") &&
        voiceClonePCMDriveBody.contains("outputMode=\\(synthesis.outputMode ?? \"none\")") &&
        voiceClonePCMDriveBody.contains("durationSeconds=\\(synthesis.durationSeconds ?? 0)") &&
        voiceClonePCMDriveBody.contains("\\(self.currentEchoAudioOwner.logLabel)") &&
        echo.contains("var logLabel: String"),
    "Echo QA logs should include voiceProfileId, outputMode, providerLogId, and audioOwner"
)
require(
    releaseRegression.contains("tencent-voice-clone-echo-contract-check.swift"),
    "release regression should run the Tencent voice-clone Echo contract guard"
)
require(
    releaseQA.contains("tencent-voice-clone-echo-contract-check.swift"),
    "release QA package should include the Tencent voice-clone Echo contract guard"
)

print("Tencent voice-clone Echo contract guard passed")
