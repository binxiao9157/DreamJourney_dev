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

let runner = "tmp/visual-qa/prd-stitch-ui/run-backend-archive-image-analysis-smoke.sh"
let pythonSmoke = "tmp/visual-qa/prd-stitch-ui/backend-archive-image-analysis-smoke.py"
let statusDoc = "docs/superpowers/status/2026-06-19-backend-archive-image-analysis-smoke.md"

assertFileExists(runner, "backend archive image analysis runner")
assertFileExists(pythonSmoke, "backend archive image analysis Python smoke")
assertFileExists(statusDoc, "backend archive image analysis status doc")

let runnerContent = read(runner)
let pythonContent = read(pythonSmoke)
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let status = read(statusDoc)

assertContains(runnerContent, "BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE", "runner should have a stable log prefix")
assertContains(runnerContent, "deployed-backend-access.md", "runner should discover the private deployed backend access doc")
assertContains(runnerContent, "value intentionally omitted", "runner/report should redact the backend token")
assertContains(runnerContent, "backend-archive-image-analysis-smoke.py", "runner should execute the Python E2E smoke")
assertNotContains(runnerContent, "echo \"$BACKEND_API_TOKEN\"", "runner must not print raw token")
assertNotContains(runnerContent, "cat \"$ACCESS_DOC\"", "runner must not print the private access doc")

for required in [
    "/health",
    "/config/runtime",
    "/archive/image-analysis",
    "/archive/items",
    "dryRun",
    "responseContract",
    "GET",
    "POST",
    "detectedPeople",
    "detectedLocations",
    "detectedScenes",
    "analysisFailureReason",
    "analysisRetryable",
    "analysisStatus",
    "privacyMetadata",
    "generationAllowed",
    "archiveImageAnalysis",
    "supportsVision",
    "fallbackMode",
    "deepseek/text-only",
] {
    assertContains(pythonContent, required, "Python smoke should cover \(required)")
}
assertContains(pythonContent, "default_memory_1.imageset/memory.jpg", "Python smoke should use the app memory asset as album-import input")
assertContains(pythonContent, "assert_deployed_contract_preflight", "Python smoke should fail fast when deployed backend contract is stale")
assertContains(pythonContent, "assert_runtime_archive_image_analysis_contract", "Python smoke should verify runtime archive image-analysis capability")
assertContains(pythonContent, "assert_analysis_contract", "Python smoke should validate analyzed or failed retryable analysis contracts")
assertContains(pythonContent, "provider_unavailable", "Python smoke should accept provider unavailable as a retryable persisted analysis failure")
assertContains(pythonContent, "runtime_archive_image_analysis", "Python smoke should preserve runtime archive image-analysis capability evidence")
assertContains(pythonContent, "analysis_result", "Python smoke should preserve the image-analysis result")
assertContains(pythonContent, "persisted_item", "Python smoke should validate the saved archive item")
assertContains(pythonContent, "listed_item", "Python smoke should verify read-after-write archive listing")

assertContains(releaseRegression, "RUN_BACKEND_ARCHIVE_IMAGE_ANALYSIS_SMOKE", "release regression should expose optional archive image-analysis backend smoke")
assertContains(releaseRegression, "backend-archive-image-analysis-smoke", "release regression report should mention archive image-analysis backend smoke evidence")
assertContains(releaseRegression, "backend-archive-image-analysis-smoke-check.swift", "release regression should run the static guard")

for requiredPackageEntry in [
    "run-backend-archive-image-analysis-smoke.sh",
    "backend-archive-image-analysis-smoke.py",
    "backend-archive-image-analysis-smoke-check.swift",
    "2026-06-19-backend-archive-image-analysis-smoke.md",
] {
    assertContains(releasePackage, requiredPackageEntry, "release QA package should include \(requiredPackageEntry)")
}

assertContains(status, "相册导入 -> /archive/image-analysis -> /archive/items -> GET /archive/items", "status doc should describe the E2E smoke scope")
assertContains(status, "BACKEND_API_TOKEN", "status doc should explain token sourcing without exposing it")
assertContains(status, "analysisStatus", "status doc should record analysis status evidence")
assertContains(status, "detectedPeople", "status doc should record people clue evidence")
assertContains(status, "detectedLocations", "status doc should record location clue evidence")
assertContains(status, "detectedScenes", "status doc should record scene clue evidence")

print("Backend archive image-analysis smoke checks passed")
