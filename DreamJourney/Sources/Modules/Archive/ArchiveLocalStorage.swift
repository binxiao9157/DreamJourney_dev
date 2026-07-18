import CryptoKit
import Foundation

enum ArchiveQuarantineReason: String, Codable, CaseIterable {
    case missingOwner
    case ambiguousOwner
    case mismatch
    case corrupt
}

enum ArchiveLegacyState: String, Codable {
    case owned
    case quarantined
}

enum ArchiveEnvelopeValidation: String, Codable, Equatable {
    case accepted
    case mismatch
    case corrupt
}

struct ArchiveStorageScope: Equatable {
    static let storeSchemaVersion = 2

    let subjectId: String
    let vaultId: String
    let archiveOwnerId: String
    let generation: UInt64
    let generationId: UUID

    init(accountLease: AccountLease, archiveOwnerId: String) {
        subjectId = Self.normalized(accountLease.subjectId)
        vaultId = Self.normalized(accountLease.vaultId)
        self.archiveOwnerId = Self.normalized(archiveOwnerId)
        generation = accountLease.generation
        generationId = accountLease.generationId
    }

    var storageKey: String {
        "dj.memoryArchive.items.v2.\(scopeDigest)"
    }

    var legacyStorageKey: String {
        "dj.memoryArchive.items.\(archiveOwnerId)"
    }

    var legacySourceEvidenceStorageKey: String {
        "dj.memoryArchive.legacySourceEvidence.v1.\(legacySourceLocatorHash)"
    }

    var quarantineStorageKey: String {
        "dj.memoryArchive.quarantine.v1.\(scopeDigest)"
    }

    var migrationReceiptStorageKey: String {
        "dj.memoryArchive.migrationReceipts.v1.\(scopeDigest)"
    }

    var mediaDirectoryRelativePath: String {
        "DreamJourney/Archive/v2/\(scopeDigest)"
    }

    var isValid: Bool {
        !subjectId.isEmpty && !vaultId.isEmpty && !archiveOwnerId.isEmpty
    }

    fileprivate var scopeDigest: String {
        ArchiveLocalStoragePolicy.sha256(
            "archive-scope-v2|\(subjectId)|\(vaultId)|\(archiveOwnerId)"
        )
    }

    fileprivate var legacySourceLocatorHash: String {
        ArchiveLocalStoragePolicy.sha256(
            "archive-legacy-source-v1|\(legacyStorageKey)"
        )
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ArchiveStoreEnvelope: Codable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let archiveOwnerId: String
    let generation: UInt64
    let generationId: UUID
    let legacyState: ArchiveLegacyState
    var contentHash: String
    let items: [MemoryArchiveItem]
}

struct ArchiveQuarantinedItem {
    let item: MemoryArchiveItem
    let reason: ArchiveQuarantineReason
}

struct ArchiveLegacyPartition {
    let accepted: [MemoryArchiveItem]
    let quarantined: [ArchiveQuarantinedItem]
}

struct ArchiveLegacySourceEvidence: Codable, Equatable {
    static let schemaVersion = 1

    let evidenceSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let archiveOwnerId: String
    let sourceLocatorHash: String
    let sourceContentHash: String
    let recordedAt: Date
}

struct ArchiveVerifiedLegacySource {
    fileprivate let scopeDigest: String
    fileprivate let sourceContentHash: String

    fileprivate init(scopeDigest: String, sourceContentHash: String) {
        self.scopeDigest = scopeDigest
        self.sourceContentHash = sourceContentHash
    }
}

struct ArchiveQuarantineObservation: Codable, Equatable {
    let scopeDigest: String
    let subjectDigest: String
    let vaultDigest: String
    let archiveOwnerDigest: String
    let reason: ArchiveQuarantineReason
    let observedAt: Date
}

struct ArchiveQuarantineRecord: Codable {
    let recordId: String
    let reason: ArchiveQuarantineReason
    let sourceLocatorHash: String
    var itemIds: [String]
    let payload: Data
    let contentHash: String
    let createdAt: Date
    var observations: [ArchiveQuarantineObservation]

    private enum CodingKeys: String, CodingKey {
        case recordId
        case reason
        case sourceLocatorHash
        case sourceStorageKey
        case itemIds
        case payload
        case contentHash
        case createdAt
        case observations
    }

