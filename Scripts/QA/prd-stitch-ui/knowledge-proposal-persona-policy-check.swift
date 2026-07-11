import Foundation

let root = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? FileManager.default.currentDirectoryPath
)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Knowledge proposal/persona guard failed: \(message)\n", stderr)
        exit(1)
    }
}

func functionBody(_ signature: String, in source: String) -> String {
    guard let signatureRange = source.range(of: signature),
          let openingBrace = source[signatureRange.lowerBound...].firstIndex(of: "{") else {
        fputs("Knowledge proposal/persona guard failed: missing \(signature)\n", stderr)
        exit(1)
    }
    var depth = 0
    var cursor = openingBrace
    while cursor < source.endIndex {
        if source[cursor] == "{" {
            depth += 1
        } else if source[cursor] == "}" {
            depth -= 1
            if depth == 0 {
                return String(source[openingBrace...cursor])
            }
        }
        cursor = source.index(after: cursor)
    }
    fputs("Knowledge proposal/persona guard failed: unterminated \(signature)\n", stderr)
    exit(1)
}

let models = read("DreamJourney/Sources/Services/KBLiteModels.swift")
let client = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let policy = read("DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift")
let manager = read("DreamJourney/Sources/Services/KBLiteManager.swift")
let memory = read("DreamJourney/Sources/Services/ConversationMemoryManager.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")

require(
    models.contains("struct KBKnowledgeMutationProposal: Codable") &&
        models.contains("let ownerUserId: String") &&
        models.contains("let personaScope: String") &&
        models.contains("let digitalHumanId: String") &&
        models.contains("case proposal = \"mutationProposal\"") &&
        models.contains("container.contains(.proposal)"),
    "proposal schema and legacy-aware envelope must remain explicit"
)

require(
    client.contains("func extractKnowledgeEnvelope(") &&
        client.contains("\"personaScope\": personaScope") &&
        client.contains("\"digitalHumanId\": digitalHumanId ?? userId") &&
        client.contains("KBKnowledgeExtractionEnvelope.self") &&
        client.contains("ClientError.invalidJSONResponse"),
    "backend client must send persona identity and reject malformed proposal envelopes"
)

require(
    policy.contains("struct KBPersonaIdentity: Equatable") &&
        policy.contains("enum KBPersonaIdentityResolver") &&
        policy.contains("enum KBPersonaPolicy") &&
        policy.contains("proposal.tombstones.isEmpty") &&
        policy.contains("allowsEvidenceStatus"),
    "one canonical persona/proposal policy must guard identity, schema and evidence"
)

let finishExtraction = functionBody("private func finishExtraction(", in: manager)
require(
    manager.contains("let capturedAuthorization = authorizationSnapshot") &&
        manager.contains("isCurrentAuthorizationSnapshotLocked(capturedAuthorization)") &&
        finishExtraction.contains("isCurrentAuthorizationSnapshotLocked(authorizationSnapshot)") &&
        !finishExtraction.contains("resolveCurrentPersonaIdentity") &&
        !finishExtraction.contains("FamilyRepository") &&
        manager.contains("extractKnowledgeEnvelope(") &&
        manager.contains("mergeProposal(proposal") &&
        manager.contains("acceptedBackendExtraction") &&
        manager.contains("buildExistingSummary(for: capturedIdentity)") &&
        manager.contains("KBPersonaPolicy.allowsEvidenceStatus("),
    "KBLite extraction must be identity-bound, proposal-first and evidence-filtered"
)

require(
    memory.contains("let knowledgeAuthorization = KBLiteManager.captureCurrentPersonaAuthorizationSnapshot()") &&
        memory.contains("authorizationSnapshot: knowledgeAuthorization") &&
        memory.range(of: "captureCurrentPersonaAuthorizationSnapshot()")!.lowerBound
            < memory.range(of: "DispatchQueue.global(qos: .utility).async")!.lowerBound,
    "conversation completion must snapshot persona authorization before async extraction"
)

require(
    echo.contains("KBLiteManager.resolveAuthorizedPersonaIdentity(for: context)") &&
        echo.contains("familyRelationshipUnauthorized") &&
        echo.contains("expectedIdentity: gate.expectedIdentity") &&
        echo.contains("family_local_fallback_forbidden"),
    "Echo must share an authorized canonical identity and keep family local fallback forbidden"
)

print("Knowledge proposal/persona policy guard passed")
