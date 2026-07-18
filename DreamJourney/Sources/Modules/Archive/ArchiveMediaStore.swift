import CryptoKit
import Foundation

enum ArchiveMediaStorageClass {
    case original
    case thumbnail
}

enum ArchiveMediaRole {
    case original
    case thumbnail

    fileprivate var relativePathKey: String {
        switch self {
        case .original:
            return "archiveMediaRelativePath"
        case .thumbnail:
            return "archiveThumbnailRelativePath"
        }
    }

    fileprivate var sha256Key: String {
        switch self {
        case .original:
            return "archiveMediaSHA256"
        case .thumbnail:
            return "archiveThumbnailSHA256"
        }
    }

    fileprivate var sizeBytesKey: String {
        switch self {
        case .original:
            return "archiveMediaSizeBytes"
        case .thumbnail:
            return "archiveThumbnailSizeBytes"
        }
    }

    fileprivate var scopeDigestKey: String {
        switch self {
        case .original:
            return "archiveMediaScopeDigest"
        case .thumbnail:
            return "archiveThumbnailScopeDigest"
        }
    }
}

struct ArchiveMediaMetadata: Equatable {
    let relativePath: String
    let sha256: String
    let sizeBytes: Int64
    let scopeDigest: String

    init(
        relativePath: String,
        sha256: String,
        sizeBytes: Int64,
        scopeDigest: String
    ) {
        self.relativePath = relativePath
        self.sha256 = sha256
        self.sizeBytes = sizeBytes
        self.scopeDigest = scopeDigest
    }

    init?(itemMetadata: [String: String], role: ArchiveMediaRole) {
        guard let relativePath = itemMetadata[role.relativePathKey],
              let sha256 = itemMetadata[role.sha256Key],
              let sizeValue = itemMetadata[role.sizeBytesKey],
              let sizeBytes = Int64(sizeValue),
              sizeBytes >= 0,
              let scopeDigest = itemMetadata[role.scopeDigestKey] else {
            return nil
        }
        self.init(
            relativePath: relativePath,
            sha256: sha256,
            sizeBytes: sizeBytes,
            scopeDigest: scopeDigest
        )
    }

    func itemMetadata(for role: ArchiveMediaRole) -> [String: String] {
        [
            role.relativePathKey: relativePath,
            role.sha256Key: sha256,
            role.sizeBytesKey: "\(sizeBytes)",
            role.scopeDigestKey: scopeDigest,
        ]
    }
}

struct ArchiveMediaWriteTarget {
    let fileURL: URL

    fileprivate let relativePath: String
    fileprivate let scopeDigest: String
    fileprivate let storageClass: ArchiveMediaStorageClass
}

struct ArchiveLegacyMediaMigrationBinding: Equatable {
    let itemId: String
    let canonicalPathDigest: String
    let contentHash: String

    fileprivate let receiptId: String
    fileprivate let receiptSourceContentHash: String
    fileprivate let sourceFileIdentity: String
    fileprivate let canonicalSourceURL: URL
}

enum ArchiveMediaStoreError: Error {
    case invalidScope
    case invalidFileExtension
    case invalidRelativePath
    case invalidMetadata
    case fileMissing
    case notRegularFile
    case scopeMismatch
    case checksumMismatch
    case sizeMismatch
    case legacyOwnerProofRejected
}

final class ArchiveMediaStore {
    static let shared = ArchiveMediaStore()

    private struct ValidatedLegacySource {
        let canonicalURL: URL
        let attributes: [FileAttributeKey: Any]
    }

    private struct LegacyMigrationRecord: Codable {
        static let schemaVersion = 1

        let version: Int
        let receiptId: String
        let receiptSourceContentHash: String
        let itemId: String
        let canonicalPathDigest: String
        let contentHash: String
        let sourceFileIdentity: String
        let destinationRelativePath: String
        let destinationSHA256: String
        let destinationSizeBytes: Int64
        let destinationScopeDigest: String

        init(
            binding: ArchiveLegacyMediaMigrationBinding,
            destination: ArchiveMediaMetadata
        ) {
            version = Self.schemaVersion
            receiptId = binding.receiptId
            receiptSourceContentHash = binding.receiptSourceContentHash
            itemId = binding.itemId
            canonicalPathDigest = binding.canonicalPathDigest
            contentHash = binding.contentHash
            sourceFileIdentity = binding.sourceFileIdentity
            destinationRelativePath = destination.relativePath
            destinationSHA256 = destination.sha256
            destinationSizeBytes = destination.sizeBytes
            destinationScopeDigest = destination.scopeDigest
        }

