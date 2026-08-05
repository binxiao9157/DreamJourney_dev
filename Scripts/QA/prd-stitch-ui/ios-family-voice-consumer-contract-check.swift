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
        fatalError("\(message): found \(needle)")
    }
}

let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let familyModel = read("DreamJourney/Sources/Services/MemoryModel.swift")
let familyRepository = read("DreamJourney/Sources/Services/FamilyRepository.swift")
let voiceService = read("DreamJourney/Sources/Memoir/VoiceCloneService.swift")
let voiceShell = read("DreamJourney/Sources/Modules/Profile/ProfileVoiceCloneShellViewController.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")

for required in [
    "static func fromBackendJSON(_ object: [String: Any]) -> FamilyMember?",
    "digitalHumanModeLabel",
    "familyPersonaContractVersion",
    "backendContractMode",
    "defaultReleaseVisible",
] {
    assertContains(familyModel, required, "FamilyMember should expose reusable backend parser \(required)")
}

for required in [
    "func fetchFamilyMembers(",
    "completion: @escaping (Result<[FamilyMember], Error>) -> Void",
    "FamilyMember.fromBackendJSON",
    "ClientError.invalidJSONResponse",
] {
    assertContains(backendClient, required, "DreamJourneyBackendClient should expose typed family consumer \(required)")
}

assertContains(
    familyRepository,
    "DreamJourneyBackendClient.shared.fetchFamilyMembers",
    "FamilyRepository should consume typed family backend client instead of reparsing raw JSON"
)
assertNotContains(
    familyRepository,
    "Self.familyMembers(from: object)",
    "FamilyRepository should not keep a second family backend parser"
)

for required in [
    "let providerMode: String",
    "let contractVersion: Int",
    "let lifecycleState: VoiceProfileLifecycleState?",
    "let eligibilityAllowed: Bool",
    "let consentPurpose: String?",
    "let allowedOperations: Set<String>",
    "let defaultReleaseVisible: Bool",
    "init(backendContract: VoiceCloneProfileContract)",
    "voiceCloneShellSnapshot(from backendContract: VoiceCloneProfileContract)",
] {
    assertContains(voiceService, required, "VoiceCloneService should consume backend voice contract \(required)")
}

for required in [
    "profileVoiceCloneStatusTitle",
    "profileVoiceCloneStatusCaption",
    "profileVoiceCloneEntryStatusValue",
    "profileVoiceCloneAuthorizationHint",
    "可用于回响",
    "本人资格待验证",
    "音色状态待安全校验",
] {
    assertContains(voiceShell, required, "Voice clone shell should render user-facing backend-derived status \(required)")
}
assertNotContains(
    voiceShell,
    "profileVoiceCloneProviderModeValue",
    "Voice clone shell should not render backend provider as user-facing UI"
)
assertNotContains(
    voiceShell,
    "profileVoiceCloneContractVersionValue",
    "Voice clone shell should not render backend contract version as user-facing UI"
)

assertContains(
    releaseRegression,
    "ios-family-voice-consumer-contract-check.swift",
    "release regression should run iOS family/voice consumer guard"
)
assertContains(
    releaseQA,
    "ios-family-voice-consumer-contract-check.swift",
    "release QA package should include iOS family/voice consumer guard"
)
assertContains(
    releaseMatrix,
    "| `familySpace` | hidden |",
    "release matrix should document the iOS family consumer boundary"
)
assertContains(releaseMatrix, "| `voiceCloneShell` | hidden |", "release matrix should document the iOS voice consumer boundary")

print("iOS family/voice consumer contract guard passed")
