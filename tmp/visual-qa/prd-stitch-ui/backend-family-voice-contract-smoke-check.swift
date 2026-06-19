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

let runner = "tmp/visual-qa/prd-stitch-ui/run-backend-family-voice-contract-smoke.sh"
let pythonSmoke = "tmp/visual-qa/prd-stitch-ui/backend-family-voice-contract-smoke.py"
let statusDoc = "docs/superpowers/status/2026-06-19-backend-family-voice-contract-smoke.md"

assertFileExists(runner, "backend family/voice contract runner")
assertFileExists(pythonSmoke, "backend family/voice contract Python smoke")
assertFileExists(statusDoc, "backend family/voice contract status doc")

let runnerContent = read(runner)
let pythonContent = read(pythonSmoke)
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let status = read(statusDoc)

for required in [
    "BACKEND_FAMILY_VOICE_CONTRACT_SMOKE",
    "deployed-backend-access.md",
    "value intentionally omitted",
    "backend-family-voice-contract-smoke.py",
    "backend-family-voice-contract-smoke-result.json",
] {
    assertContains(runnerContent, required, "runner should include \(required)")
}
assertNotContains(runnerContent, "echo \"$BACKEND_API_TOKEN\"", "runner must not print raw token")
assertNotContains(runnerContent, "cat \"$ACCESS_DOC\"", "runner must not print the private access doc")

for required in [
    "/health",
    "/config/runtime",
    "/family/invite",
    "/family/members/",
    "/voice/profiles",
    "digitalHumanMode",
    "digitalHumanModeLabel",
    "sunlight",
    "star",
    "silent",
    "阳光",
    "星辰",
    "静默",
    "mockFamilyPersona",
    "familyPersonaContractVersion",
    "defaultReleaseVisible",
    "voiceProfileId",
    "authorizationConfirmed",
    "sampleStatus",
    "disable",
    "DELETE",
    "value intentionally omitted",
] {
    assertContains(pythonContent, required, "Python smoke should cover \(required)")
}

assertContains(releaseRegression, "RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE", "release regression should expose optional family/voice backend smoke")
assertContains(releaseRegression, "run-backend-family-voice-contract-smoke.sh", "release regression should call family/voice backend smoke")
assertContains(releaseRegression, "backend-family-voice-contract-smoke", "release regression report should mention family/voice evidence")
assertContains(releaseRegression, "backend-family-voice-contract-smoke-check.swift", "release regression should run the static guard")

for requiredPackageEntry in [
    "run-backend-family-voice-contract-smoke.sh",
    "backend-family-voice-contract-smoke.py",
    "backend-family-voice-contract-smoke-check.swift",
    "2026-06-19-backend-family-voice-contract-smoke.md",
] {
    assertContains(releasePackage, requiredPackageEntry, "release QA package should include \(requiredPackageEntry)")
}

assertContains(releaseMatrix, "backend-family-voice-contract-smoke-check.swift", "release matrix should document the family/voice backend smoke")
assertContains(status, "family digital-human", "status doc should document family digital-human scope")
assertContains(status, "voice profile lifecycle", "status doc should document voice profile lifecycle scope")
assertContains(status, "RUN_BACKEND_FAMILY_VOICE_CONTRACT_SMOKE=1", "status doc should show release regression flag")
assertContains(status, "BACKEND_API_TOKEN", "status doc should explain token sourcing without exposing it")

print("Backend family/voice contract smoke checks passed")
