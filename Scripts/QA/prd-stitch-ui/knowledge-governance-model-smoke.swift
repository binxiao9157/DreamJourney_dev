import Foundation

@main
enum KnowledgeGovernanceModelSmoke {
    static func main() throws {
        try verifyLegacyEntityCompatibility()
        try verifyAllActionEncodingsAndRoundTrips()
        verifyInvalidCorrectionsAreRejected()
        try verifyMetadataFidelity()
        try verifyStrictResponseAndSummaryParsing()
        print("Knowledge governance model smoke passed")
    }

    private static func verifyLegacyEntityCompatibility() throws {
        let json = """
        {
          "version": 1,
          "lastUpdated": "2026-07-11T00:00:00Z",
          "sessionCount": 1,
          "people": [{
            "id": "person-1", "name": "Alice", "aliases": [], "traits": [],
            "relatedPersonIds": [], "sourceSessionIds": [],
            "createdAt": "2026-07-11T00:00:00Z", "updatedAt": "2026-07-11T00:00:00Z"
          }],
          "places": [{
            "id": "place-1", "name": "Nanjing", "relatedPersonIds": [],
            "sourceSessionIds": [], "createdAt": "2026-07-11T00:00:00Z"
          }],
          "events": [{
            "id": "event-1", "title": "First job", "participantIds": [], "mediaIds": [],
            "sourceSessionIds": [], "createdAt": "2026-07-11T00:00:00Z"
          }],
          "facts": [{
            "id": "fact-1", "statement": "Alice worked in Nanjing", "confidence": "high",
            "relatedPersonIds": [], "relatedPlaceIds": [], "relatedEventIds": [],
            "sourceSessionIds": [], "createdAt": "2026-07-11T00:00:00Z"
          }]
        }
        """
        let graph = try graphDecoder().decode(KBLiteGraph.self, from: Data(json.utf8))
        require(graph.people[0].governanceMetadata == nil, "legacy person must not require governance metadata")
        require(graph.places[0].governanceMetadata == nil, "legacy place must not require governance metadata")
        require(graph.events[0].governanceMetadata == nil, "legacy event must not require governance metadata")
        require(graph.facts[0].governanceMetadata == nil, "legacy fact must not require governance metadata")
    }

    private static func verifyAllActionEncodingsAndRoundTrips() throws {
        let decidedAt = try isoDate("2026-07-11T10:30:00.123Z")
        let fact = KBKnowledgeEntityLink(entityType: .facts, entityId: "fact-1")
        let actions: [KBKnowledgeGovernanceAction] = [
            .confirm(target: fact, decidedAt: decidedAt),
            .reject(target: fact, decidedAt: decidedAt),
            .correct(
                target: fact,
                correction: .fact(KBFactGovernanceCorrection(statement: "Corrected fact")),
                decidedAt: decidedAt
            ),
            .deleteSource(
                sourceRef: KBKnowledgeSourceIdentity(kind: "memoryArchiveItem", id: "archive/1"),
                decidedAt: decidedAt
            ),
        ]

        for action in actions {
            let object = try action.backendJSONObject()
            require(object["kind"] as? String == action.kind.rawValue, "action kind must encode")
            require(object["decidedAt"] as? String == "2026-07-11T10:30:00.123Z", "decidedAt must be ISO-8601")
            let data = try JSONSerialization.data(withJSONObject: object)
            let decoded = try JSONDecoder().decode(KBKnowledgeGovernanceAction.self, from: data)
            require(decoded == action, "action must survive a JSON round trip")
        }

        let confirm = try actions[0].backendJSONObject()
        require(confirm["entityType"] as? String == "facts", "confirm must encode entityType")
        require(confirm["entityId"] as? String == "fact-1", "confirm must encode entityId")
        require(confirm["correction"] == nil, "confirm must not encode correction")

        let correct = try actions[2].backendJSONObject()
        let factCorrection = correct["correction"] as? [String: Any]
        require(factCorrection?["statement"] as? String == "Corrected fact", "correct must encode typed correction")

        let deleteSource = try actions[3].backendJSONObject()
        let sourceRef = deleteSource["sourceRef"] as? [String: Any]
        require(sourceRef?["kind"] as? String == "memoryArchiveItem", "deleteSource must encode source kind")
        require(sourceRef?["id"] as? String == "archive/1", "deleteSource must encode source ID")

        let typedCorrections: [(KBKnowledgeEntityLink, KBKnowledgeGovernanceCorrection)] = [
            (.init(entityType: .people, entityId: "person-1"), .person(.init(name: "Alice"))),
            (.init(entityType: .places, entityId: "place-1"), .place(.init(name: "Nanjing"))),
            (.init(entityType: .events, entityId: "event-1"), .event(.init(title: "First job"))),
            (.init(entityType: .facts, entityId: "fact-1"), .fact(.init(statement: "Corrected fact"))),
        ]
        for (target, correction) in typedCorrections {
            let action = KBKnowledgeGovernanceAction.correct(
                target: target,
                correction: correction,
                decidedAt: decidedAt
            )
            let object = try action.backendJSONObject()
            require(object["entityType"] as? String == target.entityType.rawValue,
                    "each typed correction must encode its matching entityType")
        }
    }

