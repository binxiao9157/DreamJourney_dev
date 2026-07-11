import Foundation

@main
enum KnowledgeContextPolicyModelSmoke {
    static func main() throws {
        verifyGenerationConfidencePolicy()
        verifyPersonaFallbackPolicy()
        verifyRelationCannotGrantPersonalIdentity()
        verifyPersonaAuthorizationSnapshot()
        verifyAuthorizationEpoch()
        verifyPacketIdentityPolicy()
        verifyPersonaEntityAndEvidencePolicy()
        try verifyLegacyGraphCompatibility()
        print("Knowledge context policy model smoke passed")
    }

    private static func verifyAuthorizationEpoch() {
        var epoch = KnowledgeAuthorizationEpochState()
        let callbackEpoch = epoch.currentEpoch
        require(epoch.accepts(boundEpoch: callbackEpoch), "the active callback must match its bound authorization epoch")
        epoch.rotate()
        require(!epoch.accepts(boundEpoch: callbackEpoch), "rotating authorization must immediately stale queued callbacks")
        require(epoch.accepts(boundEpoch: epoch.currentEpoch), "a new generation must bind the rotated epoch")
    }

    private static func verifyPersonaAuthorizationSnapshot() {
        let personal = KBPersonaAuthorizationSnapshot(
            identity: KBPersonaIdentity(ownerUserId: "viewer", personaScope: "personal", digitalHumanId: "viewer"),
            userGeneration: UUID(),
            personaGeneration: UUID(),
            familyAuthorizationGeneration: nil
        )
        require(personal.isComplete, "personal async authorization snapshot must not require a family token")

        let familyIdentity = KBPersonaIdentity(
            ownerUserId: "viewer",
            personaScope: "family",
            digitalHumanId: "family-A"
        )
        let missingFamilyToken = KBPersonaAuthorizationSnapshot(
            identity: familyIdentity,
            userGeneration: UUID(),
            personaGeneration: UUID(),
            familyAuthorizationGeneration: nil
        )
        require(!missingFamilyToken.isComplete, "family async authorization snapshot must fail closed without a generation token")
        let authorizedFamily = KBPersonaAuthorizationSnapshot(
            identity: familyIdentity,
            userGeneration: UUID(),
            personaGeneration: UUID(),
            familyAuthorizationGeneration: UUID()
        )
        require(authorizedFamily.isComplete, "family async authorization snapshot must accept an explicit generation token")
        require(
            KBPersonaAuthorizationSnapshotPolicy.isCurrent(
                authorizedFamily,
                currentIdentity: familyIdentity,
                userGeneration: authorizedFamily.userGeneration,
                personaGeneration: authorizedFamily.personaGeneration,
                familyAuthorizationGeneration: authorizedFamily.familyAuthorizationGeneration
            ),
            "matching family generations must keep the async snapshot current"
        )
        require(
            !KBPersonaAuthorizationSnapshotPolicy.isCurrent(
                authorizedFamily,
                currentIdentity: familyIdentity,
                userGeneration: UUID(),
                personaGeneration: authorizedFamily.personaGeneration,
                familyAuthorizationGeneration: authorizedFamily.familyAuthorizationGeneration
            ),
            "a user generation change must invalidate the async snapshot"
        )
        require(
            !KBPersonaAuthorizationSnapshotPolicy.isCurrent(
                authorizedFamily,
                currentIdentity: familyIdentity,
                userGeneration: authorizedFamily.userGeneration,
                personaGeneration: UUID(),
                familyAuthorizationGeneration: authorizedFamily.familyAuthorizationGeneration
            ),
            "a persona generation change must invalidate the async snapshot"
        )
        require(
            !KBPersonaAuthorizationSnapshotPolicy.isCurrent(
                authorizedFamily,
                currentIdentity: familyIdentity,
                userGeneration: authorizedFamily.userGeneration,
                personaGeneration: authorizedFamily.personaGeneration,
                familyAuthorizationGeneration: UUID()
            ),
            "a family authorization generation change must invalidate the async snapshot"
        )
    }

