import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func fileURL(_ relativePath: String) -> URL {
    rootURL.appendingPathComponent(relativePath)
}

func read(_ relativePath: String) -> String {
    let url = fileURL(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertFileExists(_ relativePath: String, _ message: String) {
    guard FileManager.default.fileExists(atPath: fileURL(relativePath).path) else {
        fatalError(message)
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError(message)
    }
}

let readinessDocPath = "docs/superpowers/status/2026-06-18-device-backend-acceptance-readiness.md"
let gapMapPath = "docs/superpowers/status/2026-06-18-prd-continuation-gap-map.md"
let backendSmokePath = "tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh"
let archiveSmokePath = "tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh"

assertFileExists(readinessDocPath, "Device/backend acceptance readiness doc should exist")
assertFileExists(backendSmokePath, "Backend environment smoke script should exist")
assertFileExists(archiveSmokePath, "Archive-to-echo core smoke script should exist")
assertFileExists(
    "tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift",
    "Backend build config guard should exist"
)
assertFileExists(
    "tmp/visual-qa/prd-stitch-ui/backend-env-smoke-check.swift",
    "Backend environment smoke guard should exist"
)
assertFileExists(
    "DreamJourney/Config/Backend.example.xcconfig",
    "Backend example xcconfig should exist"
)

let readinessDoc = read(readinessDocPath)
let gapMap = read(gapMapPath)
let plist = read("DreamJourney/Resources/Info.plist")
let gitignore = read(".gitignore")
let backendSmoke = read(backendSmokePath)
let archiveSmoke = read(archiveSmokePath)
let backendExample = read("DreamJourney/Config/Backend.example.xcconfig")

for required in [
    "真机验收",
    "后端验收",
    "阻塞条件",
    "验收就绪",
    "公网后端模拟器 release-like 验收已通过",
    "不是 APNs 真机通知已验收",
    "不要把真实 token 提交",
    "不能声明真机已验收",
    "20260618-deployed-echo-dispatch-contract-accepted-211732",
    "echoDelayedReplyDispatchState=readyForProvider",
    "echoDelayedReplyProviderDeliveryAttempted=false",
    "APNs provider delivery",
    "DREAMJOURNEY_BACKEND_BASE_URL",
    "DREAMJOURNEY_BACKEND_API_TOKEN",
    "Backend.local.xcconfig",
    "Backend.example.xcconfig",
    "run-backend-env-smoke.sh",
    "run-archive-to-echo-smoke.sh",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "NSCameraUsageDescription",
    "backend-env-smoke-result.json",
    "archive-to-echo-smoke-result.json",
    "report.md",
    "截图"
] {
    assertContains(readinessDoc, required, "Readiness doc should mention \(required)")
}

assertContains(
    gapMap,
    "2026-06-18-device-backend-acceptance-readiness.md",
    "PRD continuation gap map should link the device/backend readiness doc"
)
assertContains(
    gapMap,
    "公网后端 release-like scope accepted",
    "Gap map should clearly separate deployed backend simulator acceptance from true-device acceptance"
)

for required in [
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSSpeechRecognitionUsageDescription",
    "NSCameraUsageDescription",
    "DreamJourneyBackendBaseURL",
    "DreamJourneyBackendAPIToken",
    "$(DREAMJOURNEY_BACKEND_BASE_URL)",
    "$(DREAMJOURNEY_BACKEND_API_TOKEN)"
] {
    assertContains(plist, required, "Info.plist should contain \(required)")
}

assertContains(
    gitignore,
    "DreamJourney/Config/Backend.local.xcconfig",
    "Local backend xcconfig should stay ignored"
)
assertContains(
    backendExample,
    "DREAMJOURNEY_BACKEND_BASE_URL = http://127.0.0.1:3100",
    "Backend example should document local default base URL"
)
assertContains(
    backendExample,
    "DREAMJOURNEY_BACKEND_API_TOKEN = YOUR_DREAMJOURNEY_BACKEND_API_TOKEN",
    "Backend example should keep placeholder token only"
)

for required in [
    "BACKEND_API_TOKEN=\"${BACKEND_API_TOKEN:-}\"",
    "BACKEND_API_TOKEN is required",
    "DREAMJOURNEY_BACKEND_BASE_URL=\"$BACKEND_BASE_URL\"",
    "DREAMJOURNEY_BACKEND_API_TOKEN=\"$BACKEND_API_TOKEN\"",
    "backend-auth-token-contract-check.py",
    "backend-integration-contract-check.py",
    "DJRunBackendEnvSmoke",
    "backend-env-smoke-result.json",
    "report.md"
] {
    assertContains(backendSmoke, required, "Backend smoke script should contain \(required)")
}

for required in [
    "DJRunArchiveToEchoSmoke",
    "ArchiveToEchoSmoke completed",
    "archive-to-echo-smoke-result.json",
    "containsArchiveContext",
    "01-archive-to-echo-completed.png"
] {
    assertContains(archiveSmoke, required, "Archive-to-echo smoke script should contain \(required)")
}

print("Device/backend readiness checks passed")
