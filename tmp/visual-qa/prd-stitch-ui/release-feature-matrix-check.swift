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
let profileReadiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let settings = read("DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift")
let legal = read("DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift")
let matrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

let expectedDefaults: Set<String> = [
    "careDashboard",
    "personaSettings",
    "profileSettings",
    "legalCenter",
]

let hiddenByDefault: Set<String> = [
    "echoTextInput",
    "echoImageInput",
    "timeLetters",
    "archiveAudioUpload",
    "archiveVideoUpload",
    "archiveRemoteFetch",
    "archiveLocalAnalysis",
    "familyManagement",
    "familySpace",
    "accountDeletion",
    "accountPasswordChange",
    "careDoctorContact",
    "voiceCloneShell",
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
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveVideoUpload)", "archive video branch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.archiveRemoteFetch)", "archive remote fetch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.timeLetters)", "time-letter branch must be release gated")
assertContains(archive, "FeatureFlagService.shared.isEnabled(.personaSettings)", "persona branch must be release gated")
assertContains(archive, "var inputs = [\"文字\", \"图片\"]", "archive CTA subtitle must start from public inputs")
assertContains(archive, "action: #selector(photoCardTapped)", "archive photo feature card should not duplicate photo creation")
assertContains(archive, "applyArchiveKindFilter(.audio)", "archive voice feature card should open the voice archive category")
assertContains(archive, "navigationController?.pushViewController(KnowledgeBaseViewController(), animated: true)", "archive persona card should open persona settings")

assertContains(echo, "accessibilityLabel = \"开始语音\"", "echo must expose voice-first public control")
assertNotContains(echo, "FeatureFlagService.shared.isEnabled(.echoTextInput)", "echo text input should not be publicly wired yet")
assertNotContains(echo, "FeatureFlagService.shared.isEnabled(.echoImageInput)", "echo image input should not be publicly wired yet")

assertContains(profileReadiness, "DJEnableProfileHiddenBranches", "profile hidden branches need explicit QA launch argument")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument", "profile must consume the hidden branch launch argument from readiness contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.isFamilyManagementRowVisible", "family management row must use release readiness visibility contract")
assertContains(profile, "ProfileFamilyPersonaReleaseReadiness.canOpenFamilyPersonaSwitcher", "family management route must use release readiness route contract")
assertContains(profile, "featureFlags.isEnabled(.profileSettings)", "profile settings row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.legalCenter)", "legal center row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.familyManagement)", "family management row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.voiceCloneShell)", "voice clone shell row must be feature gated")
assertContains(profile, "featureFlags.isEnabled(.accountDeletion)", "account deletion row must be feature gated")
assertContains(profile, "isCareDoctorContactVisible", "doctor contact must use an explicit visibility gate")
assertContains(profile, "rows.append(.logout)", "logout should remain a stable public action")
assertContains(profileReadiness, "voiceCloneCapability", "voice clone shell should have a hidden readiness capability")
assertContains(profileReadiness, "isVoiceCloneVisible", "voice clone shell should use release readiness visibility contract")

assertContains(settings, "ProfileSettingsViewController", "profile settings page must exist")
assertContains(settings, "保存", "profile settings page must provide save action")
assertContains(profileReadiness, "isPasswordChangeVisible", "password change must use release readiness visibility contract")
assertContains(settings, "isPasswordChangeVisible", "password change must use an explicit visibility gate")
assertContains(settings, "featureFlags.isEnabled(.accountPasswordChange)", "password change must be feature gated")
assertContains(settings, "ProfileFamilyPersonaReleaseReadiness.hiddenBranchesLaunchArgument", "password change hidden branch should use shared launch argument")

assertContains(legal, "ProfileLegalViewController", "legal center page must exist")
assertContains(legal, "AI 辅助说明", "legal center must cover AI assistance")
assertContains(legal, "紧急情况", "legal center must cover emergency guidance")

