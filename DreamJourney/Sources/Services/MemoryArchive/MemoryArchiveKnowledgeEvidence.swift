import Foundation

struct MemoryArchiveKnowledgeEvidence {
    let people: [String]
    let places: [String]
    let events: [String]
    let facts: [String]

    var totalCount: Int {
        people.count + places.count + events.count + facts.count
    }

    var summaryText: String {
        "\(people.count) 人 · \(places.count) 地 · \(events.count) 事 · \(facts.count) 实"
    }
}

enum MemoryArchiveKnowledgeEvidenceBuilder {
    static func build(for item: MemoryArchiveItem, in graph: KBLiteGraph) -> MemoryArchiveKnowledgeEvidence {
        MemoryArchiveKnowledgeEvidence(
            people: graph.people
                .filter { matchesSourceRef($0.privacyMetadata, item: item) }
                .map { $0.name }
                .sorted(),
            places: graph.places
                .filter { matchesSourceRef($0.privacyMetadata, item: item) }
                .map { $0.name }
                .sorted(),
            events: graph.events
                .filter { matchesSourceRef($0.privacyMetadata, item: item) }
                .map { $0.title }
                .sorted(),
            facts: graph.facts
                .filter { matchesSourceRef($0.privacyMetadata, item: item) }
                .map { $0.statement }
                .sorted()
        )
    }

    private static func matchesSourceRef(_ metadata: MemoryPrivacyMetadata, item: MemoryArchiveItem) -> Bool {
        metadata.sourceRefs.contains { sourceRef in
            sourceRef.kind == .memoryArchiveItem && sourceRef.id == item.id
        }
    }
}