    init(
        recordId: String,
        reason: ArchiveQuarantineReason,
        sourceLocatorHash: String,
        itemIds: [String],
        payload: Data,
        contentHash: String,
        createdAt: Date,
        observations: [ArchiveQuarantineObservation]
    ) {
        self.recordId = recordId
        self.reason = reason
        self.sourceLocatorHash = sourceLocatorHash
        self.itemIds = itemIds
        self.payload = payload
        self.contentHash = contentHash
        self.createdAt = createdAt
        self.observations = observations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recordId = try container.decode(String.self, forKey: .recordId)
        reason = try container.decode(ArchiveQuarantineReason.self, forKey: .reason)
        if let locatorHash = try container.decodeIfPresent(String.self, forKey: .sourceLocatorHash) {
            sourceLocatorHash = locatorHash
        } else {
            let legacySourceKey = try container.decode(String.self, forKey: .sourceStorageKey)
            sourceLocatorHash = ArchiveLocalStoragePolicy.sha256(
                "archive-quarantine-source-v1|\(legacySourceKey)"
            )
        }
        itemIds = try container.decode([String].self, forKey: .itemIds)
        payload = try container.decode(Data.self, forKey: .payload)
        contentHash = try container.decode(String.self, forKey: .contentHash)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        observations = try container.decodeIfPresent(
            [ArchiveQuarantineObservation].self,
            forKey: .observations
        ) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordId, forKey: .recordId)
        try container.encode(reason, forKey: .reason)
        try container.encode(sourceLocatorHash, forKey: .sourceLocatorHash)
        try container.encode(itemIds, forKey: .itemIds)
        try container.encode(payload, forKey: .payload)
        try container.encode(contentHash, forKey: .contentHash)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(observations, forKey: .observations)
    }
}

struct ArchiveLegacyMigrationReceipt: Codable {
    enum State: String, Codable {
        case migrated
        case quarantined
        case mixed
    }

    let receiptId: String
    let sourceStorageKey: String
    let destinationStorageKey: String
    let subjectId: String
    let vaultId: String
    let archiveOwnerId: String
    let state: State
    let migratedItemIds: [String]
    let quarantinedItemIds: [String]
    let sourceContentHash: String
    let createdAt: Date
}

struct ArchiveLocalStorageLoadResult {
    let items: [MemoryArchiveItem]
    let migratedLegacyData: Bool
    let quarantinedItemCount: Int
}

struct ArchiveStorageRegistryEntry: Codable, Equatable {
    let subjectDigest: String
    let vaultDigest: String
    let scopeDigest: String
    let storageKey: String
    let quarantineStorageKey: String
    let migrationReceiptStorageKey: String
    let mediaDirectoryRelativePath: String
}

enum ArchiveLocalStorageError: Error {
    case invalidScope
    case ownerMismatch
    case encodingFailed
}

enum ArchiveLocalStoragePolicy {
    static func makeEnvelope(
        items: [MemoryArchiveItem],
        scope: ArchiveStorageScope
    ) throws -> ArchiveStoreEnvelope {
        guard scope.isValid else { throw ArchiveLocalStorageError.invalidScope }
        guard items.allSatisfy({ normalizedOwner($0.ownerUserId) == scope.archiveOwnerId }) else {
            throw ArchiveLocalStorageError.ownerMismatch
        }
        return ArchiveStoreEnvelope(
            storeSchemaVersion: ArchiveStorageScope.storeSchemaVersion,
            subjectId: scope.subjectId,
            vaultId: scope.vaultId,
            archiveOwnerId: scope.archiveOwnerId,
            generation: scope.generation,
            generationId: scope.generationId,
            legacyState: .owned,
            contentHash: try itemsContentHash(items),
            items: items
        )
    }

    static func validate(
        _ envelope: ArchiveStoreEnvelope,
        expectedScope: ArchiveStorageScope
    ) -> ArchiveEnvelopeValidation {
        guard expectedScope.isValid,
              envelope.storeSchemaVersion == ArchiveStorageScope.storeSchemaVersion,
              envelope.subjectId == expectedScope.subjectId,
              envelope.vaultId == expectedScope.vaultId,
              envelope.archiveOwnerId == expectedScope.archiveOwnerId,
              envelope.legacyState == .owned,
              envelope.items.allSatisfy({ normalizedOwner($0.ownerUserId) == expectedScope.archiveOwnerId }) else {
            return .mismatch
        }
        guard let expectedHash = try? itemsContentHash(envelope.items),
              envelope.contentHash == expectedHash else {
            return .corrupt
        }
        return .accepted
    }

