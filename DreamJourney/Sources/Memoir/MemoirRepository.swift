import CryptoKit
import Foundation

#if canImport(CocoaLumberjack)
import CocoaLumberjack
#endif

enum MemoirQuarantineReason: String, Codable, CaseIterable, Hashable {
    case missingOwner
    case seedFixture
    case corrupt
    case scopeMismatch
    case duplicateConflict
    case orphanRecording
}

enum MemoirEnvelopeValidation: String, Codable, Equatable {
    case accepted
    case mismatch
    case corrupt
}

struct MemoirStorageScope: Equatable {
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

    var isValid: Bool {
        !subjectId.isEmpty && !vaultId.isEmpty && !ownerId.isEmpty
    }

    var scopeDigest: String {
        MemoirOwnerStoragePolicy.pathDigest(
            "memoir-scope-v2|\(subjectId)|\(vaultId)|\(ownerId)"
        )
    }

    var recordsDirectoryRelativePath: String {
        "v2/\(scopeDigest)/records"
    }

    var recordingsDirectoryRelativePath: String {
        "v2/\(scopeDigest)/recordings"
    }

    fileprivate func recordFileRelativePath(id: String) -> String {
        "\(recordsDirectoryRelativePath)/\(MemoirOwnerStoragePolicy.pathDigest("memoir-id-v1|\(id)")).json"
    }

