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

let runner = "Scripts/QA/prd-stitch-ui/run-digital-human-voice-clone-combo-gate.sh"
assertFileExists(runner, "digital-human voice-clone combo gate runner")

let runnerContent = read(runner)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "run-backend-digital-human-session-smoke.sh",
    "run-backend-voice-clone-deployed-smoke.sh",
    "run-voice-clone-synthesis-runtime-smoke.sh",
    "run-tencent-backend-pcm-drive-mock-smoke.sh",
    "backend-digital-human-session-smoke",
    "backend-voice-clone-deployed-smoke",
    "voice-clone-synthesis-runtime-smoke",
    "tencent-backend-pcm-drive-mock-smoke",
    "Digital human + voice clone combo gate",
] {
    assertContains(runnerContent, required, "combo gate should include \(required)")
}

for required in [
    "RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE",
    "run-digital-human-voice-clone-combo-gate.sh",
    "digital-human-voice-clone-combo-gate-check.swift",
] {
    assertContains(releaseRegression, required, "release regression should include \(required)")
}

for required in [
    "run-digital-human-voice-clone-combo-gate.sh",
    "digital-human-voice-clone-combo-gate-check.swift",
] {
    assertContains(releaseQA, required, "release QA package should include \(required)")
}

print("Digital human voice clone combo gate checks passed")
