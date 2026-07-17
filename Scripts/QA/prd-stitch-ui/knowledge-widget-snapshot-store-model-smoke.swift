import Foundation

@main
enum KnowledgeWidgetSnapshotStoreModelSmoke {
    private final class Counter {
        var value = 0
    }

    private final class LeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
        var currentLease: AccountLease?
        var isValid = true

        func capture(forSubjectId subjectId: String?) -> AccountLease? {
            guard let currentLease,
                  subjectId == nil || subjectId == currentLease.subjectId else {
                return nil
            }
            return currentLease
        }

        func validate(
            _ lease: AccountLease,
            at checkpoint: AccountLeaseCheckpoint
        ) -> AccountLeaseValidationDecision {
            let allowed = isValid && lease == currentLease
            return AccountLeaseValidationDecision(
                checkpoint: checkpoint,
                allowed: allowed,
                reason: allowed ? .allowed : .authorityEpochMismatch,
                sessionRotated: false
            )
        }
    }

    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("knowledge-widget-store-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let suiteName = "knowledge-widget-store-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fail("isolated defaults must be available")
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let reloads = Counter()
        let leaseRuntime = LeaseRuntime()
        leaseRuntime.currentLease = lease(subjectId: "owner-A", generation: 1)
        let store = KnowledgeWidgetSnapshotStore(
            containerURLProvider: { root },
            sharedDefaultsProvider: { defaults },
            timelineReloader: { reloads.value += 1 },
            accountLeaseRuntime: leaseRuntime
        )
        let generationA = UUID()
        let generationB = UUID()

        store.activate(ownerUserId: "owner-A", generation: generationA)
        require(store.publish(graph: graph(owner: "owner-A"), ownerUserId: "owner-A", generation: generationA), "active owner must publish")
        require(fileManager.fileExists(atPath: store.snapshotURLForTesting.path), "publish must create snapshot")
        require(
            defaults.string(forKey: KnowledgeWidgetSnapshotStore.activeOwnerDigestKey)
                == KnowledgeWidgetPrivacyPolicy.ownerDigest(for: "owner-A"),
            "active owner digest must be shared"
        )

        leaseRuntime.isValid = false
        require(
            !store.publish(graph: graph(owner: "owner-A"), ownerUserId: "owner-A", generation: generationA),
            "authority epoch mismatch must reject Widget publication"
        )
        require(
            !fileManager.fileExists(atPath: store.snapshotURLForTesting.path),
            "invalid active lease must revoke the last Widget snapshot"
        )

        leaseRuntime.isValid = true
        leaseRuntime.currentLease = lease(subjectId: "owner-B", generation: 2)
        store.activate(ownerUserId: "owner-B", generation: generationB)
        require(!fileManager.fileExists(atPath: store.snapshotURLForTesting.path), "switch must invalidate old snapshot before new publish")
        require(
            !store.publish(graph: graph(owner: "owner-A"), ownerUserId: "owner-A", generation: generationA),
            "stale owner and generation must be rejected"
        )
        require(!fileManager.fileExists(atPath: store.snapshotURLForTesting.path), "stale publish must not recreate snapshot")
        require(store.publish(graph: graph(owner: "owner-B"), ownerUserId: "owner-B", generation: generationB), "new owner must publish")

        store.activate(ownerUserId: nil, generation: UUID())
        require(defaults.string(forKey: KnowledgeWidgetSnapshotStore.activeOwnerDigestKey) == nil, "logout must revoke active owner first")
        require(!fileManager.fileExists(atPath: store.snapshotURLForTesting.path), "logout must remove snapshot")
        require(
            !store.publish(graph: graph(owner: "owner-B"), ownerUserId: "owner-B", generation: generationB),
            "logout must reject delayed old publish"
        )
        require(reloads.value >= 5, "activation, publication and clearing must invalidate Widget timelines")

        print("Knowledge widget snapshot store model smoke passed")
    }

    private static func lease(subjectId: String, generation: UInt64) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: "vault-\(subjectId)",
            sessionId: "session-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "epoch-\(generation)"
        )
    }

    private static func graph(owner: String) -> KBLiteGraph {
        var graph = KBLiteGraph()
        graph.events = [
            KBEvent(
                id: "event-\(owner)",
                title: "允许的摘要",
                year: 2001,
                month: 7,
                privacyMetadata: .widgetSummaryAllowed(sourceRefs: []),
                ownerUserId: owner,
                personaScope: "personal",
                evidenceStatus: "confirmed"
            )
        ]
        return graph
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fail(message) }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Knowledge widget snapshot store model smoke failed: \(message)\n", stderr)
        exit(1)
    }
}
