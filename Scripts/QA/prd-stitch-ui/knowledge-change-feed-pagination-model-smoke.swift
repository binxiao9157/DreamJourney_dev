import Foundation

@main
enum KnowledgeChangeFeedPaginationModelSmoke {
    static func main() throws {
        try verifyStrictSnapshotResponse()
        verifyCompactedRecoveryClassification()
        try verifyThreePageReduction()
        try verifyLegacyTerminalPage()
        verifyMalformedPages()
        verifyCASPolicy()
        print("Knowledge change feed pagination model smoke passed")
    }

    private static func verifyStrictSnapshotResponse() throws {
        let response = try KnowledgeSnapshotResponse(
            json: snapshotJSON(),
            expectedUserId: "user-a"
        )
        require(response.userId == "user-a", "snapshot must preserve the requested user")
        require(response.revision == 8, "snapshot must preserve its non-negative revision")
        require(response.graph["marker"] as? Int == 8, "snapshot must preserve its graph")
        require(response.updatedAt == "2026-07-11T08:30:00.123Z", "snapshot must preserve updatedAt")

        var legacyPartialGraph = snapshotJSON()
        legacyPartialGraph["graph"] = ["facts": [], "marker": 8]
        _ = try KnowledgeSnapshotResponse(
            json: legacyPartialGraph,
            expectedUserId: "user-a"
        )

        requireThrows("snapshot user mismatch must be rejected") {
            _ = try KnowledgeSnapshotResponse(json: snapshotJSON(), expectedUserId: "user-b")
        }
        requireThrows("snapshot revision strings must be rejected") {
            var json = snapshotJSON()
            json["revision"] = "8"
            _ = try KnowledgeSnapshotResponse(json: json, expectedUserId: "user-a")
        }
        requireThrows("snapshot negative revisions must be rejected") {
            var json = snapshotJSON()
            json["revision"] = -1
            _ = try KnowledgeSnapshotResponse(json: json, expectedUserId: "user-a")
        }
        requireThrows("snapshot graph must be an object") {
            var json = snapshotJSON()
            json["graph"] = []
            _ = try KnowledgeSnapshotResponse(json: json, expectedUserId: "user-a")
        }
        requireThrows("snapshot updatedAt must be present and ISO-8601") {
            var json = snapshotJSON()
            json.removeValue(forKey: "updatedAt")
            _ = try KnowledgeSnapshotResponse(json: json, expectedUserId: "user-a")
        }
        requireThrows("snapshot updatedAt must be a valid ISO-8601 timestamp") {
            var json = snapshotJSON()
            json["updatedAt"] = "yesterday"
            _ = try KnowledgeSnapshotResponse(json: json, expectedUserId: "user-a")
        }
    }

    private static func verifyCompactedRecoveryClassification() {
        require(
            KnowledgeChangeFeedRecoveryPolicy.shouldFetchSnapshot(
                statusCode: 410,
                detailCode: "knowledgeChangeFeedCompacted"
            ),
            "structured compacted 410 must request a snapshot"
        )
        let nonCompactedFailures: [(Int?, String?)] = [
            (nil, nil),
            (410, nil),
            (410, "knowledgeRevisionConflict"),
            (409, "knowledgeChangeFeedCompacted"),
            (404, "knowledgeChangeFeedCompacted"),
            (405, "knowledgeChangeFeedCompacted"),
        ]
        for candidate in nonCompactedFailures {
            require(
                !KnowledgeChangeFeedRecoveryPolicy.shouldFetchSnapshot(
                    statusCode: candidate.0,
                    detailCode: candidate.1
                ),
                "only an exact structured compacted 410 may request a snapshot"
            )
        }
    }

    private static func verifyThreePageReduction() throws {
        var reducer = KnowledgeChangeFeedReducer(startRevision: 0, maxPageCount: 4)
        let first = try page(since: 0, target: 3, revisions: [1], hasMore: true, requestedTarget: nil)
        let firstResult = try reducer.consume(first)
        require(!firstResult.isTerminal, "first page must not commit")
        require(firstResult.nextSinceRevision == 1, "first page must advance to revision 1")
        require(firstResult.authoritativeSnapshot == nil, "intermediate page must not expose a snapshot")

        let second = try page(since: 1, target: 3, revisions: [2], hasMore: true, requestedTarget: 3)
        let secondResult = try reducer.consume(second)
        require(!secondResult.isTerminal, "second page must not commit")

        let third = try page(since: 2, target: 3, revisions: [3], hasMore: false, requestedTarget: 3)
        let terminal = try reducer.consume(third)
        require(terminal.isTerminal, "third page must be terminal")
        require(terminal.authoritativeSnapshot?.revision == 3, "terminal snapshot must reach target")
        require(
            terminal.authoritativeSnapshot?.graph["marker"] as? Int == 3,
            "reducer must retain only the final authoritative graph"
        )
    }

