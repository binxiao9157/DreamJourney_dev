import CryptoKit
import Foundation

enum MemoryQuarantineReason: String, Codable, Equatable {
    case missingOwner
    case ambiguousOwner
    case seedFixture
    case mismatch
    case corrupt
}

enum MemoryEnvelopeValidation: Equatable {
    case accepted
    case mismatch
    case corrupt
}

struct MemoryStorageScope: Equatable {
    static let storeSchemaVersion = 2

    let subjectId: String
    let vaultId: String
    let ownerId: String
    let generation: UInt64
    let generationId: UUID

    init(accountLease: AccountLease, ownerId: String) {
        subjectId = Self.normalized(accountLease.subjectId)
        vaultId = Self.normalized(accountLease.vaultId)
        self.ownerId = Self.normalized(ownerId)
        generation = accountLease.generation
        generationId = accountLease.generationId
    }

    var storageKey: String {
        "dj.memory.items.v2.\(scopeDigest)"
    }

    var quarantineStorageKey: String {
        "dj.memory.quarantine.v2.\(scopeDigest)"
    }

    var mapPresentationStorageKey: String {
        "dj.memoryMap.presentation.v2.\(scopeDigest)"
    }

    var mapQuarantineStorageKey: String {
        "dj.memoryMap.quarantine.v2.\(scopeDigest)"
    }

    var isValid: Bool {
        !subjectId.isEmpty && !vaultId.isEmpty && !ownerId.isEmpty
    }

    fileprivate var scopeDigest: String {
        MemoryStoragePolicy.sha256("memory-scope-v2|\(subjectId)|\(vaultId)|\(ownerId)")
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MemoryStoreEnvelope: Codable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let ownerId: String
    let generation: UInt64
    let generationId: UUID
    var contentHash: String
    let memories: [MemoryModel]
}

struct MemoryQuarantineRecord: Codable, Equatable {
    let recordId: String
    let sourceStorageKey: String
    let reason: MemoryQuarantineReason
    let itemIds: [String]
    let payload: Data
    let contentHash: String
    let createdAt: Date
}

struct MemoryLegacyMigrationReceipt: Codable, Equatable {
    enum State: String, Codable {
        case quarantined
    }

    let receiptId: String
    let surfaceId: String
    let sourceStorageKey: String
    let quarantineStorageKey: String
    let ownerEvidence: String
    let state: State
    let reason: MemoryQuarantineReason
    let sourceContentHash: String
    let itemIds: [String]
    let createdAt: Date
}

struct MemoryMapPresentationState: Equatable {
    var readMemoryIds: Set<String>
    var bouncedMemoryIds: Set<String>

    static let empty = MemoryMapPresentationState(
        readMemoryIds: [],
        bouncedMemoryIds: []
    )
}

private struct MemoryMapPresentationEnvelope: Codable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let ownerId: String
    let generation: UInt64
    let generationId: UUID
    var contentHash: String
    let readMemoryIds: [String]
    let bouncedMemoryIds: [String]
}

private struct MemoryMapPresentationHashPayload: Codable {
    let readMemoryIds: [String]
    let bouncedMemoryIds: [String]
}

private enum MemoryStorageError: Error {
    case invalidScope
    case ownerMismatch
    case encodingFailed
}

private enum MemoryStoragePolicy {
    static func makeEnvelope(
        memories: [MemoryModel],
        scope: MemoryStorageScope
    ) throws -> MemoryStoreEnvelope {
        guard scope.isValid else { throw MemoryStorageError.invalidScope }
        guard memories.allSatisfy({ normalized($0.authorId) == scope.ownerId }) else {
            throw MemoryStorageError.ownerMismatch
        }
        return MemoryStoreEnvelope(
            storeSchemaVersion: MemoryStorageScope.storeSchemaVersion,
            subjectId: scope.subjectId,
            vaultId: scope.vaultId,
            ownerId: scope.ownerId,
            generation: scope.generation,
            generationId: scope.generationId,
            contentHash: try memoriesContentHash(memories),
            memories: memories
        )
    }

    static func validate(
        _ envelope: MemoryStoreEnvelope,
        expectedScope: MemoryStorageScope
    ) -> MemoryEnvelopeValidation {
        guard expectedScope.isValid,
              envelope.storeSchemaVersion == MemoryStorageScope.storeSchemaVersion,
              normalized(envelope.subjectId) == expectedScope.subjectId,
              normalized(envelope.vaultId) == expectedScope.vaultId,
              normalized(envelope.ownerId) == expectedScope.ownerId,
              envelope.memories.allSatisfy({ normalized($0.authorId) == expectedScope.ownerId }) else {
            return .mismatch
        }
        let ids = envelope.memories.map { normalized($0.id) }
        guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count,
              let expectedHash = try? memoriesContentHash(envelope.memories),
              envelope.contentHash == expectedHash else {
            return .corrupt
        }
        return .accepted
    }

