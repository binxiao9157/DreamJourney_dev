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

let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let familyController = read("DreamJourney/Sources/Modules/Family/FamilyCircleViewController.swift")
let profileController = read("DreamJourney/Sources/Modules/Profile/ProfileViewController.swift")
let voiceShell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let readiness = read("DreamJourney/Sources/Modules/Profile/ProfileFamilyPersonaReleaseReadiness.swift")
let releaseScript = read("Scripts/QA/prd-stitch-ui/run-profile-family-persona-release-smoke.sh")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let statusDoc = read("docs/superpowers/status/2026-06-19-ios-family-voice-hidden-uiqa.md")

for required in [
    "makeProfileFamilyVoiceBackendDerivedFamilyMember",
    "FamilyMember.fromBackendJSON",
    "\"backendFamilyDigitalHumanMode\"",
    "\"backendFamilyPersonaContractVersion\"",
    "\"backendFamilyContractMode\"",
    "\"backendFamilyDefaultReleaseVisible\"",
    "\"backendFamilyRenderedInRepository\"",
] {
    assertContains(appDelegate, required, "profile family/persona UIQA smoke should assert backend-derived family contract \(required)")
}

for required in [
    "makeProfileFamilyVoiceBackendVoiceProfile",
    "VoiceCloneProfileContract(json:",
    "VoiceCloneService.shared.voiceCloneShellSnapshot(from:",
    "ProfileVoiceCloneShellViewController(snapshot:",
    "\"backendVoiceProfileId\"",
    "\"backendVoiceSampleStatus\"",
    "\"backendVoiceProviderMode\"",
    "\"backendVoiceShellRendered\"",
] {
    assertContains(appDelegate, required, "profile family/persona UIQA smoke should assert backend-derived voice contract \(required)")
}

for required in [
    "FamilyRepository.shared.refreshFromBackend",
    "membersTableView.reloadData()",
] {
    assertContains(familyController, required, "hidden family screen should refresh from typed backend client when available \(required)")
}

for required in [
    "loadBackendVoiceCloneSnapshot",
    "DreamJourneyBackendClient.shared.fetchVoiceCloneProfiles",
    "VoiceCloneService.shared.voiceCloneShellSnapshot(from:",
] {
    assertContains(profileController, required, "profile voice clone route should consume backend voice contract when available \(required)")
}

for required in [
    "profileVoiceCloneStatusTitle",
    "profileVoiceCloneStatusCaption",
    "profileVoiceCloneSampleStatusValue",
    "profileVoiceCloneEntryStatusValue",
    "profileVoiceCloneAuthorizationHint",
    "profileVoiceCloneSubmitButton",
    "profileVoiceCloneRefreshButton",
] {
    assertContains(voiceShell, required, "voice clone shell should expose backend-derived fields and public actions for UIQA \(required)")
}
assertNotContains(
    voiceShell,
    "profileVoiceCloneProviderModeValue",
    "voice clone UIQA should not depend on visible backend provider mode"
)

assertContains(readiness, "hiddenBranchesLaunchArgument", "hidden profile branch gate must remain explicit")
assertContains(releaseScript, "\"backendFamilyDigitalHumanMode\"", "family/persona smoke runner should grep backend family mode")
assertContains(releaseScript, "\"backendVoiceProfileId\"", "family/persona smoke runner should grep backend voice profile id")
assertContains(releaseRegression, "ios-family-voice-hidden-uiqa-smoke-check.swift", "release regression should run hidden family/voice UIQA guard")
assertContains(releaseQA, "ios-family-voice-hidden-uiqa-smoke-check.swift", "release QA package should include hidden family/voice UIQA guard")
assertContains(releaseMatrix, "| `familyManagement` | hidden |", "release matrix should document hidden family UI")
assertContains(releaseMatrix, "| `voiceCloneShell` | hidden |", "release matrix should document hidden voice UI")
assertContains(statusDoc, "Hidden Family / Voice UIQA", "status doc should describe hidden family/voice UIQA")

assertNotContains(profileController, ".voiceCloneShell,", "voice clone shell must not be added to default feature flags from profile code")

print("iOS family/voice hidden UIQA smoke guard passed")