    static func verifiedLegacySource(
        evidence: ArchiveLegacySourceEvidence,
        sourceData: Data,
        expectedScope: ArchiveStorageScope
    ) -> ArchiveVerifiedLegacySource? {
        guard expectedScope.isValid,
              evidence.evidenceSchemaVersion == ArchiveLegacySourceEvidence.schemaVersion,
              normalizedOwner(evidence.subjectId) == expectedScope.subjectId,
              normalizedOwner(evidence.vaultId) == expectedScope.vaultId,
              normalizedOwner(evidence.archiveOwnerId) == expectedScope.archiveOwnerId,
              evidence.sourceLocatorHash == expectedScope.legacySourceLocatorHash,
              evidence.sourceContentHash == sha256(sourceData) else {
            return nil
        }
        return ArchiveVerifiedLegacySource(
            scopeDigest: expectedScope.scopeDigest,
            sourceContentHash: evidence.sourceContentHash
        )
    }

    static func partitionLegacyItems(
        _ items: [MemoryArchiveItem],
        expectedScope: ArchiveStorageScope,
        verifiedSource: ArchiveVerifiedLegacySource
    ) -> ArchiveLegacyPartition {
        let expectedOwner = normalizedOwner(expectedScope.archiveOwnerId)
        var accepted: [MemoryArchiveItem] = []
        var quarantined: [ArchiveQuarantinedItem] = []

        guard verifiedSource.scopeDigest == expectedScope.scopeDigest,
              !verifiedSource.sourceContentHash.isEmpty else {
            return ArchiveLegacyPartition(
                accepted: [],
                quarantined: items.map {
                    ArchiveQuarantinedItem(item: $0, reason: .ambiguousOwner)
                }
            )
        }

        for item in items {
            let owner = normalizedOwner(item.ownerUserId)
            if owner.isEmpty || owner == MemoryArchiveItem.legacyOwnerUserId {
                quarantined.append(ArchiveQuarantinedItem(item: item, reason: .missingOwner))
            } else if expectedOwner.isEmpty {
                quarantined.append(ArchiveQuarantinedItem(item: item, reason: .ambiguousOwner))
            } else if owner != expectedOwner {
                quarantined.append(ArchiveQuarantinedItem(item: item, reason: .mismatch))
            } else {
                accepted.append(item)
            }
        }
        return ArchiveLegacyPartition(accepted: accepted, quarantined: quarantined)
    }

    static func merge(
        remoteItems: [MemoryArchiveItem],
        localItems: [MemoryArchiveItem],
        expectedArchiveOwnerId: String
    ) -> [MemoryArchiveItem] {
        let expectedOwner = normalizedOwner(expectedArchiveOwnerId)
        let validLocalItems = localItems.filter { normalizedOwner($0.ownerUserId) == expectedOwner }
        let validRemoteItems = remoteItems.filter { normalizedOwner($0.ownerUserId) == expectedOwner }
        var itemsById: [String: MemoryArchiveItem] = [:]

        for item in validLocalItems {
            if let existing = itemsById[item.id], existing.updatedAt >= item.updatedAt {
                continue
            }
            itemsById[item.id] = item
        }

        for remoteItem in validRemoteItems {
            guard let localItem = itemsById[remoteItem.id] else {
                itemsById[remoteItem.id] = remoteItem
                continue
            }
            let selected = remoteItem.updatedAt >= localItem.updatedAt ? remoteItem : localItem
            itemsById[remoteItem.id] = selected
        }

        return itemsById.values.sorted { $0.createdAt > $1.createdAt }
    }