    static func makeMapEnvelope(
        state: MemoryMapPresentationState,
        scope: MemoryStorageScope
    ) throws -> MemoryMapPresentationEnvelope {
        guard scope.isValid else { throw MemoryStorageError.invalidScope }
        let readIds = normalizedIds(state.readMemoryIds)
        let bouncedIds = normalizedIds(state.bouncedMemoryIds)
        return MemoryMapPresentationEnvelope(
            storeSchemaVersion: MemoryStorageScope.storeSchemaVersion,
            subjectId: scope.subjectId,
            vaultId: scope.vaultId,
            ownerId: scope.ownerId,
            generation: scope.generation,
            generationId: scope.generationId,
            contentHash: try mapContentHash(readIds: readIds, bouncedIds: bouncedIds),
            readMemoryIds: readIds,
            bouncedMemoryIds: bouncedIds
        )
    }

    static func validateMapEnvelope(
        _ envelope: MemoryMapPresentationEnvelope,
        expectedScope: MemoryStorageScope
    ) -> MemoryEnvelopeValidation {
        guard expectedScope.isValid,
              envelope.storeSchemaVersion == MemoryStorageScope.storeSchemaVersion,
              normalized(envelope.subjectId) == expectedScope.subjectId,
              normalized(envelope.vaultId) == expectedScope.vaultId,
              normalized(envelope.ownerId) == expectedScope.ownerId else {
            return .mismatch
        }
        let readIds = normalizedIds(Set(envelope.readMemoryIds))
        let bouncedIds = normalizedIds(Set(envelope.bouncedMemoryIds))
        guard readIds.count == envelope.readMemoryIds.count,
              bouncedIds.count == envelope.bouncedMemoryIds.count,
              let expectedHash = try? mapContentHash(readIds: readIds, bouncedIds: bouncedIds),
              envelope.contentHash == expectedHash else {
            return .corrupt
        }
        return .accepted
    }

    static func quarantineRecord(
        sourceStorageKey: String,
        reason: MemoryQuarantineReason,
        itemIds: [String],
        payload: Data
    ) -> MemoryQuarantineRecord {
        let contentHash = sha256(payload)
        return MemoryQuarantineRecord(
            recordId: sha256(
                "memory-quarantine-v2|\(sourceStorageKey)|\(contentHash)|\(reason.rawValue)"
            ),
            sourceStorageKey: sourceStorageKey,
            reason: reason,
            itemIds: normalizedIds(Set(itemIds)),
            payload: payload,
            contentHash: contentHash,
            createdAt: Date()
        )
    }

    static func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func memoriesContentHash(_ memories: [MemoryModel]) throws -> String {
        sha256(try encoder().encode(memories))
    }

    private static func mapContentHash(
        readIds: [String],
        bouncedIds: [String]
    ) throws -> String {
        sha256(
            try encoder().encode(
                MemoryMapPresentationHashPayload(
                    readMemoryIds: readIds,
                    bouncedMemoryIds: bouncedIds
                )
            )
        )
    }

