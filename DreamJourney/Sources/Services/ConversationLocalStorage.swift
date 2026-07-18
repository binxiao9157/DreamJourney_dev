import CryptoKit
import Foundation

enum ConversationPersonaScope: String, Codable {
    case personal
    case family
}

enum ConversationLegacyDisposition: String, Codable {
    case migrated
    case quarantined
    case discarded
}

enum ConversationQuarantineReason: String, Codable {
    case ambiguousOwner
    case corrupt
    case ownerMismatch
    case reservedFallbackOwner
}

struct ConversationStorageScope: Equatable {
    static let schemaVersion = 2

    let subjectId: String
    let vaultId: String
    let ownerId: String
    let personaScope: ConversationPersonaScope
    let generation: UInt64
    let generationId: UUID

    init?(
        accountLease: AccountLease,
        ownerId: String,
        personaScope: ConversationPersonaScope
    ) {
        let subjectId = Self.normalized(accountLease.subjectId)
        let vaultId = Self.normalized(accountLease.vaultId)
        let ownerId = Self.normalized(ownerId)
        guard !subjectId.isEmpty,
              !vaultId.isEmpty,
              !ownerId.isEmpty,
              !Self.isReservedFallbackOwner(subjectId),
              !Self.isReservedFallbackOwner(ownerId) else {
            return nil
        }
        if personaScope == .personal, ownerId != subjectId {
            return nil
        }
        self.subjectId = subjectId
        self.vaultId = vaultId
        self.ownerId = ownerId
        self.personaScope = personaScope
        generation = accountLease.generation
        generationId = accountLease.generationId
    }

    var scopeDigest: String {
        ConversationLocalStorage.sha256(
            "conversation-v2|\(subjectId)|\(vaultId)|\(ownerId)|\(personaScope.rawValue)"
        )
    }

    var legacyScopeId: String {
        let prefix = personaScope == .personal ? "personal" : "family"
        return "\(prefix)_\(Self.sanitized(ownerId))"
    }

    func matchesPersistentOwner(_ other: ConversationStorageScope) -> Bool {
        subjectId == other.subjectId
            && vaultId == other.vaultId
            && ownerId == other.ownerId
            && personaScope == other.personaScope
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isReservedFallbackOwner(_ value: String) -> Bool {
        ["user_001", "unknown", "default"].contains(value.lowercased())
    }

    private static func sanitized(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "_" })
    }
}

struct ConversationStoreEnvelope: Codable {
    let schemaVersion: Int
    let subjectId: String
    let vaultId: String
    let ownerId: String
    let personaScope: ConversationPersonaScope
    let generation: UInt64
    let generationId: UUID
    let contentHash: String
    let memory: ConversationMemory
}

struct ConversationLegacyMigrationReceipt: Codable, Equatable {
    let schemaVersion: Int
    let sourceLocatorHash: String
    let sourceContentHash: String
    let subjectDigest: String
    let vaultDigest: String
    let ownerDigest: String
    let disposition: ConversationLegacyDisposition
    let reason: ConversationQuarantineReason?
    let createdAt: Date
}

struct ConversationQuarantineRecord: Codable, Equatable {
    let schemaVersion: Int
    let sourceLocatorHash: String
    let sourceContentHash: String
    let subjectDigest: String
    let vaultDigest: String
    let ownerDigest: String
    let reason: ConversationQuarantineReason
    let payload: Data
    let observedAt: Date
}

enum ConversationLocalStorageError: Error {
    case invalidScope
    case encodingFailed
    case envelopeMismatch
    case corruptEnvelope
    case staleCommit
}

final class ConversationLocalStorage {
    static let shared = ConversationLocalStorage()

    private static let rootRelativePath = "DreamJourney/Conversation/v2"
    private static let memoryFileName = "memory.json"
    private static let receiptSchemaVersion = 1
    private static let quarantineSchemaVersion = 1

    private let fileManager: FileManager
    private let applicationSupportRootOverride: URL?
    private let legacyDocumentsRootOverride: URL?
    private let now: () -> Date
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        applicationSupportRoot: URL? = nil,
        legacyDocumentsRoot: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        applicationSupportRootOverride = applicationSupportRoot
        legacyDocumentsRootOverride = legacyDocumentsRoot
        self.now = now
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func mount(
        scope: ConversationStorageScope,
        commitValidator: () -> Bool = { true }
    ) -> ConversationMemory {
        lock.lock()
        defer { lock.unlock() }
        guard isValid(scope) else { return ConversationMemory() }

        observeGlobalLegacyIfNeeded(scope: scope)
        let destination = memoryURL(scope: scope)
        if fileManager.fileExists(atPath: destination.path) {
            return loadEnvelope(at: destination, scope: scope)
        }
        return migrateScopedLegacyIfPermitted(
            scope: scope,
            commitValidator: commitValidator
        )
    }

