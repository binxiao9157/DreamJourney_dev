import Foundation

@main
enum KnowledgeWidgetSnapshotReaderModelSmoke {
    static func main() throws {
        let ownerDigest = String(repeating: "a", count: 64)
        let snapshot = WidgetKnowledgeSnapshot(
            schemaVersion: 2,
            ownerDigest: ownerDigest,
            generatedAt: Date(timeIntervalSince1970: 1_750_000_000),
            events: [
                WidgetKnowledgeEventSummary(
                    idDigest: String(repeating: "b", count: 64),
                    title: "允许的记忆摘要",
                    year: 1999,
                    month: 7
                )
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        require(
            WidgetKnowledgeSnapshotReader.acceptedEvents(from: data, activeOwnerDigest: ownerDigest).count == 1,
            "matching v2 owner must be accepted"
        )
        require(WidgetKnowledgeSnapshotReader.acceptedEvents(from: data, activeOwnerDigest: nil).isEmpty, "missing active owner must fail closed")
        require(WidgetKnowledgeSnapshotReader.acceptedEvents(from: data, activeOwnerDigest: "").isEmpty, "empty active owner must fail closed")
        require(
            WidgetKnowledgeSnapshotReader.acceptedEvents(from: data, activeOwnerDigest: String(repeating: "c", count: 64)).isEmpty,
            "owner mismatch must fail closed"
        )

        let oldSchema = WidgetKnowledgeSnapshot(
            schemaVersion: 1,
            ownerDigest: ownerDigest,
            generatedAt: snapshot.generatedAt,
            events: snapshot.events
        )
        let oldData = try encoder.encode(oldSchema)
        require(
            WidgetKnowledgeSnapshotReader.acceptedEvents(from: oldData, activeOwnerDigest: ownerDigest).isEmpty,
            "old schema must fail closed"
        )
        require(
            WidgetKnowledgeSnapshotReader.acceptedEvents(from: Data("not-json".utf8), activeOwnerDigest: ownerDigest).isEmpty,
            "corrupt JSON must fail closed"
        )

        let invalidEvent = WidgetKnowledgeSnapshot(
            schemaVersion: 2,
            ownerDigest: ownerDigest,
            generatedAt: snapshot.generatedAt,
            events: [
                WidgetKnowledgeEventSummary(
                    idDigest: "raw-event-id",
                    title: String(repeating: "x", count: 81),
                    year: 1999,
                    month: 13
                )
            ]
        )
        let invalidData = try encoder.encode(invalidEvent)
        require(
            WidgetKnowledgeSnapshotReader.acceptedEvents(
                from: invalidData,
                activeOwnerDigest: ownerDigest
            ).isEmpty,
            "invalid summary fields must reject the whole snapshot"
        )

        print("Knowledge widget snapshot reader model smoke passed")
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Knowledge widget snapshot reader model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
