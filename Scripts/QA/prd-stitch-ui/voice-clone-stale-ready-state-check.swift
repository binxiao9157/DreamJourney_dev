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

let voiceService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let voiceShell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let appDelegate = read("DreamJourney/Sources/AppDelegate.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "let realCloneProviderReady: Bool",
    "let qualityAcceptanceRequired: Bool",
    "var isReadyForUse: Bool",
    "sampleStatus == .ready && isEnabled && realCloneProviderReady && !qualityAcceptanceRequired",
    "guard snapshot.isReadyForUse",
    "saveBackendState(snapshot)",
    "storedBool(forKey: realCloneProviderReadyKey)",
    "storedBool(forKey: qualityAcceptanceRequiredKey)",
    "let preferred = activeProfiles.first(where: {",
    "$0.voiceProfileId == preferredProfileId",
] {
    assertContains(voiceService, required, "voice clone service should prevent stale ready state \(required)")
}

assertNotContains(
    voiceService,
    "existingStatus == .ready",
    "new pending/failed backend state must be allowed to replace a stale ready cache"
)
assertNotContains(
    voiceService,
    "snapshot.sampleStatus == .ready,",
    "currentUsableSpeakerId must use snapshot.isReadyForUse instead of sampleStatus alone"
)

for required in [
    "音色状态待同步",
    "后端还未确认这次训练可用于合成，请刷新训练状态。",
    "训练完成，待试听确认",
    "火山已返回可合成状态，但这不等于音色效果已验收；请试听确认后再作为正式复刻音色使用。",
    "待试听确认",
    "可合成，待确认效果",
    "待同步确认",
    "音色状态待同步，暂不用于回响",
] {
    assertContains(voiceShell, required, "voice clone UI should avoid overclaiming failed or unverified training \(required)")
}

for required in [
    "pendingPreferredRespected",
    "pendingClearsUsableReady",
    "usableAfterPending == nil",
] {
    assertContains(appDelegate, required, "voice clone UIQA smoke should verify pending clears stale ready \(required)")
}

assertContains(
    releaseRegression,
    "voice-clone-stale-ready-state-check.swift",
    "release regression should include voice clone stale ready guard"
)
assertContains(
    releaseQA,
    "voice-clone-stale-ready-state-check.swift",
    "release QA package should include voice clone stale ready guard"
)

print("Voice clone stale ready state checks passed")