    func save(
        memory: ConversationMemory,
        scope: ConversationStorageScope,
        commitValidator: () -> Bool = { true }
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        guard isValid(scope) else { throw ConversationLocalStorageError.invalidScope }
        try saveUnlocked(
            memory: memory,
            scope: scope,
            commitValidator: commitValidator
        )
    }

    func purge(accountLease: AccountLease) {
        lock.lock()
        defer { lock.unlock() }
        let subjectId = accountLease.subjectId.trimmingCharacters(in: .whitespacesAndNewlines)
        let vaultId = accountLease.vaultId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subjectId.isEmpty, !vaultId.isEmpty else { return }
        let root = storageRoot
        guard let children = try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        for child in children where !["receipts", "quarantine"].contains(child.lastPathComponent) {
            let candidate = child.appendingPathComponent(Self.memoryFileName)
            guard let data = try? Data(contentsOf: candidate),
                  let envelope = try? decoder.decode(ConversationStoreEnvelope.self, from: data),
                  envelope.subjectId == subjectId,
                  envelope.vaultId == vaultId else {
                continue
            }
            try? fileManager.removeItem(at: child)
        }
    }

    func memoryURL(scope: ConversationStorageScope) -> URL {
        storageRoot
            .appendingPathComponent(scope.scopeDigest, isDirectory: true)
            .appendingPathComponent(Self.memoryFileName)
    }

    func migrationReceipt(scope: ConversationStorageScope) -> ConversationLegacyMigrationReceipt? {
        let source = legacyScopedURL(scope: scope)
        return migrationReceipt(sourceURL: source)
    }

    func quarantineRecord(sourceURL: URL) -> ConversationQuarantineRecord? {
        guard let data = try? Data(contentsOf: quarantineURL(sourceURL: sourceURL)) else { return nil }
        return try? decoder.decode(ConversationQuarantineRecord.self, from: data)
    }

    func legacyScopedURL(scope: ConversationStorageScope) -> URL {
        legacyDocumentsRoot.appendingPathComponent("conversation_memory_\(scope.legacyScopeId).json")
    }

    var globalLegacyURL: URL {
        legacyDocumentsRoot.appendingPathComponent("conversation_memory.json")
    }

