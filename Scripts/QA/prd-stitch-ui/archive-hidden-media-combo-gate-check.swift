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

let runner = read("Scripts/QA/prd-stitch-ui/run-archive-hidden-media-combo-gate.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-hidden-media-combo-gate.md")
let oneCommandReleaseDoc = read("docs/superpowers/status/2026-06-18-one-command-release-regression.md")

for required in [
    "run-archive-hidden-shell-smoke.sh",
    "run-backend-hidden-media-sync-smoke.sh",
    "archive-hidden-shell-smoke-result.json",
    "backend-hidden-media-sync-smoke-result.json",
    "archive-hidden-audio-empty-detail.png",
    "archive-hidden-video-failed-detail.png",
    "archive-hidden-time-letter-sealed-detail.png",
    "mock 媒体详情状态 + /archive/items 持久化字段",
] {
    assertContains(runner, required, "combo gate runner should include \(required)")
}

for required in [
    "RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE",
    "run-archive-hidden-media-combo-gate.sh",
    "archive-hidden-media-combo-gate",
    "Release handoff mode forces hidden media combo gate",
    "RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=1",
] {
    assertContains(releaseRegression, required, "release regression should expose combo gate \(required)")
}

for required in [
    "archive-hidden-media-combo-gate-check.swift",
    "run-archive-hidden-media-combo-gate.sh",
    "2026-06-19-archive-hidden-media-combo-gate.md",
] {
    assertContains(releaseQA, required, "release QA package should include combo gate \(required)")
}

assertContains(
    statusDoc,
    "隐藏媒体组合 gate",
    "status doc should document combo gate scope"
)
assertContains(
    statusDoc,
    "真实后端 hidden media sync smoke",
    "status doc should document deployed backend half"
)
assertContains(
    statusDoc,
    "Release handoff 常态 gate",
    "status doc should document combo gate as a release handoff gate"
)
assertContains(
    oneCommandReleaseDoc,
    "Hidden media combo gate",
    "one-command release docs should list hidden media combo gate"
)
assertContains(
    oneCommandReleaseDoc,
    "RUN_ARCHIVE_HIDDEN_MEDIA_COMBO_GATE=1",
    "one-command release docs should show hidden media combo gate is forced during handoff"
)

print("Archive hidden media combo gate checks passed")
