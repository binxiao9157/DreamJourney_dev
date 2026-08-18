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
let passwordContract = read("DreamJourney/Sources/Services/BackendPasswordAuthentication.swift")
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
assertContains(login, "private let verificationField", "Verification code entry should remain visible on the login page")
assertContains(login, "private let credentialModeControl", "Login should expose password / verification segmented modes")
assertContains(login, "private let passwordField", "Password login should use an inline secure password field")
assertContains(login, "忘记密码", "Password mode should expose the reset flow")
assertContains(login, "passwordAuthentication.canLogin", "Password mode must fail closed on runtime readiness")
assertContains(login, "loginWithPassword", "Password mode should call the typed password login client")
assertContains(login, "PasswordResetViewController", "Forgot password should route to the typed reset flow")
assertContains(login, "requestVerificationCodeTapped", "Login should expose an explicit request-code action")
assertContains(login, "verificationField.isEnabled = !isBusy", "Verification entry should accept typing before challenge creation")
assertContains(login, "usesPassword ? hasPassword && passwordAuthentication.canLogin : hasVerificationCode", "Login should validate the active credential mode before enabling submit")
assertContains(login, "requestIdentityChallenge(autoSubmitCode: verificationCode)", "Login should create a challenge automatically when a code was entered first")
assertContains(login, "submitIdentityVerification(", "Login should continue verification after automatic challenge creation")
assertContains(login, "authMode = authMode == .login ? .register : .login", "Registration link should switch to a real registration state")
assertContains(login, "注册并登录", "Registration state should expose a clear submit action")
assertNotContains(login, "alert.addTextField", "Verification code entry should not regress to a transient alert")
assertContains(login, "purpose: authMode == .register ? \"register\" : \"login\"", "OTP login and registration must retain explicit challenge purposes")

assertContains(userManager, "func login(phone: String, nickname: String, id: String? = nil)", "UserManager should support backend user ids")

assertContains(backendClient, "var isLoginSyncConfigured", "Backend client should expose login sync configuration")
assertContains(backendClient, "func createIdentityChallenge(", "Backend client should expose challenge creation")
assertContains(backendClient, "path: \"/v2/auth/challenges\"", "Backend client should use the typed challenge endpoint")
assertContains(backendClient, "func verifyIdentityChallenge(", "Backend client should expose challenge verification")
assertContains(backendClient, "func verifyIdentityChallengeAction(", "Backend client should parse password reset and reauthentication action tokens")
assertContains(backendClient, "func loginWithPassword(", "Backend client should expose typed password login")
assertContains(backendClient, "path: \"/v2/auth/password/login\"", "Password login must use the PC-A0 endpoint")
assertContains(backendClient, "func resetPassword(", "Backend client should expose typed password reset")
assertContains(backendClient, "path: \"/v2/auth/password/reset\"", "Password reset must use the PC-A0 endpoint")
assertContains(identityContract, "contractFieldsComplete", "Runtime capability fields must fail closed when incomplete")
assertContains(identityContract, "testAccountFlowEnabled", "Test allowlist login must require an explicit runtime enablement")
assertContains(identityContract, "testAccountTargetRestricted", "Test allowlist login must remain target restricted")
assertContains(passwordContract, "struct BackendPasswordAuthenticationCapability", "Password runtime capability must be typed")
assertContains(passwordContract, "json?[\"ready\"]", "Password readiness must consume the backend V2 runtime descriptor")
assertContains(passwordContract, "json?[\"loginReady\"]", "Password login must consume its explicit runtime readiness")
assertContains(passwordContract, "json?[\"setupReady\"]", "Password setup must consume its explicit runtime readiness")
assertContains(passwordContract, "json?[\"resetReady\"]", "Password reset must consume its explicit runtime readiness")
assertContains(passwordContract, "json?[\"reauthReady\"]", "Password action flows must consume explicit reauthentication readiness")
assertContains(passwordContract, "json?[\"minLength\"]", "Password validation must consume the backend minimum length")
assertContains(passwordContract, "sessionContractVersion == 2", "Password readiness must reject incompatible session contracts")
assertContains(passwordContract, "contractVersion == 2", "Password readiness must reject incompatible password contracts")
assertContains(passwordContract, "struct BackendPasswordActionTokenContract", "OTP action verification must return a typed one-time token")
assertContains(passwordContract, "case locked", "Password presentation state must preserve lockout")

assertContains(releaseRegression, "login-password-contract-check.swift", "Release regression should run login password guard")
assertContains(releasePackage, "Scripts/QA/prd-stitch-ui/login-password-contract-check.swift", "Release QA package should include login password guard")
assertContains(coverageMatrix, "strong identity challenge", "PRD coverage should track the strong identity boundary")

print("Login strong identity contract checks passed")
