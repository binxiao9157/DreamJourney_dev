import Foundation

@main
enum KnowledgeThreeWayMergeModelSmoke {
    private static let authorization = KnowledgeSyncAuthorizationScope(
        identity: KBPersonaIdentity(
            ownerUserId: "owner-A",
            personaScope: "personal",
            digitalHumanId: "owner-A"
        )
    )

    static func main() throws {
        try verifyFirstUpgradeBootstrap()
        try verifyOneSidedAndConflictingChanges()
        try verifyOneSidedDeletions()
        try verifyConflictingDeletionAndEdit()
        try verifyTombstonesAndPrivateProtection()
        try verifyPerUserBaseAndPendingIsolation()
        try verifyOwnerAndPersonaAuthorizationBoundary()
        try verifyAccountPersonaAuthorizationPreventsCrossPersonaTombstones()
        verifyV2ResponseAndFallbackContracts()
        print("Knowledge three-way merge model smoke passed")
    }

    private static func verifyFirstUpgradeBootstrap() throws {
        let local = graph(
            people: [entity(id: "local-person", value: "local")],
            facts: [entity(id: "shared", value: "local-version")]
        )
        let remote = graph(
            places: [entity(id: "remote-place", value: "remote")],
            facts: [entity(id: "shared", value: "remote-version")]
        )

        let result = try KnowledgeSyncGraphEngine.bootstrap(
            local: local,
            remote: remote,
            authorization: authorization
        )
        require(ids(in: result.graph, type: "people") == ["local-person"], "bootstrap must retain local entities")
        require(ids(in: result.graph, type: "places") == ["remote-place"], "bootstrap must absorb remote entities")
        require(value(in: result.graph, type: "facts", id: "shared") == "local-version", "bootstrap must prefer local on same ID")
        require(result.conflicts.isEmpty, "bootstrap must not report a false historical conflict")
    }

    private static func verifyOneSidedAndConflictingChanges() throws {
        let base = graph(
            people: [entity(id: "local-change", value: "base")],
            places: [entity(id: "remote-change", value: "base")],
            events: [entity(id: "conflict", value: "base")]
        )
        let local = graph(
            people: [entity(id: "local-change", value: "local")],
            places: [entity(id: "remote-change", value: "base")],
            events: [entity(id: "conflict", value: "local-secret-text")]
        )
        let remote = graph(
            people: [entity(id: "local-change", value: "base")],
            places: [entity(id: "remote-change", value: "remote")],
            events: [entity(id: "conflict", value: "remote-secret-text")]
        )

        let result = try KnowledgeSyncGraphEngine.merge(
            base: base,
            local: local,
            remote: remote,
            authorization: authorization
        )
        require(value(in: result.graph, type: "people", id: "local-change") == "local", "local-only change must survive")
        require(value(in: result.graph, type: "places", id: "remote-change") == "remote", "remote-only change must be adopted")
        require(value(in: result.graph, type: "events", id: "conflict") == "local-secret-text", "two-sided conflict must be local-wins")
        require(result.conflicts == [KnowledgeSyncConflict(entityType: "events", entityId: "conflict")], "conflict summary must contain type and ID only")
        require(!result.qaConflictSummary.contains("secret-text"), "QA conflict summary must not contain entity content")
    }

