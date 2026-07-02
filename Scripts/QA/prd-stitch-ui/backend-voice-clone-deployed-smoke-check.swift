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

let runner = "Scripts/QA/prd-stitch-ui/run-backend-voice-clone-deployed-smoke.sh"
let pythonSmoke = "Scripts/QA/prd-stitch-ui/backend-voice-clone-deployed-smoke.py"
let statusDoc = "docs/superpowers/status/2026-06-29-backend-voice-clone-deployed-smoke.md"

assertFileExists(runner, "backend voice clone deployed smoke runner")
assertFileExists(pythonSmoke, "backend voice clone deployed Python smoke")
assertFileExists(statusDoc, "backend voice clone deployed smoke status doc")

let runnerContent = read(runner)
let pythonContent = read(pythonSmoke)
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let status = read(statusDoc)

for required in [
    "BACKEND_VOICE_CLONE_DEPLOYED_SMOKE",
    "Backend.local.xcconfig",
    "deployed-backend-access.md",
    "value intentionally omitted",
    "backend-voice-clone-deployed-smoke.py",
    "backend-voice-clone-deployed-smoke-result.json",
] {
    assertContains(runnerContent, required, "runner should include \(required)")
}
assertNotContains(runnerContent, "echo \"$BACKEND_API_TOKEN\"", "runner must not print raw token")
assertNotContains(runnerContent, "cat \"$ACCESS_DOC\"", "runner must not print the private access doc")

for required in [
    "/health",
    "/config/runtime",
    "/voice/profiles",
    "/voice/synthesis",
    "voiceClone2TrialReady",
    "synthesisProviderReady",
    "tencentAudioDrive",
    "seed-icl-2.0",
    "VOICE_CLONE_READY_PROFILE_ID",
    "VOICE_CLONE_NON_READY_PROFILE_ID",
    "pcm16kMono",
    "byteCount",
    "audioDataOmitted",
    "diagnosticFailure",
    "value intentionally omitted",
] {
    assertContains(pythonContent, required, "Python smoke should cover \(required)")
}
assertNotContains(pythonContent, "print(audio", "Python smoke must not print raw audio")
assertNotContains(pythonContent, "S_PhXlHqB52", "Python smoke must not default to exhausted trial voice IDs")
assertNotContains(pythonContent, "S_deJ2HqB52", "Python smoke must not default to old trial voice IDs")
assertNotContains(runnerContent, "S_PhXlHqB52", "runner must not default to exhausted trial voice IDs")
assertNotContains(runnerContent, "S_deJ2HqB52", "runner must not default to old trial voice IDs")

assertContains(releaseRegression, "RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE", "release regression should expose optional deployed voice clone smoke")
assertContains(releaseRegression, "run-backend-voice-clone-deployed-smoke.sh", "release regression should call deployed voice clone smoke")
assertContains(releaseRegression, "backend-voice-clone-deployed-smoke", "release regression report should mention deployed voice clone evidence")
assertContains(releaseRegression, "backend-voice-clone-deployed-smoke-check.swift", "release regression should run the deployed voice clone static guard")

for requiredPackageEntry in [
    "run-backend-voice-clone-deployed-smoke.sh",
    "backend-voice-clone-deployed-smoke.py",
    "backend-voice-clone-deployed-smoke-check.swift",
    "2026-06-29-backend-voice-clone-deployed-smoke.md",
] {
    assertContains(releasePackage, requiredPackageEntry, "release QA package should include \(requiredPackageEntry)")
}

assertContains(status, "RUN_BACKEND_VOICE_CLONE_DEPLOYED_SMOKE=1", "status doc should show release regression flag")
assertContains(status, "VOICE_CLONE_READY_PROFILE_ID", "status doc should require explicit ready probe voice")
assertContains(status, "S_PhXlHqB52` 已耗尽训练次数", "status doc should mark the exhausted voice slot explicitly")
assertContains(status, "S_URAKGqB52,S_TRAKGqB52,S_SRAKGqB52", "status doc should document the replacement trial slot pool")
assertContains(status, "不输出音频", "status doc should state raw audio is omitted")

print("Backend voice clone deployed smoke checks passed")
