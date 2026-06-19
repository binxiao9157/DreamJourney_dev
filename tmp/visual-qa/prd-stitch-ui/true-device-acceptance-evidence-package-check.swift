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

let voicePreflight = read("tmp/visual-qa/prd-stitch-ui/run-true-device-voice-preflight.sh")
let archiveAudioPreflight = read("tmp/visual-qa/prd-stitch-ui/run-true-device-archive-audio-preflight.sh")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let readinessDoc = read("docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md")
let statusDoc = read("docs/superpowers/status/2026-06-19-true-device-acceptance-evidence-package.md")

for required in [
    "EVIDENCE_MANIFEST",
    "MANUAL_QA_NOTES",
    "write_evidence_manifest",
    "console-output.log",
    "manual-qa-notes.md",
    "01-photo-permission-allow.png",
    "02-photo-created-archive.png",
    "03-photo-echo-context.png",
    "04-microphone-permission-allow.png",
    "05-speech-permission-allow.png",
    "06-echo-listening.png",
    "07-echo-tts-playback.png",
    "08-background-before.png",
    "09-foreground-restored.png",
    "播放路由",
    "前后台",
] {
    assertContains(voicePreflight, required, "true-device voice preflight should define evidence package \(required)")
}

for required in [
    "EVIDENCE_MANIFEST",
    "AUDIO_QUALITY_NOTES",
    "PLAYBACK_ROUTE_NOTES",
    "BACKGROUND_FOREGROUND_NOTES",
    "write_evidence_manifest",
    "audio-quality-notes.md",
    "playback-route-notes.md",
    "background-foreground-notes.md",
    "01-audio-permission-allow.png",
    "02-audio-permission-deny.png",
    "03-audio-permission-recover.png",
    "04-audio-created.png",
    "05-audio-detail-playback.png",
    "06-audio-after-background-foreground.png",
] {
    assertContains(archiveAudioPreflight, required, "true-device archive audio preflight should define evidence package \(required)")
}

assertContains(
    releaseRegression,
    "true-device-acceptance-evidence-package-check.swift",
    "release regression should run true-device evidence package guard"
)
assertContains(
    releaseQA,
    "true-device-acceptance-evidence-package-check.swift",
    "release QA package should include true-device evidence package guard"
)
assertContains(
    releaseQA,
    "docs/superpowers/status/2026-06-19-true-device-acceptance-evidence-package.md",
    "release QA package should include true-device evidence package status doc"
)

for required in [
    "真机验收证据包",
    "麦克风",
    "相册",
    "语音识别",
    "前后台",
    "播放路由",
    "截图",
    "日志",
] {
    assertContains(readinessDoc, required, "device readiness doc should mention strengthened evidence package \(required)")
    assertContains(statusDoc, required, "status doc should document strengthened evidence package \(required)")
}

print("True-device acceptance evidence package checks passed")