    private static func verifyTombstonesAndPrivateProtection() throws {
        let base = graph(
            people: [entity(id: "deleted-person", value: "base")],
            facts: [entity(id: "private-collision", value: "remote-base")]
        )
        let privateEntity = entity(id: "private-collision", value: "private-local", scope: "localOnly")
        let legacyPrivate = entity(id: "legacy-private", value: "legacy", scope: nil)
        let local = graph(facts: [privateEntity, legacyPrivate])
        let deletedAt = "2026-07-11T01:02:03Z"

        let delta = try KnowledgeSyncGraphEngine.makeDelta(
            base: base,
            local: local,
            deletedAt: deletedAt,
            authorization: authorization
        )
        require(delta.upserts.values.flatMap { $0 }.isEmpty, "private entities must never be uploaded")
        require(delta.tombstones.count == 1, "only the actually removed syncable entity should become a tombstone")
        require(delta.tombstones.first?.entityType == "people", "tombstone must retain entity type")
        require(delta.tombstones.first?.entityId == "deleted-person", "tombstone must retain entity ID")
        require(delta.tombstones.first?.deletedAt == deletedAt, "tombstone timestamp must be stable")

        let merge = try KnowledgeSyncGraphEngine.merge(
            base: base,
            local: local,
            remote: graph(),
            authorization: authorization
        )
        require(value(in: merge.graph, type: "facts", id: "private-collision") == "private-local", "remote deletion must not delete localOnly data")
        require(value(in: merge.graph, type: "facts", id: "legacy-private") == "legacy", "remote deletion must not delete legacy data without metadata")
    }

    private static func verifyOneSidedDeletions() throws {
        let base = graph(people: [
            entity(id: "remote-delete", value: "base"),
            entity(id: "local-delete", value: "base"),
        ])
        let local = graph(people: [entity(id: "remote-delete", value: "base")])
        let remote = graph(people: [entity(id: "local-delete", value: "base")])

        let result = try KnowledgeSyncGraphEngine.merge(
            base: base,
            local: local,
            remote: remote,
            authorization: authorization
        )
        require(ids(in: result.graph, type: "people").isEmpty, "one-sided local and remote deletions must both be retained")
        require(result.conflicts.isEmpty, "one-sided deletions must not be reported as conflicts")
    }

    private static func verifyConflictingDeletionAndEdit() throws {
        let base = graph(facts: [
            entity(id: "local-edit", value: "base"),
            entity(id: "local-delete", value: "base"),
        ])
        let local = graph(facts: [entity(id: "local-edit", value: "edited locally")])
        let remote = graph(facts: [entity(id: "local-delete", value: "edited remotely")])

        let result = try KnowledgeSyncGraphEngine.merge(
            base: base,
            local: local,
            remote: remote,
            authorization: authorization
        )
        require(
            value(in: result.graph, type: "facts", id: "local-edit") == "edited locally",
            "a local edit must win when the remote side deleted the same entity"
        )
        require(
            value(in: result.graph, type: "facts", id: "local-delete") == nil,
            "a local deletion must win when the remote side edited the same entity"
        )
        require(
            result.conflicts == [
                KnowledgeSyncConflict(entityType: "facts", entityId: "local-delete"),
                KnowledgeSyncConflict(entityType: "facts", entityId: "local-edit"),
            ],
            "edit/delete conflicts must remain visible in QA evidence"
        )
        require(!result.qaConflictSummary.contains("edited"), "conflict evidence must not contain knowledge text")
    }

    private static func verifyPerUserBaseAndPendingIsolation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("knowledge-three-way-smoke-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let baseStore = KnowledgeRemoteBaseStore(rootDirectory: root)
        try baseStore.save(
            KnowledgeRemoteBaseSnapshot(revision: 3, graph: graph(people: [entity(id: "alice", value: "a")])),
            for: "user/a"
        )
        try baseStore.save(
            KnowledgeRemoteBaseSnapshot(revision: 7, graph: graph(people: [entity(id: "bob", value: "b")])),
            for: "user/a?other"
        )
        let firstBase = try requireValue(baseStore.load(for: "user/a"))
        let secondBase = try requireValue(baseStore.load(for: "user/a?other"))
        require(firstBase.revision == 3, "first user base must remain isolated")
        require(secondBase.revision == 7, "second user base must remain isolated")
        require(ids(in: firstBase.graph, type: "people") == ["alice"], "base store must return the correct user's graph")

        let pendingStore = KnowledgePendingMutationStore(rootDirectory: root)
        let pending = KnowledgePendingMutation(
            operationId: "operation-stable",
            baseRevision: 3,
            localFingerprint: "fingerprint-stable",
            deletedAt: "2026-07-11T01:02:03Z",
            payload: ["mutationSchemaVersion": 2, "upserts": emptyUpserts(), "tombstones": []]
        )
        try pendingStore.save(pending, for: "user/a")
        let restored = try requireValue(pendingStore.load(for: "user/a"))
        require(restored.operationId == pending.operationId, "pending retry must reuse operation ID")
        require(restored.deletedAt == pending.deletedAt, "pending retry must reuse deletion timestamp")
        let restoredUpserts = restored.payload["upserts"] as? [String: Any]
        require(restoredUpserts?["people"] as? [[String: Any]] != nil, "pending payload must remain callable after JSON restoration")
        let otherPending = try pendingStore.load(for: "user/a?other")
        require(otherPending == nil, "pending mutation must be user-isolated")
    }