    fileprivate func recordingFileRelativePath(sessionId: String) -> String {
        "\(recordingsDirectoryRelativePath)/\(MemoirOwnerStoragePolicy.pathDigest("memoir-session-v1|\(sessionId)")).m4a"
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MemoirStoreEnvelope: Codable {
    let storeSchemaVersion: Int
    let subjectId: String
    let vaultId: String
    let ownerId: String
    let generation: UInt64
    let generationId: UUID
    var contentHash: String
    let memoir: MemoirModel
}

struct MemoirQuarantineRecord: Codable, Equatable {
    static let schemaVersion = 1

    let recordSchemaVersion: Int
    let recordId: String
    let reason: MemoirQuarantineReason
    let sourceLocatorHash: String
    let sourceContentHash: String
    let memoirId: String?
    let sessionIdHash: String?
    let payloadRelativePath: String
    let createdAt: Date
}

struct MemoirLegacyMigrationReceipt: Codable, Equatable {
    enum State: String, Codable {
        case migrated
        case quarantined
    }

    static let schemaVersion = 1

    let receiptSchemaVersion: Int
    let receiptId: String
    let surfaceId: String
    let sourceLocatorHash: String
    let sourceContentHash: String
    let state: State
    let subjectId: String?
    let vaultId: String?
    let ownerId: String?
    let destinationScopeDigest: String?
    let memoirId: String?
    let reason: MemoirQuarantineReason?
    let createdAt: Date
}

enum MemoirOwnerStorageError: Error {
    case invalidScope
    case invalidIdentifier
    case ownerMismatch
    case encodingFailed
    case staleCommit
    case corruptedRecord
}

enum MemoirOwnerStoragePolicy {
    static func makeEnvelope(
        memoir: MemoirModel,
        scope: MemoirStorageScope
    ) throws -> MemoirStoreEnvelope {
        guard scope.isValid else { throw MemoirOwnerStorageError.invalidScope }
        guard validIdentifier(memoir.id) else { throw MemoirOwnerStorageError.invalidIdentifier }
        guard normalized(memoir.authorId) == scope.ownerId else {
            throw MemoirOwnerStorageError.ownerMismatch
        }
        return MemoirStoreEnvelope(
            storeSchemaVersion: MemoirStorageScope.storeSchemaVersion,
            subjectId: scope.subjectId,
            vaultId: scope.vaultId,
            ownerId: scope.ownerId,
            generation: scope.generation,
            generationId: scope.generationId,
            contentHash: try memoirContentHash(memoir),
            memoir: memoir
        )
    }

    static func validate(
        _ envelope: MemoirStoreEnvelope,
        expectedScope scope: MemoirStorageScope
    ) -> MemoirEnvelopeValidation {
        guard scope.isValid,
              envelope.storeSchemaVersion == MemoirStorageScope.storeSchemaVersion,
              envelope.subjectId == scope.subjectId,
              envelope.vaultId == scope.vaultId,
              envelope.ownerId == scope.ownerId,
              normalized(envelope.memoir.authorId) == scope.ownerId,
              validIdentifier(envelope.memoir.id) else {
            return .mismatch
        }
        guard let contentHash = try? memoirContentHash(envelope.memoir),
              contentHash == envelope.contentHash else {
            return .corrupt
        }
        return .accepted
    }

    static func isLegacySeed(_ memoir: MemoirModel) -> Bool {
        // This value is recognized only as retired fixture evidence. It is never
        // assigned by a production initializer or writer.
        normalized(memoir.authorId) == "user_001"
    }

    static func encodedMemoir(_ memoir: MemoirModel) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(memoir)
    }

    static func encodedEnvelope(_ envelope: MemoirStoreEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(envelope)
    }

    static func sha256(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(_ value: String) -> String {
        sha256(Data(value.utf8))
    }

    static func pathDigest(_ value: String) -> String {
        String(sha256(value).dropFirst("sha256:".count))
    }

    static func validIdentifier(_ value: String) -> Bool {
        let normalizedValue = normalized(value)
        return !normalizedValue.isEmpty
            && !normalizedValue.contains("/")
            && !normalizedValue.contains("\\")
            && normalizedValue != "."
            && normalizedValue != ".."
    }

    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func memoirContentHash(_ memoir: MemoirModel) throws -> String {
        sha256(try encodedMemoir(memoir))
    }
}

final class MemoirOwnerStorage {
    private let rootDirectory: URL
    private let fileManager: FileManager
    private let lock = NSRecursiveLock()
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(rootDirectory: URL, fileManager: FileManager = .default) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.fileManager = fileManager
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try? fileManager.createDirectory(
            at: self.rootDirectory,
            withIntermediateDirectories: true
        )
    }

    func loadAll(
        scope: MemoirStorageScope,
        commitValidator: () -> Bool = { true }
    ) -> [MemoirModel] {
        lock.lock()
        defer { lock.unlock() }
        guard scope.isValid else { return [] }
        migrateLegacyDataIfNeeded(scope: scope, commitValidator: commitValidator)

        let recordsDirectory = scopedURL(scope.recordsDirectoryRelativePath)
        guard let files = try? fileManager.contentsOfDirectory(
            at: recordsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var memoirs: [MemoirModel] = []
        for fileURL in files where fileURL.pathExtension == "json" {
            guard let data = try? Data(contentsOf: fileURL),
                  let envelope = try? decoder.decode(MemoirStoreEnvelope.self, from: data) else {
                quarantineScopedPayload(
                    at: fileURL,
                    data: (try? Data(contentsOf: fileURL)) ?? Data(),
                    reason: .corrupt,
                    memoirId: nil,
                    scope: scope,
                    commitValidator: commitValidator
                )
                continue
            }
            switch MemoirOwnerStoragePolicy.validate(envelope, expectedScope: scope) {
            case .accepted:
                memoirs.append(envelope.memoir)
            case .mismatch:
                quarantineScopedPayload(
                    at: fileURL,
                    data: data,
                    reason: .scopeMismatch,
                    memoirId: envelope.memoir.id,
                    scope: scope,
                    commitValidator: commitValidator
                )
            case .corrupt:
                quarantineScopedPayload(
                    at: fileURL,
                    data: data,
                    reason: .corrupt,
                    memoirId: envelope.memoir.id,
                    scope: scope,
                    commitValidator: commitValidator
                )
            }
        }
        return memoirs.sorted { $0.createdAt > $1.createdAt }
    }

    func get(id: String, scope: MemoirStorageScope) -> MemoirModel? {
        guard MemoirOwnerStoragePolicy.validIdentifier(id) else { return nil }
        return loadAll(scope: scope).first { $0.id == id }
    }

    func get(
        id: String,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool
    ) -> MemoirModel? {
        guard MemoirOwnerStoragePolicy.validIdentifier(id) else { return nil }
        return loadAll(scope: scope, commitValidator: commitValidator).first { $0.id == id }
    }

    func save(
        _ memoir: MemoirModel,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool = { true }
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        let envelope = try MemoirOwnerStoragePolicy.makeEnvelope(memoir: memoir, scope: scope)
        guard let data = try? encoder.encode(envelope) else {
            throw MemoirOwnerStorageError.encodingFailed
        }
        let destination = scopedURL(scope.recordFileRelativePath(id: memoir.id))
        try stageAndCommit(data, to: destination, commitValidator: commitValidator)
    }

    @discardableResult
    func delete(
        id: String,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool = { true }
    ) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard scope.isValid,
              MemoirOwnerStoragePolicy.validIdentifier(id) else {
            throw MemoirOwnerStorageError.invalidIdentifier
        }
        let destination = scopedURL(scope.recordFileRelativePath(id: id))
        guard fileManager.fileExists(atPath: destination.path) else { return false }
        guard let data = try? Data(contentsOf: destination),
              let envelope = try? decoder.decode(MemoirStoreEnvelope.self, from: data),
              MemoirOwnerStoragePolicy.validate(envelope, expectedScope: scope) == .accepted,
              envelope.memoir.id == id else {
            throw MemoirOwnerStorageError.corruptedRecord
        }
        guard commitValidator() else { throw MemoirOwnerStorageError.staleCommit }
        try fileManager.removeItem(at: destination)
        return true
    }

    func saveRecording(
        from sourceURL: URL,
        sessionId: String,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool = { true }
    ) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        guard scope.isValid,
              MemoirOwnerStoragePolicy.validIdentifier(sessionId) else {
            throw MemoirOwnerStorageError.invalidIdentifier
        }
        let data = try Data(contentsOf: sourceURL)
        let destination = scopedURL(scope.recordingFileRelativePath(sessionId: sessionId))
        try stageAndCommit(data, to: destination, commitValidator: commitValidator)
        return destination
    }