    private static func verifyInvalidCorrectionsAreRejected() {
        let decidedAt = Date(timeIntervalSince1970: 1_752_229_800)
        let mismatch = KBKnowledgeGovernanceAction.correct(
            target: .init(entityType: .facts, entityId: "fact-1"),
            correction: .person(.init(name: "Wrong type")),
            decidedAt: decidedAt
        )
        requireThrows("mismatched correction type must fail encoding") {
            _ = try mismatch.backendJSONObject()
        }

        let empty = KBKnowledgeGovernanceAction.correct(
            target: .init(entityType: .places, entityId: "place-1"),
            correction: .place(.init()),
            decidedAt: decidedAt
        )
        requireThrows("empty correction must fail encoding") {
            _ = try empty.backendJSONObject()
        }

        let arbitraryField = """
        {
          "kind": "correct", "entityType": "facts", "entityId": "fact-1",
          "correction": {"statement": "valid", "ownerUserId": "other"},
          "decidedAt": "2026-07-11T10:30:00Z"
        }
        """
        requireThrows("arbitrary correction fields must fail decoding") {
            _ = try JSONDecoder().decode(KBKnowledgeGovernanceAction.self, from: Data(arbitraryField.utf8))
        }

        let emptyTarget = KBKnowledgeGovernanceAction.confirm(
            target: .init(entityType: .facts, entityId: "  "),
            decidedAt: decidedAt
        )
        requireThrows("empty entity ID must fail backend encoding") {
            _ = try emptyTarget.backendJSONObject()
        }

        let emptySource = KBKnowledgeGovernanceAction.deleteSource(
            sourceRef: .init(kind: "memoryArchiveItem", id: ""),
            decidedAt: decidedAt
        )
        requireThrows("empty source ID must fail backend encoding") {
            _ = try emptySource.backendJSONObject()
        }
    }

    private static func verifyMetadataFidelity() throws {
        let correctionJSON = """
        {
          "action": "correct", "operationId": "operation-1", "decidedAt": "2026-07-11T10:30:00Z",
          "target": {"entityType": "facts", "entityId": "fact-1"},
          "replacement": {"entityType": "facts", "entityId": "fact-2"}
        }
        """
        let correction = try JSONDecoder().decode(
            KBKnowledgeGovernanceMetadata.self,
            from: Data(correctionJSON.utf8)
        )
        require(correction.target.entityType == .facts, "metadata target type must decode")
        require(correction.target.entityId == "fact-1", "metadata target ID must decode")
        require(correction.replacement?.entityId == "fact-2", "metadata replacement must decode")

        let deletionJSON = """
        {
          "action": "deleteSource", "operationId": "operation-2", "decidedAt": "2026-07-11T10:31:00Z",
          "target": {"entityType": "events", "entityId": "event-1"},
          "sourceRef": {"kind": "memoryArchiveItem", "id": "archive-1"}
        }
        """
        let deletion = try JSONDecoder().decode(
            KBKnowledgeGovernanceMetadata.self,
            from: Data(deletionJSON.utf8)
        )
        require(deletion.sourceRef == .init(kind: "memoryArchiveItem", id: "archive-1"),
                "metadata sourceRef must retain kind and ID")

        let roundTrip = try JSONDecoder().decode(
            KBKnowledgeGovernanceMetadata.self,
            from: JSONEncoder().encode(deletion)
        )
        require(roundTrip == deletion, "metadata must survive a JSON round trip")
    }

