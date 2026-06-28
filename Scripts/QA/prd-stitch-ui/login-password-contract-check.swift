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

let login = read("DreamJourney/Sources/Modules/Auth/LoginViewController.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let coverageMatrix = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")

assertContains(login, "let password = normalizedPassword()", "Login should normalize password before submitting")
assertContains(login, "guard password.count >= 8", "Login should validate password length")
assertContains(login, "showLoginAlert(title: \"密码不能为空\"", "Login should show a clear password validation error")
assertContains(login, "DreamJourneyBackendClient.shared.isLoginSyncConfigured", "Login should only call remote auth when backend auth is configured")
assertContains(login, "DreamJourneyBackendClient.shared.upsertUser(phone: rawPhone, nickname: \"\", password: password)", "Login should send password to /auth/login")
assertContains(login, "handleBackendLoginSuccess", "Login should persist the backend returned user identity")
assertContains(login, "setLoginInProgress(true)", "Login should prevent repeated submissions while remote auth is running")
assertContains(login, "setLoginInProgress(false)", "Login should restore button state after remote auth finishes")

assertContains(userManager, "func login(phone: String, nickname: String, id: String? = nil)", "UserManager should support backend user ids")
assertContains(userManager, "id: id ?? \"user_\\(phone.suffix(4))\"", "UserManager should preserve local fallback ids")

assertContains(backendClient, "var isLoginSyncConfigured", "Backend client should expose login sync configuration")
assertContains(backendClient, "func upsertUser(", "Backend client login should expose upsertUser")
assertContains(backendClient, "password: String? = nil", "Backend client login should accept an optional password")
assertContains(backendClient, "payload[\"password\"] = password", "Backend auth payload should include password when provided")
assertContains(backendClient, "requestJSON(path: \"/auth/login\"", "Backend auth should use /auth/login")

assertContains(releaseRegression, "login-password-contract-check.swift", "Release regression should run login password guard")
assertContains(releasePackage, "Scripts/QA/prd-stitch-ui/login-password-contract-check.swift", "Release QA package should include login password guard")
assertContains(coverageMatrix, "login password participation", "PRD coverage should track login password participation boundary")

print("Login password contract checks passed")