    private static func normalizedIds(_ ids: Set<String>) -> [String] {
        ids.map(normalized).filter { !$0.isEmpty }.sorted()
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private enum MemoryQuarantineStorage {
    static let deviceStorageKey = "dj.memory.quarantine.device.v2"
    private static let lock = NSRecursiveLock()

    static func append(
        _ record: MemoryQuarantineRecord,
        storageKey: String,
        defaults: UserDefaults
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        var records = load(storageKey: storageKey, defaults: defaults)
        if let existing = records.first(where: { $0.recordId == record.recordId }) {
            return existing == record
                || (existing.sourceStorageKey == record.sourceStorageKey
                    && existing.reason == record.reason
                    && existing.itemIds == record.itemIds
                    && existing.contentHash == record.contentHash
                    && existing.payload == record.payload)
        }
        records.append(record)
        guard let data = try? JSONEncoder().encode(records) else { return false }
        defaults.set(data, forKey: storageKey)
        return defaults.data(forKey: storageKey) == data
    }

    static func load(
        storageKey: String,
        defaults: UserDefaults
    ) -> [MemoryQuarantineRecord] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([MemoryQuarantineRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func append(
        _ receipt: MemoryLegacyMigrationReceipt,
        quarantineStorageKey: String,
        defaults: UserDefaults
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let storageKey = receiptStorageKey(for: quarantineStorageKey)
        var receipts = loadReceipts(
            quarantineStorageKey: quarantineStorageKey,
            defaults: defaults
        )
        if let existing = receipts.first(where: { $0.receiptId == receipt.receiptId }) {
            return existing == receipt
                || (existing.sourceStorageKey == receipt.sourceStorageKey
                    && existing.sourceContentHash == receipt.sourceContentHash
                    && existing.state == receipt.state
                    && existing.reason == receipt.reason
                    && existing.itemIds == receipt.itemIds)
        }
        receipts.append(receipt)
        guard let data = try? JSONEncoder().encode(receipts) else { return false }
        defaults.set(data, forKey: storageKey)
        return defaults.data(forKey: storageKey) == data
    }

    static func loadReceipts(
        quarantineStorageKey: String,
        defaults: UserDefaults
    ) -> [MemoryLegacyMigrationReceipt] {
        lock.lock()
        defer { lock.unlock() }
        let storageKey = receiptStorageKey(for: quarantineStorageKey)
        guard let data = defaults.data(forKey: storageKey),
              let receipts = try? JSONDecoder().decode(
                  [MemoryLegacyMigrationReceipt].self,
                  from: data
              ) else {
            return []
        }
        return receipts
    }

    private static func receiptStorageKey(for quarantineStorageKey: String) -> String {
        "\(quarantineStorageKey).migrationReceipts.v1"
    }
}

// MARK: - Owner-scoped Memory storage
final class MemoryRepository {
    static let shared = MemoryRepository()

    static let legacyPersistKey = "dj.persistedMemories"

    private enum ScopedLoadResult {
        case missing
        case loaded([MemoryModel])
        case rejected
    }

    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let notificationCenter: NotificationCenter
    private let lock = NSRecursiveLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
        self.notificationCenter = notificationCenter
    }

    // MARK: Reads
    func getAll() -> [MemoryModel] {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return [] }
        return getAllByOwner(accountLease.subjectId, accountLease: accountLease)
    }

    func getAllByOwner(_ ownerId: String) -> [MemoryModel] {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return [] }
        return getAllByOwner(ownerId, accountLease: accountLease)
    }

    func getAllByOwner(
        _ ownerId: String,
        accountLease: AccountLease
    ) -> [MemoryModel] {
        guard let scope = validatedScope(
            ownerId: ownerId,
            accountLease: accountLease,
            checkpoint: .request
        ) else {
            return []
        }
        let memories: [MemoryModel] = withLock {
            guard quarantineLegacyGlobalPayloadIfNeeded() else { return [] }
            switch loadScopedMemories(scope: scope) {
            case .missing, .rejected:
                return []
            case .loaded(let memories):
                return memories
            }
        }
        guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else { return [] }
        return memories.sorted { $0.createdAt > $1.createdAt }
    }

    func getPublicByOwner(_ ownerId: String) -> [MemoryModel] {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return [] }
        return getPublicByOwner(ownerId, accountLease: accountLease)
    }

    func getPublicByOwner(
        _ ownerId: String,
        accountLease: AccountLease
    ) -> [MemoryModel] {
        getAllByOwner(ownerId, accountLease: accountLease).filter { !$0.isPrivate }
    }

