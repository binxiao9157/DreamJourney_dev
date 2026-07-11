import Foundation

@main
enum KnowledgeWidgetPrivacyPolicyModelSmoke {
    static func main() throws {
        try verifyLegacyMetadataDefaultsToDeny()
        verifyAllowlistMatrix()
        try verifySnapshotMinimizesAndDeidentifiesData()
        print("Knowledge widget privacy policy model smoke passed")
    }

    private static func verifyLegacyMetadataDefaultsToDeny() throws {
        let legacy = #"{"scope":"generationAllowed","sourceRefs":[]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KBPrivacyMetadata.self, from: legacy)
        require(decoded.widgetVisibility == nil, "legacy metadata must decode with Widget visibility denied")

        let event = makeEvent(privacyMetadata: decoded)
        require(
            KnowledgeWidgetPrivacyPolicy.summary(for: event, ownerUserId: "owner-A") == nil,
            "legacy generation permission must not imply Widget disclosure"
        )
    }

    private static func verifyAllowlistMatrix() {
        let allowed = makeEvent(
            privacyMetadata: KBPrivacyMetadata(
                scope: "generationAllowed",
                sourceRefs: [KBSourceReference(kind: "conversationTurn", id: "private-source", title: "来源")],
                widgetVisibility: "summaryAllowed"
            )
        )
        require(
            KnowledgeWidgetPrivacyPolicy.summary(for: allowed, ownerUserId: "owner-A") != nil,
            "an explicitly allowed confirmed personal owner event must be projected"
        )

        let denied: [KBEvent] = [
            makeEvent(privacyMetadata: nil),
            makeEvent(privacyMetadata: KBPrivacyMetadata(scope: "generationAllowed", sourceRefs: [])),
            makeEvent(privacyMetadata: KBPrivacyMetadata(scope: "localOnly", sourceRefs: [], widgetVisibility: "summaryAllowed")),
            makeEvent(ownerUserId: "owner-B", privacyMetadata: allowed.privacyMetadata),
            makeEvent(personaScope: "family", privacyMetadata: allowed.privacyMetadata),
            makeEvent(evidenceStatus: "observed", privacyMetadata: allowed.privacyMetadata),
            makeEvent(title: " \n\t ", privacyMetadata: allowed.privacyMetadata),
        ]
        for event in denied {
            require(
                KnowledgeWidgetPrivacyPolicy.summary(for: event, ownerUserId: "owner-A") == nil,
                "each missing or mismatched allowlist dimension must fail closed"
            )
        }
    }

    private static func verifySnapshotMinimizesAndDeidentifiesData() throws {
        let longTitle = String(repeating: "回", count: 120) + "  \n  忆"
        let allowed = makeEvent(
            id: "raw-event-id",
            title: longTitle,
            privacyMetadata: KBPrivacyMetadata(
                scope: "generationAllowed",
                sourceRefs: [KBSourceReference(kind: "conversationTurn", id: "raw-source-id", title: "来源")],
                widgetVisibility: "summaryAllowed"
            )
        )
        let denied = makeEvent(id: "denied-event-id", privacyMetadata: nil)
        var graph = KBLiteGraph()
        graph.events = [allowed, denied]

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        guard let snapshot = KnowledgeWidgetPrivacyPolicy.snapshot(
            graph: graph,
            ownerUserId: "owner-A",
            generatedAt: now
        ) else {
            fail("valid owner must produce a snapshot")
        }
        require(snapshot.schemaVersion == 2, "Widget snapshot schema must be v2")
        require(snapshot.events.count == 1, "only explicitly allowed events may be exported")
        require(snapshot.events[0].title.count <= 80, "Widget title must be bounded")
        require(snapshot.events[0].idDigest != "raw-event-id", "event IDs must be deidentified")
        require(snapshot.ownerDigest != "owner-A", "owner ID must be deidentified")
        require(
            snapshot.ownerDigest == KnowledgeWidgetPrivacyPolicy.ownerDigest(for: "owner-A"),
            "owner digest must be stable"
        )
        require(
            KnowledgeWidgetPrivacyPolicy.snapshot(graph: graph, ownerUserId: "  ", generatedAt: now) == nil,
            "empty owners must not produce a snapshot"
        )

        let data = try JSONEncoder().encode(snapshot)
        let json = String(decoding: data, as: UTF8.self)
        for forbidden in ["owner-A", "raw-event-id", "denied-event-id", "raw-source-id", "description", "sourceRefs"] {
            require(!json.contains(forbidden), "snapshot JSON must not contain \(forbidden)")
        }
    }

    private static func makeEvent(
        id: String = "event-A",
        title: String = "  春节   团聚  ",
        ownerUserId: String = "owner-A",
        personaScope: String = "personal",
        evidenceStatus: String = "confirmed",
        privacyMetadata: KBPrivacyMetadata?
    ) -> KBEvent {
        KBEvent(
            id: id,
            title: title,
            description: "不得进入 Widget 的正文",
            year: 1998,
            month: 2,
            privacyMetadata: privacyMetadata,
            ownerUserId: ownerUserId,
            personaScope: personaScope,
            evidenceStatus: evidenceStatus
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Knowledge widget privacy policy model smoke failed: \(message)\n", stderr)
        exit(1)
    }
}
