import Foundation

@main
enum KnowledgeProposalModelSmoke {
    static func main() throws {
        try verifyLegacyGraphCompatibility()
        try verifyCompleteProposalEnvelope()
        try verifyLegacyExtractionEnvelope()
        verifyMalformedProposalIsRejected()
        print("Knowledge proposal model smoke passed")
    }

    private static func verifyLegacyGraphCompatibility() throws {
        let json = """
        {
          "version": 1,
          "lastUpdated": "2026-07-11T00:00:00Z",
          "sessionCount": 4,
          "people": [{
            "id": "person-legacy", "name": "Alice", "aliases": [], "traits": [],
            "relatedPersonIds": [], "sourceSessionIds": [1],
            "createdAt": "2026-07-10T00:00:00Z", "updatedAt": "2026-07-11T00:00:00Z"
          }],
          "places": [{
            "id": "place-legacy", "name": "Nanjing", "relatedPersonIds": [],
            "sourceSessionIds": [1], "createdAt": "2026-07-10T00:00:00Z"
          }],
          "events": [{
            "id": "event-legacy", "title": "First job", "participantIds": [], "mediaIds": [],
            "sourceSessionIds": [1], "createdAt": "2026-07-10T00:00:00Z"
          }],
          "facts": [{
            "id": "fact-legacy", "statement": "Alice worked in Nanjing", "confidence": "high",
            "relatedPersonIds": [], "relatedPlaceIds": [], "relatedEventIds": [],
            "sourceSessionIds": [1], "createdAt": "2026-07-10T00:00:00Z"
          }]
        }
        """

        let graph = try makeDecoder().decode(KBLiteGraph.self, from: Data(json.utf8))
        require(graph.sessionCount == 4, "legacy graph fields must decode")
        require(graph.people.first?.ownerUserId == nil, "legacy person owner must remain optional")
        require(graph.places.first?.personaScope == nil, "legacy place persona must remain optional")
        require(graph.events.first?.digitalHumanId == nil, "legacy event digital-human ID must remain optional")
        require(graph.facts.first?.sourceTurnIndices == nil, "legacy fact turn indices must remain optional")
    }

