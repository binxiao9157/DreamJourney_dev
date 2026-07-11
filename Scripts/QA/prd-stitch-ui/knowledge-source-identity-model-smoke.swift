import Foundation

@main
enum KnowledgeSourceIdentityModelSmoke {
    static func main() {
        verifyConversationTurnReferences()
        verifyConversationPhotoReference()
        verifyAuditClassification()
        verifyBackendAuditContract()
        print("Knowledge source identity model smoke passed")
    }

    private static func verifyConversationTurnReferences() {
        let refs = KBKnowledgeSourceIdentityPolicy.conversationTurnReferences(
            sessionId: 42,
            turnIndices: [2, 0, 2, -1]
        )
        require(
            refs.map { "\($0.kind)|\($0.id)" } == [
                "conversationTurn|session-42:turn-2",
                "conversationTurn|session-42:turn-0",
            ],
            "turn refs must be canonical, stable and deduplicated"
        )
        require(
            KBKnowledgeSourceIdentityPolicy.conversationTurnReferences(
                sessionId: -1,
                turnIndices: [0]
            ).isEmpty,
            "invalid sessions must not produce refs"
        )
    }

    private static func verifyConversationPhotoReference() {
        let valid = KBKnowledgeSourceIdentityPolicy.conversationPhotoReference(
            assetId: "A3B82D72-8BE4-49FB-8293-40C1A61C607F"
        )
        require(valid?.kind == "conversationPhoto", "photo kind must be canonical")
        require(
            valid?.id == "photo-a3b82d72-8be4-49fb-8293-40c1a61c607f",
            "photo ID must be stable and normalized"
        )
        require(
            KBKnowledgeSourceIdentityPolicy.conversationPhotoReference(
                assetId: "/private/var/mobile/photo.jpg"
            ) == nil,
            "absolute paths must never become source IDs"
        )
    }

    private static func verifyAuditClassification() {
        let counts = KBKnowledgeSourceIdentityPolicy.audit(
            sourceReferences: [
                KBSourceReference(kind: "conversationTurn", id: "turn-1", title: "raw"),
                KBSourceReference(kind: "memoir", id: "memoir-1", title: "raw"),
                KBSourceReference(kind: "conversationSession", id: "session-1", title: "raw"),
                KBSourceReference(kind: "archiveImageAnalysis", id: "session-2", title: "raw"),
                KBSourceReference(kind: "futureKind", id: "future-1", title: "raw"),
            ]
        )
        require(counts.total == 5, "audit must count every ref")
        require(counts.canonical == 2, "known product sources must be canonical")
        require(counts.legacy == 2, "old ambiguous refs must remain legacy")
        require(counts.unknown == 1, "future refs must remain visible as unknown")
        require(counts.recommendedAction == .reviewUnknownSourceRefs,
                "unknown refs must win over migration planning")
    }

    private static func verifyBackendAuditContract() {
        let json: [String: Any] = [
            "schemaVersion": 1,
            "userId": "user-a",
            "revision": 7,
            "counts": [
                "entities": [
                    "total": 4,
                    "withSourceRefs": 3,
                    "withCanonicalRefs": 2,
                    "withLegacyRefs": 1,
                    "withUnknownRefs": 0,
                ],
                "sourceRefs": [
                    "total": 3,
                    "canonical": 2,
                    "legacy": 1,
                    "unknown": 0,
                ],
            ],
            "recommendedAction": "planLegacySourceRefMigration",
        ]
        let response = KBKnowledgeSourceRefAuditResponse(json: json, expectedUserId: "user-a")
        require(response?.revision == 7, "typed audit must retain revision")
        require(response?.sourceRefCounts.legacy == 1, "typed audit must retain legacy count")
        require(
            response?.recommendedAction == .planLegacySourceRefMigration,
            "typed audit must validate the recommended action"
        )

        var inconsistent = json
        inconsistent["recommendedAction"] = "none"
        require(
            KBKnowledgeSourceRefAuditResponse(
                json: inconsistent,
                expectedUserId: "user-a"
            ) == nil,
            "typed audit must reject an action that contradicts counts"
        )
        require(
            KBKnowledgeSourceRefAuditResponse(
                json: json,
                expectedUserId: "user-b"
            ) == nil,
            "typed audit must reject cross-user payloads"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("knowledge-source-identity-model-smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}
