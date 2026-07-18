import CryptoKit
import Foundation

struct EchoDelayedReply: Codable, Equatable {
    let id: String
    let scheduledAt: Date
    let deliverAt: Date
    let minutes: Int
    let userTurnCount: Int
    let trigger: EchoDelayedReplyTrigger
}

enum EchoDelayedReplyTrigger: String, Codable {
    case tenRoundBaseline
    case contentSignal
}

struct EchoDelayedReplyOperationScope: Equatable {
    let accountLease: AccountLease
    let resourceOwnerId: String
    let operationId: String

    init?(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) {
        guard Self.normalized(accountLease.subjectId) != nil,
              Self.normalized(accountLease.vaultId) != nil,
              Self.normalized(accountLease.authorityEpoch) != nil,
              let normalizedResourceOwnerId = Self.normalized(resourceOwnerId),
              let normalizedOperationId = Self.normalized(operationId) else {
            return nil
        }
        self.accountLease = accountLease
        self.resourceOwnerId = normalizedResourceOwnerId
        self.operationId = normalizedOperationId
    }

    var storageIdentity: String {
        Self.identityDigest(
            values: leaseIdentityValues
                + ["resource-owner", resourceOwnerId, "operation", operationId]
        )
    }

    var operationIndexIdentity: String {
        Self.identityDigest(
            values: leaseIdentityValues + ["resource-owner", resourceOwnerId, "operation-index"]
        )
    }

    var notificationIdentifier: String {
        "\(EchoDelayedReplyNotificationScheduler.notificationIdentifier).\(storageIdentity)"
    }

    var subjectIdentity: String {
        Self.identityDigest(values: ["subject", accountLease.subjectId])
    }

    var vaultIdentity: String {
        Self.identityDigest(values: ["vault", accountLease.vaultId])
    }

    var authorityEpochIdentity: String {
        Self.identityDigest(values: ["authority-epoch", accountLease.authorityEpoch])
    }

    var resourceOwnerIdentity: String {
        Self.identityDigest(values: ["resource-owner", resourceOwnerId])
    }

    var operationIdentity: String {
        Self.identityDigest(values: ["operation", operationId])
    }

    private var leaseIdentityValues: [String] {
        [
            "subject", accountLease.subjectId,
            "vault", accountLease.vaultId,
            "generation", String(accountLease.generation),
            "generation-id", accountLease.generationId.uuidString,
            "authority-epoch", accountLease.authorityEpoch,
        ]
    }

    static func identityDigest(values: [String]) -> String {
        let canonicalIdentity = values
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
        return SHA256.hash(data: Data(canonicalIdentity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func normalized(_ value: String) -> String? {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedValue.isEmpty ? nil : normalizedValue
    }
}

private struct EchoDelayedReplyEnvelope: Codable {
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
    let resourceOwnerId: String
    let operationId: String
    let reply: EchoDelayedReply

    init(reply: EchoDelayedReply, scope: EchoDelayedReplyOperationScope) {
        subjectId = scope.accountLease.subjectId
        vaultId = scope.accountLease.vaultId
        generation = scope.accountLease.generation
        generationId = scope.accountLease.generationId
        authorityEpoch = scope.accountLease.authorityEpoch
        resourceOwnerId = scope.resourceOwnerId
        operationId = scope.operationId
        self.reply = reply
    }

    func matchesOwnership(_ scope: EchoDelayedReplyOperationScope) -> Bool {
        subjectId == scope.accountLease.subjectId
            && vaultId == scope.accountLease.vaultId
            && generation == scope.accountLease.generation
            && generationId == scope.accountLease.generationId
            && authorityEpoch == scope.accountLease.authorityEpoch
            && resourceOwnerId == scope.resourceOwnerId
            && operationId == scope.operationId
    }

    func matchesLifecycleLease(_ accountLease: AccountLease) -> Bool {
        subjectId == accountLease.subjectId
            && vaultId == accountLease.vaultId
            && generation == accountLease.generation
            && generationId == accountLease.generationId
            && authorityEpoch == accountLease.authorityEpoch
    }
}

private struct EchoDelayedReplyOperationIndexEnvelope: Codable {
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
    let resourceOwnerId: String
    let operationId: String

    init(scope: EchoDelayedReplyOperationScope) {
        subjectId = scope.accountLease.subjectId
        vaultId = scope.accountLease.vaultId
        generation = scope.accountLease.generation
        generationId = scope.accountLease.generationId
        authorityEpoch = scope.accountLease.authorityEpoch
        resourceOwnerId = scope.resourceOwnerId
        operationId = scope.operationId
    }

    func matchesLeaseAndOwner(_ scope: EchoDelayedReplyOperationScope) -> Bool {
        subjectId == scope.accountLease.subjectId
            && vaultId == scope.accountLease.vaultId
            && generation == scope.accountLease.generation
            && generationId == scope.accountLease.generationId
            && authorityEpoch == scope.accountLease.authorityEpoch
            && resourceOwnerId == scope.resourceOwnerId
    }

    func matchesOwnership(_ scope: EchoDelayedReplyOperationScope) -> Bool {
        matchesLeaseAndOwner(scope) && operationId == scope.operationId
    }

    func matchesLifecycleLease(_ accountLease: AccountLease) -> Bool {
        subjectId == accountLease.subjectId
            && vaultId == accountLease.vaultId
            && generation == accountLease.generation
            && generationId == accountLease.generationId
            && authorityEpoch == accountLease.authorityEpoch
    }
}

enum EchoDelayedReplyLegacyIsolationReason: String, Codable, Equatable {
    case missingAuthenticatedOwner
}

struct EchoDelayedReplyLegacyIsolationRecord: Codable, Equatable {
    let reason: EchoDelayedReplyLegacyIsolationReason
    let sourceStorageKey: String
    let quarantineStorageKey: String
    let isolatedAt: Date
}

final class EchoDelayedReplyStore {
    static let shared = EchoDelayedReplyStore()

    private let storageNamespace = "dj.echo.delayedReply.scoped.v2"
    private let legacyStorageKey = "dj.echo.delayedReply"
    private let legacyQuarantineStorageKey = "dj.echo.delayedReply.legacy-quarantine.payload"
    private let legacyIsolationReceiptKey = "dj.echo.delayedReply.legacy-quarantine.receipt"
    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let now: () -> Date
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
        self.now = now
    }

    func save(_ reply: EchoDelayedReply) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            return false
        }
        return save(
            reply,
            resourceOwnerId: accountLease.subjectId,
            operationId: reply.id,
            accountLease: accountLease
        )
    }

