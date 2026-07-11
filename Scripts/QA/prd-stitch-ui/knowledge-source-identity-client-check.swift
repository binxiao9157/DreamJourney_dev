import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) throws -> String {
    try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("knowledge-source-identity-client-check failed: \(message)\n", stderr)
        exit(1)
    }
}

let models = try read("DreamJourney/Sources/Services/KBLiteModels.swift")
let manager = try read("DreamJourney/Sources/Services/KBLiteManager.swift")
let client = try read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let recording = try read("DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift")

for contract in [
    "enum KBKnowledgeSourceIdentityPolicy",
    "conversationTurnReferences(",
    "conversationPhotoReference(",
    "enum KBKnowledgeSourceAuditRecommendedAction",
] {
    require(models.contains(contract), "missing source identity contract \(contract)")
}
require(!manager.contains("kind: \"conversationSession\""),
        "KBLite must not generate new conversationSession refs")
require(!manager.contains("kind: \"archiveImageAnalysis\""),
        "KBLite must not generate new archiveImageAnalysis refs")
require(manager.contains("sourceTurnIndices: turnIndices"),
        "quick extraction must bind refs to entity turn indices")
require(manager.contains("sourceAssetId:"), "photo ingestion must accept a stable asset ID")
require(manager.contains("func sourceRefAuditCounts()"),
        "KBLite must expose an aggregate-only QA audit")
require(client.contains("sourceContractVersion"),
        "backend extraction request must declare the canonical source contract")
require(!client.contains("\"kind\": \"conversationSession\""),
        "backend extraction request must not send a legacy source ref")
require(client.contains("func fetchKnowledgeSourceRefAudit("),
        "backend client must expose typed source audit")
require(client.contains("KBKnowledgeSourceRefAuditResponse"),
        "source audit response must be typed")
require(recording.contains("UUID().uuidString.lowercased()"),
        "conversation photos must use collision-resistant IDs")
require(recording.contains("sourceAssetId:"),
        "conversation photo analysis must pass the stable asset ID")

print("Knowledge source identity client check passed")