    private static func verifyStrictResponseAndSummaryParsing() throws {
        let responseJSON: [String: Any] = [
            "governanceSchemaVersion": 1,
            "mutationSchemaVersion": 2,
            "userId": "owner-1",
            "operationId": "operation-1",
            "revision": 8,
            "duplicate": false,
            "summary": [
                "action": "correct",
                "decidedAt": "2026-07-11T10:30:00Z",
                "affectedEntityCount": 2,
                "target": ["entityType": "facts", "entityId": "fact-1"],
                "replacement": ["entityType": "facts", "entityId": "fact-2"],
            ],
            "graph": [
                "version": 1,
                "people": [], "places": [], "events": [],
                "facts": [["id": "fact-1"], ["id": "fact-2"]],
            ],
        ]
        let wireData = try JSONSerialization.data(withJSONObject: responseJSON)
        let wireObject = try JSONSerialization.jsonObject(with: wireData) as? [String: Any]
        let response = try KBKnowledgeGovernanceResponse(json: wireObject ?? [:])
        require(response.governanceSchemaVersion == 1, "governance schema must parse")
        require(response.mutationSchemaVersion == 2, "mutation schema must parse")
        require(response.userId == "owner-1" && response.operationId == "operation-1",
                "response identity must parse")
        require(response.revision == 8 && !response.duplicate, "response revision metadata must parse")
        require(response.summary.action == .correct, "summary action must parse")
        require(response.summary.replacement?.entityId == "fact-2", "summary replacement must parse")
        require((response.graph["facts"] as? [[String: Any]])?.count == 2,
                "authoritative graph must remain an untyped JSON object")

        var invalidGovernance = responseJSON
        invalidGovernance["governanceSchemaVersion"] = 2
        requireThrows("unsupported governance schema must fail") {
            _ = try KBKnowledgeGovernanceResponse(json: invalidGovernance)
        }

        var invalidMutation = responseJSON
        invalidMutation["mutationSchemaVersion"] = 1
        requireThrows("unsupported mutation schema must fail") {
            _ = try KBKnowledgeGovernanceResponse(json: invalidMutation)
        }

        var nonIntegerRevision = responseJSON
        nonIntegerRevision["revision"] = 8.0
        requireThrows("floating-point revision must fail") {
            _ = try KBKnowledgeGovernanceResponse(json: nonIntegerRevision)
        }

        var nonBooleanDuplicate = responseJSON
        nonBooleanDuplicate["duplicate"] = 0
        requireThrows("numeric duplicate must fail") {
            _ = try KBKnowledgeGovernanceResponse(json: nonBooleanDuplicate)
        }

        var missingGraph = responseJSON
        missingGraph.removeValue(forKey: "graph")
        requireThrows("missing authoritative graph must fail") {
            _ = try KBKnowledgeGovernanceResponse(json: missingGraph)
        }

        var malformedSummary = responseJSON
        malformedSummary["summary"] = [
            "action": "correct",
            "decidedAt": "2026-07-11T10:30:00Z",
            "affectedEntityCount": 1,
            "target": ["entityType": "facts", "entityId": "fact-1"],
        ]
        requireThrows("correct summary without replacement must fail") {
            _ = try KBKnowledgeGovernanceResponse(json: malformedSummary)
        }
    }

    private static func graphDecoder() -> JSONDecoder {
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

    private static func isoDate(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: value) else { throw SmokeError.invalidDate }
        return date
    }

    private static func requireThrows(_ message: String, operation: () throws -> Void) {
        do {
            try operation()
            require(false, message)
        } catch {
            return
        }
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Knowledge governance model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }

    private enum SmokeError: Error {
        case invalidDate
    }
}
