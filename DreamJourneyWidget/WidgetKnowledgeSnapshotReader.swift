import Foundation

enum WidgetKnowledgeSnapshotReader {
    static let currentSchemaVersion = 2
    static let snapshotFileName = "kb_widget_snapshot_v2.json"
    static let activeOwnerDigestKey = "DreamJourneyKnowledgeWidgetActiveOwnerDigestV2"

    static func acceptedEvents(
        from data: Data,
        activeOwnerDigest: String?
    ) -> [WidgetKnowledgeEventSummary] {
        guard let activeOwnerDigest,
              isDigest(activeOwnerDigest) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(WidgetKnowledgeSnapshot.self, from: data),
              snapshot.schemaVersion == currentSchemaVersion,
              snapshot.ownerDigest == activeOwnerDigest,
              isDigest(snapshot.ownerDigest),
              snapshot.events.allSatisfy(isValidSummary) else {
            return []
        }
        return snapshot.events
    }

    private static func isValidSummary(_ event: WidgetKnowledgeEventSummary) -> Bool {
        let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDigest(event.idDigest),
              !title.isEmpty,
              title.count <= 80 else {
            return false
        }
        if let month = event.month, !(1...12).contains(month) {
            return false
        }
        return true
    }

    private static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }
}
