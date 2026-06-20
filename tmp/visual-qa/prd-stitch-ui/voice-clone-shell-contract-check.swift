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
let memoirFlow = read("DreamJourney/Sources/Memoir/MemoirFlowManager.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")

assertContains(flags, "case voiceCloneShell", "voice clone shell should be feature flagged")
assertContains(flags, ".voiceCloneShell,", "voice clone should be default enabled after public product decision")
assertContains(flags, "currentStorageVersion = 5", "feature flag schema should migrate existing installs to public voice clone default")

for required in [
    "voiceCloneCapability",
    "title: \"音色复刻\"",
    "feature: .voiceCloneShell",
    "voiceProfileId",
    "publicReady",
    "isVoiceCloneVisible(",
] {
    assertContains(readiness, required, "profile readiness should define public voice clone capability \(required)")
}
assertNotContains(readiness, "声音克隆暂未开放", "public voice clone copy should not say unavailable")
assertNotContains(readiness, "默认发布态不展示声音克隆", "public voice clone capability should not remain hidden")

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
    "authorizationConfirmed: Bool",
    "authorizationRequired",
    "\"authorizationConfirmed\": authorizationConfirmed",
    "disableVoiceProfileRemote(",
    "deleteVoiceProfileRemote(",
    "DreamJourneyBackendClient.shared.disableVoiceCloneProfile",
    "DreamJourneyBackendClient.shared.deleteVoiceCloneProfile",
] {
    assertContains(voiceService, required, "voice clone service should expose public backend-backed contract \(required)")
}
assertNotContains(voiceService, "\"authorizationConfirmed\": true", "voice clone service must not forge authorization")
assertContains(voiceService, "case .disabled:\n            return .notFound", "disabled voice profile must not be treated as ready")
assertNotContains(memoirFlow, "trainVoice(audioURL: recordingURL)", "memoir flow must not auto-train voice clone from ordinary recording")

for required in [
    "final class ProfileVoiceCloneShellViewController",
    "音色复刻",
    "UIDocumentPickerDelegate",
    "profileVoiceCloneStatusTitle",
    "profileVoiceCloneStatusCaption",
    "还没有创建音色",
    "授权与样本",
    "authorizationSwitch",
    "我确认本人授权",
    "profileVoiceCloneAuthorizationHint",
    "样本状态",
    "可用状态",
    "训练与管理",
    "选择音频样本并提交",
    "刷新训练状态",
    "禁用音色",
    "删除音色",
    "VoiceCloneService.shared.trainVoice",
    "authorizationConfirmed: authorizationSwitch.isOn",
    "onProfileAccepted",
    "VoiceCloneService.shared.disableVoiceProfileRemote",
    "VoiceCloneService.shared.deleteVoiceProfileRemote",
    "profile-voice-clone-shell",
] {
    assertContains(shell, required, "voice clone shell should render public basic feature surface \(required)")
}
assertNotContains(shell, "未开放", "public voice clone shell should not render unavailable disabled actions")
assertNotContains(shell, "默认隐藏", "public voice clone shell should not claim default hidden")
assertNotContains(shell, "profileVoiceCloneProfileIdValue", "voice profile id should not be a visible user-facing field")
assertNotContains(shell, "profileVoiceCloneProviderModeValue", "provider mode should not be a visible user-facing field")
assertNotContains(shell, "profileVoiceCloneContractVersionValue", "contract version should not be a visible user-facing field")
assertNotContains(shell, "providerMode", "provider mode should stay out of user-facing voice clone UI")
assertNotContains(shell, "合同版本", "contract version should stay out of user-facing voice clone UI")
assertNotContains(shell, "删除/禁用合同", "contract language should stay out of user-facing voice clone UI")

assertContains(project, "ProfileVoiceCloneShellViewController.swift in Sources", "voice clone shell should be in Xcode target")
assertContains(
    releaseRegression,
    "voice-clone-shell-contract-check.swift",
    "release regression should run voice clone shell guard"
)
assertContains(
    releaseRegression,
    "voice-clone-backend-contract-check.swift",
    "release regression should run voice clone backend guard"
)
assertContains(
    releaseQA,
    "voice-clone-shell-contract-check.swift",
    "release QA package should include voice clone shell guard"
)
assertContains(
    releaseQA,
    "voice-clone-backend-contract-check.swift",
    "release QA package should include voice clone backend guard"
)

print("Voice clone shell contract guard passed")
