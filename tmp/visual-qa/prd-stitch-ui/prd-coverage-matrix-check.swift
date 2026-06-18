import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let fileManager = FileManager.default

func url(_ relativePath: String) -> URL {
    root.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let fileURL = url(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard fileManager.fileExists(atPath: url(relativePath).path) else {
        fatalError("\(message): missing \(relativePath)")
    }
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let coveragePath = "docs/superpowers/status/2026-06-18-prd-coverage-matrix.md"
assertFileExists(coveragePath, "PRD coverage matrix")

let coverage = read(coveragePath)
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertContains(coverage, "# PRD Coverage Matrix", "coverage matrix should have title")
assertContains(coverage, "Source of truth", "coverage matrix should document source of truth")
assertContains(coverage, "current Stitch canvas and `htmlCode`", "coverage matrix should keep visual authority")
assertContains(coverage, "MCP screenshots are auxiliary", "coverage matrix should keep MCP screenshots auxiliary")
assertContains(coverage, "| PRD requirement | Current status | Public? | Evidence | Next action |", "coverage matrix should use the required table")

let requiredRows = [
    "| 回响语音输入 | implemented | yes | `EchoViewController`, archive-to-echo smoke | true-device microphone acceptance |",
    "| 2-3轮后等待回信 | partially implemented | yes | `EchoViewModel` | tune delay policy after product review |",
    "| 档案照片 | implemented | yes | Archive photo entry smoke | true-device photo acceptance |",
    "| 档案视频 | not implemented | no | release matrix | define video upload scope |",
    "| 档案录音 | hidden candidate | no | archive media smoke | true-device audio acceptance |",
    "| 档案文字描述 | implemented | yes | archive smoke | maintain |",
    "| 时间信件 | hidden candidate | no | archive media smoke | delivery policy |",
    "| 个人资料管理 | partially implemented | yes | `ProfileSettingsViewController` | avatar/password scope |",
    "| 心境追踪 | implemented fallback | yes | Profile care checks | lifecycle policy |",
    "| 家人管理 | hidden candidate | no | family persona smoke | product exposure decision |",
    "| 法律法规 | implemented | yes | `ProfileLegalViewController` | legal review |",
    "| 账号退出 | implemented | yes | `ProfileViewController` | maintain |",
    "| 账号注销 | hidden blocked shell | no | safety check | compliance/backend contract |",
    "| 长辈关怀 | implemented aggregate | yes | elder dashboard check | real backend acceptance |",
    "| 生死转换机制 | hidden boundary | no | mode lifecycle checks | product/legal policy |",
]

for row in requiredRows {
    assertContains(coverage, row, "coverage matrix should include required PRD row")
}

let requiredStatuses = [
    "implemented",
    "partially implemented",
    "hidden candidate",
    "hidden blocked shell",
    "hidden boundary",
    "not implemented",
    "implemented aggregate",
    "implemented fallback",
]

for status in requiredStatuses {
    assertContains(coverage, status, "coverage matrix should use explicit status \(status)")
}

for phrase in [
    "真机已验收",
    "真实后端已验收",
    "true-device complete",
    "real backend complete",
    "production backend accepted",
    "physical device accepted",
] {
    assertNotContains(coverage, phrase, "coverage matrix must not overclaim external acceptance")
}

assertContains(coverage, "本地 FastAPI 后端 smoke：accepted", "coverage matrix should mark local FastAPI backend smoke as accepted")
assertContains(coverage, "release-like FastAPI/Postgres 后端验收：not accepted", "coverage matrix should mark release-like Postgres backend as not accepted")
assertContains(coverage, "线上/公网后端验收：not accepted", "coverage matrix should mark remote backend as not accepted")
assertContains(coverage, "真机验收：not accepted", "coverage matrix should mark true-device as not accepted")
assertContains(coverage, "No hidden PRD feature is public by default", "coverage matrix should preserve release gating policy")
assertContains(coverage, "需要 Docker/Postgres runtime or deployed FastAPI/Postgres URL/token", "coverage matrix should call out release-like backend blocker")
assertContains(coverage, "需要确认线上/公网后端 URL/token", "coverage matrix should call out remote backend blocker")
assertContains(coverage, "需要真机、签名和设备操作", "coverage matrix should call out device blocker")

assertContains(releasePackage, "tmp/visual-qa/prd-stitch-ui/prd-coverage-matrix-check.swift", "release QA package should include PRD coverage guard")
assertContains(releasePackage, coveragePath, "release QA package should include PRD coverage doc")

print("PRD coverage matrix checks passed")