    func get(by id: String) -> MemoryModel? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return nil }
        return get(by: id, ownerId: accountLease.subjectId, accountLease: accountLease)
    }

    func get(
        by id: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> MemoryModel? {
        let normalizedId = MemoryStoragePolicy.normalized(id)
        guard !normalizedId.isEmpty else { return nil }
        return getAllByOwner(ownerId, accountLease: accountLease).first { $0.id == normalizedId }
    }

    // MARK: Owner mutations
    @discardableResult
    func add(_ memory: MemoryModel) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: memory.authorId) else {
            return false
        }
        return add(memory, ownerId: memory.authorId, accountLease: accountLease)
    }

    @discardableResult
    func add(
        _ memory: MemoryModel,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard MemoryStoragePolicy.normalized(memory.id).isEmpty == false,
              MemoryStoragePolicy.normalized(memory.authorId) == MemoryStoragePolicy.normalized(ownerId),
              let scope = validatedOwnerMutationScope(
                  ownerId: ownerId,
                  accountLease: accountLease
              ) else {
            return false
        }
        let saved = withLock {
            guard quarantineLegacyGlobalPayloadIfNeeded() else { return false }
            let memories: [MemoryModel]
            switch loadScopedMemories(scope: scope) {
            case .missing:
                memories = []
            case .loaded(let loaded):
                memories = loaded
            case .rejected:
                return false
            }
            guard !memories.contains(where: { $0.id == memory.id }) else { return false }
            var updated = memories
            updated.insert(memory, at: 0)
            return save(memories: updated, scope: scope, accountLease: accountLease)
        }
        guard saved else { return false }
        notificationCenter.post(name: .djNewMemoryCreated, object: memory)
        return true
    }

    @discardableResult
    func update(_ memory: MemoryModel) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: memory.authorId) else {
            return false
        }
        return update(memory, ownerId: memory.authorId, accountLease: accountLease)
    }

    @discardableResult
    func update(
        _ memory: MemoryModel,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard MemoryStoragePolicy.normalized(memory.authorId) == MemoryStoragePolicy.normalized(ownerId) else {
            return false
        }
        return mutateMemory(
            id: memory.id,
            ownerId: ownerId,
            accountLease: accountLease,
            requiresOwnerLease: true
        ) { stored in
            guard stored.authorId == memory.authorId else { return nil }
            stored = memory
            return true
        } ?? false
    }

    @discardableResult
    func delete(id: String) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return false }
        return delete(id: id, ownerId: accountLease.subjectId, accountLease: accountLease)
    }

    @discardableResult
    func delete(id: String, ownerId: String, accountLease: AccountLease) -> Bool {
        guard let scope = validatedOwnerMutationScope(
            ownerId: ownerId,
            accountLease: accountLease
        ) else {
            return false
        }
        return withLock {
            guard quarantineLegacyGlobalPayloadIfNeeded() else { return false }
            guard case .loaded(var memories) = loadScopedMemories(scope: scope),
                  let index = memories.firstIndex(where: { $0.id == id && $0.authorId == scope.ownerId }) else {
                return false
            }
            memories.remove(at: index)
            return save(memories: memories, scope: scope, accountLease: accountLease)
        }
    }

    @discardableResult
    func purgeLocalDataForAccountDeletion(accountLease: AccountLease) -> Bool {
        let selfScope = MemoryStorageScope(
            accountLease: accountLease,
            ownerId: accountLease.subjectId
        )
        guard selfScope.isValid else { return false }
        return withLock {
            let itemPrefix = "dj.memory.items.v2."
            var scopeDigests: Set<String> = [selfScope.scopeDigest]
            for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(itemPrefix) {
                guard let data = value as? Data,
                      let envelope = try? JSONDecoder().decode(
                          MemoryStoreEnvelope.self,
                          from: data
                      ),
                      MemoryStoragePolicy.normalized(envelope.subjectId)
                        == MemoryStoragePolicy.normalized(accountLease.subjectId),
                      MemoryStoragePolicy.normalized(envelope.vaultId)
                        == MemoryStoragePolicy.normalized(accountLease.vaultId) else {
                    continue
                }
                scopeDigests.insert(String(key.dropFirst(itemPrefix.count)))
            }
            for scopeDigest in scopeDigests {
                let storageKey = itemPrefix + scopeDigest
                let quarantineStorageKey = "dj.memory.quarantine.v2." + scopeDigest
                defaults.removeObject(forKey: storageKey)
                defaults.removeObject(forKey: quarantineStorageKey)
                defaults.removeObject(
                    forKey: quarantineStorageKey + ".migrationReceipts.v1"
                )
            }
            return scopeDigests.allSatisfy {
                defaults.object(forKey: itemPrefix + $0) == nil
                    && defaults.object(forKey: "dj.memory.quarantine.v2." + $0) == nil
            }
        }
    }

    // MARK: Actor mutations
    @discardableResult
    func addComment(
        _ comment: CommentModel,
        to memoryId: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard MemoryStoragePolicy.normalized(comment.authorId) == accountLease.subjectId else {
            return false
        }
        return mutateMemory(
            id: memoryId,
            ownerId: ownerId,
            accountLease: accountLease,
            requiresOwnerLease: false
        ) { memory in
            guard !memory.comments.contains(where: { $0.id == comment.id }) else { return nil }
            memory.comments.append(comment)
            return true
        } ?? false
    }

    func toggleLike(
        userName: String,
        on memoryId: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool? {
        let normalizedUserName = MemoryStoragePolicy.normalized(userName)
        guard !normalizedUserName.isEmpty else { return nil }
        return mutateMemory(
            id: memoryId,
            ownerId: ownerId,
            accountLease: accountLease,
            requiresOwnerLease: false
        ) { memory in
            if let index = memory.likes.firstIndex(where: { $0.userId == accountLease.subjectId }) {
                memory.likes.remove(at: index)
                return false
            }
            memory.likes.append(
                LikeModel(userId: accountLease.subjectId, userName: normalizedUserName)
            )
            return true
        }
    }

    @discardableResult
    func addSupplement(
        _ supplement: SupplementModel,
        to memoryId: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard MemoryStoragePolicy.normalized(supplement.authorId) == accountLease.subjectId else {
            return false
        }
        return mutateMemory(
            id: memoryId,
            ownerId: ownerId,
            accountLease: accountLease,
            requiresOwnerLease: false
        ) { memory in
            guard !memory.supplements.contains(where: { $0.id == supplement.id }) else { return nil }
            memory.supplements.append(supplement)
            return true
        } ?? false
    }

    @discardableResult
    func togglePrivacy(
        memoryId: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        mutateMemory(
            id: memoryId,
            ownerId: ownerId,
            accountLease: accountLease,
            requiresOwnerLease: true
        ) { memory in
            memory.isPrivate.toggle()
            return true
        } ?? false
    }

    func quarantineRecords(
        ownerId: String,
        accountLease: AccountLease
    ) -> [MemoryQuarantineRecord] {
        guard let scope = validatedScope(
            ownerId: ownerId,
            accountLease: accountLease,
            checkpoint: .runtime
        ) else {
            return []
        }
        return MemoryQuarantineStorage.load(
            storageKey: scope.quarantineStorageKey,
            defaults: defaults
        )
    }

    func deviceQuarantineRecords() -> [MemoryQuarantineRecord] {
        MemoryQuarantineStorage.load(
            storageKey: MemoryQuarantineStorage.deviceStorageKey,
            defaults: defaults
        )
    }

    func deviceMigrationReceipts() -> [MemoryLegacyMigrationReceipt] {
        MemoryQuarantineStorage.loadReceipts(
            quarantineStorageKey: MemoryQuarantineStorage.deviceStorageKey,
            defaults: defaults
        )
    }

    private func mutateMemory<Result>(
        id: String,
        ownerId: String,
        accountLease: AccountLease,
        requiresOwnerLease: Bool,
        mutation: (inout MemoryModel) -> Result?
    ) -> Result? {
        let normalizedId = MemoryStoragePolicy.normalized(id)
        guard !normalizedId.isEmpty,
              let scope = validatedScope(
                  ownerId: ownerId,
                  accountLease: accountLease,
                  checkpoint: .commit
              ),
              !requiresOwnerLease || scope.ownerId == scope.subjectId else {
            return nil
        }
        return withLock {
            guard quarantineLegacyGlobalPayloadIfNeeded() else { return nil }
            guard case .loaded(var memories) = loadScopedMemories(scope: scope),
                  let index = memories.firstIndex(where: {
                      $0.id == normalizedId && $0.authorId == scope.ownerId
                  }),
                  let result = mutation(&memories[index]),
                  save(memories: memories, scope: scope, accountLease: accountLease) else {
                return nil
            }
            return result
        }
    }

    private func validatedOwnerMutationScope(
        ownerId: String,
        accountLease: AccountLease
    ) -> MemoryStorageScope? {
        guard let scope = validatedScope(
            ownerId: ownerId,
            accountLease: accountLease,
            checkpoint: .commit
        ), scope.ownerId == scope.subjectId else {
            return nil
        }
        return scope
    }

    private func validatedScope(
        ownerId: String,
        accountLease: AccountLease,
        checkpoint: AccountLeaseCheckpoint
    ) -> MemoryStorageScope? {
        guard accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed else { return nil }
        let scope = MemoryStorageScope(accountLease: accountLease, ownerId: ownerId)
        return scope.isValid ? scope : nil
    }

    private func loadScopedMemories(scope: MemoryStorageScope) -> ScopedLoadResult {
        guard let data = defaults.data(forKey: scope.storageKey) else { return .missing }
        guard let envelope = try? JSONDecoder().decode(MemoryStoreEnvelope.self, from: data) else {
            quarantine(
                data,
                sourceStorageKey: scope.storageKey,
                quarantineStorageKey: scope.quarantineStorageKey,
                reason: .corrupt,
                itemIds: []
            )
            return .rejected
        }
        switch MemoryStoragePolicy.validate(envelope, expectedScope: scope) {
        case .accepted:
            return .loaded(envelope.memories)
        case .mismatch:
            quarantine(
                data,
                sourceStorageKey: scope.storageKey,
                quarantineStorageKey: scope.quarantineStorageKey,
                reason: .mismatch,
                itemIds: envelope.memories.map(\.id)
            )
        case .corrupt:
            quarantine(
                data,
                sourceStorageKey: scope.storageKey,
                quarantineStorageKey: scope.quarantineStorageKey,
                reason: .corrupt,
                itemIds: envelope.memories.map(\.id)
            )
        }
        return .rejected
    }

    private func save(
        memories: [MemoryModel],
        scope: MemoryStorageScope,
        accountLease: AccountLease
    ) -> Bool {
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let envelope = try? MemoryStoragePolicy.makeEnvelope(
                  memories: memories,
                  scope: scope
              ),
              let data = try? JSONEncoder().encode(envelope) else {
            return false
        }
        let previousData = defaults.data(forKey: scope.storageKey)
        defaults.set(data, forKey: scope.storageKey)
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            if defaults.data(forKey: scope.storageKey) == data {
                if let previousData {
                    defaults.set(previousData, forKey: scope.storageKey)
                } else {
                    defaults.removeObject(forKey: scope.storageKey)
                }
            }
            return false
        }
        return true
    }

    @discardableResult
    private func quarantineLegacyGlobalPayloadIfNeeded() -> Bool {
        guard let data = defaults.data(forKey: Self.legacyPersistKey) else { return true }
        let reason: MemoryQuarantineReason
        let itemIds: [String]
        if let memories = try? JSONDecoder().decode([MemoryModel].self, from: data) {
            itemIds = memories.map(\.id)
            if memories.contains(where: {
                MemoryStoragePolicy.normalized($0.authorId).isEmpty
            }) {
                reason = .missingOwner
            } else if !memories.isEmpty && memories.allSatisfy({ $0.id.hasPrefix("mem_") }) {
                reason = .seedFixture
            } else {
                reason = .ambiguousOwner
            }
        } else {
            itemIds = []
            reason = .corrupt
        }
        return quarantine(
            data,
            sourceStorageKey: Self.legacyPersistKey,
            quarantineStorageKey: MemoryQuarantineStorage.deviceStorageKey,
            reason: reason,
            itemIds: itemIds
        )
    }

    @discardableResult
    private func quarantine(
        _ data: Data,
        sourceStorageKey: String,
        quarantineStorageKey: String,
        reason: MemoryQuarantineReason,
        itemIds: [String]
    ) -> Bool {
        let record = MemoryStoragePolicy.quarantineRecord(
            sourceStorageKey: sourceStorageKey,
            reason: reason,
            itemIds: itemIds,
            payload: data
        )
        guard MemoryQuarantineStorage.append(
            record,
            storageKey: quarantineStorageKey,
            defaults: defaults
        ), MemoryQuarantineStorage.append(
            MemoryLegacyMigrationReceipt(
                receiptId: MemoryStoragePolicy.sha256(
                    "memory-receipt-v2|\(sourceStorageKey)|\(record.contentHash)|\(reason.rawValue)"
                ),
                surfaceId: "memory",
                sourceStorageKey: sourceStorageKey,
                quarantineStorageKey: quarantineStorageKey,
                ownerEvidence: sourceStorageKey == Self.legacyPersistKey
                    ? "none"
                    : "rejectedEnvelope",
                state: .quarantined,
                reason: reason,
                sourceContentHash: record.contentHash,
                itemIds: record.itemIds,
                createdAt: Date()
            ),
            quarantineStorageKey: quarantineStorageKey,
            defaults: defaults
        ) else {
            return false
        }
        if defaults.data(forKey: sourceStorageKey) == data {
            defaults.removeObject(forKey: sourceStorageKey)
        }
        return true
    }

    private func withLock<Result>(_ operation: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}