    private static func verifyRelationCannotGrantPersonalIdentity() {
        let spoofed = KBPersonaIdentityResolver.resolve(
            viewerUserId: "viewer",
            ownerId: "family-member",
            relation: "本人",
            isSelfAssistant: false,
            familyMemberDigitalHumanId: "family-digital-human"
        )
        require(spoofed.personaScope == "family", "relation text must not grant personal identity")
        require(spoofed.digitalHumanId == "family-digital-human", "authorized family identity must retain canonical digital-human ID")

        let explicitSelf = KBPersonaIdentityResolver.resolve(
            viewerUserId: "viewer",
            ownerId: "viewer",
            relation: "家人",
            isSelfAssistant: true,
            familyMemberDigitalHumanId: nil
        )
        require(explicitSelf.isPersonal, "explicit self identity must remain personal")
    }

    private static func verifyGenerationConfidencePolicy() {
        require(
            KnowledgeGenerationPolicy.allowsFact(
                privacyScope: "generationAllowed",
                confidence: "high"
            ),
            "high facts with generationAllowed scope must be usable"
        )
        require(
            KnowledgeGenerationPolicy.allowsFact(
                privacyScope: "generationAllowed",
                confidence: "confirmed"
            ),
            "confirmed facts with generationAllowed scope must be usable"
        )
        require(
            !KnowledgeGenerationPolicy.allowsFact(
                privacyScope: "generationAllowed",
                confidence: "medium"
            ),
            "medium facts must not enter generation context"
        )
        require(
            !KnowledgeGenerationPolicy.allowsFact(
                privacyScope: "generationAllowed",
                confidence: "low"
            ),
            "low facts must not enter generation context"
        )
        require(
            !KnowledgeGenerationPolicy.allowsFact(
                privacyScope: "localOnly",
                confidence: "confirmed"
            ),
            "confidence must not bypass privacy scope"
        )
    }

    private static func verifyPersonaFallbackPolicy() {
        let personal = EchoKnowledgeContextIdentity(
            userId: "viewer",
            personaScope: "personal",
            digitalHumanId: "viewer"
        )
        let family = EchoKnowledgeContextIdentity(
            userId: "viewer",
            personaScope: "family",
            digitalHumanId: "family-digital-human"
        )
        require(
            EchoKnowledgeContextPolicy.allowsLocalKBLiteFallback(for: personal),
            "personal persona must allow viewer-owned local fallback"
        )
        require(
            !EchoKnowledgeContextPolicy.allowsLocalKBLiteFallback(for: family),
            "family persona must forbid viewer-owned local fallback"
        )
        require(
            EchoKnowledgeContextPolicy.canonicalDigitalHumanId(
                personaScope: "family",
                ownerId: "family-owner",
                familyMemberDigitalHumanId: "family-canonical"
            ) == "family-canonical",
            "family identity must prefer the repository digital-human ID"
        )
        require(
            EchoKnowledgeContextPolicy.canonicalDigitalHumanId(
                personaScope: "family",
                ownerId: "family-owner",
                familyMemberDigitalHumanId: nil
            ) == "family-owner",
            "family identity must fall back to owner ID"
        )
        require(
            EchoKnowledgeContextPolicy.canonicalDigitalHumanId(
                personaScope: "personal",
                ownerId: "personal-owner",
                familyMemberDigitalHumanId: "ignored-family-id"
            ) == "personal-owner",
            "personal identity must use owner ID"
        )
    }