    private var applicationSupportRoot: URL {
        applicationSupportRootOverride
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    private var legacyDocumentsRoot: URL {
        legacyDocumentsRootOverride
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private var storageRoot: URL {
        applicationSupportRoot.appendingPathComponent(Self.rootRelativePath, isDirectory: true)
    }

    private func isValid(_ scope: ConversationStorageScope) -> Bool {
        !scope.subjectId.isEmpty && !scope.vaultId.isEmpty && !scope.ownerId.isEmpty
    }

    private func loadEnvelope(at url: URL, scope: ConversationStorageScope) -> ConversationMemory {
        guard let data = try? Data(contentsOf: url),
              let envelope = try? decoder.decode(ConversationStoreEnvelope.self, from: data) else {
            quarantine(data: (try? Data(contentsOf: url)) ?? Data(), sourceURL: url, scope: scope, reason: .corrupt)
            return ConversationMemory()
        }
        guard envelope.schemaVersion == ConversationStorageScope.schemaVersion,
              envelope.subjectId == scope.subjectId,
              envelope.vaultId == scope.vaultId,
              envelope.ownerId == scope.ownerId,
              envelope.personaScope == scope.personaScope else {
            quarantine(data: data, sourceURL: url, scope: scope, reason: .ownerMismatch)
            return ConversationMemory()
        }
        guard let memoryData = try? encoder.encode(envelope.memory),
              Self.sha256(memoryData) == envelope.contentHash else {
            quarantine(data: data, sourceURL: url, scope: scope, reason: .corrupt)
            return ConversationMemory()
        }
        return envelope.memory
    }

    private func saveUnlocked(
        memory: ConversationMemory,
        scope: ConversationStorageScope,
        commitValidator: () -> Bool
    ) throws {
        guard let memoryData = try? encoder.encode(memory) else {
            throw ConversationLocalStorageError.encodingFailed
        }
        let envelope = ConversationStoreEnvelope(
            schemaVersion: ConversationStorageScope.schemaVersion,
            subjectId: scope.subjectId,
            vaultId: scope.vaultId,
            ownerId: scope.ownerId,
            personaScope: scope.personaScope,
            generation: scope.generation,
            generationId: scope.generationId,
            contentHash: Self.sha256(memoryData),
            memory: memory
        )
        guard let data = try? encoder.encode(envelope) else {
            throw ConversationLocalStorageError.encodingFailed
        }
        let destination = memoryURL(scope: scope)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard commitValidator() else {
            throw ConversationLocalStorageError.staleCommit
        }
        try data.write(to: destination, options: [.atomic])
    }

    private func migrateScopedLegacyIfPermitted(
        scope: ConversationStorageScope,
        commitValidator: () -> Bool
    ) -> ConversationMemory {
        let source = legacyScopedURL(scope: scope)
        guard fileManager.fileExists(atPath: source.path),
              let sourceData = try? Data(contentsOf: source) else {
            return ConversationMemory()
        }
        if let receipt = migrationReceipt(sourceURL: source),
           receipt.sourceContentHash == Self.sha256(sourceData),
           receipt.disposition != .migrated {
            return ConversationMemory()
        }
        guard scope.personaScope == .personal, scope.ownerId == scope.subjectId else {
            quarantine(data: sourceData, sourceURL: source, scope: scope, reason: .ambiguousOwner)
            return ConversationMemory()
        }
        guard let memory = try? decoder.decode(ConversationMemory.self, from: sourceData) else {
            quarantine(data: sourceData, sourceURL: source, scope: scope, reason: .corrupt)
            return ConversationMemory()
        }
        do {
            try saveUnlocked(
                memory: memory,
                scope: scope,
                commitValidator: commitValidator
            )
            guard commitValidator() else { return ConversationMemory() }
            writeReceipt(
                sourceData: sourceData,
                sourceURL: source,
                scope: scope,
                disposition: .migrated,
                reason: nil
            )
            return memory
        } catch {
            return ConversationMemory()
        }
    }

    private func observeGlobalLegacyIfNeeded(scope: ConversationStorageScope) {
        let source = globalLegacyURL
        guard fileManager.fileExists(atPath: source.path),
              let data = try? Data(contentsOf: source),
              migrationReceipt(sourceURL: source) == nil else {
            return
        }
        quarantine(data: data, sourceURL: source, scope: scope, reason: .ambiguousOwner)
    }

    private func quarantine(
        data: Data,
        sourceURL: URL,
        scope: ConversationStorageScope,
        reason: ConversationQuarantineReason
    ) {
        let sourceContentHash = Self.sha256(data)
        if let receipt = migrationReceipt(sourceURL: sourceURL),
           receipt.sourceContentHash == sourceContentHash,
           receipt.disposition == .quarantined {
            return
        }
        let record = ConversationQuarantineRecord(
            schemaVersion: Self.quarantineSchemaVersion,
            sourceLocatorHash: sourceLocatorHash(sourceURL),
            sourceContentHash: sourceContentHash,
            subjectDigest: Self.sha256(scope.subjectId),
            vaultDigest: Self.sha256(scope.vaultId),
            ownerDigest: Self.sha256(scope.ownerId),
            reason: reason,
            payload: data,
            observedAt: now()
        )
        guard let encoded = try? encoder.encode(record) else { return }
        let url = quarantineURL(sourceURL: sourceURL)
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoded.write(to: url, options: [.atomic])
            writeReceipt(
                sourceData: data,
                sourceURL: sourceURL,
                scope: scope,
                disposition: .quarantined,
                reason: reason
            )
        } catch {
            return
        }
    }

    private func writeReceipt(
        sourceData: Data,
        sourceURL: URL,
        scope: ConversationStorageScope,
        disposition: ConversationLegacyDisposition,
        reason: ConversationQuarantineReason?
    ) {
        let receipt = ConversationLegacyMigrationReceipt(
            schemaVersion: Self.receiptSchemaVersion,
            sourceLocatorHash: sourceLocatorHash(sourceURL),
            sourceContentHash: Self.sha256(sourceData),
            subjectDigest: Self.sha256(scope.subjectId),
            vaultDigest: Self.sha256(scope.vaultId),
            ownerDigest: Self.sha256(scope.ownerId),
            disposition: disposition,
            reason: reason,
            createdAt: now()
        )
        guard let data = try? encoder.encode(receipt) else { return }
        let url = receiptURL(sourceURL: sourceURL)
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
        } catch {
            return
        }
    }

    private func migrationReceipt(sourceURL: URL) -> ConversationLegacyMigrationReceipt? {
        guard let data = try? Data(contentsOf: receiptURL(sourceURL: sourceURL)) else { return nil }
        return try? decoder.decode(ConversationLegacyMigrationReceipt.self, from: data)
    }

    private func receiptURL(sourceURL: URL) -> URL {
        storageRoot
            .appendingPathComponent("receipts", isDirectory: true)
            .appendingPathComponent("\(sourceLocatorHash(sourceURL)).json")
    }

    private func quarantineURL(sourceURL: URL) -> URL {
        storageRoot
            .appendingPathComponent("quarantine", isDirectory: true)
            .appendingPathComponent("\(sourceLocatorHash(sourceURL)).json")
    }

    private func sourceLocatorHash(_ url: URL) -> String {
        Self.sha256(url.standardizedFileURL.path)
    }

    static func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
