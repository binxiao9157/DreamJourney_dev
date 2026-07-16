import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let fileURL = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
        fatalError("Unable to read \(fileURL.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Operations evidence event guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let mapper = read("DreamJourney/Sources/Services/OperationsEvidenceEvent.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let releaseRegression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")
let releaseQA = read("Scripts/QA/prd-stitch-ui/release-qa-package-check.swift")

for required in [
    "struct OperationsEvidenceEventEnvelope: Codable",
    "enum OperationsEvidenceEventMapper",
    "static func echoRuntime(",
    "schemaVersion: Int",
    "principalHash: String?",
    "resourceIdHash: String?",
    "redactionVersion: Int",
    "private static func digest(",
    "private static func safeCode(",
    "redactedRuntimeReason",
] {
    require(mapper.contains(required), "missing typed mapper contract: \(required)")
}

for forbiddenStoredField in [
    "let userId:",
    "let rawText:",
    "let prompt:",
    "let token:",
    "let phone:",
    "let mediaInput:",
    "let audioData:",
    "let archiveItemIDs:",
] {
    require(!mapper.contains(forbiddenStoredField), "event envelope must not persist \(forbiddenStoredField)")
}

require(
    mapper.contains("digest(snapshot.userId, namespace: \"principal\")"),
    "Echo owner must be hashed before entering the event envelope"
)
require(
    mapper.contains("digest(snapshot.turnID, namespace: \"echoTurn\")"),
    "Echo turn must be hashed before entering the event envelope"
)
require(
    project.contains("OperationsEvidenceEvent.swift in Sources"),
    "typed mapper must be compiled into the iOS target"
)
require(
    releaseRegression.contains("operations-evidence-event-check.swift"),
    "release regression must run the event mapper guard"
)
require(
    releaseQA.contains("operations-evidence-event-check.swift"),
    "release QA package must include the event mapper guard"
)

print("Operations evidence event guard passed")