    static func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    static func sha256(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func encodedItems(_ items: [MemoryArchiveItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(items.sorted { $0.id < $1.id })
    }

    private static func itemsContentHash(_ items: [MemoryArchiveItem]) throws -> String {
        sha256(try encodedItems(items))
    }

    private static func normalizedOwner(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class ArchiveLocalStorage {
    static let shared = ArchiveLocalStorage()
    static let deviceQuarantineStorageKey = "dj.memoryArchive.quarantine.device.v2"

    private let scopeRegistryKey = "dj.memoryArchive.scopeRegistry.v1"
    private let defaults: UserDefaults
    private let lock = NSRecursiveLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(scope: ArchiveStorageScope) -> ArchiveLocalStorageLoadResult {
        lock.lock()
        defer { lock.unlock() }
        guard scope.isValid else {
            return ArchiveLocalStorageLoadResult(
                items: [],
                migratedLegacyData: false,
                quarantinedItemCount: 0
            )
        }
        register(scope: scope)

        if let data = defaults.data(forKey: scope.storageKey) {
            guard let envelope = try? decoder.decode(ArchiveStoreEnvelope.self, from: data) else {
                let quarantined = quarantineScopedPayload(
                    data,
                    sourceStorageKey: scope.storageKey,
                    itemIds: [],
                    reason: .corrupt,
                    scope: scope
                )
                if quarantined {
                    defaults.removeObject(forKey: scope.storageKey)
                }
                return ArchiveLocalStorageLoadResult(
                    items: [],
                    migratedLegacyData: false,
                    quarantinedItemCount: quarantined ? 1 : 0
                )
            }
            let quarantined: Bool
            switch ArchiveLocalStoragePolicy.validate(envelope, expectedScope: scope) {
            case .accepted:
                let retiredInterruptedLegacyWrite = retireLegacyDataAfterEnvelopeCommitIfNeeded(
                    scope: scope,
                    authoritativeItems: envelope.items
                )
                return ArchiveLocalStorageLoadResult(
                    items: envelope.items,
                    migratedLegacyData: retiredInterruptedLegacyWrite,
                    quarantinedItemCount: 0
                )
            case .mismatch:
                quarantined = quarantineScopedPayload(
                    data,
                    sourceStorageKey: scope.storageKey,
                    itemIds: envelope.items.map(\.id),
                    reason: .mismatch,
                    scope: scope
                )
            case .corrupt:
                quarantined = quarantineScopedPayload(
                    data,
                    sourceStorageKey: scope.storageKey,
                    itemIds: envelope.items.map(\.id),
                    reason: .corrupt,
                    scope: scope
                )
            }
            if quarantined {
                defaults.removeObject(forKey: scope.storageKey)
            }
            return ArchiveLocalStorageLoadResult(
                items: [],
                migratedLegacyData: false,
                quarantinedItemCount: quarantined ? 1 : 0
            )
        }

        return migrateLegacyDataIfNeeded(scope: scope)
    }

    func save(items: [MemoryArchiveItem], scope: ArchiveStorageScope) throws {
        lock.lock()
        defer { lock.unlock() }
        register(scope: scope)
        let envelope = try ArchiveLocalStoragePolicy.makeEnvelope(items: items, scope: scope)
        guard let data = try? encoder.encode(envelope) else {
            throw ArchiveLocalStorageError.encodingFailed
        }
        defaults.set(data, forKey: scope.storageKey)
    }

    func purge(scope: ArchiveStorageScope) {
        lock.lock()
        defer { lock.unlock() }
        defaults.removeObject(forKey: scope.storageKey)
        defaults.removeObject(forKey: scope.quarantineStorageKey)
        defaults.removeObject(forKey: scope.migrationReceiptStorageKey)
        var entries = scopeRegistryEntries()
        entries.removeAll { $0.scopeDigest == scope.scopeDigest }
        saveScopeRegistryEntries(entries)
    }

    func mediaDirectoryRelativePaths(accountLease: AccountLease) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let subjectDigest = ArchiveLocalStoragePolicy.sha256(
            "archive-subject-v1|\(accountLease.subjectId)"
        )
        let vaultDigest = ArchiveLocalStoragePolicy.sha256(
            "archive-vault-v1|\(accountLease.vaultId)"
        )
        return scopeRegistryEntries()
            .filter { $0.subjectDigest == subjectDigest && $0.vaultDigest == vaultDigest }
            .map(\.mediaDirectoryRelativePath)
    }

    @discardableResult
    func purgeAccount(accountLease: AccountLease) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let subjectDigest = ArchiveLocalStoragePolicy.sha256(
            "archive-subject-v1|\(accountLease.subjectId)"
        )
        let vaultDigest = ArchiveLocalStoragePolicy.sha256(
            "archive-vault-v1|\(accountLease.vaultId)"
        )
        var entries = scopeRegistryEntries()
        let accountEntries = entries.filter {
            $0.subjectDigest == subjectDigest && $0.vaultDigest == vaultDigest
        }
        for entry in accountEntries {
            defaults.removeObject(forKey: entry.storageKey)
            defaults.removeObject(forKey: entry.quarantineStorageKey)
            defaults.removeObject(forKey: entry.migrationReceiptStorageKey)
        }
        entries.removeAll {
            $0.subjectDigest == subjectDigest && $0.vaultDigest == vaultDigest
        }
        saveScopeRegistryEntries(entries)
        return accountEntries.map(\.mediaDirectoryRelativePath)
    }

    func migrationReceipts(scope: ArchiveStorageScope) -> [ArchiveLegacyMigrationReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return decodedArray(
            ArchiveLegacyMigrationReceipt.self,
            key: scope.migrationReceiptStorageKey
        )
    }

    func quarantineRecords(scope: ArchiveStorageScope) -> [ArchiveQuarantineRecord] {
        lock.lock()
        defer { lock.unlock() }
        return decodedArray(
            ArchiveQuarantineRecord.self,
            key: scope.quarantineStorageKey
        )
    }

    func deviceQuarantineRecords() -> [ArchiveQuarantineRecord] {
        lock.lock()
        defer { lock.unlock() }
        return decodedArray(
            ArchiveQuarantineRecord.self,
            key: Self.deviceQuarantineStorageKey
        )
    }

    private func migrateLegacyDataIfNeeded(
        scope: ArchiveStorageScope
    ) -> ArchiveLocalStorageLoadResult {
        guard let sourceData = defaults.data(forKey: scope.legacyStorageKey) else {
            return ArchiveLocalStorageLoadResult(
                items: [],
                migratedLegacyData: false,
                quarantinedItemCount: 0
            )
        }

        let decodedLegacyItems = try? decoder.decode([MemoryArchiveItem].self, from: sourceData)
        let verification = legacySourceVerification(sourceData: sourceData, scope: scope)
        guard let verifiedSource = verification.verifiedSource else {
            let itemIds = decodedLegacyItems?.map(\.id) ?? []
            let quarantined = quarantineLegacyPayload(
                sourceData,
                itemIds: itemIds,
                reason: verification.rejectionReason,
                scope: scope
            )
            return ArchiveLocalStorageLoadResult(
                items: [],
                migratedLegacyData: false,
                quarantinedItemCount: quarantined ? max(itemIds.count, 1) : 0
            )
        }

        guard let legacyItems = decodedLegacyItems else {
            guard quarantineLegacyPayload(
                sourceData,
                itemIds: [],
                reason: .corrupt,
                scope: scope
            ), appendReceipt(
                sourceData: sourceData,
                scope: scope,
                state: .quarantined,
                migratedItemIds: [],
                quarantinedItemIds: []
            ) else {
                return ArchiveLocalStorageLoadResult(
                    items: [],
                    migratedLegacyData: false,
                    quarantinedItemCount: 0
                )
            }
            let retired = retireLegacySourceIfUnchanged(sourceData: sourceData, scope: scope)
            return ArchiveLocalStorageLoadResult(
                items: [],
                migratedLegacyData: retired,
                quarantinedItemCount: 1
            )
        }

        let partition = ArchiveLocalStoragePolicy.partitionLegacyItems(
            legacyItems,
            expectedScope: scope,
            verifiedSource: verifiedSource
        )
        if !partition.accepted.isEmpty {
            do {
                try save(items: partition.accepted, scope: scope)
            } catch {
                return ArchiveLocalStorageLoadResult(
                    items: [],
                    migratedLegacyData: false,
                    quarantinedItemCount: 0
                )
            }
        }

        if !partition.quarantined.isEmpty {
            let reason = aggregateReason(for: partition.quarantined)
            guard quarantineLegacyPayload(
                sourceData,
                itemIds: partition.quarantined.map(\.item.id),
                reason: reason,
                scope: scope
            ) else {
                return ArchiveLocalStorageLoadResult(
                    items: partition.accepted,
                    migratedLegacyData: false,
                    quarantinedItemCount: 0
                )
            }
        }

        let receiptState: ArchiveLegacyMigrationReceipt.State
        if partition.accepted.isEmpty {
            receiptState = .quarantined
        } else if partition.quarantined.isEmpty {
            receiptState = .migrated
        } else {
            receiptState = .mixed
        }
        guard appendReceipt(
            sourceData: sourceData,
            scope: scope,
            state: receiptState,
            migratedItemIds: partition.accepted.map(\.id),
            quarantinedItemIds: partition.quarantined.map(\.item.id)
        ) else {
            return ArchiveLocalStorageLoadResult(
                items: partition.accepted,
                migratedLegacyData: false,
                quarantinedItemCount: partition.quarantined.count
            )
        }
        let retired = retireLegacySourceIfUnchanged(sourceData: sourceData, scope: scope)

        return ArchiveLocalStorageLoadResult(
            items: partition.accepted,
            migratedLegacyData: retired,
            quarantinedItemCount: partition.quarantined.count
        )
    }

    private func retireLegacyDataAfterEnvelopeCommitIfNeeded(
        scope: ArchiveStorageScope,
        authoritativeItems: [MemoryArchiveItem]
    ) -> Bool {
        guard let sourceData = defaults.data(forKey: scope.legacyStorageKey) else {
            return false
        }

        let verification = legacySourceVerification(sourceData: sourceData, scope: scope)
        guard let verifiedSource = verification.verifiedSource else {
            let itemIds = (try? decoder.decode([MemoryArchiveItem].self, from: sourceData))?.map(\.id) ?? []
            _ = quarantineLegacyPayload(
                sourceData,
                itemIds: itemIds,
                reason: verification.rejectionReason,
                scope: scope
            )
            return false
        }

        guard let legacyItems = try? decoder.decode([MemoryArchiveItem].self, from: sourceData) else {
            guard quarantineLegacyPayload(
                sourceData,
                itemIds: [],
                reason: .corrupt,
                scope: scope
            ), appendReceipt(
                sourceData: sourceData,
                scope: scope,
                state: .quarantined,
                migratedItemIds: [],
                quarantinedItemIds: []
            ) else {
                return false
            }
            return retireLegacySourceIfUnchanged(sourceData: sourceData, scope: scope)
        }

        let partition = ArchiveLocalStoragePolicy.partitionLegacyItems(
            legacyItems,
            expectedScope: scope,
            verifiedSource: verifiedSource
        )
        let authoritativeHash = try? ArchiveLocalStoragePolicy.encodedItems(authoritativeItems)
        let acceptedHash = try? ArchiveLocalStoragePolicy.encodedItems(partition.accepted)
        guard authoritativeHash == acceptedHash else {
            _ = quarantineLegacyPayload(
                sourceData,
                itemIds: legacyItems.map(\.id),
                reason: .ambiguousOwner,
                scope: scope
            )
            return false
        }

        if !partition.quarantined.isEmpty {
            guard quarantineLegacyPayload(
                sourceData,
                itemIds: partition.quarantined.map(\.item.id),
                reason: aggregateReason(for: partition.quarantined),
                scope: scope
            ) else {
                return false
            }
        }
        let state: ArchiveLegacyMigrationReceipt.State = partition.quarantined.isEmpty
            ? .migrated
            : .mixed
        guard appendReceipt(
            sourceData: sourceData,
            scope: scope,
            state: state,
            migratedItemIds: partition.accepted.map(\.id),
            quarantinedItemIds: partition.quarantined.map(\.item.id)
        ) else {
            return false
        }
        return retireLegacySourceIfUnchanged(sourceData: sourceData, scope: scope)
    }

    private func legacySourceVerification(
        sourceData: Data,
        scope: ArchiveStorageScope
    ) -> (
        verifiedSource: ArchiveVerifiedLegacySource?,
        rejectionReason: ArchiveQuarantineReason
    ) {
        guard let evidenceData = defaults.data(forKey: scope.legacySourceEvidenceStorageKey) else {
            guard scope.subjectId == scope.archiveOwnerId else {
                return (nil, .ambiguousOwner)
            }
            guard let items = try? decoder.decode([MemoryArchiveItem].self, from: sourceData) else {
                return (nil, .corrupt)
            }
            let hasOnlySelfOrUnassignedItems = items.allSatisfy { item in
                let owner = item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
                return owner.isEmpty
                    || owner == MemoryArchiveItem.legacyOwnerUserId
                    || owner == scope.subjectId
            }
            guard hasOnlySelfOrUnassignedItems else {
                return (nil, .mismatch)
            }
            return (
                ArchiveVerifiedLegacySource(
                    scopeDigest: scope.scopeDigest,
                    sourceContentHash: ArchiveLocalStoragePolicy.sha256(sourceData)
                ),
                .ambiguousOwner
            )
        }
        guard let evidence = try? decoder.decode(
            ArchiveLegacySourceEvidence.self,
            from: evidenceData
        ) else {
            return (nil, .corrupt)
        }
        guard let verifiedSource = ArchiveLocalStoragePolicy.verifiedLegacySource(
            evidence: evidence,
            sourceData: sourceData,
            expectedScope: scope
        ) else {
            return (nil, .mismatch)
        }
        return (verifiedSource, .ambiguousOwner)
    }

    private func retireLegacySourceIfUnchanged(
        sourceData: Data,
        scope: ArchiveStorageScope
    ) -> Bool {
        guard defaults.data(forKey: scope.legacyStorageKey) == sourceData,
              legacySourceVerification(
                  sourceData: sourceData,
                  scope: scope
              ).verifiedSource != nil else {
            return false
        }
        defaults.removeObject(forKey: scope.legacyStorageKey)
        defaults.removeObject(forKey: scope.legacySourceEvidenceStorageKey)
        return defaults.data(forKey: scope.legacyStorageKey) == nil
    }

    private func aggregateReason(
        for quarantinedItems: [ArchiveQuarantinedItem]
    ) -> ArchiveQuarantineReason {
        let reasons = quarantinedItems.map(\.reason)
        if reasons.contains(.mismatch) {
            return .mismatch
        }
        if reasons.allSatisfy({ $0 == .missingOwner }) {
            return .missingOwner
        }
        return .ambiguousOwner
    }

    @discardableResult
    private func quarantineScopedPayload(
        _ payload: Data,
        sourceStorageKey: String,
        itemIds: [String],
        reason: ArchiveQuarantineReason,
        scope: ArchiveStorageScope
    ) -> Bool {
        quarantinePayload(
            payload,
            sourceLocatorHash: ArchiveLocalStoragePolicy.sha256(
                "archive-quarantine-source-v1|\(sourceStorageKey)"
            ),
            itemIds: itemIds,
            reason: reason,
            scope: scope,
            quarantineStorageKey: scope.quarantineStorageKey
        )
    }

    @discardableResult
    private func quarantineLegacyPayload(
        _ payload: Data,
        itemIds: [String],
        reason: ArchiveQuarantineReason,
        scope: ArchiveStorageScope
    ) -> Bool {
        quarantinePayload(
            payload,
            sourceLocatorHash: scope.legacySourceLocatorHash,
            itemIds: itemIds,
            reason: reason,
            scope: scope,
            quarantineStorageKey: Self.deviceQuarantineStorageKey
        )
    }

    private func quarantinePayload(
        _ payload: Data,
        sourceLocatorHash: String,
        itemIds: [String],
        reason: ArchiveQuarantineReason,
        scope: ArchiveStorageScope,
        quarantineStorageKey: String
    ) -> Bool {
        var records = decodedArray(ArchiveQuarantineRecord.self, key: quarantineStorageKey)
        let contentHash = ArchiveLocalStoragePolicy.sha256(payload)
        let observation = ArchiveQuarantineObservation(
            scopeDigest: scope.scopeDigest,
            subjectDigest: ArchiveLocalStoragePolicy.sha256(
                "archive-subject-v1|\(scope.subjectId)"
            ),
            vaultDigest: ArchiveLocalStoragePolicy.sha256(
                "archive-vault-v1|\(scope.vaultId)"
            ),
            archiveOwnerDigest: ArchiveLocalStoragePolicy.sha256(
                "archive-owner-v1|\(scope.archiveOwnerId)"
            ),
            reason: reason,
            observedAt: Date()
        )
        if let index = records.firstIndex(where: {
            $0.sourceLocatorHash == sourceLocatorHash && $0.contentHash == contentHash
        }) {
            records[index].itemIds = Array(Set(records[index].itemIds + itemIds)).sorted()
            if !records[index].observations.contains(where: {
                $0.scopeDigest == observation.scopeDigest && $0.reason == observation.reason
            }) {
                records[index].observations.append(observation)
            }
        } else {
            records.append(
                ArchiveQuarantineRecord(
                    recordId: ArchiveLocalStoragePolicy.sha256(
                        "archive-quarantine-record-v2|\(sourceLocatorHash)|\(contentHash)"
                    ),
                    reason: reason,
                    sourceLocatorHash: sourceLocatorHash,
                    itemIds: Array(Set(itemIds)).sorted(),
                    payload: payload,
                    contentHash: contentHash,
                    createdAt: Date(),
                    observations: [observation]
                )
            )
        }
        guard let data = try? encoder.encode(records) else { return false }
        defaults.set(data, forKey: quarantineStorageKey)
        return decodedArray(ArchiveQuarantineRecord.self, key: quarantineStorageKey).contains {
            $0.sourceLocatorHash == sourceLocatorHash && $0.contentHash == contentHash
        }
    }

    @discardableResult
    private func appendReceipt(
        sourceData: Data,
        scope: ArchiveStorageScope,
        state: ArchiveLegacyMigrationReceipt.State,
        migratedItemIds: [String],
        quarantinedItemIds: [String]
    ) -> Bool {
        var receipts = decodedArray(
            ArchiveLegacyMigrationReceipt.self,
            key: scope.migrationReceiptStorageKey
        )
        let sourceHash = ArchiveLocalStoragePolicy.sha256(sourceData)
        guard !receipts.contains(where: {
            $0.sourceStorageKey == scope.legacyStorageKey && $0.sourceContentHash == sourceHash
        }) else {
            return true
        }
        receipts.append(
            ArchiveLegacyMigrationReceipt(
                receiptId: UUID().uuidString,
                sourceStorageKey: scope.legacyStorageKey,
                destinationStorageKey: scope.storageKey,
                subjectId: scope.subjectId,
                vaultId: scope.vaultId,
                archiveOwnerId: scope.archiveOwnerId,
                state: state,
                migratedItemIds: migratedItemIds,
                quarantinedItemIds: quarantinedItemIds,
                sourceContentHash: sourceHash,
                createdAt: Date()
            )
        )
        guard let data = try? encoder.encode(receipts) else { return false }
        defaults.set(data, forKey: scope.migrationReceiptStorageKey)
        return decodedArray(
            ArchiveLegacyMigrationReceipt.self,
            key: scope.migrationReceiptStorageKey
        ).contains {
            $0.sourceStorageKey == scope.legacyStorageKey && $0.sourceContentHash == sourceHash
        }
    }

    private func decodedArray<T: Decodable>(_ type: T.Type, key: String) -> [T] {
        guard let data = defaults.data(forKey: key),
              let values = try? decoder.decode([T].self, from: data) else {
            return []
        }
        return values
    }

    private func register(scope: ArchiveStorageScope) {
        let entry = ArchiveStorageRegistryEntry(
            subjectDigest: ArchiveLocalStoragePolicy.sha256(
                "archive-subject-v1|\(scope.subjectId)"
            ),
            vaultDigest: ArchiveLocalStoragePolicy.sha256(
                "archive-vault-v1|\(scope.vaultId)"
            ),
            scopeDigest: scope.scopeDigest,
            storageKey: scope.storageKey,
            quarantineStorageKey: scope.quarantineStorageKey,
            migrationReceiptStorageKey: scope.migrationReceiptStorageKey,
            mediaDirectoryRelativePath: scope.mediaDirectoryRelativePath
        )
        var entries = scopeRegistryEntries()
        guard !entries.contains(where: { $0.scopeDigest == entry.scopeDigest }) else {
            return
        }
        entries.append(entry)
        saveScopeRegistryEntries(entries)
    }

    private func scopeRegistryEntries() -> [ArchiveStorageRegistryEntry] {
        decodedArray(ArchiveStorageRegistryEntry.self, key: scopeRegistryKey)
    }

    private func saveScopeRegistryEntries(_ entries: [ArchiveStorageRegistryEntry]) {
        if entries.isEmpty {
            defaults.removeObject(forKey: scopeRegistryKey)
            return
        }
        if let data = try? encoder.encode(entries) {
            defaults.set(data, forKey: scopeRegistryKey)
        }
    }
}
