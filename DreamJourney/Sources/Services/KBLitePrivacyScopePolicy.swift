import Foundation

enum KBLitePrivacyScopePolicy {
    static func remoteExtractableTurns(from turns: [ConversationTurn]) -> [ConversationTurn] {
        turns.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: .remoteExtraction)
        }
    }

    static func localExtractableTurns(from turns: [ConversationTurn]) -> [ConversationTurn] {
        turns.filter { $0.privacyMetadata.scope != .privateOnly }
    }

    static func derivedEntityMetadata(from turns: [ConversationTurn]) -> MemoryPrivacyMetadata {
        guard let scope = highestAvailableScope(in: turns) else {
            return MemoryPrivacyMetadata(scope: .localOnly)
        }
        let sourceRefs = turns.reduce(into: [MemorySourceRef]()) { result, turn in
            for sourceRef in turn.privacyMetadata.sourceRefs
                where !result.contains(where: { $0.kind == sourceRef.kind && $0.id == sourceRef.id }) {
                result.append(sourceRef)
            }
        }
        let familyVisibility = turns.first { $0.privacyMetadata.scope == .familyCircle }?
            .privacyMetadata.familyVisibility ?? .allMembers
        let createdAt = turns.compactMap { $0.privacyMetadata.createdAt }.min()
        return MemoryPrivacyMetadata(
            scope: scope,
            sourceRefs: sourceRefs,
            createdAt: createdAt,
            familyVisibility: familyVisibility
        )
    }

    static func canMerge(existing: MemoryPrivacyMetadata, incoming: MemoryPrivacyMetadata) -> Bool {
        existing.scope == incoming.scope
    }

    static func relatedFacts(
        in graph: KBLiteGraph,
        relatedPersonId: String,
        surface: MemoryUseSurface
    ) -> [KBFact] {
        graph.facts.filter {
            $0.relatedPersonIds.contains(relatedPersonId)
                && PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface)
        }
    }

    static func sanitizedGraph(
        _ graph: KBLiteGraph,
        for surface: MemoryUseSurface,
        familyMemberID: String? = nil
    ) -> KBLiteGraph {
        let retainedPeople = graph.people.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface, familyMemberID: familyMemberID)
        }
        let retainedPlaces = graph.places.filter {
            PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface, familyMemberID: familyMemberID)
        }

        let peopleIDs = Set(retainedPeople.map(\.id))
        let placeIDs = Set(retainedPlaces.map(\.id))

        let people = retainedPeople.map { person -> KBPerson in
            var sanitized = person
            sanitized.relatedPersonIds = person.relatedPersonIds.filter { peopleIDs.contains($0) }
            sanitized.privacyMetadata = sanitizedMetadata(person.privacyMetadata, for: surface)
            return sanitized
        }

        let places = retainedPlaces.map { place -> KBPlace in
            var sanitized = place
            sanitized.relatedPersonIds = place.relatedPersonIds.filter { peopleIDs.contains($0) }
            sanitized.privacyMetadata = sanitizedMetadata(place.privacyMetadata, for: surface)
            return sanitized
        }

        let events = graph.events
            .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface, familyMemberID: familyMemberID) }
            .map { event -> KBEvent in
                var sanitized = event
                sanitized.participantIds = event.participantIds.filter { peopleIDs.contains($0) }
                if let locationId = event.locationId, !placeIDs.contains(locationId) {
                    sanitized.locationId = nil
                }
                sanitized.privacyMetadata = sanitizedMetadata(event.privacyMetadata, for: surface)
                return sanitized
            }

        let eventIDs = Set(events.map(\.id))

        let facts = graph.facts
            .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface, familyMemberID: familyMemberID) }
            .map { fact -> KBFact in
                var sanitized = fact
                sanitized.relatedPersonIds = fact.relatedPersonIds.filter { peopleIDs.contains($0) }
                sanitized.relatedPlaceIds = fact.relatedPlaceIds.filter { placeIDs.contains($0) }
                sanitized.relatedEventIds = fact.relatedEventIds.filter { eventIDs.contains($0) }
                sanitized.privacyMetadata = sanitizedMetadata(fact.privacyMetadata, for: surface)
                return sanitized
            }

        return KBLiteGraph(
            version: graph.version,
            lastUpdated: graph.lastUpdated,
            sessionCount: graph.sessionCount,
            people: people,
            places: places,
            events: events,
            facts: facts
        )
    }

    private static func sanitizedMetadata(
        _ metadata: MemoryPrivacyMetadata,
        for surface: MemoryUseSurface
    ) -> MemoryPrivacyMetadata {
        guard shouldRedactSourceRefTitles(for: surface) else { return metadata }
        let sourceRefs = metadata.sourceRefs.map { sourceRef in
            MemorySourceRef(
                kind: sourceRef.kind,
                id: sourceRef.id,
                title: externalSourceTitle(for: sourceRef.kind),
                capturedAt: sourceRef.capturedAt
            )
        }
        return MemoryPrivacyMetadata(
            scope: metadata.scope,
            sourceRefs: sourceRefs,
            createdBySurface: metadata.createdBySurface,
            createdAt: metadata.createdAt,
            familyVisibility: metadata.familyVisibility
        )
    }

    private static func shouldRedactSourceRefTitles(for surface: MemoryUseSurface) -> Bool {
        switch surface {
        case .backendSync, .familySync, .export, .widget:
            return true
        case .remoteExtraction,
             .prompt,
             .memoirGeneration,
             .timeMailboxEcho,
             .careDashboard:
            return false
        }
    }

    private static func externalSourceTitle(for kind: MemorySourceKind) -> String {
        switch kind {
        case .conversationTurn:
            return "对话来源"
        case .memoryArchiveItem:
            return "档案素材"
        case .timeMailboxLetter:
            return "时空信件"
        case .kbLiteEntity:
            return "知识条目"
        case .memoir:
            return "回忆录"
        case .importRecord:
            return "导入记录"
        case .userAuthorization:
            return "授权记录"
        case .unknown:
            return "来源记录"
        }
    }

    private static func highestAvailableScope(in turns: [ConversationTurn]) -> MemoryPrivacyScope? {
        let scopes = Set(turns.map { $0.privacyMetadata.scope })
        guard scopes.count == 1, let scope = scopes.first, scope != .privateOnly else {
            return .localOnly
        }
        return scope
    }
}
