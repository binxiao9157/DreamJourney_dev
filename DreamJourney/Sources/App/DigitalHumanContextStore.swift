import Foundation

enum DigitalHumanMode: String, Codable, Equatable {
    case sunlight
    case star
    case silent

    var displayName: String {
        switch self {
        case .sunlight:
            return "阳光"
        case .star:
            return "星辰"
        case .silent:
            return "静默"
        }
    }

    var selectionDescription: String {
        switch self {
        case .sunlight:
            return "普通陪伴，不展示心境追踪"
        case .star:
            return "启用心理引导和心境追踪"
        case .silent:
            return "长期失联观察态，不公开展示"
        }
    }
}

struct DigitalHumanContext: Codable, Equatable {
    var viewerUserId: String?
    var ownerId: String
    var displayName: String
    var relation: String?
    var mode: DigitalHumanMode
    var isSelfAssistant: Bool

    static func defaultContext(userId: String) -> DigitalHumanContext {
        DigitalHumanContext(
            viewerUserId: userId,
            ownerId: userId,
            displayName: "AI 助手",
            relation: nil,
            mode: .sunlight,
            isSelfAssistant: true
        )
    }

    var resolvedDisplayName: String {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            return trimmedName
        }
        return isSelfAssistant ? "AI 助手" : "家人数字人"
    }

    func normalizedForCurrentViewer(_ viewerUserId: String) -> DigitalHumanContext {
        var normalized = self
        normalized.viewerUserId = viewerUserId
        if normalized.ownerId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.ownerId = viewerUserId
        }
        normalized.displayName = normalized.resolvedDisplayName
        return normalized
    }
}

private struct DigitalHumanContextStorageEnvelope: Codable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let subjectId: String
    let accountGeneration: UInt64
    let accountGenerationId: UUID
    let context: DigitalHumanContext

    init(context: DigitalHumanContext, accountLease: AccountLease) {
        schemaVersion = Self.currentSchemaVersion
        subjectId = accountLease.subjectId
        accountGeneration = accountLease.generation
        accountGenerationId = accountLease.generationId
        self.context = context
    }

    func matches(_ accountLease: AccountLease) -> Bool {
        schemaVersion == Self.currentSchemaVersion
            && subjectId == accountLease.subjectId
            && accountGeneration == accountLease.generation
            && accountGenerationId == accountLease.generationId
    }
}