        var destination: ArchiveMediaMetadata {
            ArchiveMediaMetadata(
                relativePath: destinationRelativePath,
                sha256: destinationSHA256,
                sizeBytes: destinationSizeBytes,
                scopeDigest: destinationScopeDigest
            )
        }

        func matches(_ binding: ArchiveLegacyMediaMigrationBinding) -> Bool {
            version == Self.schemaVersion
                && receiptId == binding.receiptId
                && receiptSourceContentHash == binding.receiptSourceContentHash
                && itemId == binding.itemId
                && canonicalPathDigest == binding.canonicalPathDigest
                && contentHash == binding.contentHash
                && sourceFileIdentity == binding.sourceFileIdentity
        }
    }

    private static let legacyMediaDirectoryNames = [
        "archive-images",
        "archive-audio",
        "archive-video",
        "archive-video-thumbnails",
        "archive-time-letter-images",
    ]
    private static let legacyMigrationLedgerFileName = ".legacy-media-migrations-v1.json"

    private let fileManager: FileManager
    private let applicationSupportRootOverride: URL?
    private let cachesRootOverride: URL?
    private let legacyDocumentsRootOverride: URL?
    private let currentScopeResolver: (String) -> ArchiveStorageScope?
    private let legacyMigrationLock = NSLock()

    init(
        fileManager: FileManager = .default,
        applicationSupportRoot: URL? = nil,
        cachesRoot: URL? = nil,
        legacyDocumentsRoot: URL? = nil,
        currentScopeResolver: ((String) -> ArchiveStorageScope?)? = nil
    ) {
        self.fileManager = fileManager
        applicationSupportRootOverride = applicationSupportRoot
        cachesRootOverride = cachesRoot
        legacyDocumentsRootOverride = legacyDocumentsRoot
        self.currentScopeResolver = currentScopeResolver ?? Self.resolveCurrentScope
    }

    func write(
        _ data: Data,
        fileExtension: String,
        scope: ArchiveStorageScope,
        storageClass: ArchiveMediaStorageClass = .original
    ) throws -> ArchiveMediaMetadata {
        let target = try prepareWriteTarget(
            fileExtension: fileExtension,
            scope: scope,
            storageClass: storageClass
        )
        do {
            try data.write(to: target.fileURL, options: [.atomic])
            return try finalizeWriteTarget(target)
        } catch {
            discardWriteTarget(target)
            throw error
        }
    }

    func importFile(
        at sourceURL: URL,
        fileExtension: String? = nil,
        scope: ArchiveStorageScope,
        storageClass: ArchiveMediaStorageClass = .original
    ) throws -> ArchiveMediaMetadata {
        guard try isRegularFile(at: sourceURL) else {
            throw ArchiveMediaStoreError.notRegularFile
        }
        let target = try prepareWriteTarget(
            fileExtension: fileExtension ?? sourceURL.pathExtension,
            scope: scope,
            storageClass: storageClass
        )
        do {
            try fileManager.copyItem(at: sourceURL, to: target.fileURL)
            return try finalizeWriteTarget(target)
        } catch {
            discardWriteTarget(target)
            throw error
        }
    }

    func prepareWriteTarget(
        fileExtension: String,
        scope: ArchiveStorageScope,
        storageClass: ArchiveMediaStorageClass = .original
    ) throws -> ArchiveMediaWriteTarget {
        let normalizedExtension = try Self.normalizedFileExtension(fileExtension)
        let scopeDigest = try Self.scopeDigest(for: scope)
        let relativePath = scope.mediaDirectoryRelativePath
            + "/"
            + UUID().uuidString
            + "."
            + normalizedExtension
        let fileURL = try managedFileURL(
            relativePath: relativePath,
            scope: scope,
            storageClass: storageClass,
            createDirectory: true
        )
        guard !fileManager.fileExists(atPath: fileURL.path) else {
            throw ArchiveMediaStoreError.invalidRelativePath
        }
        return ArchiveMediaWriteTarget(
            fileURL: fileURL,
            relativePath: relativePath,
            scopeDigest: scopeDigest,
            storageClass: storageClass
        )
    }

