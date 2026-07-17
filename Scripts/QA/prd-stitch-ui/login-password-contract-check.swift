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

func assertNotContains(_ haystack: String, _ needle: String, _ message: String) {
    guard !haystack.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

let login = read("DreamJourney/Sources/Modules/Auth/LoginViewController.swift")
let userManager = read("DreamJourney/Sources/Services/UserManager.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let identityContract = read("DreamJourney/Sources/Services/BackendIdentityChallenge.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releasePackage = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let coverageMatrix = read("docs/superpowers/status/2026-06-18-prd-coverage-matrix.md")

assertContains(login, "DreamJourneyBackendClient.shared.isLoginSyncConfigured", "Login should only call remote auth when backend auth is configured")
assertContains(login, "identityChallenge.canStartClientFlow", "Login should fail closed unless the typed identity capability is ready")
assertContains(login, "beginIdentityChallengeLogin", "Login should create an identity challenge")
assertContains(login, "verifyIdentityChallenge", "Login should verify the identity challenge")
assertContains(login, "let submittedPhone = rawPhone", "Login should snapshot the submitted phone before asynchronous work")
assertContains(login, "handleBackendLoginSuccess", "Login should persist the backend returned user identity")
assertContains(login, "setLoginInProgress(true)", "Login should prevent repeated submissions while remote auth is running")
assertContains(login, "setLoginInProgress(false)", "Login should restore button state after remote auth finishes")
assertNotContains(login, "passwordField", "Current strong identity login must not present an unused password field")
assertNotContains(login, "忘记密码", "Current strong identity login must not expose the retired password recovery path")

assertContains(userManager, "func login(phone: String, nickname: String, id: String? = nil)", "UserManager should support backend user ids")

assertContains(backendClient, "var isLoginSyncConfigured", "Backend client should expose login sync configuration")
assertContains(backendClient, "func createIdentityChallenge(", "Backend client should expose challenge creation")
assertContains(backendClient, "path: \"/v2/auth/challenges\"", "Backend client should use the typed challenge endpoint")
assertContains(backendClient, "func verifyIdentityChallenge(", "Backend client should expose challenge verification")
assertContains(identityContract, "contractFieldsComplete", "Runtime capability fields must fail closed when incomplete")

assertContains(releaseRegression, "login-password-contract-check.swift", "Release regression should run login password guard")
assertContains(releasePackage, "Scripts/QA/prd-stitch-ui/login-password-contract-check.swift", "Release QA package should include login password guard")
assertContains(coverageMatrix, "strong identity challenge", "PRD coverage should track the strong identity boundary")

print("Login strong identity contract checks passed")