    private static func verifyCompleteProposalEnvelope() throws {
        let json = """
        {
          "extraction": {
            "people": [{"name": "Alice", "aliases": [], "traits": [], "sourceTurnIndices": [0]}],
            "places": [], "events": [], "facts": []
          },
          "mutationProposal": {
            "proposalSchemaVersion": 1,
            "mutationSchemaVersion": 2,
            "baseRevision": 17,
            "ownerUserId": "owner-1",
            "personaScope": "family",
            "digitalHumanId": "digital-human-1",
            "upserts": {
              "people": [{
                "id": "person-1", "name": "Alice", "aliases": ["A"], "relation": "mother",
                "traits": ["teacher"], "briefBio": "Short bio", "relatedPersonIds": ["person-2"],
                "sourceSessionIds": [42], "sourceTurnIndices": [0],
                "privacyMetadata": {"scope": "generationAllowed", "sourceRefs": [{"kind": "conversationTurn", "id": "turn-0", "title": "Conversation"}]},
                "ownerUserId": "owner-1", "personaScope": "family", "digitalHumanId": "digital-human-1",
                "evidenceStatus": "observed", "createdAt": "2026-07-11T01:02:03.123Z", "updatedAt": "2026-07-11T01:03:04Z"
              }],
              "places": [{
                "id": "place-1", "name": "Nanjing", "category": "worked", "latitude": 32.06, "longitude": 118.79,
                "description": "Workplace", "relatedPersonIds": ["person-1"], "sourceSessionIds": [42], "sourceTurnIndices": [0],
                "privacyMetadata": {"scope": "generationAllowed", "sourceRefs": []},
                "ownerUserId": "owner-1", "personaScope": "family", "digitalHumanId": "digital-human-1", "evidenceStatus": "observed"
              }],
              "events": [{
                "id": "event-1", "title": "First job", "description": "Started work", "year": 1968, "month": 5,
                "locationId": "place-1", "participantIds": ["person-1"], "mediaIds": ["media-1"], "memoirId": "memoir-1",
                "sourceSessionIds": [42], "sourceTurnIndices": [0],
                "privacyMetadata": {"scope": "generationAllowed", "sourceRefs": []},
                "ownerUserId": "owner-1", "personaScope": "family", "digitalHumanId": "digital-human-1", "evidenceStatus": "observed"
              }],
              "facts": [{
                "id": "fact-1", "statement": "Alice worked in Nanjing", "confidence": "high",
                "relatedPersonIds": ["person-1"], "relatedPlaceIds": ["place-1"], "relatedEventIds": ["event-1"],
                "sourceSessionIds": [42], "sourceTurnIndices": [0],
                "privacyMetadata": {"scope": "generationAllowed", "sourceRefs": []},
                "ownerUserId": "owner-1", "personaScope": "family", "digitalHumanId": "digital-human-1", "evidenceStatus": "observed"
              }]
            },
            "tombstones": [],
            "proposalPolicy": {
              "version": 1, "snapshotEntityCount": 8, "eligibleSnapshotEntityCount": 5,
              "upsertEntityCount": 4, "upsertCounts": {"people": 1, "places": 1, "events": 1, "facts": 1},
              "reusedEntityCount": 1, "generatedEntityCount": 3, "duplicateEntityCount": 0,
              "skippedEntityCount": 0, "resolvedRelationCount": 6, "unresolvedRelationCount": 1
            }
          }
        }
        """

        let envelope = try makeDecoder().decode(KBKnowledgeExtractionEnvelope.self, from: Data(json.utf8))
        let proposal = try requireValue(envelope.proposal, "complete response must expose its proposal")
        require(proposal.baseRevision == 17, "proposal revision must decode")
        require(proposal.upserts.places[0].relatedPersonIds == ["person-1"], "place relation IDs must decode")
        require(proposal.upserts.events[0].locationId == "place-1", "event location ID must decode")
        require(proposal.upserts.facts[0].relatedEventIds == ["event-1"], "fact relation IDs must decode")
        require(proposal.upserts.people[0].privacyMetadata.sourceRefs.first?.id == "turn-0", "source metadata must decode")
        require(proposal.upserts.people[0].createdAt != nil, "fractional proposal dates must decode")
        let expectedIdentity = KBPersonaIdentity(
            ownerUserId: "owner-1",
            personaScope: "family",
            digitalHumanId: "digital-human-1"
        )
        require(
            KBPersonaPolicy.isValidProposal(proposal, for: expectedIdentity),
            "matching extraction proposal must pass the persona/schema policy"
        )
        require(
            !KBPersonaPolicy.isValidProposal(
                proposal,
                for: KBPersonaIdentity(
                    ownerUserId: "owner-1",
                    personaScope: "family",
                    digitalHumanId: "another-digital-human"
                )
            ),
            "proposal identity mismatch must be rejected"
        )
        require(proposal.proposalPolicy.upsertCounts.events == 1, "proposal policy counts must decode")
    }

    private static func verifyLegacyExtractionEnvelope() throws {
        let json = """
        {"extraction":{"people":[],"places":[],"events":[],"facts":[]}}
        """
        let envelope = try makeDecoder().decode(KBKnowledgeExtractionEnvelope.self, from: Data(json.utf8))
        require(envelope.proposal == nil, "missing mutationProposal must be treated as legacy")
    }

    private static func verifyMalformedProposalIsRejected() {
        let malformed = """
        {"extraction":{"people":[],"places":[],"events":[],"facts":[]},"mutationProposal":{"proposalSchemaVersion":"invalid"}}
        """
        let explicitNull = """
        {"extraction":{"people":[],"places":[],"events":[],"facts":[]},"mutationProposal":null}
        """
        requireDecodeFailure(malformed, "malformed mutationProposal must not degrade to legacy extraction")
        requireDecodeFailure(explicitNull, "explicit null mutationProposal must not be treated as an absent field")
    }

    private static func makeDecoder() -> JSONDecoder {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = fractional.date(from: value) ?? standard.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
            }
            return date
        }
        return decoder
    }

    private static func requireDecodeFailure(_ json: String, _ message: String) {
        do {
            _ = try makeDecoder().decode(KBKnowledgeExtractionEnvelope.self, from: Data(json.utf8))
            require(false, message)
        } catch {
            return
        }
    }

    private static func requireValue<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            require(false, message)
            throw SmokeError.missingValue
        }
        return value
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Knowledge proposal model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }

    private enum SmokeError: Error {
        case missingValue
    }
}