for label in ["记忆档案", "回响", "我的", "添加文字描述", "选择照片", "个人资料设置", "法律法规", "退出登录"] {
    assertContains(matrix, label, "release matrix must document public label \(label)")
}
for label in ["语音档案", "人格设定"] {
    assertContains(matrix, label, "release matrix must document PRD archive feature-card label \(label)")
}

for label in ["录入语音", "录入时间信件", "家人管理", "注销账户", "修改密码", "立即通话"] {
    assertContains(matrix, label, "release matrix must document hidden label \(label)")
}
assertContains(matrix, "录入视频片段", "release matrix must document hidden video label")

assertContains(matrix, "## Hidden Candidate Release Decisions", "release matrix should include hidden candidate decision table")
assertContains(matrix, "| Feature | Current gate | Public in MVP | Needed before public | Test evidence |", "release matrix should include hidden candidate decision columns")
assertContains(matrix, "No hidden PRD feature is public by default", "release matrix should preserve hidden-by-default policy")

let hiddenDecisionRows = [
    "| archive audio upload | `DJFeature.archiveAudioUpload` or `DJEnableArchiveHiddenBranches` | no | true-device recording acceptance, storage/privacy copy, backend media policy | `archive-media-entries-smoke-check.swift`, release regression |",
    "| time letters | `DJFeature.timeLetters` or `DJEnableArchiveHiddenBranches` | no | delivery/scheduling policy, reminder semantics, true-device notification decision | `archive-media-entries-smoke-check.swift`, release regression |",
    "| video upload | `DJFeature.archiveVideoUpload` or `DJEnableArchiveHiddenBranches` mock-file shell only | no | PRD scope, picker/compression/storage/backend policy, true-device video picker acceptance | `archive-media-entries-smoke-check.swift`, `archive-media-release-readiness-check.swift`, `archive-hidden-media-timeletter-shell-check.swift`, release regression |",
    "| family management public release | `DJFeature.familyManagement` or `DJEnableProfileHiddenBranches` | no | invitation/permission model, backend membership contract, privacy copy | `profile-family-persona-switcher-check.swift` |",
    "| care dashboard expansion | aggregate `DJFeature.careDashboard` and non-executing `关怀升级准备中` placeholder are public; intervention/contact execution stays behind `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | aggregate + placeholder only | family-facing copy, alert thresholds, backend persistence, true-device acceptance | `elder-care-dashboard-check.swift`, `profile-care-public-placeholder-check.swift`, backend acceptance |",
    "| account deletion execution | `DJFeature.accountDeletion` or `DJEnableProfileHiddenBranches` safety shell only | no | compliance policy, cooling-off period, backend deletion/export contract | `profile-safety-flow-check.swift` |",
    "| account password change | `DJFeature.accountPasswordChange` or `DJEnableProfileHiddenBranches` | no | backend `/auth/password` implementation, auth/security review, true-device acceptance | `profile-password-change-check.swift`, release regression |",
    "| doctor contact / intervention execution | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` | no | real escalation provider, emergency disclaimers, backend submission contract | `profile-care-escalation-contract-check.swift`, `profile-care-escalation-backend-boundary-check.swift` |",
    "| care escalation draft | `DJFeature.careDoctorContact` or `DJEnableProfileHiddenBranches` local draft shell only | no | product decision to promote draft, backend submit contract, clinical/legal review | `profile-care-escalation-contract-check.swift`, `run-profile-care-escalation-boundary-smoke.sh` |",
    "| sunlight/star/silent lifecycle transition controls | hidden family rows / local QA context only | no | product/legal policy for lifecycle transitions, consent copy, recovery rules | `digital-human-mode-management-check.swift`, `digital-human-mode-lifecycle-check.swift` |",
    "| digital inheritance lifecycle | hidden lifecycle boundary only | no | inheritance trigger policy, family/legal consent, backend audit contract | `digital-human-mode-lifecycle-check.swift`, PRD coverage matrix |",
]

for row in hiddenDecisionRows {
    assertContains(matrix, row, "release matrix should include hidden candidate decision row")
}