    private static func verifyPacketIdentityPolicy() {
        let expected = EchoKnowledgeContextIdentity(
            userId: "viewer",
            personaScope: "family",
            digitalHumanId: "family-canonical"
        )
        require(
            EchoKnowledgeContextPolicy.responseIdentityMatches(
                expected: expected,
                responseUserId: "viewer",
                responsePersonaScope: "family",
                responseDigitalHumanId: "family-canonical"
            ),
            "matching packet identity must be accepted"
        )
        require(
            !EchoKnowledgeContextPolicy.responseIdentityMatches(
                expected: expected,
                responseUserId: "other-viewer",
                responsePersonaScope: "family",
                responseDigitalHumanId: "family-canonical"
            ),
            "packet user mismatch must be rejected"
        )
        require(
            !EchoKnowledgeContextPolicy.responseIdentityMatches(
                expected: expected,
                responseUserId: "viewer",
                responsePersonaScope: "personal",
                responseDigitalHumanId: "family-canonical"
            ),
            "packet persona mismatch must be rejected"
        )
        require(
            !EchoKnowledgeContextPolicy.responseIdentityMatches(
                expected: expected,
                responseUserId: "viewer",
                responsePersonaScope: "family",
                responseDigitalHumanId: "wrong-digital-human"
            ),
            "packet digital-human mismatch must be rejected"
        )
        require(
            !EchoKnowledgeContextPolicy.responseIdentityMatches(
                expected: expected,
                responseUserId: "viewer",
                responsePersonaScope: nil,
                responseDigitalHumanId: nil
            ),
            "packet identity contract omissions must be rejected"
        )
    }

    private static func verifyPersonaEntityAndEvidencePolicy() {
        let personal = KBPersonaIdentity(
            ownerUserId: "viewer",
            personaScope: "personal",
            digitalHumanId: "viewer"
        )
        let family = KBPersonaIdentity(
            ownerUserId: "viewer",
            personaScope: "family",
            digitalHumanId: "family-canonical"
        )
        require(
            !KBPersonaPolicy.allowsEntity(
                ownerUserId: nil,
                personaScope: nil,
                digitalHumanId: nil,
                for: personal,
                legacyOwnerUserId: "viewer"
            ),
            "personal identity must not claim ownerless legacy entities"
        )
        require(
            !KBPersonaPolicy.allowsEntity(
                ownerUserId: nil,
                personaScope: nil,
                digitalHumanId: nil,
                for: family,
                legacyOwnerUserId: "viewer"
            ),
            "family identity must reject legacy entities without explicit metadata"
        )
        require(
            KBPersonaPolicy.allowsEntity(
                ownerUserId: "viewer",
                personaScope: "family",
                digitalHumanId: "family-canonical",
                for: family,
                legacyOwnerUserId: "viewer"
            ),
            "family identity must allow an exact owner/persona/digital-human match"
        )
        require(
            !KBPersonaPolicy.allowsEvidenceStatus(nil, for: personal),
            "personal legacy evidence must remain quarantined from generation"
        )
        require(
            !KBPersonaPolicy.allowsEvidenceStatus(nil, for: family),
            "family evidence must be explicit"
        )
        require(
            KBPersonaPolicy.allowsEvidenceStatus("observed", for: family),
            "observed family evidence must be usable"
        )
        require(
            !KBPersonaPolicy.allowsEvidenceStatus("candidate", for: personal),
            "candidate evidence must not enter generation"
        )
        require(
            !KBPersonaPolicy.allowsEvidenceStatus("rejected", for: personal),
            "rejected evidence must not enter generation"
        )
    }

    private static func verifyLegacyGraphCompatibility() throws {
        let legacyJSON = """
        {
          "version": 1,
          "lastUpdated": "2026-07-11T00:00:00Z",
          "sessionCount": 7,
          "people": [],
          "places": [],
          "events": [],
          "facts": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let graph = try decoder.decode(KBLiteGraph.self, from: Data(legacyJSON.utf8))
        require(graph.sessionCount == 7, "legacy graph fields must remain decodable")
        require(graph.lastBackendExtractionSessionId == nil, "legacy graph must start without a backend session watermark")
        require(graph.lastBackendExtractionAt == nil, "legacy graph must start without a backend date watermark")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Knowledge context policy model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
