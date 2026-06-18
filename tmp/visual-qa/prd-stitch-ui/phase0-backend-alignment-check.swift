import Foundation

let appRoot = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let workspaceRoot = appRoot.deletingLastPathComponent()
let backendRoot = workspaceRoot.appendingPathComponent("DreamJourneyBackend")
let fileManager = FileManager.default

func read(_ url: URL) -> String {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertFileExists(_ url: URL, _ message: String) {
    guard fileManager.fileExists(atPath: url.path) else {
        fatalError("\(message): missing \(url.path)")
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

let statusDocURL = appRoot.appendingPathComponent("docs/superpowers/status/2026-06-18-phase0-backend-alignment.md")
let appClientURL = appRoot.appendingPathComponent("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releasePackageURL = appRoot.appendingPathComponent("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
let backendMainURL = backendRoot.appendingPathComponent("app/main.py")
let backendREADMEURL = backendRoot.appendingPathComponent("README.md")
let backendVerifyURL = backendRoot.appendingPathComponent("scripts/verify_backend.sh")

assertFileExists(backendMainURL, "DreamJourneyBackend FastAPI app")
assertFileExists(backendREADMEURL, "DreamJourneyBackend README")
assertFileExists(backendVerifyURL, "DreamJourneyBackend verify script")
assertFileExists(statusDocURL, "phase 0 backend alignment status doc")

let statusDoc = read(statusDocURL)
let appClient = read(appClientURL)
let releasePackage = read(releasePackageURL)
let backendMain = read(backendMainURL)
let backendREADME = read(backendREADMEURL)
let backendVerify = read(backendVerifyURL)

let appRequiredEndpoints = [
    "/archive/items",
    "/archive/items/",
    "/kb/sync",
    "/family/members/",
    "/care/snapshots/latest/",
]

for endpoint in appRequiredEndpoints {
    assertContains(appClient, endpoint, "iOS backend client should still call \(endpoint)")
}

let backendRequiredRoutes = [
    "@app.get(\"/health\")",
    "@app.get(\"/config/runtime\")",
    "@app.post(\"/archive/items\")",
    "@app.get(\"/archive/items/{user_id}\")",
    "@app.post(\"/kb/sync\")",
    "@app.get(\"/kb/snapshot/{user_id}\")",
    "@app.post(\"/family/invite\")",
    "@app.post(\"/family/members/{user_id}/{member_id}/accept\")",
    "@app.get(\"/family/members/{user_id}\")",
    "@app.post(\"/care/snapshots\")",
    "@app.get(\"/care/snapshots/latest/{user_id}\")",
]

for route in backendRequiredRoutes {
    assertContains(backendMain, route, "DreamJourneyBackend should expose route \(route)")
}

let readmeRequiredRoutes = [
    "POST /archive/items",
    "GET /archive/items/{user_id}",
    "POST /mailbox/letters",
    "GET /mailbox/letters/{user_id}",
    "POST /care/snapshots",
    "GET /care/snapshots/latest/{user_id}",
    "GET /care/snapshots/{user_id}",
]

for route in readmeRequiredRoutes {
    assertContains(backendREADME, route, "DreamJourneyBackend README should document route \(route)")
}

assertContains(backendVerify, "PYTHON_BIN", "verify_backend should use a configurable Python interpreter")
assertContains(backendVerify, ".venv/bin/python", "verify_backend should prefer the local virtualenv")
assertContains(backendVerify, "STORE_BACKEND=memory PYTHONPATH=.", "verify_backend unittest should run in memory mode")

assertContains(statusDoc, "DreamJourneyBackend exists", "phase 0 doc should state backend repo exists")
assertContains(statusDoc, "/Users/yxj/Documents/Codex/Video/DreamJourneyBackend", "phase 0 doc should record backend path")
assertContains(statusDoc, "20260618-phase0-backend-alignment", "phase 0 doc should record iOS backend smoke run id")
assertContains(statusDoc, "backend-env-smoke-result.json", "phase 0 doc should reference iOS backend smoke result")
assertContains(statusDoc, "真机验收：not accepted", "phase 0 doc should preserve true-device boundary")
assertContains(statusDoc, "线上/公网后端验收：not accepted", "phase 0 doc should preserve remote backend boundary")
assertContains(statusDoc, "本地 FastAPI 后端 smoke：accepted", "phase 0 doc should record local backend acceptance")
assertNotContains(statusDoc, "后端不存在", "phase 0 doc must not claim backend is missing")

assertContains(releasePackage, "phase0-backend-alignment-check.swift", "release QA package should include phase 0 backend alignment guard")

print("Phase 0 backend alignment checks passed")