    private static func verifyOwnerAndPersonaAuthorizationBoundary() throws {
        let exact = entity(id: "exact", value: "allowed")
        let wrongOwner = entity(id: "wrong-owner", value: "denied", ownerUserId: "owner-B")
        let ownerless = entity(id: "ownerless", value: "local-only", ownerUserId: nil)
        let family = entity(
            id: "family",
            value: "family-only",
            personaScope: "family",
            digitalHumanId: "family-A"
        )
        let local = graph(facts: [exact, wrongOwner, ownerless, family])

        let payload = try KnowledgeSyncGraphEngine.syncPayloadGraph(
            from: local,
            authorization: authorization
        )
        require(
            ids(in: payload, type: "facts") == ["exact"],
            "personal sync payload must require exact owner/persona/digital-human identity"
        )

        let merged = try KnowledgeSyncGraphEngine.bootstrap(
            local: graph(facts: [ownerless]),
            remote: graph(facts: [exact, wrongOwner, family]),
            authorization: authorization
        )
        require(
            ids(in: merged.graph, type: "facts") == ["exact", "ownerless"],
            "remote unauthorized entities must be filtered while local legacy remains local"
        )

        let familyAuthorization = KnowledgeSyncAuthorizationScope(
            identity: KBPersonaIdentity(
                ownerUserId: "owner-A",
                personaScope: "family",
                digitalHumanId: "family-A"
            )
        )
        let familyPayload = try KnowledgeSyncGraphEngine.syncPayloadGraph(
            from: graph(facts: [family, exact]),
            authorization: familyAuthorization
        )
        require(
            ids(in: familyPayload, type: "facts") == ["family"],
            "family sync must require exact family digital-human identity"
        )
    }

    private static func verifyAccountPersonaAuthorizationPreventsCrossPersonaTombstones() throws {
        let familyIdentity = KBPersonaIdentity(
            ownerUserId: "owner-A",
            personaScope: "family",
            digitalHumanId: "family-A"
        )
        let accountAuthorization = KnowledgeSyncAuthorizationScope(
            identity: KBPersonaIdentity(
                ownerUserId: "owner-A",
                personaScope: "personal",
                digitalHumanId: "owner-A"
            ),
            additionalIdentities: [familyIdentity]
        )
        let personal = entity(id: "personal", value: "personal")
        let family = entity(
            id: "family",
            value: "family",
            personaScope: "family",
            digitalHumanId: "family-A"
        )
        let unauthorizedFamily = entity(
            id: "other-family",
            value: "denied",
            personaScope: "family",
            digitalHumanId: "family-B"
        )

        let bootstrap = try KnowledgeSyncGraphEngine.bootstrap(
            local: graph(),
            remote: graph(facts: [personal, family, unauthorizedFamily]),
            authorization: accountAuthorization
        )
        require(
            ids(in: bootstrap.graph, type: "facts") == ["family", "personal"],
            "account sync must retain every authorized persona and reject unaccepted family personas"
        )

        let delta = try KnowledgeSyncGraphEngine.makeDelta(
            base: graph(facts: [personal, family]),
            local: bootstrap.graph,
            deletedAt: "2026-07-11T01:02:03Z",
            authorization: accountAuthorization
        )
        require(delta.tombstones.isEmpty, "persona switching must not tombstone another authorized persona")
        require(delta.upserts.values.flatMap { $0 }.isEmpty, "unchanged authorized personas must not be re-uploaded")
    }