    func save(
        _ reply: EchoDelayedReply,
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ), accountLeaseRuntime.validate(accountLease, at: .request).allowed,
           let envelopeData = try? JSONEncoder().encode(
               EchoDelayedReplyEnvelope(reply: reply, scope: scope)
           ),
           let indexData = try? JSONEncoder().encode(
               EchoDelayedReplyOperationIndexEnvelope(scope: scope)
           ) else {
            return false
        }

        lock.lock()
        defer { lock.unlock() }
        isolateLegacyPayloadIfNeeded()
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }

        let scopedStorageKey = storageKey(for: scope)
        let indexStorageKey = operationIndexStorageKey(for: scope)
        let previousEnvelopeData = defaults.data(forKey: scopedStorageKey)
        let previousIndexData = defaults.data(forKey: indexStorageKey)
        defaults.set(envelopeData, forKey: scopedStorageKey)
        defaults.set(indexData, forKey: indexStorageKey)

        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            restore(
                previousData: previousEnvelopeData,
                replacing: envelopeData,
                forKey: scopedStorageKey
            )
            restore(
                previousData: previousIndexData,
                replacing: indexData,
                forKey: indexStorageKey
            )
            return false
        }

        retirePreviousOperationIfNeeded(
            previousIndexData: previousIndexData,
            replacingWith: scope
        )
        return true
    }

    func load() -> EchoDelayedReply? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            return nil
        }
        let resourceOwnerId = accountLease.subjectId
        guard let operationId = currentOperationId(
            resourceOwnerId: resourceOwnerId,
            accountLease: accountLease
        ) else {
            return nil
        }
        return load(
            resourceOwnerId: resourceOwnerId,
            operationId: operationId,
            accountLease: accountLease
        )
    }

    func load(
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease
    ) -> EchoDelayedReply? {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ), accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        isolateLegacyPayloadIfNeeded()
        guard let data = defaults.data(forKey: storageKey(for: scope)),
              let envelope = try? JSONDecoder().decode(EchoDelayedReplyEnvelope.self, from: data),
              envelope.matchesOwnership(scope),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        return envelope.reply
    }

    func clear() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            return
        }
        let resourceOwnerId = accountLease.subjectId
        guard let operationId = currentOperationId(
            resourceOwnerId: resourceOwnerId,
            accountLease: accountLease
        ) else {
            return
        }
        _ = clear(
            resourceOwnerId: resourceOwnerId,
            operationId: operationId,
            accountLease: accountLease
        )
    }

    @discardableResult
    func clear(
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease
    ) -> Bool {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ), accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }

        lock.lock()
        defer { lock.unlock() }
        isolateLegacyPayloadIfNeeded()
        let scopedStorageKey = storageKey(for: scope)
        let indexStorageKey = operationIndexStorageKey(for: scope)
        guard let envelopeData = defaults.data(forKey: scopedStorageKey),
              let envelope = try? JSONDecoder().decode(
                  EchoDelayedReplyEnvelope.self,
                  from: envelopeData
              ),
              envelope.matchesOwnership(scope),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }

        let indexData = defaults.data(forKey: indexStorageKey)
        let indexEnvelope = indexData.flatMap {
            try? JSONDecoder().decode(EchoDelayedReplyOperationIndexEnvelope.self, from: $0)
        }
        defaults.removeObject(forKey: scopedStorageKey)
        if indexEnvelope?.matchesOwnership(scope) == true {
            defaults.removeObject(forKey: indexStorageKey)
        }

        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            if defaults.data(forKey: scopedStorageKey) == nil {
                defaults.set(envelopeData, forKey: scopedStorageKey)
            }
            if indexEnvelope?.matchesOwnership(scope) == true,
               defaults.data(forKey: indexStorageKey) == nil,
               let indexData {
                defaults.set(indexData, forKey: indexStorageKey)
            }
            return false
        }
        return true
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }

        lock.lock()
        defer { lock.unlock() }

        let indexPrefix = "\(storageNamespace).index."
        let candidateKeys = defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix("\(storageNamespace).")
        }
        var ownedKeys: [String] = []

        for key in candidateKeys {
            guard let data = defaults.data(forKey: key) else { return false }
            if key.hasPrefix(indexPrefix) {
                guard let envelope = try? JSONDecoder().decode(
                    EchoDelayedReplyOperationIndexEnvelope.self,
                    from: data
                ) else {
                    return false
                }
                if envelope.matchesLifecycleLease(oldAccountLease) {
                    ownedKeys.append(key)
                }
            } else {
                guard let envelope = try? JSONDecoder().decode(
                    EchoDelayedReplyEnvelope.self,
                    from: data
                ) else {
                    return false
                }
                if envelope.matchesLifecycleLease(oldAccountLease) {
                    ownedKeys.append(key)
                }
            }
        }

        ownedKeys.forEach(defaults.removeObject(forKey:))
        return ownedKeys.allSatisfy { defaults.object(forKey: $0) == nil }
    }

    func storageKey(
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease
    ) -> String? {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ) else {
            return nil
        }
        return storageKey(for: scope)
    }

    func legacyIsolationRecord() -> EchoDelayedReplyLegacyIsolationRecord? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: legacyIsolationReceiptKey) else {
            return nil
        }
        return try? JSONDecoder().decode(EchoDelayedReplyLegacyIsolationRecord.self, from: data)
    }

    private func currentOperationId(
        resourceOwnerId: String,
        accountLease: AccountLease
    ) -> String? {
        guard let lookupScope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: "operation-index-lookup"
        ), accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        isolateLegacyPayloadIfNeeded()
        guard let data = defaults.data(forKey: operationIndexStorageKey(for: lookupScope)),
              let indexEnvelope = try? JSONDecoder().decode(
                  EchoDelayedReplyOperationIndexEnvelope.self,
                  from: data
              ),
              indexEnvelope.matchesLeaseAndOwner(lookupScope),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        return indexEnvelope.operationId
    }

    private func storageKey(for scope: EchoDelayedReplyOperationScope) -> String {
        let accountLease = scope.accountLease
        return "\(storageKey(for: accountLease.subjectId)).\(scope.storageIdentity)"
    }

    private func storageKey(for subjectId: String) -> String {
        let subjectIdentity = EchoDelayedReplyOperationScope.identityDigest(
            values: ["storage-subject", subjectId]
        )
        return "\(storageNamespace).\(subjectIdentity)"
    }

    private func operationIndexStorageKey(for scope: EchoDelayedReplyOperationScope) -> String {
        "\(storageNamespace).index.\(scope.operationIndexIdentity)"
    }

    private func retirePreviousOperationIfNeeded(
        previousIndexData: Data?,
        replacingWith scope: EchoDelayedReplyOperationScope
    ) {
        guard let previousIndexData,
              let previousIndex = try? JSONDecoder().decode(
                  EchoDelayedReplyOperationIndexEnvelope.self,
                  from: previousIndexData
              ),
              previousIndex.matchesLeaseAndOwner(scope),
              previousIndex.operationId != scope.operationId,
              let previousScope = EchoDelayedReplyOperationScope(
                  accountLease: scope.accountLease,
                  resourceOwnerId: scope.resourceOwnerId,
                  operationId: previousIndex.operationId
              ) else {
            return
        }
        defaults.removeObject(forKey: storageKey(for: previousScope))
    }

    private func restore(previousData: Data?, replacing data: Data, forKey key: String) {
        guard defaults.data(forKey: key) == data else { return }
        if let previousData {
            defaults.set(previousData, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func isolateLegacyPayloadIfNeeded() {
        guard let legacyPayload = defaults.object(forKey: legacyStorageKey) else {
            return
        }
        defaults.set(legacyPayload, forKey: legacyQuarantineStorageKey)
        let record = EchoDelayedReplyLegacyIsolationRecord(
            reason: .missingAuthenticatedOwner,
            sourceStorageKey: legacyStorageKey,
            quarantineStorageKey: legacyQuarantineStorageKey,
            isolatedAt: now()
        )
        guard let recordData = try? JSONEncoder().encode(record) else {
            return
        }
        defaults.set(recordData, forKey: legacyIsolationReceiptKey)
        guard defaults.object(forKey: legacyQuarantineStorageKey) != nil,
              defaults.data(forKey: legacyIsolationReceiptKey) == recordData else {
            return
        }
        defaults.removeObject(forKey: legacyStorageKey)
    }
}
