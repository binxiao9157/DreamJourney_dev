import Foundation

// Compile-only carriers keep this smoke focused on the production MemoryRepository
// storage contract without pulling the rest of the application model graph.
enum AccountLeaseCheckpoint {
    case request
    case commit
    case ui
    case timer
    case runtime
}

struct AccountLeaseValidationDecision {
    let allowed: Bool
}

struct AccountLease: Equatable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
}

protocol AccountLeaseRuntimePort {
    func capture(forSubjectId subjectId: String?) -> AccountLease?
    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision
}

final class AccountLeaseRuntime: AccountLeaseRuntimePort {
    static let shared = AccountLeaseRuntime()

    func capture(forSubjectId subjectId: String?) -> AccountLease? { nil }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        AccountLeaseValidationDecision(allowed: false)
    }
}

struct CommentModel: Codable, Equatable, Identifiable {
    let id: String
    var authorId: String
}

struct LikeModel: Codable, Equatable, Identifiable {
    let id: String
    var userId: String
    var userName: String
    var createdAt: Date

    init(id: String = UUID().uuidString, userId: String, userName: String) {
        self.id = id
        self.userId = userId
        self.userName = userName
        createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    }
}

struct SupplementModel: Codable, Equatable, Identifiable {
    let id: String
    var authorId: String
}

struct MemoryModel: Codable, Equatable, Identifiable {
    let id: String
    var title: String
    var isPrivate: Bool
    var createdAt: Date
    var comments: [CommentModel]
    var likes: [LikeModel]
    var supplements: [SupplementModel]
    var authorId: String
}

extension Notification.Name {
    static let djNewMemoryCreated = Notification.Name("djNewMemoryCreated")
}

private final class MutableLeaseRuntime: AccountLeaseRuntimePort {
    var activeLease: AccountLease?

    init(activeLease: AccountLease?) {
        self.activeLease = activeLease
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        guard let activeLease,
              subjectId == nil || subjectId == activeLease.subjectId else {
            return nil
        }
        return activeLease
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        AccountLeaseValidationDecision(allowed: lease == activeLease)
    }
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else { fatalError(message) }
}

private func makeLease(
    subjectId: String,
    vaultId: String,
    generation: UInt64 = 1
) -> AccountLease {
    AccountLease(
        subjectId: subjectId,
        vaultId: vaultId,
        sessionId: "session-\(subjectId)-\(generation)",
        generation: generation,
        generationId: UUID(),
        authorityEpoch: "epoch-a"
    )
}

private func makeMemory(
    id: String,
    ownerId: String,
    title: String? = nil
) -> MemoryModel {
    MemoryModel(
        id: id,
        title: title ?? "memory-\(id)",
        isPrivate: false,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        comments: [],
        likes: [],
        supplements: [],
        authorId: ownerId
    )
}

private func makeDefaults(_ label: String) -> UserDefaults {
    let suiteName = "memory-map-owner-storage-smoke.\(label).\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        fatalError("failed to create isolated defaults")
    }
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}

@main
private enum MemoryMapOwnerStorageModelSmoke {
    static func main() throws {
        try verifyOwnerAndLeaseIsolation()
        try verifyScopedCorruptionFailsClosed()
        try verifyLegacyPayloadsAreQuarantined()
        print("Memory/Map owner storage model smoke passed")
    }

    private static func verifyOwnerAndLeaseIsolation() throws {
        let defaults = makeDefaults("owner-isolation")
        let leaseA = makeLease(subjectId: "owner-a", vaultId: "vault-a")
        let leaseB = makeLease(subjectId: "owner-b", vaultId: "vault-b")
        let rotatedVault = makeLease(subjectId: "owner-a", vaultId: "vault-a-rotated")
        let runtime = MutableLeaseRuntime(activeLease: leaseA)
        let repository = MemoryRepository(defaults: defaults, accountLeaseRuntime: runtime)

        let scopeA = MemoryStorageScope(accountLease: leaseA, ownerId: "owner-a")
        let scopeB = MemoryStorageScope(accountLease: leaseB, ownerId: "owner-b")
        let scopeRotatedVault = MemoryStorageScope(accountLease: rotatedVault, ownerId: "owner-a")
        require(scopeA.storageKey != scopeB.storageKey, "accounts must not share a memory key")
        require(
            scopeA.storageKey != scopeRotatedVault.storageKey,
            "vault rotation must not reuse a memory key"
        )

        let memoryA = makeMemory(id: "same-id", ownerId: "owner-a")
        require(
            repository.add(memoryA, ownerId: "owner-a", accountLease: leaseA),
            "owner A add should persist"
        )
        require(
            repository.get(by: "same-id", ownerId: "owner-a", accountLease: leaseA)?.authorId
                == "owner-a",
            "owner A should read its scoped record"
        )

        runtime.activeLease = leaseB
        require(
            repository.getAllByOwner("owner-a", accountLease: leaseA).isEmpty,
            "a stale lease must fail closed after account switch"
        )
        let memoryB = makeMemory(id: "same-id", ownerId: "owner-b")
        require(
            repository.add(memoryB, ownerId: "owner-b", accountLease: leaseB),
            "owner B may persist the same id in its own scope"
        )
        require(
            !repository.delete(id: "same-id", ownerId: "owner-a", accountLease: leaseB),
            "an ID mutation must reject a mismatched owner and lease"
        )
        var injectedOwner = memoryA
        injectedOwner.title = "cross-owner overwrite"
        require(
            !repository.update(injectedOwner, ownerId: "owner-b", accountLease: leaseB),
            "an update must reject a payload owner mismatch"
        )

        runtime.activeLease = leaseA
        require(
            repository.get(by: "same-id", ownerId: "owner-a", accountLease: leaseA)?.title
                == memoryA.title,
            "owner B operations must not alter owner A"
        )

        let mapStore = MemoryMapPresentationStore(
            defaults: defaults,
            accountLeaseRuntime: runtime
        )
        require(
            mapStore.markRead(
                memoryId: "memory-a",
                ownerId: "family-owner",
                accountLease: leaseA
            ),
            "map read state should persist for the active lease"
        )
        require(
            mapStore.markBounced(
                memoryId: "memory-a",
                ownerId: "family-owner",
                accountLease: leaseA
            ),
            "map bounce state should persist for the active lease"
        )
        let stateA = mapStore.load(ownerId: "family-owner", accountLease: leaseA)
        require(stateA.readMemoryIds == ["memory-a"], "owner A map read state is missing")
        require(stateA.bouncedMemoryIds == ["memory-a"], "owner A map bounce state is missing")

        runtime.activeLease = leaseB
        let stateB = mapStore.load(ownerId: "family-owner", accountLease: leaseB)
        require(stateB.readMemoryIds.isEmpty, "map read state leaked across accounts")
        require(stateB.bouncedMemoryIds.isEmpty, "map bounce state leaked across accounts")
        require(
            !mapStore.markRead(
                memoryId: "stale-write",
                ownerId: "family-owner",
                accountLease: leaseA
            ),
            "stale map state writes must be rejected"
        )
    }