private struct DigitalHumanContextLegacyQuarantineRecord: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sourceStorageKey: String
    let observedSubjectId: String
    let observedAccountGeneration: UInt64
    let observedAccountGenerationId: UUID
    let reason: String
    let payload: Data
    let quarantinedAt: Date
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()

    private enum ReadResult {
        case stored(DigitalHumanContext)
        case empty
        case denied
    }

    private let legacyKeyBase = "dj.digitalHuman.currentContext"
    private let scopedKeyBase = "dj.digitalHuman.currentContext.v2"
    private let legacyQuarantineKeyBase = "dj.digitalHuman.currentContext.legacy-quarantine.v1"
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let defaults: UserDefaults
    private let storageLock = NSRecursiveLock()

    private init(
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        defaults: UserDefaults = .standard
    ) {
        self.accountLeaseRuntime = accountLeaseRuntime
        self.defaults = defaults
    }

    var current: DigitalHumanContext {
        get {
            let userId = normalizedUserId(UserManager.shared.currentUser?.id)
            guard !userId.isEmpty,
                  let accountLease = accountLeaseRuntime.capture(forSubjectId: userId) else {
                return unavailableContext
            }
            switch readCurrent(accountLease: accountLease) {
            case .stored(let context):
                return context
            case .empty:
                return .defaultContext(userId: accountLease.subjectId)
            case .denied:
                return unavailableContext
            }
        }
        set {
            let sourceUserId = normalizedUserId(UserManager.shared.currentUser?.id)
            guard !sourceUserId.isEmpty,
                  let accountLease = accountLeaseRuntime.capture(forSubjectId: sourceUserId) else {
                return
            }
            guard Thread.isMainThread else {
                DispatchQueue.main.async {
                    self.applyCurrent(
                        newValue,
                        userId: sourceUserId,
                        accountLease: accountLease
                    )
                }
                return
            }
            applyCurrent(newValue, userId: sourceUserId, accountLease: accountLease)
        }
    }

    func reconcileFamilyAuthorization() {
        let sourceUserId = normalizedUserId(UserManager.shared.currentUser?.id)
        guard !sourceUserId.isEmpty,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: sourceUserId) else {
            return
        }
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.reconcileFamilyAuthorization(
                    userId: sourceUserId,
                    accountLease: accountLease
                )
            }
            return
        }
        reconcileFamilyAuthorization(userId: sourceUserId, accountLease: accountLease)
    }

    private func applyCurrent(
        _ newValue: DigitalHumanContext,
        userId: String,
        accountLease: AccountLease
    ) {
        guard normalizedUserId(UserManager.shared.currentUser?.id) == userId,
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              let safeContext = validatedContext(newValue, userId: userId) else {
            return
        }

        storageLock.lock()
        guard quarantineLegacySubjectPayloadIfNeeded(accountLease: accountLease) else {
            storageLock.unlock()
            return
        }
        let storageKey = scopedKey(for: accountLease)
        let previousData = defaults.data(forKey: storageKey)
        let previousContext = storedContext(accountLease: accountLease)
        let envelope = DigitalHumanContextStorageEnvelope(
            context: safeContext,
            accountLease: accountLease
        )
        guard let data = try? JSONEncoder().encode(envelope) else {
            storageLock.unlock()
            return
        }
        defaults.set(data, forKey: storageKey)
        guard defaults.data(forKey: storageKey) == data,
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            restore(previousData, forKey: storageKey)
            storageLock.unlock()
            return
        }
        storageLock.unlock()

        guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else { return }
        let identity = KBLiteManager.resolveAuthorizedPersonaIdentity(for: safeContext)
        KBLiteManager.shared.personaContextDidChange(to: identity)
        guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else { return }
        KnowledgeSyncCoordinator.shared.personaContextDidChange(to: identity)
        guard previousContext != safeContext else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
        NotificationCenter.default.post(name: .djDigitalHumanContextDidChange, object: safeContext)
    }

    private func reconcileFamilyAuthorization(
        userId: String,
        accountLease: AccountLease
    ) {
        guard normalizedUserId(UserManager.shared.currentUser?.id) == userId,
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return
        }
        guard case .stored(let storedContext) = readCurrent(accountLease: accountLease) else {
            return
        }
        let hasAuthorizedFamilyMember = FamilyRepository.shared.acceptedMember(
            by: storedContext.ownerId
        ) != nil
        guard FamilyContextReconciliationPolicy.shouldFallbackToSelf(
            viewerUserId: userId,
            contextOwnerId: storedContext.ownerId,
            isSelfAssistant: storedContext.isSelfAssistant,
            hasAuthorizedFamilyMember: hasAuthorizedFamilyMember
        ) else { return }
        applyCurrent(
            .defaultContext(userId: userId),
            userId: userId,
            accountLease: accountLease
        )
    }

    private func readCurrent(accountLease: AccountLease) -> ReadResult {
        guard normalizedUserId(UserManager.shared.currentUser?.id) == accountLease.subjectId,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return .denied
        }

        storageLock.lock()
        defer { storageLock.unlock() }
        guard quarantineLegacySubjectPayloadIfNeeded(accountLease: accountLease),
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return .denied
        }
        guard let data = defaults.data(forKey: scopedKey(for: accountLease)) else {
            return .empty
        }
        guard let envelope = try? JSONDecoder().decode(
            DigitalHumanContextStorageEnvelope.self,
            from: data
        ),
        envelope.matches(accountLease),
        let context = validatedContext(envelope.context, userId: accountLease.subjectId),
        accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return .denied
        }
        return .stored(context)
    }

    private func validatedContext(_ context: DigitalHumanContext, userId: String) -> DigitalHumanContext? {
        let normalized = context.normalizedForCurrentViewer(userId)
        let ownerId = normalized.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ownerId.isEmpty else { return nil }

        if normalized.isSelfAssistant || ownerId == userId {
            return .defaultContext(userId: userId)
        }
        guard let member = FamilyRepository.shared.acceptedMember(by: ownerId) else {
            return nil
        }
        return DigitalHumanContext(
            viewerUserId: userId,
            ownerId: member.id,
            displayName: member.name,
            relation: member.relation,
            mode: member.digitalHumanMode,
            isSelfAssistant: false
        )
    }

    private func scopedKey(for accountLease: AccountLease) -> String {
        [
            scopedKeyBase,
            storageKeyComponent(accountLease.subjectId),
            String(accountLease.generation),
            accountLease.generationId.uuidString.lowercased()
        ].joined(separator: ".")
    }

    private func legacyKey(for subjectId: String) -> String {
        "\(legacyKeyBase).\(subjectId)"
    }

    private func legacyQuarantineKey(for subjectId: String) -> String {
        "\(legacyQuarantineKeyBase).\(storageKeyComponent(subjectId))"
    }

    private func storedContext(accountLease: AccountLease) -> DigitalHumanContext? {
        guard let data = defaults.data(forKey: scopedKey(for: accountLease)),
              let envelope = try? JSONDecoder().decode(
                DigitalHumanContextStorageEnvelope.self,
                from: data
              ),
              envelope.matches(accountLease) else {
            return nil
        }
        return validatedContext(envelope.context, userId: accountLease.subjectId)
    }

    private func quarantineLegacySubjectPayloadIfNeeded(accountLease: AccountLease) -> Bool {
        let sourceStorageKey = legacyKey(for: accountLease.subjectId)
        guard let legacyPayload = defaults.data(forKey: sourceStorageKey) else { return true }

        let quarantineStorageKey = legacyQuarantineKey(for: accountLease.subjectId)
        if let existingData = defaults.data(forKey: quarantineStorageKey),
           let existingRecord = try? JSONDecoder().decode(
            DigitalHumanContextLegacyQuarantineRecord.self,
            from: existingData
           ) {
            guard existingRecord.sourceStorageKey == sourceStorageKey,
                  existingRecord.payload == legacyPayload else {
                return false
            }
            defaults.removeObject(forKey: sourceStorageKey)
            return defaults.data(forKey: sourceStorageKey) == nil
        }

        let record = DigitalHumanContextLegacyQuarantineRecord(
            schemaVersion: DigitalHumanContextLegacyQuarantineRecord.currentSchemaVersion,
            sourceStorageKey: sourceStorageKey,
            observedSubjectId: accountLease.subjectId,
            observedAccountGeneration: accountLease.generation,
            observedAccountGenerationId: accountLease.generationId,
            reason: "missingAccountGeneration",
            payload: legacyPayload,
            quarantinedAt: Date()
        )
        guard let quarantineData = try? JSONEncoder().encode(record) else { return false }
        defaults.set(quarantineData, forKey: quarantineStorageKey)
        guard defaults.data(forKey: quarantineStorageKey) == quarantineData else { return false }
        defaults.removeObject(forKey: sourceStorageKey)
        return defaults.data(forKey: sourceStorageKey) == nil
    }

    private func restore(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func storageKeyComponent(_ value: String) -> String {
        Data(value.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func normalizedUserId(_ userId: String?) -> String {
        userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var unavailableContext: DigitalHumanContext {
        DigitalHumanContext(
            viewerUserId: nil,
            ownerId: "",
            displayName: "",
            relation: nil,
            mode: .silent,
            isSelfAssistant: false
        )
    }
}

extension Notification.Name {
    static let djDigitalHumanContextDidChange = Notification.Name("dj.digitalHuman.contextDidChange")
}
