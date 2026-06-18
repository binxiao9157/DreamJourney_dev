import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String, root baseURL: URL = root) -> String {
    let url = baseURL.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let matrix = read("docs/superpowers/status/2026-06-18-backend-contract-gap-matrix.md")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")
let backendMain = read("app/main.py", root: backendRoot)
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

for endpoint in [
    "/echo/delayed-replies",
    "/profile",
    "/auth/login",
    "/auth/password",
    "/archive/items",
    "/care/snapshots/latest/{userId}",
] {
    assertContains(matrix, endpoint, "backend contract matrix should include endpoint \(endpoint)")
}

for rowLabel in [
    "Echo delayed reply push",
    "Profile update",
    "Password change",
    "Archive ownership",
    "Care snapshot states",
] {
    assertContains(matrix, rowLabel, "backend contract matrix should include \(rowLabel)")
}

for state in [
    "backend route missing",
    "backend route present locally",
    "deployment/APNs/device token needed",
    "backend accepts and persists nickname/gender/region/avatar metadata",
    "backend/security needed",
    "backend field migration needed",
    "backend accepted, state variants needed",
] {
    assertContains(matrix, state, "backend contract matrix should record \(state)")
}

assertContains(client, "requestJSON(path: \"/echo/delayed-replies\"", "iOS client should define echo delayed reply endpoint")
assertContains(client, "requestJSON(path: \"/profile\"", "iOS client should define profile endpoint")
assertContains(client, "path: \"/auth/password\"", "iOS client should define password endpoint")
assertContains(client, "requestJSON(path: \"/archive/items\"", "iOS client should define archive create endpoint")
assertContains(client, "requestJSON(path: \"/care/snapshots/latest/\\(pathComponent(userId))\"", "iOS client should define care latest endpoint")
assertContains(userManager, "DreamJourneyBackendClient.shared.updateProfile", "Profile update should use the dedicated backend contract")

assertContains(backendMain, "@app.post(\"/auth/login\")", "backend should expose auth login")
assertContains(backendMain, "@app.post(\"/profile\")", "backend should expose profile update")
assertContains(backendMain, "@app.get(\"/profile/{user_id}\")", "backend should expose profile read")
assertContains(backendMain, "@app.post(\"/echo/delayed-replies\")", "backend should expose echo delayed reply schedule")
assertContains(backendMain, "@app.get(\"/echo/delayed-replies/{user_id}\")", "backend should expose echo delayed reply list")
assertContains(backendMain, "@app.post(\"/archive/items\")", "backend should expose archive item create")
assertContains(backendMain, "@app.get(\"/archive/items/{user_id}\")", "backend should expose archive item list")
assertContains(backendMain, "@app.get(\"/care/snapshots/latest/{user_id}\")", "backend should expose latest care snapshot")

assertContains(releaseRegression, "backend-contract-gap-check.swift", "Release regression should run backend contract gap guard")
assertContains(releaseQA, "backend-contract-gap-check.swift", "Release QA package should include backend contract gap guard")
assertContains(releaseQA, "2026-06-18-backend-contract-gap-matrix.md", "Release QA package should include backend contract matrix")

print("Backend contract gap checks passed")
