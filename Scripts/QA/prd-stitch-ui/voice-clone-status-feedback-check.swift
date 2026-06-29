import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let shell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "private weak var synthesisStatusValueLabel",
    "profileVoiceCloneSynthesisStatusValue",
    "synthesisStatusValueLabel?.text = voiceSynthesisStatusText(for: snapshot)",
    "voiceSynthesisStatusText(for snapshot: VoiceCloneProfileSnapshot)",
    "voiceCloneRuntimeCapability.canSynthesize",
    "回响语音",
    "音色已就绪，回响可使用复刻语音",
    "音色已就绪，合成服务待配置",
    "训练完成后可用于回响",
    "训练失败，重新提交样本后可用",
    "音色已暂停，回响会使用普通语音",
] {
    assertContains(shell, required, "voice clone shell should expose synthesis readiness feedback \(required)")
}

for required in [
    "DJShowVoiceCloneStatusFeedbackPreview",
    "showVoiceCloneStatusFeedbackPreview()",
    "ProfileVoiceCloneShellViewController(snapshot: snapshot)",
] {
    assertContains(appDelegate, required, "AppDelegate should expose voice clone status preview \(required)")
}

assertContains(
    releaseRegression,
    "voice-clone-status-feedback-check.swift",
    "release regression should run voice clone status feedback guard"
)
assertContains(
    releaseQA,
    "voice-clone-status-feedback-check.swift",
    "release QA package should include voice clone status feedback guard"
)

print("Voice clone status feedback checks passed")
