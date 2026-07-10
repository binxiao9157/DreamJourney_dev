import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)

func read(_ relativePath: String) -> String {
    let url = root.appendingPathComponent(relativePath)
    guard let content = try? String(contentsOf: url, encoding: .utf8) else {
        fatalError("Unable to read \(url.path)")
    }
    return content
}

func require(_ condition: Bool, _ message: String) {
    guard condition else {
        fputs("Knowledge evidence/context policy guard failed: \(message)\n", stderr)
        exit(1)
    }
}

func requireOrdered(_ content: String, _ first: String, _ second: String, _ message: String) {
    guard let firstRange = content.range(of: first),
          let secondRange = content.range(of: second),
          firstRange.lowerBound < secondRange.lowerBound else {
        fputs("Knowledge evidence/context policy guard failed: \(message)\n", stderr)
        exit(1)
    }
}

let models = read("DreamJourney/Sources/Services/KBLiteModels.swift")
let manager = read("DreamJourney/Sources/Services/KBLiteManager.swift")
let backend = read("DreamJourney/Sources/Services/DreamJourneyBackendClient.swift")
let generationPolicy = read("DreamJourney/Sources/Services/KnowledgeGenerationPolicy.swift")
let echoPolicy = read("DreamJourney/Sources/Services/EchoKnowledgeContextPolicy.swift")
let echo = read("DreamJourney/Sources/Modules/Echo/EchoViewController.swift")
let project = read("DreamJourney.xcodeproj/project.pbxproj")
let regression = read("Scripts/QA/prd-stitch-ui/run-release-regression.sh")

require(
    backend.contains("\"extractionSchemaVersion\": 2") &&
        backend.contains("\"sourcePolicy\": \"userEvidenceOnly\"") &&
        backend.contains("\"turns\": indexedTurns") &&
        backend.contains("\"transcript\": transcript") &&
        backend.contains("turn.role == \"user\" ? \"user\" : \"assistant\"") &&
        manager.contains("turns: turns") &&
        manager.contains("let transcript = turns.filter { $0.role == \"user\" }") &&
        !manager.contains("let role = t.role == \"user\" ? \"长辈\" : \"寻梦环游\""),
    "iOS extraction must send indexed user/assistant turns while retaining legacy transcript"
)

require(
    models.contains("var lastBackendExtractionSessionId: Int? = nil") &&
        models.contains("var lastBackendExtractionAt: Date? = nil") &&
        manager.contains("if let lastBackendExtractionSessionId, let lastBackendExtractionAt") &&
        manager.contains("sessionId - lastBackendExtractionSessionId >= 3") &&
        manager.contains("graph.lastBackendExtractionSessionId = max(") &&
        manager.contains("graph.lastBackendExtractionAt = Date()") &&
        !manager.contains("imported.lastBackendExtractionSessionId") &&
        !manager.contains("imported.lastBackendExtractionAt"),
    "backend extraction cadence must use optional compatibility watermarks"
)
requireOrdered(
    manager,
    "if acceptedBackendExtraction {",
    "graph.lastBackendExtractionSessionId = max(",
    "backend watermarks must only advance inside the successful extraction branch"
)

require(
    generationPolicy.contains("case \"high\", \"confirmed\"") &&
        generationPolicy.contains("privacyScope == \"generationAllowed\"") &&
        manager.contains("KnowledgeGenerationPolicy.allowsFact(") &&
        manager.contains("$0.relatedPersonIds.contains(p.id)") &&
        manager.contains("&& canGenerateFact($0)") &&
        manager.contains("let facts = result.facts.filter {") &&
        manager.contains("KBPersonaPolicy.allowsEvidenceStatus("),
    "direct and related local facts must share privacy/confidence generation policy"
)

require(
    backend.contains("let personaScope: String?") &&
        backend.contains("let digitalHumanId: String?") &&
        backend.contains("let persona = json[\"persona\"] as? [String: Any]") &&
        backend.contains("Self.nonEmptyString(persona?[\"personaScope\"])") &&
        backend.contains("Self.nonEmptyString(persona?[\"digitalHumanId\"])") &&
        backend.contains("Self.nonEmptyString(json[\"personaScope\"])") &&
        backend.contains("Self.nonEmptyString(json[\"digitalHumanId\"])") &&
        echo.contains("expectedUserID") &&
        echo.contains("expectedPersonaScope") &&
        echo.contains("expectedDigitalHumanID") &&
        echo.contains("EchoKnowledgeContextPolicy.responseIdentityMatches("),
    "Context Packet and turn gate must carry the complete expected identity"
)

require(
    echoPolicy.contains("enum KBPersonaIdentityResolver") &&
        echoPolicy.contains("let personaScope = isPersonal ? \"personal\" : \"family\"") &&
        echoPolicy.contains("identity.isPersonal") &&
        manager.contains("FamilyRepository.shared.get(by: context.ownerId)?.digitalHumanId") &&
        echo.contains("KBLiteManager.resolvePersonaIdentity(for: context)") &&
        echo.contains("digitalHumanId: expectedIdentity.digitalHumanId") &&
        echo.contains("family_local_fallback_forbidden") &&
        echo.contains("activeEchoTurnKnowledgeContextGate = nil"),
    "Echo must use canonical persona IDs and forbid family local fallback"
)
requireOrdered(
    echo,
    "EchoKnowledgeContextPolicy.allowsLocalKBLiteFallback(",
    "KBLiteManager.shared.buildGenerationAllowedContextString(",
    "persona fallback policy must run before any local KBLite read"
)
require(
    echo.contains("turn knowledge finished without local context") &&
        echo.contains("turn knowledge finished without backend context") &&
        echo.contains("gate.finishWithoutContext()"),
    "empty backend/local knowledge must close the turn gate without retry leakage"
)

require(
    project.contains("KnowledgeGenerationPolicy.swift in Sources") &&
        project.contains("EchoKnowledgeContextPolicy.swift in Sources") &&
        regression.contains("run-knowledge-context-policy-model-smoke.sh") &&
        regression.contains("knowledge-evidence-context-policy-check.swift"),
    "policies and deterministic QA must be wired into the app/release regression"
)

print("Knowledge evidence/context policy guard passed")