// MARK: - Owner-scoped Map presentation state
final class MemoryMapPresentationStore {
    static let shared = MemoryMapPresentationStore()

    private static let legacyReadKey = "dj.readMemoryIds"
    private static let legacyBouncedKey = "dj.bouncedMemoryIds"

    private enum ScopedLoadResult {
        case missing
        case loaded(MemoryMapPresentationState)
        case rejected
    }

    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSRecursiveLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func load(
        ownerId: String,
        accountLease: AccountLease
    ) -> MemoryMapPresentationState {
        guard let scope = validatedScope(
            ownerId: ownerId,
            accountLease: accountLease,
            checkpoint: .request
        ) else {
            return .empty
        }
        let state = withLock {
            guard quarantineLegacyMapStateIfNeeded() else { return MemoryMapPresentationState.empty }
            switch loadScopedState(scope: scope) {
            case .missing, .rejected:
                return .empty
            case .loaded(let state):
                return state
            }
        }
        guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else { return .empty }
        return state
    }

    @discardableResult
    func markRead(
        memoryId: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        mutate(
            memoryId: memoryId,
            ownerId: ownerId,
            accountLease: accountLease
        ) { $0.readMemoryIds.insert(memoryId) }
    }

    @discardableResult
    func markBounced(
        memoryId: String,
        ownerId: String,
        accountLease: AccountLease
    ) -> Bool {
        mutate(
            memoryId: memoryId,
            ownerId: ownerId,
            accountLease: accountLease
        ) { $0.bouncedMemoryIds.insert(memoryId) }
    }

