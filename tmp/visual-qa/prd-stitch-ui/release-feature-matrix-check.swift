import Foundation

let root = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

func read(_ relativePath: String) -> String {
    let path = "\(root)/\(relativePath)"
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        fatalError("Unable to read \(path)")
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

func extractDefaultEnabledFeatures(from flags: String) -> Set<String> {
    let marker = "private static let defaultEnabled: Set<DJFeature> = ["
    guard let start = flags.range(of: marker)?.upperBound,
          let end = flags[start...].range(of: "]")?.lowerBound else {
        fatalError("Unable to find FeatureFlagService.defaultEnabled")
    }

    let body = flags[start..<end]
    let pattern = "\\.([A-Za-z0-9_]+)"
    let regex = try! NSRegularExpression(pattern: pattern)
    let nsRange = NSRange(body.startIndex..<body.endIndex, in: body)
    return Set(regex.matches(in: String(body), range: nsRange).compactMap { match in
        guard let range = Range(match.range(at: 1), in: body) else { return nil }
        return String(body[range])
    })
}

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let archive = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift")
let readiness = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveMediaReleaseReadiness.swift")
let archiveOptions = read("DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let settings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let legal = read("DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift")
let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

let expectedDefaults: Set<String> = [
    "careDashboard",
    "profileSettings",
    "legalCenter",
]

let hiddenByDefault: Set<String> = [
    "echoTextInput",
    "echoImageInput",
    "timeLetters",
    "personaSettings",
    "archiveAudioUpload",
    "archiveRemoteFetch",
    "archiveLocalAnalysis",
    "familyManagement",
    "familySpace",
    "accountDeletion",
    "careDoctorContact",
]

let defaults = extractDefaultEnabledFeatures(from: flags)
guard defaults == expectedDefaults else {
    fatalError("Default release feature flags changed. Expected \(expectedDefaults.sorted()), got \(defaults.sorted())")
}

for feature in expectedDefaults.union(hiddenByDefault) {
    assertContains(flags, "case \(feature)", "feature enum must declare \(feature)")
}

for feature in hiddenByDefault {
    guard !defaults.contains(feature) else {
        fatalError("\(feature) must stay hidden by default")
    }
}

assertContains(archiveOptions, "var options: [MemoryArchiveCreationOption] = [\n            .text,\n            .photo,\n        ]", "archive creation must default to text/photo only")
assertContains(readiness, "DJEnableArchiveHiddenBranches", "archive hidden branches need explicit QA launch argument")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.hiddenBranchesLaunchArgument", "archive screen must use shared hidden branch launch argument")
assertContains(archive, "MemoryArchiveMediaReleaseReadiness.isCreationVisible", "archive hidden creation branches must use media readiness contract")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveAudioUpload)", "archive audio branch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveRemoteFetch)", "archive remote fetch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.timeLetters)", "time-letter branch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.personaSettings)", "persona branch must be release gated")
assertContains(archive, "var inputs = [\"文字\", \"图片\"]", "archive CTA subtitle must start from public inputs")

assertContains(echo, "accessibilityLabel = \"开始语音\"", "echo must expose voice-first public control")
assertNotContains(echo, "FeatureFlagService.shared.isEnabled(.echoTextInput)", "echo text input should not be publicly wired yet")
assertNotContains(echo, "FeatureFlagService.shared.isEnabled(.echoImageInput)", "echo image input should not be publicly wired yet")

assertContains(profile, "DJEnableProfileHiddenBranches", "profile hidden branches need explicit QA launch argument")
assertContains(profile, "featureFlags.isEnabled(.profileSettings)", "profile settings row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.legalCenter)", "legal center row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.familyManagement)", "family management row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.accountDeletion)", "account deletion row must be feature gated")
assertContains(profile, "isCareDoctorContactVisible", "doctor contact must use an explicit visibility gate")
assertContains(profile, "rows.append(.logout)", "logout should remain a stable public action")

assertContains(settings, "ProfileSettingsViewController", "profile settings page must exist")
assertContains(settings, "保存", "profile settings page must provide save action")
assertNotContains(settings, "密码", "password change must stay hidden")

assertContains(legal, "ProfileLegalViewController", "legal center page must exist")
assertContains(legal, "AI 辅助说明", "legal center must cover AI assistance")
assertContains(legal, "紧急情况", "legal center must cover emergency guidance")

for label in ["记忆档案", "回响", "我的", "添加文字描述", "选择照片", "个人资料设置", "法律法规", "退出登录"] {
    assertContains(matrix, label, "release matrix must document public label \(label)")
}

for label in ["录入语音", "录入时间信件", "家人管理", "注销账户", "立即通话"] {
    assertContains(matrix, label, "release matrix must document hidden label \(label)")
}
