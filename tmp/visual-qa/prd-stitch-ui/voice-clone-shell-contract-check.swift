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

let flags = read("DreamJourney/Sources/App/FeatureFlagService.swift")
let readiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let profile = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let voiceService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let shell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertContains(flags, "case voiceCloneShell", "voice clone shell should be feature flagged")
assertNotContains(flags, ".voiceCloneShell,", "voice clone shell must not be default enabled")

for required in [
    "voiceCloneCapability",
    "title: \"声音克隆\"",
    "feature: .voiceCloneShell",
    "voiceProfileId",
    "默认发布态不展示声音克隆",
    "isVoiceCloneVisible(",
] {
    assertContains(readiness, required, "profile readiness should define hidden voice clone capability \(required)")
}

for required in [
    "isVoiceCloneShellVisible",
    "rows.append(.voiceClone)",
    "case .voiceClone:",
    "showVoiceCloneShell()",
    "ProfileVoiceCloneShellViewController",
] {
    assertContains(profile, required, "profile settings should gate hidden voice clone shell \(required)")
}

for required in [
    "struct VoiceCloneProfileSnapshot",
    "enum VoiceCloneSampleStatus",
    "let voiceProfileId: String",
    "authorizationCopy",
    "voiceCloneShellSnapshot()",
    "disableVoiceProfile(profileId:",
    "deleteVoiceProfile(profileId:",
] {
    assertContains(voiceService, required, "voice clone service should expose product shell contract \(required)")
}

for required in [
    "final class ProfileVoiceCloneShellViewController",
    "声音克隆",
    "授权说明",
    "声音样本状态",
    "voiceProfileId",
    "删除/禁用合同",
    "禁用声音样本（未开放）",
    "删除声音样本（未开放）",
    "profile-voice-clone-shell",
] {
    assertContains(shell, required, "voice clone shell should render hidden product surface \(required)")
}

assertContains(project, "ProfileVoiceCloneShellViewController.swift in Sources", "voice clone shell should be in Xcode target")
assertContains(
    releaseRegression,
    "voice-clone-shell-contract-check.swift",
    "release regression should run voice clone shell guard"
)
assertContains(
    releaseQA,
    "voice-clone-shell-contract-check.swift",
    "release QA package should include voice clone shell guard"
)

print("Voice clone shell contract guard passed")