    @discardableResult
    func purgeLocalDataForAccountDeletion(accountLease: AccountLease) -> Bool {
        let selfScope = MemoryStorageScope(
            accountLease: accountLease,
            ownerId: accountLease.subjectId
        )
        guard selfScope.isValid else { return false }
        return withLock {
            let presentationPrefix = "dj.memoryMap.presentation.v2."
            var scopeDigests: Set<String> = [selfScope.scopeDigest]
            for (key, value) in defaults.dictionaryRepresentation()
            where key.hasPrefix(presentationPrefix) {
                guard let data = value as? Data,
                      let envelope = try? JSONDecoder().decode(
                          MemoryMapPresentationEnvelope.self,
                          from: data
                      ),
                      MemoryStoragePolicy.normalized(envelope.subjectId)
                        == MemoryStoragePolicy.normalized(accountLease.subjectId),
                      MemoryStoragePolicy.normalized(envelope.vaultId)
                        == MemoryStoragePolicy.normalized(accountLease.vaultId) else {
                    continue
                }
                scopeDigests.insert(String(key.dropFirst(presentationPrefix.count)))
            }
            for scopeDigest in scopeDigests {
                let storageKey = presentationPrefix + scopeDigest
                let quarantineStorageKey = "dj.memoryMap.quarantine.v2." + scopeDigest
                defaults.removeObject(forKey: storageKey)
                defaults.removeObject(forKey: quarantineStorageKey)
                defaults.removeObject(
                    forKey: quarantineStorageKey + ".migrationReceipts.v1"
                )
            }
            return scopeDigests.allSatisfy {
                defaults.object(forKey: presentationPrefix + $0) == nil
                    && defaults.object(forKey: "dj.memoryMap.quarantine.v2." + $0) == nil
            }
        }
    }

