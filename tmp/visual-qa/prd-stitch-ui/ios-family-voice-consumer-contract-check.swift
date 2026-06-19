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
let releaseRegression = read("tmp/visual-qa/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift")
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
    "let defaultReleaseVisible: Bool",
    "init(backendContract: VoiceCloneProfileContract)",
    "voiceCloneShellSnapshot(from backendContract: VoiceCloneProfileContract)",
] {
    assertContains(voiceService, required, "VoiceCloneService should consume backend voice contract \(required)")
}

for required in [
    "snapshot.providerMode",
    "snapshot.contractVersion",
    "snapshot.defaultReleaseVisible",
] {
    assertContains(voiceShell, required, "Voice clone shell should render backend-derived hidden contract field \(required)")
}

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
    "ios-family-voice-consumer-contract-check.swift",
    "release matrix should document iOS family/voice consumer guard"
)

print("iOS family/voice consumer contract guard passed")