    private static func verifyV2ResponseAndFallbackContracts() {
        let mutation: [String: Any] = ["upserts": emptyUpserts(), "tombstones": []]
        let response: [String: Any] = [
            "revision": 9,
            "graph": graph(),
            "mutationSchemaVersion": 2,
            "mutation": mutation,
        ]
        require(KnowledgeMutationV2Contract.authoritativeSnapshot(from: response)?.revision == 9, "v2 response metadata must be recognized")

        let feed: [String: Any] = [
            "currentRevision": 10,
            "changes": [[
                "revision": 10,
                "graph": graph(facts: [entity(id: "feed", value: "ok")]),
                "mutationSchemaVersion": 2,
                "mutation": mutation,
            ]],
        ]
        require(KnowledgeMutationV2Contract.latestAuthoritativeSnapshot(fromChangeFeed: feed)?.revision == 10, "v2 change metadata must be recognized")
        require(KnowledgeMutationV2Contract.latestAuthoritativeSnapshot(fromChangeFeed: ["currentRevision": 10, "changes": []]) == nil, "malformed feed must not advance revision")

        require(KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 404, detail: "not found"), "404 must fall back to v1")
        require(KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 405, detail: "method"), "405 must fall back to v1")
        require(KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 400, detail: "mutationSchemaVersion is not allowed"), "old schema rejection must fall back to v1")
        require(KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 400, detail: "graph field required"), "old graph-required contract must fall back to v1")
        require(KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 400, detail: "graph must be an object"), "old graph-object contract must fall back to v1")
        require(!KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 400, detail: "tombstone entityId is invalid"), "valid v2 validation errors must not silently fall back")
        require(!KnowledgeMutationV2FallbackPolicy.shouldFallback(statusCode: 500, detail: "server failure"), "provider failures must not silently fall back")
    }

    private static func graph(
        people: [[String: Any]] = [],
        places: [[String: Any]] = [],
        events: [[String: Any]] = [],
        facts: [[String: Any]] = []
    ) -> [String: Any] {
        [
            "version": 1,
            "lastUpdated": "2026-07-11T00:00:00Z",
            "sessionCount": 1,
            "people": people,
            "places": places,
            "events": events,
            "facts": facts,
        ]
    }

    private static func entity(
        id: String,
        value: String,
        scope: String? = "generationAllowed",
        ownerUserId: String? = "owner-A",
        personaScope: String = "personal",
        digitalHumanId: String = "owner-A"
    ) -> [String: Any] {
        var object: [String: Any] = ["id": id, "value": value]
        if let ownerUserId { object["ownerUserId"] = ownerUserId }
        object["personaScope"] = personaScope
        object["digitalHumanId"] = digitalHumanId
        if let scope {
            object["privacyMetadata"] = ["scope": scope, "sourceRefs": []]
        }
        return object
    }

    private static func emptyUpserts() -> [String: [[String: Any]]] {
        ["people": [], "places": [], "events": [], "facts": []]
    }

    private static func ids(in graph: [String: Any], type: String) -> [String] {
        ((graph[type] as? [[String: Any]]) ?? [])
            .compactMap { $0["id"] as? String }
            .sorted()
    }

    private static func value(in graph: [String: Any], type: String, id: String) -> String? {
        ((graph[type] as? [[String: Any]]) ?? [])
            .first { ($0["id"] as? String) == id }?["value"] as? String
    }

    private static func requireValue<T>(_ value: T?, _ message: String = "expected value") throws -> T {
        guard let value else { throw SmokeError.failure(message) }
        return value
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("Knowledge three-way merge model smoke failed: \(message)\n", stderr)
            exit(1)
        }
    }
}

private enum SmokeError: Error {
    case failure(String)
}
