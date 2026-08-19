import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func assertContains(_ haystack: String, _ needle: String, _ message: String) {
    guard haystack.contains(needle) else {
        fatalError("\(message): missing \(needle)")
    }
}

let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let service = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let shell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct VoiceCloneCreationQuotaContract: Equatable",
    "voice-profile-creation-quota-v1",
    "creationLimit == 5",
    "deletionRefundsCreation == false",
    "struct VoiceCloneProfileInventoryContract",
    "struct VoiceCloneProfileCreationResult",
    "func createVoiceCloneProfile(",
    "func fetchVoiceCloneProfileInventory(",
] {
    assertContains(client, required, "backend client must consume the PC-A4 quota contract")
}

for required in [
    "onCreationQuotaUpdated: ((VoiceCloneCreationQuotaContract) -> Void)? = nil",
    "payload[\"commandId\"] = \"voice-create-",
    "createVoiceCloneProfile(",
    "onCreationQuotaUpdated?(creationResult.creationQuota)",
] {
    assertContains(service, required, "voice clone creation must carry a stable command and quota result")
}

for required in [
    "private var creationQuota: VoiceCloneCreationQuotaContract?",
    "profileVoiceCloneAuthorizationScopeValue",
    "仅限本人声音与本人确认",
    "profileVoiceCloneCreationQuotaValue",
    "已创建 \\(creationQuota.creationCount)/\\(creationQuota.creationLimit)，剩余 \\(creationQuota.remainingCount) 次",
    "已达到累计 5 次创建上限；删除或撤销音色不会返还次数。",
    "submitButton?.isHidden = creationQuota?.limitReached == true && !snapshot.canRetryTraining",
    "fetchVoiceCloneProfileInventory",
] {
    assertContains(shell, required, "voice clone shell must fail closed on the server quota")
}

assertContains(
    releaseRegression,
    "voice-clone-creation-quota-check.swift",
    "release regression must run the PC-A4 quota guard"
)
assertContains(
    releaseQA,
    "voice-clone-creation-quota-check.swift",
    "release QA package must inventory the PC-A4 quota guard"
)

print("Voice clone creation quota checks passed")
