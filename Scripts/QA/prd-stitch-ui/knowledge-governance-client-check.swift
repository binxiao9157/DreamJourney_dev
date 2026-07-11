import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("knowledge-governance-client-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let models = try read("DreamJourney/Sources/Services/KBLiteModels.swift")
let client = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")

for declaration in [
    "enum KBKnowledgeEntityType: String, Codable, CaseIterable",
    "struct KBKnowledgeEntityLink: Codable, Equatable",
    "struct KBKnowledgeSourceIdentity: Codable, Equatable",
    "struct KBKnowledgeGovernanceMetadata: Codable, Equatable",
    "enum KBKnowledgeGovernanceAction: Codable, Equatable",
    "struct KBKnowledgeGovernanceSummary: Codable, Equatable",
    "struct KBKnowledgeGovernanceResponse",
] {
    require(models.contains(declaration), "missing model declaration \(declaration)")
}

for correction in [
    "KBPersonGovernanceCorrection",
    "KBPlaceGovernanceCorrection",
    "KBEventGovernanceCorrection",
    "KBFactGovernanceCorrection",
] {
    require(models.contains(correction), "missing typed correction \(correction)")
}

require(models.components(separatedBy: "var governanceMetadata: KBKnowledgeGovernanceMetadata? = nil").count == 5,
        "all four KBLite entities must expose optional governanceMetadata")
require(models.contains("func backendJSONObject() throws -> [String: Any]"),
        "governance action must provide a backend JSON object")
require(models.contains("target.entityType == correction.entityType"),
        "correct action must enforce entityType/correction matching")
require(models.contains("governanceSchemaVersion == 1"),
        "response consumer must pin governance schema v1")
require(models.contains("mutationSchemaVersion == 2"),
        "response consumer must pin mutation schema v2")
for field in ["userId", "operationId", "revision", "duplicate", "summary", "graph"] {
    require(models.contains("json[\"\(field)\"]"), "response consumer must parse \(field)")
}

require(client.contains("func governKnowledge("), "backend client governance method is missing")
require(client.contains("action: KBKnowledgeGovernanceAction"), "governance method must accept a typed action")
require(client.contains("Result<KBKnowledgeGovernanceResponse, Error>"),
        "governance method must return a typed response")
require(client.contains("path: \"/kb/governance/actions\""),
        "governance method must call /kb/governance/actions")
for field in ["governanceSchemaVersion", "userId", "operationId", "baseRevision", "action"] {
    require(client.contains("\"\(field)\":"), "governance request must include \(field)")
}
require(client.contains("action.backendJSONObject()"), "governance request must use safe action encoding")
require(client.contains("response.userId == userId, response.operationId == operationId"),
        "governance response identity must match the request")

require(client.contains("operationId: String? = nil"),
        "archive deletion must accept a stable operationId")
require(client.contains(#"?operationId=\(queryComponent(operationId))"#),
        "archive deletion must URL encode operationId")
require(client.contains("private func queryComponent(_ value: String) -> String"),
        "query encoding helper is missing")

print("Knowledge governance client check passed")