    private func mutate(
        memoryId: String,
        ownerId: String,
        accountLease: AccountLease,
        mutation: (inout MemoryMapPresentationState) -> Void
    ) -> Bool {
        let normalizedId = MemoryStoragePolicy.normalized(memoryId)
        guard !normalizedId.isEmpty,
              let scope = validatedScope(
                  ownerId: ownerId,
                  accountLease: accountLease,
                  checkpoint: .commit
              ) else {
            return false
        }
        return withLock {
            guard quarantineLegacyMapStateIfNeeded() else { return false }
            var state: MemoryMapPresentationState
            switch loadScopedState(scope: scope) {
            case .missing:
                state = .empty
            case .loaded(let loaded):
                state = loaded
            case .rejected:
                return false
            }
            mutation(&state)
            return save(state: state, scope: scope, accountLease: accountLease)
        }
    }

    private func validatedScope(
        ownerId: String,
        accountLease: AccountLease,
        checkpoint: AccountLeaseCheckpoint
    ) -> MemoryStorageScope? {
        guard accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed else { return nil }
        let scope = MemoryStorageScope(accountLease: accountLease, ownerId: ownerId)
        return scope.isValid ? scope : nil
    }

    private func loadScopedState(scope: MemoryStorageScope) -> ScopedLoadResult {
        let storageKey = scope.mapPresentationStorageKey
        guard let data = defaults.data(forKey: storageKey) else { return .missing }
        guard let envelope = try? JSONDecoder().decode(
            MemoryMapPresentationEnvelope.self,
            from: data
        ) else {
            quarantine(
                data,
                sourceStorageKey: storageKey,
                quarantineStorageKey: scope.mapQuarantineStorageKey,
                reason: .corrupt,
                itemIds: []
            )
            return .rejected
        }
        switch MemoryStoragePolicy.validateMapEnvelope(envelope, expectedScope: scope) {
        case .accepted:
            return .loaded(
                MemoryMapPresentationState(
                    readMemoryIds: Set(envelope.readMemoryIds),
                    bouncedMemoryIds: Set(envelope.bouncedMemoryIds)
                )
            )
        case .mismatch:
            quarantine(
                data,
                sourceStorageKey: storageKey,
                quarantineStorageKey: scope.mapQuarantineStorageKey,
                reason: .mismatch,
                itemIds: envelope.readMemoryIds + envelope.bouncedMemoryIds
            )
        case .corrupt:
            quarantine(
                data,
                sourceStorageKey: storageKey,
                quarantineStorageKey: scope.mapQuarantineStorageKey,
                reason: .corrupt,
                itemIds: envelope.readMemoryIds + envelope.bouncedMemoryIds
            )
        }
        return .rejected
    }