    private static func verifyLegacyTerminalPage() throws {
        let json: [String: Any] = [
            "userId": "user-a",
            "sinceRevision": 0,
            "currentRevision": 1,
            "changes": [change(revision: 1)],
        ]
        let page = try KnowledgeChangePage(
            json: json,
            expectedUserId: "user-a",
            requestedSinceRevision: 0,
            requestedTargetRevision: nil
        )
        require(page.isLegacy, "legacy response must remain identifiable")
        var reducer = KnowledgeChangeFeedReducer(startRevision: 0)
        let result = try reducer.consume(page)
        require(result.isTerminal, "legacy response must be a single terminal page")
    }

    private static func verifyMalformedPages() {
        requireThrows("revision gaps must be rejected") {
            _ = try page(since: 0, target: 2, revisions: [2], hasMore: false, requestedTarget: nil)
        }
        requireThrows("empty non-terminal pages must be rejected") {
            _ = try page(since: 0, target: 2, revisions: [], hasMore: true, requestedTarget: nil)
        }
        requireThrows("changed target must be rejected") {
            var reducer = KnowledgeChangeFeedReducer(startRevision: 0)
            _ = try reducer.consume(
                page(since: 0, target: 2, revisions: [1], hasMore: true, requestedTarget: nil)
            )
            _ = try reducer.consume(
                page(since: 1, target: 3, revisions: [2], hasMore: true, requestedTarget: 3)
            )
        }
        requireThrows("page count must be bounded") {
            var reducer = KnowledgeChangeFeedReducer(startRevision: 0, maxPageCount: 1)
            _ = try reducer.consume(
                page(since: 0, target: 2, revisions: [1], hasMore: true, requestedTarget: nil)
            )
            _ = try reducer.consume(
                page(since: 1, target: 2, revisions: [2], hasMore: false, requestedTarget: 2)
            )
        }
    }

    private static func verifyCASPolicy() {
        require(
            KnowledgeGraphCASPolicy.canApply(
                expectedMutationToken: 7,
                currentMutationToken: 7,
                expectedUserId: "user-a",
                currentUserId: "user-a"
            ),
            "matching user and mutation token must apply"
        )
        require(
            !KnowledgeGraphCASPolicy.canApply(
                expectedMutationToken: 7,
                currentMutationToken: 8,
                expectedUserId: "user-a",
                currentUserId: "user-a"
            ),
            "local mutation must invalidate the old token"
        )
        require(
            !KnowledgeGraphCASPolicy.canApply(
                expectedMutationToken: 7,
                currentMutationToken: 7,
                expectedUserId: "user-a",
                currentUserId: "user-b"
            ),
            "user switch must invalidate the old snapshot"
        )
    }

    private static func page(
        since: Int,
        target: Int,
        revisions: [Int],
        hasMore: Bool,
        requestedTarget: Int?
    ) throws -> KnowledgeChangePage {
        let next = revisions.last ?? since
        return try KnowledgeChangePage(
            json: [
                "userId": "user-a",
                "sinceRevision": since,
                "currentRevision": target,
                "targetRevision": target,
                "nextSinceRevision": next,
                "hasMore": hasMore,
                "pageLimit": 1,
                "changes": revisions.map(change),
            ],
            expectedUserId: "user-a",
            requestedSinceRevision: since,
            requestedTargetRevision: requestedTarget
        )
    }

    private static func change(revision: Int) -> [String: Any] {
        [
            "revision": revision,
            "operationId": "operation-\(revision)",
            "graph": [
                "version": 1,
                "lastUpdated": "2026-07-11T00:00:00Z",
                "sessionCount": 0,
                "people": [],
                "places": [],
                "events": [],
                "facts": [],
                "marker": revision,
            ],
            "mutationSchemaVersion": 1,
        ]
    }

    private static func snapshotJSON() -> [String: Any] {
        [
            "userId": "user-a",
            "graph": [
                "version": 1,
                "lastUpdated": "2026-07-11T08:30:00Z",
                "sessionCount": 0,
                "people": [],
                "places": [],
                "events": [],
                "facts": [],
                "marker": 8,
            ],
            "revision": 8,
            "updatedAt": "2026-07-11T08:30:00.123Z",
        ]
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fail(message) }
    }

    private static func requireThrows(_ message: String, _ body: () throws -> Void) {
        do {
            try body()
            fail(message)
        } catch {
            return
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("knowledge-change-feed-pagination-model-smoke failed: \(message)\n", stderr)
        exit(1)
    }
}
