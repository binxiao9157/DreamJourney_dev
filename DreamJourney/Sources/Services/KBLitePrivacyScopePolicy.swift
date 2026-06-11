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
        return MemoryPrivacyMetadata(scope: scope)
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

    static func sanitizedGraph(_ graph: KBLiteGraph, for surface: MemoryUseSurface) -> KBLiteGraph {
        let retainedPeople = graph.people.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }
        let retainedPlaces = graph.places.filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }

        let peopleIDs = Set(retainedPeople.map(\.id))
        let placeIDs = Set(retainedPlaces.map(\.id))

        let people = retainedPeople.map { person -> KBPerson in
            var sanitized = person
            sanitized.relatedPersonIds = person.relatedPersonIds.filter { peopleIDs.contains($0) }
            return sanitized
        }

        let places = retainedPlaces.map { place -> KBPlace in
            var sanitized = place
            sanitized.relatedPersonIds = place.relatedPersonIds.filter { peopleIDs.contains($0) }
            return sanitized
        }

        let events = graph.events
            .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }
            .map { event -> KBEvent in
                var sanitized = event
                sanitized.participantIds = event.participantIds.filter { peopleIDs.contains($0) }
                if let locationId = event.locationId, !placeIDs.contains(locationId) {
                    sanitized.locationId = nil
                }
                return sanitized
            }

        let eventIDs = Set(events.map(\.id))

        let facts = graph.facts
            .filter { PrivacyScopePolicy.canUse(metadata: $0.privacyMetadata, surface: surface) }
            .map { fact -> KBFact in
                var sanitized = fact
                sanitized.relatedPersonIds = fact.relatedPersonIds.filter { peopleIDs.contains($0) }
                sanitized.relatedPlaceIds = fact.relatedPlaceIds.filter { placeIDs.contains($0) }
                sanitized.relatedEventIds = fact.relatedEventIds.filter { eventIDs.contains($0) }
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

    private static func highestAvailableScope(in turns: [ConversationTurn]) -> MemoryPrivacyScope? {
        let scopes = Set(turns.map { $0.privacyMetadata.scope })
        guard scopes.count == 1, let scope = scopes.first, scope != .privateOnly else {
            return .localOnly
        }
        return scope
    }
}