    func finalizeWriteTarget(_ target: ArchiveMediaWriteTarget) throws -> ArchiveMediaMetadata {
        guard fileManager.fileExists(atPath: target.fileURL.path) else {
            throw ArchiveMediaStoreError.fileMissing
        }
        guard try isRegularFile(at: target.fileURL) else {
            throw ArchiveMediaStoreError.notRegularFile
        }
        try applyLocalFilePolicy(to: target.fileURL)
        return ArchiveMediaMetadata(
            relativePath: target.relativePath,
            sha256: try Self.sha256(of: target.fileURL),
            sizeBytes: try Self.fileSize(at: target.fileURL, fileManager: fileManager),
            scopeDigest: target.scopeDigest
        )
    }

    func discardWriteTarget(_ target: ArchiveMediaWriteTarget) {
        try? fileManager.removeItem(at: target.fileURL)
    }

    func resolvedFileURL(
        for metadata: ArchiveMediaMetadata,
        scope: ArchiveStorageScope,
        storageClass: ArchiveMediaStorageClass = .original
    ) throws -> URL {
        guard metadata.scopeDigest == (try Self.scopeDigest(for: scope)) else {
            throw ArchiveMediaStoreError.scopeMismatch
        }
        let fileURL = try managedFileURL(
            relativePath: metadata.relativePath,
            scope: scope,
            storageClass: storageClass,
            createDirectory: false
        )
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw ArchiveMediaStoreError.fileMissing
        }
        guard try isRegularFile(at: fileURL) else {
            throw ArchiveMediaStoreError.notRegularFile
        }
        guard try Self.fileSize(at: fileURL, fileManager: fileManager) == metadata.sizeBytes else {
            throw ArchiveMediaStoreError.sizeMismatch
        }
        guard try Self.sha256(of: fileURL) == metadata.sha256 else {
            throw ArchiveMediaStoreError.checksumMismatch
        }
        return fileURL
    }

    func resolvedFileURL(
        for metadata: ArchiveMediaMetadata,
        archiveOwnerId: String,
        storageClass: ArchiveMediaStorageClass = .original
    ) throws -> URL {
        let normalizedOwner = archiveOwnerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwner.isEmpty,
              normalizedOwner != MemoryArchiveItem.legacyOwnerUserId,
              let scope = currentScopeResolver(normalizedOwner) else {
            throw ArchiveMediaStoreError.invalidScope
        }
        return try resolvedFileURL(
            for: metadata,
            scope: scope,
            storageClass: storageClass
        )
    }

    func remove(
        _ metadata: ArchiveMediaMetadata,
        scope: ArchiveStorageScope,
        storageClass: ArchiveMediaStorageClass = .original
    ) throws {
        guard metadata.scopeDigest == (try Self.scopeDigest(for: scope)) else {
            throw ArchiveMediaStoreError.scopeMismatch
        }
        let fileURL = try managedFileURL(
            relativePath: metadata.relativePath,
            scope: scope,
            storageClass: storageClass,
            createDirectory: false
        )
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try fileManager.removeItem(at: fileURL)
    }

    func purgeScopedDirectories(relativePaths: [String]) throws {
        for relativePath in Set(relativePaths) {
            let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard components.count == 4,
                  components[0] == "DreamJourney",
                  components[1] == "Archive",
                  components[2] == "v2",
                  !components[3].isEmpty,
                  components.allSatisfy({ $0 != "." && $0 != ".." }) else {
                throw ArchiveMediaStoreError.invalidRelativePath
            }

            for storageClass in [ArchiveMediaStorageClass.original, .thumbnail] {
                let rootURL = try storageRoot(for: storageClass, create: false)
                let directoryURL = components.reduce(rootURL) {
                    $0.appendingPathComponent($1, isDirectory: true)
                }.standardizedFileURL
                let resolvedRootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
                let resolvedDirectoryURL = directoryURL.resolvingSymlinksInPath().standardizedFileURL
                guard Self.isDescendant(resolvedDirectoryURL, of: resolvedRootURL) else {
                    throw ArchiveMediaStoreError.invalidRelativePath
                }
                if fileManager.fileExists(atPath: directoryURL.path) {
                    try fileManager.removeItem(at: directoryURL)
                }
            }
        }
    }

    func legacyMigrationBinding(
        for item: MemoryArchiveItem,
        receipt: ArchiveLegacyMigrationReceipt,
        scope: ArchiveStorageScope
    ) throws -> ArchiveLegacyMediaMigrationBinding {
        try validateLegacyMigrationAuthority(for: item, receipt: receipt, scope: scope)
        let source = try validatedLegacySource(for: item)
        guard let modificationDate = source.attributes[.modificationDate] as? Date,
              modificationDate <= receipt.createdAt else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }
        return ArchiveLegacyMediaMigrationBinding(
            itemId: item.id,
            canonicalPathDigest: Self.sha256(
                Data("archive-legacy-canonical-path-v1|\(source.canonicalURL.path)".utf8)
            ),
            contentHash: try Self.sha256(of: source.canonicalURL),
            receiptId: receipt.receiptId,
            receiptSourceContentHash: receipt.sourceContentHash,
            sourceFileIdentity: try Self.sourceFileIdentity(from: source.attributes),
            canonicalSourceURL: source.canonicalURL
        )
    }

    func migrateLegacyOriginal(
        for item: MemoryArchiveItem,
        receipt: ArchiveLegacyMigrationReceipt,
        binding: ArchiveLegacyMediaMigrationBinding,
        scope: ArchiveStorageScope
    ) throws -> ArchiveMediaMetadata {
        let currentBinding = try legacyMigrationBinding(for: item, receipt: receipt, scope: scope)
        guard currentBinding == binding else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }

        legacyMigrationLock.lock()
        defer { legacyMigrationLock.unlock() }

        let ledgerURL = try legacyMigrationLedgerURL(scope: scope)
        var records = try loadLegacyMigrationRecords(at: ledgerURL)
        if let record = records.first(where: { $0.itemId == binding.itemId }) {
            guard record.matches(binding) else {
                throw ArchiveMediaStoreError.legacyOwnerProofRejected
            }
            do {
                _ = try resolvedFileURL(for: record.destination, scope: scope)
                return record.destination
            } catch ArchiveMediaStoreError.fileMissing {
                // A repository rollback removes the copy. The same source binding may retry it.
            }
        }

        let destination = try importFile(
            at: binding.canonicalSourceURL,
            scope: scope,
            storageClass: .original
        )
        do {
            let postCopyBinding = try legacyMigrationBinding(for: item, receipt: receipt, scope: scope)
            guard postCopyBinding == binding,
                  destination.sha256 == binding.contentHash else {
                throw ArchiveMediaStoreError.legacyOwnerProofRejected
            }

            let record = LegacyMigrationRecord(binding: binding, destination: destination)
            if let index = records.firstIndex(where: { $0.itemId == binding.itemId }) {
                records[index] = record
            } else {
                records.append(record)
            }
            try saveLegacyMigrationRecords(records, at: ledgerURL)
            return destination
        } catch {
            try? remove(destination, scope: scope, storageClass: .original)
            throw error
        }
    }

    private func validateLegacyMigrationAuthority(
        for item: MemoryArchiveItem,
        receipt: ArchiveLegacyMigrationReceipt,
        scope: ArchiveStorageScope
    ) throws {
        let normalizedOwner = item.ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard scope.isValid,
              normalizedOwner == scope.archiveOwnerId,
              normalizedOwner != MemoryArchiveItem.legacyOwnerUserId,
              receipt.receiptId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              receipt.sourceStorageKey == scope.legacyStorageKey,
              receipt.subjectId == scope.subjectId,
              receipt.vaultId == scope.vaultId,
              receipt.archiveOwnerId == scope.archiveOwnerId,
              receipt.destinationStorageKey == scope.storageKey,
              receipt.state == .migrated || receipt.state == .mixed,
              receipt.migratedItemIds.contains(item.id),
              Self.isSHA256Digest(receipt.sourceContentHash) else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }
    }

    static func scopeDigest(for scope: ArchiveStorageScope) throws -> String {
        guard scope.isValid else { throw ArchiveMediaStoreError.invalidScope }
        let components = scope.mediaDirectoryRelativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 4,
              components[0] == "DreamJourney",
              components[1] == "Archive",
              components[2] == "v2",
              !components[3].isEmpty else {
            throw ArchiveMediaStoreError.invalidScope
        }
        return String(components[3])
    }

    private func validatedLegacySource(for item: MemoryArchiveItem) throws -> ValidatedLegacySource {
        guard let legacyPath = item.localPath,
              NSString(string: legacyPath).isAbsolutePath else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }
        let rawComponents = legacyPath.split(separator: "/", omittingEmptySubsequences: false)
        guard rawComponents.first?.isEmpty == true,
              rawComponents.dropFirst().allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".."
              }) else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }

        let candidateURL = URL(fileURLWithPath: legacyPath, isDirectory: false).standardizedFileURL
        let documentsRoot = (legacyDocumentsRootOverride ?? URL(
            fileURLWithPath: NSHomeDirectory(),
            isDirectory: true
        ).appendingPathComponent("Documents", isDirectory: true)).standardizedFileURL
        let allowedRoots = Self.legacyMediaDirectoryNames.map {
            documentsRoot.appendingPathComponent($0, isDirectory: true).standardizedFileURL
        }
        guard let allowedRoot = allowedRoots.first(where: {
            Self.isDescendant(candidateURL, of: $0)
        }) else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }

        let rootAttributes = try legacySourceAttributes(at: allowedRoot)
        guard rootAttributes[.type] as? FileAttributeType != .typeSymbolicLink,
              rootAttributes[.type] as? FileAttributeType == .typeDirectory else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }

        let relativePath = String(candidateURL.path.dropFirst(allowedRoot.path.count + 1))
        let components = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }

        var currentURL = allowedRoot
        var sourceAttributes = rootAttributes
        for (index, component) in components.enumerated() {
            currentURL.appendPathComponent(component, isDirectory: index < components.count - 1)
            sourceAttributes = try legacySourceAttributes(at: currentURL)
            let fileType = sourceAttributes[.type] as? FileAttributeType
            guard fileType != .typeSymbolicLink else {
                throw ArchiveMediaStoreError.legacyOwnerProofRejected
            }
            if index < components.count - 1 {
                guard fileType == .typeDirectory else {
                    throw ArchiveMediaStoreError.legacyOwnerProofRejected
                }
            } else if fileType != .typeRegular {
                throw ArchiveMediaStoreError.notRegularFile
            }
        }

        let canonicalRoot = allowedRoot.resolvingSymlinksInPath().standardizedFileURL
        let canonicalURL = candidateURL.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isDescendant(canonicalURL, of: canonicalRoot) else {
            throw ArchiveMediaStoreError.legacyOwnerProofRejected
        }
        return ValidatedLegacySource(
            canonicalURL: canonicalURL,
            attributes: sourceAttributes
        )
    }

    private func legacySourceAttributes(at url: URL) throws -> [FileAttributeKey: Any] {
        do {
            return try fileManager.attributesOfItem(atPath: url.path)
        } catch {
            throw ArchiveMediaStoreError.fileMissing
        }
    }

    private func legacyMigrationLedgerURL(scope: ArchiveStorageScope) throws -> URL {
        _ = try Self.scopeDigest(for: scope)
        let rootURL = try storageRoot(for: .original, create: true).standardizedFileURL
        let directoryURL = scope.mediaDirectoryRelativePath.split(separator: "/").reduce(rootURL) {
            $0.appendingPathComponent(String($1), isDirectory: true)
        }.standardizedFileURL
        let resolvedRootURL = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedDirectoryURL = directoryURL.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isDescendant(resolvedDirectoryURL, of: resolvedRootURL) else {
            throw ArchiveMediaStoreError.invalidRelativePath
        }
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try applyLocalFilePolicy(to: directoryURL)
        return directoryURL.appendingPathComponent(
            Self.legacyMigrationLedgerFileName,
            isDirectory: false
        )
    }

    private func loadLegacyMigrationRecords(at ledgerURL: URL) throws -> [LegacyMigrationRecord] {
        guard fileManager.fileExists(atPath: ledgerURL.path) else { return [] }
        let attributes = try fileManager.attributesOfItem(atPath: ledgerURL.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw ArchiveMediaStoreError.invalidMetadata
        }
        do {
            let records = try JSONDecoder().decode(
                [LegacyMigrationRecord].self,
                from: Data(contentsOf: ledgerURL)
            )
            guard records.allSatisfy({ $0.version == LegacyMigrationRecord.schemaVersion }),
                  Set(records.map(\.itemId)).count == records.count else {
                throw ArchiveMediaStoreError.invalidMetadata
            }
            return records
        } catch let error as ArchiveMediaStoreError {
            throw error
        } catch {
            throw ArchiveMediaStoreError.invalidMetadata
        }
    }

    private func saveLegacyMigrationRecords(
        _ records: [LegacyMigrationRecord],
        at ledgerURL: URL
    ) throws {
        if fileManager.fileExists(atPath: ledgerURL.path) {
            let attributes = try fileManager.attributesOfItem(atPath: ledgerURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw ArchiveMediaStoreError.invalidMetadata
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(records.sorted { $0.itemId < $1.itemId })
        try data.write(to: ledgerURL, options: [.atomic])
        try applyLocalFilePolicy(to: ledgerURL)
    }

    private static func resolveCurrentScope(archiveOwnerId: String) -> ArchiveStorageScope? {
        guard let accountLease = AccountLeaseRuntime.shared.capture(),
              AccountLeaseRuntime.shared.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        let scope = ArchiveStorageScope(
            accountLease: accountLease,
            archiveOwnerId: archiveOwnerId
        )
        return scope.isValid ? scope : nil
    }

    private func managedFileURL(
        relativePath: String,
        scope: ArchiveStorageScope,
        storageClass: ArchiveMediaStorageClass,
        createDirectory: Bool
    ) throws -> URL {
        let expectedDirectoryComponents = scope.mediaDirectoryRelativePath.split(separator: "/").map(String.init)
        let relativeComponents = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !relativePath.hasPrefix("/"),
              relativeComponents.count == expectedDirectoryComponents.count + 1,
              Array(relativeComponents.dropLast()) == expectedDirectoryComponents,
              relativeComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let fileName = relativeComponents.last,
              Self.isUUIDFileName(fileName) else {
            throw ArchiveMediaStoreError.invalidRelativePath
        }

        let rootURL = try storageRoot(for: storageClass, create: createDirectory)
        let directoryURL = expectedDirectoryComponents.reduce(rootURL) {
            $0.appendingPathComponent($1, isDirectory: true)
        }
        if createDirectory {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try applyLocalFilePolicy(to: directoryURL)
        } else if !fileManager.fileExists(atPath: directoryURL.path) {
            throw ArchiveMediaStoreError.fileMissing
        }

        let candidateURL = directoryURL.appendingPathComponent(fileName, isDirectory: false).standardizedFileURL
        let resolvedDirectoryURL = directoryURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedCandidateURL = candidateURL.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isDescendant(resolvedCandidateURL, of: resolvedDirectoryURL) else {
            throw ArchiveMediaStoreError.invalidRelativePath
        }
        return candidateURL
    }

    private func storageRoot(
        for storageClass: ArchiveMediaStorageClass,
        create: Bool
    ) throws -> URL {
        if storageClass == .original, let applicationSupportRootOverride {
            return applicationSupportRootOverride
        }
        if storageClass == .thumbnail, let cachesRootOverride {
            return cachesRootOverride
        }
        let searchDirectory: FileManager.SearchPathDirectory = storageClass == .original
            ? .applicationSupportDirectory
            : .cachesDirectory
        return try fileManager.url(
            for: searchDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
    }

    private func applyLocalFilePolicy(to url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)

        #if os(iOS) || os(tvOS) || os(watchOS)
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
        #endif
    }

    private func isRegularFile(at url: URL) throws -> Bool {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.type] as? FileAttributeType == .typeRegular
    }

    private static func normalizedFileExtension(_ value: String) throws -> String {
        let normalized = value
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
        guard !normalized.isEmpty,
              normalized.count <= 16,
              normalized.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            throw ArchiveMediaStoreError.invalidFileExtension
        }
        return normalized
    }

    private static func isUUIDFileName(_ fileName: String) -> Bool {
        let stem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        return !URL(fileURLWithPath: fileName).pathExtension.isEmpty && UUID(uuidString: stem) != nil
    }

    private static func isDescendant(_ candidate: URL, of directory: URL) -> Bool {
        candidate.path.hasPrefix(directory.path + "/")
    }

    private static func isSHA256Digest(_ value: String) -> Bool {
        guard value.hasPrefix("sha256:") else { return false }
        let digest = value.dropFirst("sha256:".count)
        return digest.count == 64 && digest.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdef").contains($0)
        }
    }

    private static func sourceFileIdentity(
        from attributes: [FileAttributeKey: Any]
    ) throws -> String {
        guard let systemNumber = attributes[.systemNumber] as? NSNumber,
              let fileNumber = attributes[.systemFileNumber] as? NSNumber,
              let size = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date else {
            throw ArchiveMediaStoreError.invalidMetadata
        }
        let identity = [
            "archive-legacy-file-identity-v1",
            systemNumber.stringValue,
            fileNumber.stringValue,
            size.stringValue,
            String(modificationDate.timeIntervalSinceReferenceDate.bitPattern, radix: 16),
        ].joined(separator: "|")
        return sha256(Data(identity.utf8))
    }

    private static func fileSize(at url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber else {
            throw ArchiveMediaStoreError.invalidMetadata
        }
        return size.int64Value
    }

    private static func sha256(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return "sha256:" + hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