    private func save(
        state: MemoryMapPresentationState,
        scope: MemoryStorageScope,
        accountLease: AccountLease
    ) -> Bool {
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              let envelope = try? MemoryStoragePolicy.makeMapEnvelope(state: state, scope: scope),
              let data = try? JSONEncoder().encode(envelope) else {
            return false
        }
        let storageKey = scope.mapPresentationStorageKey
        let previousData = defaults.data(forKey: storageKey)
        defaults.set(data, forKey: storageKey)
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            if defaults.data(forKey: storageKey) == data {
                if let previousData {
                    defaults.set(previousData, forKey: storageKey)
                } else {
                    defaults.removeObject(forKey: storageKey)
                }
            }
            return false
        }
        return true
    }

    @discardableResult
    private func quarantineLegacyMapStateIfNeeded() -> Bool {
        for storageKey in [Self.legacyReadKey, Self.legacyBouncedKey] {
            guard let object = defaults.object(forKey: storageKey) else { continue }
            let payload: Data
            let itemIds: [String]
            let reason: MemoryQuarantineReason
            if let ids = object as? [String],
               let encoded = try? JSONEncoder().encode(ids.sorted()) {
                payload = encoded
                itemIds = ids
                reason = !ids.isEmpty && ids.allSatisfy({ $0.hasPrefix("mem_") })
                    ? .seedFixture
                    : .missingOwner
            } else if let data = object as? Data {
                payload = data
                itemIds = []
                reason = .corrupt
            } else {
                payload = Data(String(describing: object).utf8)
                itemIds = []
                reason = .corrupt
            }
            let record = MemoryStoragePolicy.quarantineRecord(
                sourceStorageKey: storageKey,
                reason: reason,
                itemIds: itemIds,
                payload: payload
            )
            guard MemoryQuarantineStorage.append(
                record,
                storageKey: MemoryQuarantineStorage.deviceStorageKey,
                defaults: defaults
            ), MemoryQuarantineStorage.append(
                MemoryLegacyMigrationReceipt(
                    receiptId: MemoryStoragePolicy.sha256(
                        "memory-map-receipt-v2|\(storageKey)|\(record.contentHash)|\(reason.rawValue)"
                    ),
                    surfaceId: "memoryMapPresentation",
                    sourceStorageKey: storageKey,
                    quarantineStorageKey: MemoryQuarantineStorage.deviceStorageKey,
                    ownerEvidence: "none",
                    state: .quarantined,
                    reason: reason,
                    sourceContentHash: record.contentHash,
                    itemIds: record.itemIds,
                    createdAt: Date()
                ),
                quarantineStorageKey: MemoryQuarantineStorage.deviceStorageKey,
                defaults: defaults
            ) else {
                return false
            }
            if defaults.object(forKey: storageKey) != nil {
                defaults.removeObject(forKey: storageKey)
            }
        }
        return true
    }

    @discardableResult
    private func quarantine(
        _ data: Data,
        sourceStorageKey: String,
        quarantineStorageKey: String,
        reason: MemoryQuarantineReason,
        itemIds: [String]
    ) -> Bool {
        let record = MemoryStoragePolicy.quarantineRecord(
            sourceStorageKey: sourceStorageKey,
            reason: reason,
            itemIds: itemIds,
            payload: data
        )
        guard MemoryQuarantineStorage.append(
            record,
            storageKey: quarantineStorageKey,
            defaults: defaults
        ), MemoryQuarantineStorage.append(
            MemoryLegacyMigrationReceipt(
                receiptId: MemoryStoragePolicy.sha256(
                    "memory-map-receipt-v2|\(sourceStorageKey)|\(record.contentHash)|\(reason.rawValue)"
                ),
                surfaceId: "memoryMapPresentation",
                sourceStorageKey: sourceStorageKey,
                quarantineStorageKey: quarantineStorageKey,
                ownerEvidence: "rejectedEnvelope",
                state: .quarantined,
                reason: reason,
                sourceContentHash: record.contentHash,
                itemIds: record.itemIds,
                createdAt: Date()
            ),
            quarantineStorageKey: quarantineStorageKey,
            defaults: defaults
        ) else {
            return false
        }
        if defaults.data(forKey: sourceStorageKey) == data {
            defaults.removeObject(forKey: sourceStorageKey)
        }
        return true
    }

    private func withLock<Result>(_ operation: () -> Result) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}