    func getRecordingURL(sessionId: String, scope: MemoirStorageScope) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        guard scope.isValid,
              MemoirOwnerStoragePolicy.validIdentifier(sessionId) else {
            return nil
        }
        let destination = scopedURL(scope.recordingFileRelativePath(sessionId: sessionId))
        return fileManager.fileExists(atPath: destination.path) ? destination : nil
    }

    @discardableResult
    func deleteRecording(
        sessionId: String,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool = { true }
    ) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard scope.isValid,
              MemoirOwnerStoragePolicy.validIdentifier(sessionId) else {
            throw MemoirOwnerStorageError.invalidIdentifier
        }
        let destination = scopedURL(scope.recordingFileRelativePath(sessionId: sessionId))
        guard fileManager.fileExists(atPath: destination.path) else { return false }
        guard commitValidator() else { throw MemoirOwnerStorageError.staleCommit }
        try fileManager.removeItem(at: destination)
        return true
    }

    func migrationReceipts() -> [MemoirLegacyMigrationReceipt] {
        lock.lock()
        defer { lock.unlock() }
        return decodedArtifacts(
            MemoirLegacyMigrationReceipt.self,
            directory: scopedURL("migration-receipts/v1")
        )
    }

    func quarantineRecords() -> [MemoirQuarantineRecord] {
        lock.lock()
        defer { lock.unlock() }
        let quarantineRoot = scopedURL("quarantine/v1")
        guard let directories = try? fileManager.contentsOfDirectory(
            at: quarantineRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return directories.compactMap { directory in
            let recordURL = directory.appendingPathComponent("record.json")
            guard let data = try? Data(contentsOf: recordURL) else { return nil }
            return try? decoder.decode(MemoirQuarantineRecord.self, from: data)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    private func migrateLegacyDataIfNeeded(
        scope: MemoirStorageScope,
        commitValidator: () -> Bool
    ) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for sourceURL in files where sourceURL.pathExtension == "json" {
            guard commitValidator(),
                  let sourceData = try? Data(contentsOf: sourceURL) else {
                continue
            }
            guard let memoir = try? decoder.decode(MemoirModel.self, from: sourceData) else {
                quarantineLegacyPayload(
                    at: sourceURL,
                    data: sourceData,
                    reason: .corrupt,
                    memoir: nil,
                    commitValidator: commitValidator
                )
                continue
            }
            let legacyOwner = MemoirOwnerStoragePolicy.normalized(memoir.authorId)
            if legacyOwner.isEmpty {
                quarantineLegacyPayload(
                    at: sourceURL,
                    data: sourceData,
                    reason: .missingOwner,
                    memoir: memoir,
                    commitValidator: commitValidator
                )
            } else if MemoirOwnerStoragePolicy.isLegacySeed(memoir) {
                quarantineLegacyPayload(
                    at: sourceURL,
                    data: sourceData,
                    reason: .seedFixture,
                    memoir: memoir,
                    commitValidator: commitValidator
                )
            } else if legacyOwner == scope.ownerId {
                migrateOwnedLegacyMemoir(
                    memoir,
                    sourceURL: sourceURL,
                    sourceData: sourceData,
                    scope: scope,
                    commitValidator: commitValidator
                )
            }
        }

        quarantineUnclaimedLegacyRecordings(commitValidator: commitValidator)
    }

    private func migrateOwnedLegacyMemoir(
        _ memoir: MemoirModel,
        sourceURL: URL,
        sourceData: Data,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool
    ) {
        guard commitValidator(),
              let envelope = try? MemoirOwnerStoragePolicy.makeEnvelope(
                  memoir: memoir,
                  scope: scope
              ),
              let envelopeData = try? encoder.encode(envelope) else {
            return
        }

        let destination = scopedURL(scope.recordFileRelativePath(id: memoir.id))
        if fileManager.fileExists(atPath: destination.path) {
            guard let existingData = try? Data(contentsOf: destination),
                  let existing = try? decoder.decode(MemoirStoreEnvelope.self, from: existingData),
                  MemoirOwnerStoragePolicy.validate(existing, expectedScope: scope) == .accepted,
                  existing.memoir.id == memoir.id,
                  existing.contentHash == envelope.contentHash else {
                quarantineLegacyPayload(
                    at: sourceURL,
                    data: sourceData,
                    reason: .duplicateConflict,
                    memoir: memoir,
                    commitValidator: commitValidator
                )
                return
            }
        } else {
            do {
                try stageAndCommit(
                    envelopeData,
                    to: destination,
                    commitValidator: commitValidator
                )
            } catch {
                return
            }
        }

        if let sessionId = memoir.sessionId,
           MemoirOwnerStoragePolicy.validIdentifier(sessionId),
           let legacyRecordingURL = legacyRecordingURL(sessionId: sessionId),
           let recordingData = try? Data(contentsOf: legacyRecordingURL) {
            let scopedRecordingURL = scopedURL(
                scope.recordingFileRelativePath(sessionId: sessionId)
            )
            do {
                try stageAndCommit(
                    recordingData,
                    to: scopedRecordingURL,
                    commitValidator: commitValidator
                )
            } catch {
                return
            }
        }

        let receipt = migratedReceipt(
            sourceURL: sourceURL,
            sourceData: sourceData,
            memoir: memoir,
            scope: scope
        )
        guard commitValidator(), appendReceipt(receipt) else { return }
        try? fileManager.removeItem(at: sourceURL)
        if let sessionId = memoir.sessionId {
            retireMigratedLegacyRecordingIfUnreferenced(sessionId: sessionId)
        }
    }

    private func quarantineLegacyPayload(
        at sourceURL: URL,
        data: Data,
        reason: MemoirQuarantineReason,
        memoir: MemoirModel?,
        commitValidator: () -> Bool
    ) {
        guard commitValidator(),
              quarantinePayload(
                  at: sourceURL,
                  data: data,
                  reason: reason,
                  memoirId: memoir?.id,
                  sessionId: nil
              ) != nil else {
            return
        }
        let receipt = quarantinedReceipt(
            sourceURL: sourceURL,
            sourceData: data,
            memoirId: memoir?.id,
            reason: reason
        )
        guard commitValidator(), appendReceipt(receipt) else { return }
        try? fileManager.removeItem(at: sourceURL)
    }

    private func quarantineScopedPayload(
        at sourceURL: URL,
        data: Data,
        reason: MemoirQuarantineReason,
        memoirId: String?,
        scope: MemoirStorageScope,
        commitValidator: () -> Bool
    ) {
        guard commitValidator(),
              quarantinePayload(
                  at: sourceURL,
                  data: data,
                  reason: reason,
                  memoirId: memoirId,
                  sessionId: nil
              ) != nil else {
            return
        }
        // A malformed scoped file is retained in device quarantine, then unmounted.
        // It does not receive a legacy migration receipt because it is already v2.
        try? fileManager.removeItem(at: sourceURL)
        memoirStorageLog(
            "quarantined scoped payload reason=\(reason.rawValue) scope=\(scope.scopeDigest)"
        )
    }

    private func quarantineUnclaimedLegacyRecordings(commitValidator: () -> Bool) {
        let recordingsDirectory = rootDirectory.appendingPathComponent(
            "recordings",
            isDirectory: true
        )
        guard let recordingFiles = try? fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return
        }
        let referencedSessionIds = remainingLegacySessionIds()
        for sourceURL in recordingFiles where sourceURL.pathExtension == "m4a" {
            let sessionId = sourceURL.deletingPathExtension().lastPathComponent
            guard !referencedSessionIds.contains(sessionId),
                  commitValidator(),
                  let data = try? Data(contentsOf: sourceURL),
                  quarantinePayload(
                      at: sourceURL,
                      data: data,
                      reason: .orphanRecording,
                      memoirId: nil,
                      sessionId: sessionId
                  ) != nil else {
                continue
            }
            let receipt = quarantinedReceipt(
                sourceURL: sourceURL,
                sourceData: data,
                memoirId: nil,
                reason: .orphanRecording
            )
            guard commitValidator(), appendReceipt(receipt) else { continue }
            try? fileManager.removeItem(at: sourceURL)
        }
    }

    private func remainingLegacySessionIds() -> Set<String> {
        guard let files = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return Set(files.compactMap { fileURL -> String? in
            guard fileURL.pathExtension == "json",
                  let data = try? Data(contentsOf: fileURL),
                  let memoir = try? decoder.decode(MemoirModel.self, from: data),
                  let sessionId = memoir.sessionId,
                  MemoirOwnerStoragePolicy.validIdentifier(sessionId) else {
                return nil
            }
            return sessionId
        })
    }

    private func retireMigratedLegacyRecordingIfUnreferenced(sessionId: String) {
        guard !remainingLegacySessionIds().contains(sessionId),
              let sourceURL = legacyRecordingURL(sessionId: sessionId) else {
            return
        }
        try? fileManager.removeItem(at: sourceURL)
    }

    private func legacyRecordingURL(sessionId: String) -> URL? {
        guard MemoirOwnerStoragePolicy.validIdentifier(sessionId) else { return nil }
        let recordingsDirectory = rootDirectory.appendingPathComponent(
            "recordings",
            isDirectory: true
        )
        guard let files = try? fileManager.contentsOfDirectory(
            at: recordingsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return files.first {
            $0.pathExtension == "m4a"
                && $0.deletingPathExtension().lastPathComponent == sessionId
        }
    }

    private func quarantinePayload(
        at sourceURL: URL,
        data: Data,
        reason: MemoirQuarantineReason,
        memoirId: String?,
        sessionId: String?
    ) -> MemoirQuarantineRecord? {
        let sourceLocatorHash = locatorHash(for: sourceURL)
        let sourceContentHash = MemoirOwnerStoragePolicy.sha256(data)
        let recordId = MemoirOwnerStoragePolicy.pathDigest(
            "memoir-quarantine-v1|\(sourceLocatorHash)|\(sourceContentHash)|\(reason.rawValue)"
        )
        let recordDirectoryRelativePath = "quarantine/v1/\(recordId)"
        let recordDirectory = scopedURL(recordDirectoryRelativePath)
        let payloadExtension = sourceURL.pathExtension.isEmpty ? "bin" : sourceURL.pathExtension
        let payloadRelativePath = "\(recordDirectoryRelativePath)/payload.\(payloadExtension)"
        let payloadURL = scopedURL(payloadRelativePath)
        let record = MemoirQuarantineRecord(
            recordSchemaVersion: MemoirQuarantineRecord.schemaVersion,
            recordId: recordId,
            reason: reason,
            sourceLocatorHash: sourceLocatorHash,
            sourceContentHash: sourceContentHash,
            memoirId: memoirId,
            sessionIdHash: sessionId.map {
                MemoirOwnerStoragePolicy.sha256("memoir-session-evidence-v1|\($0)")
            },
            payloadRelativePath: payloadRelativePath,
            createdAt: Date()
        )
        do {
            try fileManager.createDirectory(
                at: recordDirectory,
                withIntermediateDirectories: true
            )
            if !fileManager.fileExists(atPath: payloadURL.path) {
                try data.write(to: payloadURL, options: .atomic)
            }
            let recordURL = recordDirectory.appendingPathComponent("record.json")
            if !fileManager.fileExists(atPath: recordURL.path) {
                try encoder.encode(record).write(to: recordURL, options: .atomic)
            }
            return record
        } catch {
            return nil
        }
    }

    private func migratedReceipt(
        sourceURL: URL,
        sourceData: Data,
        memoir: MemoirModel,
        scope: MemoirStorageScope
    ) -> MemoirLegacyMigrationReceipt {
        makeReceipt(
            sourceURL: sourceURL,
            sourceData: sourceData,
            state: .migrated,
            subjectId: scope.subjectId,
            vaultId: scope.vaultId,
            ownerId: scope.ownerId,
            destinationScopeDigest: scope.scopeDigest,
            memoirId: memoir.id,
            reason: nil
        )
    }

    private func quarantinedReceipt(
        sourceURL: URL,
        sourceData: Data,
        memoirId: String?,
        reason: MemoirQuarantineReason
    ) -> MemoirLegacyMigrationReceipt {
        makeReceipt(
            sourceURL: sourceURL,
            sourceData: sourceData,
            state: .quarantined,
            subjectId: nil,
            vaultId: nil,
            ownerId: nil,
            destinationScopeDigest: nil,
            memoirId: memoirId,
            reason: reason
        )
    }

    private func makeReceipt(
        sourceURL: URL,
        sourceData: Data,
        state: MemoirLegacyMigrationReceipt.State,
        subjectId: String?,
        vaultId: String?,
        ownerId: String?,
        destinationScopeDigest: String?,
        memoirId: String?,
        reason: MemoirQuarantineReason?
    ) -> MemoirLegacyMigrationReceipt {
        let sourceLocatorHash = locatorHash(for: sourceURL)
        let sourceContentHash = MemoirOwnerStoragePolicy.sha256(sourceData)
        let receiptId = MemoirOwnerStoragePolicy.pathDigest(
            "memoir-receipt-v1|\(sourceLocatorHash)|\(sourceContentHash)|\(state.rawValue)"
        )
        return MemoirLegacyMigrationReceipt(
            receiptSchemaVersion: MemoirLegacyMigrationReceipt.schemaVersion,
            receiptId: receiptId,
            surfaceId: "memoir",
            sourceLocatorHash: sourceLocatorHash,
            sourceContentHash: sourceContentHash,
            state: state,
            subjectId: subjectId,
            vaultId: vaultId,
            ownerId: ownerId,
            destinationScopeDigest: destinationScopeDigest,
            memoirId: memoirId,
            reason: reason,
            createdAt: Date()
        )
    }

    private func appendReceipt(_ receipt: MemoirLegacyMigrationReceipt) -> Bool {
        let receiptsDirectory = scopedURL("migration-receipts/v1")
        let receiptURL = receiptsDirectory.appendingPathComponent("\(receipt.receiptId).json")
        if fileManager.fileExists(atPath: receiptURL.path) { return true }
        do {
            try fileManager.createDirectory(
                at: receiptsDirectory,
                withIntermediateDirectories: true
            )
            try encoder.encode(receipt).write(to: receiptURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func decodedArtifacts<T: Decodable>(
        _ type: T.Type,
        directory: URL
    ) -> [T] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files.compactMap { fileURL in
            guard fileURL.pathExtension == "json",
                  let data = try? Data(contentsOf: fileURL) else {
                return nil
            }
            return try? decoder.decode(type, from: data)
        }
    }

    private func stageAndCommit(
        _ data: Data,
        to destination: URL,
        commitValidator: () -> Bool
    ) throws {
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let stagingURL = destination.deletingLastPathComponent().appendingPathComponent(
            ".\(destination.lastPathComponent).\(UUID().uuidString).staging"
        )
        do {
            try data.write(to: stagingURL, options: .atomic)
            guard commitValidator() else {
                try? fileManager.removeItem(at: stagingURL)
                throw MemoirOwnerStorageError.staleCommit
            }
            if fileManager.fileExists(atPath: destination.path) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: stagingURL)
            } else {
                try fileManager.moveItem(at: stagingURL, to: destination)
            }
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    private func locatorHash(for sourceURL: URL) -> String {
        let rootPath = rootDirectory.path
        let sourcePath = sourceURL.standardizedFileURL.path
        let relativePath: String
        if sourcePath.hasPrefix(rootPath + "/") {
            relativePath = String(sourcePath.dropFirst(rootPath.count + 1))
        } else {
            relativePath = sourceURL.lastPathComponent
        }
        return MemoirOwnerStoragePolicy.sha256("memoir-legacy-locator-v1|\(relativePath)")
    }

    private func scopedURL(_ relativePath: String) -> URL {
        relativePath.split(separator: "/").reduce(rootDirectory) { partial, component in
            partial.appendingPathComponent(String(component))
        }
    }
}

// MARK: - 回忆录本地持久化（账号与 owner 作用域）
final class MemoirRepository {
    static let shared = MemoirRepository()

    private let storage: MemoirOwnerStorage
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let ownerResolver: (AccountLease) -> String

    private init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        storage = MemoirOwnerStorage(
            rootDirectory: appSupport.appendingPathComponent("memoirs", isDirectory: true)
        )
        accountLeaseRuntime = AccountLeaseRuntime.shared
        ownerResolver = Self.productionOwnerId
    }

    init(
        storage: MemoirOwnerStorage,
        accountLeaseRuntime: AccountLeaseRuntimePort,
        ownerResolver: @escaping (AccountLease) -> String
    ) {
        self.storage = storage
        self.accountLeaseRuntime = accountLeaseRuntime
        self.ownerResolver = ownerResolver
    }

    func getAll() -> [MemoirModel] {
        guard let authorization = captureAuthorization(at: .request) else { return [] }
        return getAll(
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    func getAll(accountLease: AccountLease, ownerId: String) -> [MemoirModel] {
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return []
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        let memoirs = storage.loadAll(scope: scope) { [weak self] in
            self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
        }
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime) else {
            return []
        }
        return memoirs
    }

    func get(by id: String) -> MemoirModel? {
        guard let authorization = captureAuthorization(at: .request) else { return nil }
        return get(
            by: id,
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    func get(by id: String, accountLease: AccountLease, ownerId: String) -> MemoirModel? {
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return nil
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        let memoir = storage.get(id: id, scope: scope) { [weak self] in
            self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
        }
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime) else {
            return nil
        }
        return memoir
    }

    @discardableResult
    func save(_ memoir: MemoirModel) -> Bool {
        guard let authorization = captureAuthorization(at: .request) else { return false }
        return save(
            memoir,
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    @discardableResult
    func save(_ memoir: MemoirModel, accountLease: AccountLease, ownerId: String) -> Bool {
        guard MemoirOwnerStoragePolicy.normalized(memoir.authorId)
                == MemoirOwnerStoragePolicy.normalized(ownerId),
              validateAuthorization(accountLease, ownerId: ownerId, at: .request),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        let isNew = storage.get(id: memoir.id, scope: scope) { [weak self] in
            self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
        } == nil
        do {
            try storage.save(memoir, scope: scope) { [weak self] in
                self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
            }
        } catch {
            memoirStorageLog(
                "save rejected id=\(memoir.id) owner=\(scope.ownerId) error=\(error)"
            )
            return false
        }
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime) else {
            return false
        }

        memoirStorageLog(
            "save id=\(memoir.id) isNew=\(isNew) scope=\(scope.scopeDigest)"
        )
        #if canImport(UIKit)
        if isNew {
            syncToMemoryRepository(
                memoir,
                accountLease: accountLease,
                ownerId: ownerId
            )
        }
        #endif
        if isNew,
           validateAuthorization(accountLease, ownerId: ownerId, at: .ui) {
            NotificationCenter.default.post(name: .djNewMemoirGenerated, object: memoir)
        }
        return true
    }

    #if canImport(UIKit)
    private func syncToMemoryRepository(
        _ memoir: MemoirModel,
        accountLease: AccountLease,
        ownerId: String
    ) {
        let normalizedOwner = MemoirOwnerStoragePolicy.normalized(ownerId)
        guard normalizedOwner == accountLease.subjectId,
              validateAuthorization(accountLease, ownerId: ownerId, at: .commit),
              MemoryRepository.shared.get(
                  by: memoir.id,
                  ownerId: ownerId,
                  accountLease: accountLease
              ) == nil else {
            return
        }

        let prose = memoir.prose.replacingOccurrences(of: "\n", with: " ")
        let subtitle: String
        if let sentenceEnd = prose.firstIndex(where: { "。！？.!?".contains($0) }) {
            subtitle = String(prose[..<sentenceEnd])
        } else {
            subtitle = String(prose.prefix(30))
        }
        let memory = MemoryModel(
            id: memoir.id,
            title: "\(memoir.location) · \(memoir.year)年\(memoir.month)月",
            subtitle: subtitle,
            fullContent: memoir.prose,
            location: memoir.location,
            year: memoir.year,
            month: memoir.month,
            latitude: memoir.latitude,
            longitude: memoir.longitude,
            imageNames: [],
            audioName: memoir.sessionId,
            isPrivate: memoir.isPrivate,
            authorId: ownerId
        )
        guard MemoryRepository.shared.add(
            memory,
            ownerId: ownerId,
            accountLease: accountLease
        ) else {
            memoirStorageLog("memory bridge rejected id=\(memoir.id) owner=\(ownerId)")
            return
        }
        memoirStorageLog("memory bridge saved id=\(memoir.id) owner=\(ownerId)")
    }
    #endif

    @discardableResult
    func delete(id: String) -> Bool {
        guard let authorization = captureAuthorization(at: .request) else { return false }
        return delete(
            id: id,
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    @discardableResult
    func delete(id: String, accountLease: AccountLease, ownerId: String) -> Bool {
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .request),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        do {
            return try storage.delete(id: id, scope: scope) { [weak self] in
                self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
            }
        } catch {
            memoirStorageLog(
                "delete rejected id=\(id) owner=\(scope.ownerId) error=\(error)"
            )
            return false
        }
    }

    func saveRecording(from sourceURL: URL, sessionId: String) -> URL? {
        guard let authorization = captureAuthorization(at: .request) else { return nil }
        return saveRecording(
            from: sourceURL,
            sessionId: sessionId,
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    func saveRecording(
        from sourceURL: URL,
        sessionId: String,
        accountLease: AccountLease,
        ownerId: String
    ) -> URL? {
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .request),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return nil
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        do {
            let destination = try storage.saveRecording(
                from: sourceURL,
                sessionId: sessionId,
                scope: scope
            ) { [weak self] in
                self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
            }
            guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime) else {
                return nil
            }
            memoirStorageLog(
                "recording saved sessionHash=\(MemoirOwnerStoragePolicy.pathDigest(sessionId)) scope=\(scope.scopeDigest)"
            )
            return destination
        } catch {
            memoirStorageLog("recording save rejected error=\(error)")
            return nil
        }
    }

    func getRecordingURL(sessionId: String) -> URL? {
        guard let authorization = captureAuthorization(at: .request) else { return nil }
        return getRecordingURL(
            sessionId: sessionId,
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    func getRecordingURL(
        sessionId: String,
        accountLease: AccountLease,
        ownerId: String
    ) -> URL? {
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .runtime) else {
            return nil
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        return storage.getRecordingURL(sessionId: sessionId, scope: scope)
    }

    @discardableResult
    func deleteRecording(sessionId: String) -> Bool {
        guard let authorization = captureAuthorization(at: .request) else { return false }
        return deleteRecording(
            sessionId: sessionId,
            accountLease: authorization.accountLease,
            ownerId: authorization.scope.ownerId
        )
    }

    @discardableResult
    func deleteRecording(
        sessionId: String,
        accountLease: AccountLease,
        ownerId: String
    ) -> Bool {
        guard validateAuthorization(accountLease, ownerId: ownerId, at: .request),
              accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
            return false
        }
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        do {
            return try storage.deleteRecording(
                sessionId: sessionId,
                scope: scope
            ) { [weak self] in
                self?.validateAuthorization(accountLease, ownerId: ownerId, at: .commit) == true
            }
        } catch {
            memoirStorageLog("recording delete rejected error=\(error)")
            return false
        }
    }

    func captureAccountLeaseAndOwner() -> (accountLease: AccountLease, ownerId: String)? {
        guard let authorization = captureAuthorization(at: .request) else { return nil }
        return (authorization.accountLease, authorization.scope.ownerId)
    }

    func validateAccountLease(
        _ accountLease: AccountLease,
        ownerId: String,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        validateAuthorization(accountLease, ownerId: ownerId, at: checkpoint)
    }

    private func captureAuthorization(
        at checkpoint: AccountLeaseCheckpoint
    ) -> (accountLease: AccountLease, scope: MemoirStorageScope)? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed else {
            memoirStorageLog("lease unavailable checkpoint=\(checkpoint.rawValue)")
            return nil
        }
        let ownerId = MemoirOwnerStoragePolicy.normalized(ownerResolver(accountLease))
        let scope = MemoirStorageScope(accountLease: accountLease, ownerId: ownerId)
        guard scope.isValid else {
            memoirStorageLog("owner unavailable checkpoint=\(checkpoint.rawValue)")
            return nil
        }
        return (accountLease, scope)
    }

    private func validateAuthorization(
        _ accountLease: AccountLease,
        ownerId: String,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        guard accountLeaseRuntime.validate(accountLease, at: checkpoint).allowed else {
            memoirStorageLog("stale lease checkpoint=\(checkpoint.rawValue)")
            return false
        }
        let expectedOwner = MemoirOwnerStoragePolicy.normalized(ownerId)
        let activeOwner = MemoirOwnerStoragePolicy.normalized(ownerResolver(accountLease))
        guard !expectedOwner.isEmpty, expectedOwner == activeOwner else {
            memoirStorageLog("owner changed checkpoint=\(checkpoint.rawValue)")
            return false
        }
        return true
    }

    private static func productionOwnerId(accountLease: AccountLease) -> String {
        #if canImport(UIKit)
        let context = DigitalHumanContextStore.shared.current
        let viewerId = context.viewerUserId?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        let ownerId = context.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard viewerId == accountLease.subjectId, !ownerId.isEmpty else { return "" }
        return ownerId
        #else
        return accountLease.subjectId
        #endif
    }
}

private func memoirStorageLog(_ message: String) {
    #if canImport(CocoaLumberjack)
    DDLogInfo("[MemoirStorage] \(message)")
    #else
    print("[MemoirStorage] \(message)")
    #endif
}

// MARK: - Notification
extension Notification.Name {
    static let djNewMemoirGenerated = Notification.Name("dj.memoir.newGenerated")
    static let djMemoirAudioReady = Notification.Name("dj.memoir.audioReady")
    static let djDialogDidStart = Notification.Name("dj.dialog.didStart")
    static let djDialogDidStop = Notification.Name("dj.dialog.didStop")
}
