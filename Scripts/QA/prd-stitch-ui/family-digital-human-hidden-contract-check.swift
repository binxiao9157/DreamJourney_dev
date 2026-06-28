import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
let backendRoot = root.deletingLastPathComponent().appendingPathComponent("DreamJourneyBackend")

func read(_ relativePath: String, in baseURL: URL = root) -> String {
    let fileURL = baseURL.appendingPathComponent(relativePath)
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

let backendMain = read("app/main.py", in: backendRoot)
let backendTests = read("tests/test_core_services.py", in: backendRoot)
let backendPostgresTests = read("tests/test_postgres_store.py", in: backendRoot)
let familyModel = read("DreamJourney/Sources/Services/MemoryModel.swift")
let backendClient = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let familyRepository = read("DreamJourney/Sources/Services/FamilyRepository.swift")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")
let releaseMatrix = read("docs/superpowers/status/2026-06-17-release-feature-matrix.md")
let statusDoc = read("docs/superpowers/status/2026-06-19-family-digital-human-hidden-contract.md")

for required in [
    "FAMILY_PERSONA_CONTRACT_VERSION = 1",
    "FAMILY_PERSONA_CONTRACT_MODE = \"mockFamilyPersona\"",
    "DIGITAL_HUMAN_MODE_LABELS",
    "\"sunlight\": \"阳光\"",
    "\"star\": \"星辰\"",
    "\"silent\": \"静默\"",
    "_sanitize_family_member_payload",
    "digitalHumanModeLabel",
    "defaultReleaseVisible",
] {
    assertContains(backendMain, required, "backend should expose hidden family digital-human contract \(required)")
}

for required in [
    "test_family_member_api_defaults_hidden_digital_human_contract",
    "test_family_member_api_persists_digital_human_mode_contract",
    "test_family_member_api_rejects_invalid_digital_human_mode_contract",
] {
    assertContains(backendTests, required, "backend tests should cover family digital-human API \(required)")
}

assertContains(
    backendPostgresTests,
    "test_store_persists_family_member_digital_human_contract",
    "postgres tests should cover family digital-human payload persistence"
)

for required in [
    "var personaScope: String",
    "var digitalHumanId: String",
    "var digitalHumanModeLabel: String",
    "var familyPersonaContractVersion: Int",
    "var backendContractMode: String?",
    "var defaultReleaseVisible: Bool",
    "static func fromBackendJSON(_ object: [String: Any]) -> FamilyMember?",
    "digitalHumanMode(from: object)",
] {
    assertContains(familyModel, required, "iOS FamilyMember should model backend contract \(required)")
}

for required in [
    "func fetchFamilyMembers(",
    "completion: @escaping (Result<[FamilyMember], Error>) -> Void",
    "FamilyMember.fromBackendJSON",
] {
    assertContains(backendClient, required, "iOS backend client should parse typed family contract \(required)")
}

for required in [
    "DreamJourneyBackendClient.shared.fetchFamilyMembers",
    "mergeRemoteMembers(remoteMembers)",
] {
    assertContains(familyRepository, required, "iOS FamilyRepository should consume typed family contract \(required)")
}

assertContains(releaseRegression, "family-digital-human-hidden-contract-check.swift", "release regression should run family digital-human guard")
assertContains(releaseQA, "family-digital-human-hidden-contract-check.swift", "release QA package should include family digital-human guard")
assertContains(releaseMatrix, "family-digital-human-hidden-contract-check.swift", "release matrix should document family digital-human guard")
assertContains(statusDoc, "mockFamilyPersona", "status doc should record the hidden backend contract")
assertContains(statusDoc, "不开放公开入口", "status doc should preserve public release boundary")

print("Family digital-human hidden contract guard passed")