    private static func verifyScopedCorruptionFailsClosed() throws {
        let defaults = makeDefaults("scoped-corrupt")
        let lease = makeLease(subjectId: "owner-a", vaultId: "vault-a")
        let runtime = MutableLeaseRuntime(activeLease: lease)
        let repository = MemoryRepository(defaults: defaults, accountLeaseRuntime: runtime)
        let scope = MemoryStorageScope(accountLease: lease, ownerId: "owner-a")

        require(
            repository.add(
                makeMemory(id: "corrupt-me", ownerId: "owner-a"),
                ownerId: "owner-a",
                accountLease: lease
            ),
            "fixture add failed"
        )
        guard let data = defaults.data(forKey: scope.storageKey) else {
            fatalError("scoped envelope was not persisted")
        }
        var envelope = try JSONDecoder().decode(MemoryStoreEnvelope.self, from: data)
        envelope.contentHash = "sha256:corrupt"
        defaults.set(try JSONEncoder().encode(envelope), forKey: scope.storageKey)

        require(
            repository.getAllByOwner("owner-a", accountLease: lease).isEmpty,
            "corrupt scoped data must fail closed"
        )
        require(
            defaults.data(forKey: scope.storageKey) == nil,
            "quarantined corrupt data must be retired from the live key"
        )
        require(
            repository.quarantineRecords(ownerId: "owner-a", accountLease: lease)
                .contains(where: { $0.reason == .corrupt }),
            "corrupt scoped data must leave a quarantine record"
        )
    }

    private static func verifyLegacyPayloadsAreQuarantined() throws {
        try verifyLegacyCase(
            label: "ownerless",
            payload: JSONEncoder().encode([makeMemory(id: "ownerless", ownerId: "")]),
            expectedReason: .missingOwner
        )
        try verifyLegacyCase(
            label: "seed",
            payload: JSONEncoder().encode([makeMemory(id: "mem_001", ownerId: "fixture")]),
            expectedReason: .seedFixture
        )
        try verifyLegacyCase(
            label: "ambiguous",
            payload: JSONEncoder().encode([makeMemory(id: "legacy", ownerId: "owner-a")]),
            expectedReason: .ambiguousOwner
        )
        try verifyLegacyCase(
            label: "corrupt",
            payload: Data("not-json".utf8),
            expectedReason: .corrupt
        )
    }

    private static func verifyLegacyCase(
        label: String,
        payload: Data,
        expectedReason: MemoryQuarantineReason
    ) throws {
        let defaults = makeDefaults(label)
        defaults.set(payload, forKey: "dj.persistedMemories")
        let lease = makeLease(subjectId: "owner-a", vaultId: "vault-a")
        let runtime = MutableLeaseRuntime(activeLease: lease)
        let repository = MemoryRepository(defaults: defaults, accountLeaseRuntime: runtime)
        let scope = MemoryStorageScope(accountLease: lease, ownerId: "owner-a")

        require(
            repository.getAllByOwner("owner-a", accountLease: lease).isEmpty,
            "legacy \(label) payload must never mount into the active owner"
        )
        require(
            defaults.data(forKey: scope.storageKey) == nil,
            "legacy \(label) payload must not be auto-claimed"
        )
        require(
            defaults.data(forKey: "dj.persistedMemories") == nil,
            "legacy \(label) live key should be retired after quarantine"
        )
        require(
            repository.deviceQuarantineRecords().contains(where: {
                $0.reason == expectedReason && $0.sourceStorageKey == "dj.persistedMemories"
            }),
            "legacy \(label) payload has no expected quarantine record"
        )
        require(
            repository.deviceMigrationReceipts().contains(where: {
                $0.state == .quarantined
                    && $0.reason == expectedReason
                    && $0.sourceStorageKey == "dj.persistedMemories"
                    && $0.ownerEvidence == "none"
            }),
            "legacy \(label) payload has no quarantine migration receipt"
        )
    }
}
