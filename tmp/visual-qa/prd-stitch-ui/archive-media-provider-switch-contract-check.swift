import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, in baseURL: URL = root) -> String {
    let fileURL = baseURL.appendingPathComponent(relativePath)
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

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let detail = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let hiddenShellRunner = read("tmp/visual-qa/prd-stitch-ui/run-archive-hidden-shell-smoke.sh")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let statusDoc = read("docs/superpowers/status/2026-06-19-archive-hidden-media-combo-gate.md")

let backendMain = read("app/main.py", in: backendRoot)
let backendRuntime = read("app/services/runtime_config.py", in: backendRoot)
let backendTests = read("tests/test_core_services.py", in: backendRoot)

for required in [
    "providerDisplayName",
    "providerMode",
    "requiresClientUpload",
    "uploadURLScheme",
    "realProviderReady",
    "providerSwitchContractVersion",
    "clientUploadAction",
] {
    assertContains(
        backendRuntime,
        "\"\(required)\"",
        "backend /config/runtime archive capability should expose provider switch field \(required)"
    )
    assertContains(
        backendMain,
        "\"\(required)\"",
        "backend upload-intent should echo provider switch field \(required)"
    )
    assertContains(
        backendTests,
        required,
        "backend tests should lock provider switch field \(required)"
    )
    assertContains(
        backendClient,
        "let \(required)",
        "iOS runtime capability should parse provider switch field \(required)"
    )
}

for required in [
    "\"providerMode\": \"mock\"",
    "\"requiresClientUpload\": False",
    "\"uploadURLScheme\": \"mock\"",
    "\"realProviderReady\": False",
    "\"providerSwitchContractVersion\": 1",
    "\"clientUploadAction\": \"metadataOnly\"",
] {
    assertContains(backendRuntime, required, "runtime config should document mock object-storage behavior \(required)")
}

for required in [
    "Mock 模式，仅同步媒体元数据",
    "暂不执行真实文件 PUT",
] {
    assertContains(backendClient, required, "iOS runtime capability should define provider switch copy \(required)")
}

for required in [
    "providerModeDisplayText",
    "uploadExecutionDisplayText",
    "真实对象存储上传尚未开放",
    "archive-hidden-media-runtime-upload-mode",
] {
    assertContains(detail, required, "hidden media detail should disclose provider switch behavior \(required)")
}

for required in [
    "hiddenMediaRuntimeUploadModeVisible",
    "hiddenMediaRuntimeMockCopyVisible",
] {
    assertContains(appDelegate, required, "hidden media UIQA should assert provider switch copy \(required)")
    assertContains(hiddenShellRunner, "\"\(required)\"", "hidden media shell runner should assert provider switch copy \(required)")
}

assertContains(
    releaseRegression,
    "archive-media-provider-switch-contract-check.swift",
    "release regression should run provider switch contract guard"
)
assertContains(
    releaseQA,
    "archive-media-provider-switch-contract-check.swift",
    "release QA package should include provider switch contract guard"
)
assertContains(
    statusDoc,
    "provider switch contract",
    "status doc should document provider switch contract"
)

print("Archive media provider switch contract checks passed")
