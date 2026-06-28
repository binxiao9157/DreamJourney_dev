import Foundation

let rootPath = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let rootURL = URL(fileURLWithPath: rootPath)

func read(_ relativePath: String) -> String {
    let url = rootURL.appendingPathComponent(relativePath)
    do {
        return try String(contentsOf: url, encoding: .utf8)
    } catch {
        fatalError("Unable to read \(relativePath): \(error)")
    }
}

func assertContains(_ source: String, _ needle: String, _ message: String) {
    guard source.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

func assertNotContains(_ source: String, _ needle: String, _ message: String) {
    guard !source.contains(needle) else {
        fatalError("\(message): unexpected \(needle)")
    }
}

func extractDefaultEnabledFeatures(from flags: String) -> Set<String> {
    let marker = "private static let defaultEnabled: Set<DJFeature> = ["
    guard let start = flags.range(of: marker)?.upperBound,
          let end = flags[start...].range(of: "]")?.lowerBound else {
        fatalError("Unable to find FeatureFlagService.defaultEnabled")
    }

    let body = flags[start..<end]
    let regex = try! NSRegularExpression(pattern: "\\.([A-Za-z0-9_]+)")
    let range = NSRange(body.startIndex..<body.endIndex, in: body)
    return Set(regex.matches(in: String(body), range: range).compactMap { match in
        guard let valueRange = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[valueRange])
    })
}

func functionBody(named name: String, in source: String) -> String {
    guard let start = source.range(of: "func \(name)")?.lowerBound else {
        fatalError("Unable to find function \(name)")
    }
    let tail = source[start...]
    guard let nextFunction = tail.dropFirst().range(of: "\n    private func ")?.lowerBound
        ?? tail.dropFirst().range(of: "\n    @objc private func ")?.lowerBound
        ?? tail.dropFirst().range(of: "\n}")?.lowerBound else {
        return String(tail)
    }
    return String(source[start..<nextFunction])
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let careModels = read("DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")

let expectedDefaults: Set<String> = [
    "careDashboard",
    "familyManagement",
    "familySpace",
    "profileSettings",
    "legalCenter",
    "personaSettings",
    "timeLetters",
    "voiceCloneShell",
    "accountDeletion",
]
let defaults = extractDefaultEnabledFeatures(from: flags)
guard defaults == expectedDefaults else {
    fatalError("Default release flags changed. Expected \(expectedDefaults.sorted()), got \(defaults.sorted())")
}

for hidden in ["careDoctorContact", "accountPasswordChange"] {
    guard !defaults.contains(hidden) else {
        fatalError("\(hidden) must stay hidden by default")
    }
}

assertContains(profile, "private func shouldShowCareDashboard(context: DigitalHumanContext) -> Bool", "profile should expose explicit care visibility helper")
assertContains(profile, "featureFlags.isEnabled(.careDashboard)", "care visibility should still respect careDashboard flag")
assertContains(profile, "context.isSelfAssistant", "default self assistant should preserve current care dashboard")
assertContains(profile, "context.mode == .star", "family star persona should enable care dashboard")
assertContains(profile, "if shouldShowCareDashboard(context: personaContext)", "buildContent should use care visibility helper")
assertContains(profile, "guard shouldShowCareDashboard(context: personaContext)", "loadCareSnapshot should use care visibility helper")

assertContains(profile, "showAccountDeletionConfirmation()", "account deletion action should use confirmation shell")
assertContains(profile, "private func showAccountDeletionConfirmation()", "account deletion confirmation should have a dedicated function")
let deletionBody = functionBody(named: "showAccountDeletionConfirmation()", in: profile)
assertContains(deletionBody, "注销账户", "account deletion shell should have explicit title")
assertContains(deletionBody, "不支持数据导出", "account deletion shell should state no data export")
assertContains(deletionBody, "保留 30 天", "account deletion shell should state 30-day retention")
assertContains(deletionBody, "恢复机会只有 1 次", "account deletion shell should state one restore chance")
assertContains(deletionBody, "UIAlertAction(title: \"取消\", style: .cancel)", "account deletion shell should allow cancel")
assertContains(deletionBody, "UIAlertAction(title: \"我已了解，继续\", style: .destructive)", "account deletion first confirmation should be destructive")
assertContains(profile, "private func showFinalAccountDeletionConfirmation(user:", "account deletion should require a second confirmation")
assertContains(profile, "UIAlertAction(title: \"确认注销账户\", style: .destructive)", "account deletion second confirmation should be destructive")
assertContains(profile, "private func submitAccountDeletion(user:", "account deletion should submit through explicit backend function")
assertContains(backendClient, "softDeleteAccount(", "account deletion should call backend soft-delete contract")
assertContains(backendClient, "\"firstConfirmation\": true", "account deletion backend payload should include first confirmation")
assertContains(backendClient, "\"secondConfirmation\": true", "account deletion backend payload should include second confirmation")
assertContains(profile, "UserManager.shared.logout()", "account deletion should log out after backend soft delete succeeds")
assertNotContains(deletionBody, "UserDefaults.standard.remove", "account deletion shell must not delete local data")

assertContains(profile, "showDoctorContactSafetyNotice()", "doctor contact should use safety notice")
assertContains(profile, "private func showDoctorContactSafetyNotice()", "doctor contact safety notice should have a dedicated function")
let doctorBody = functionBody(named: "showDoctorContactSafetyNotice()", in: profile)
let doctorContractSource = doctorBody + careModels
assertContains(doctorBody, "关怀联系暂未接入", "doctor safety notice should have explicit title")
assertContains(doctorContractSource, "ProfileCareEscalationDraft", "doctor safety notice should use structured escalation draft")
assertContains(doctorContractSource, "非紧急", "doctor safety notice should say non-emergency")
assertContains(doctorContractSource, "不是医疗诊断", "doctor safety notice should include medical boundary")
assertContains(doctorContractSource, "急救服务", "doctor safety notice should point to emergency services")
assertContains(doctorContractSource, "真实联系契约未接入", "doctor safety notice should say real contact contract is not connected")
assertNotContains(doctorBody, "tel://", "doctor safety notice should not launch a phone call")

assertContains(releaseMatrix, "账号注销", "release matrix should document account deletion boundary")
assertContains(releaseMatrix, "医生联系", "release matrix should document doctor contact boundary")
assertContains(releaseMatrix, "profile-safety-flow-check.swift", "release matrix should include profile safety guard")

print("Profile safety flow checks passed")
