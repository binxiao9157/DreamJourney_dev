import CryptoKit
import Foundation

enum AccountPrivateMediaKind: String, Equatable {
    case persistentPhoto
    case photoStaging
    case recordingStaging

    fileprivate var directoryName: String {
        switch self {
        case .persistentPhoto:
            return "photos"
        case .photoStaging:
            return "photo-staging"
        case .recordingStaging:
            return "recording-staging"
        }
    }

    fileprivate var usesApplicationSupport: Bool {
        self == .persistentPhoto
    }
}

struct AccountPrivateMediaArtifact: Equatable {
    let fileURL: URL
    let kind: AccountPrivateMediaKind
    let scopeDigest: String

    fileprivate let relativePath: String
    fileprivate let accountLease: AccountLease
}

enum AccountPrivateMediaLegacySurface: String, Codable, Equatable {
    case documentsPhotos = "documents_photos"
    case temporarySessionRecordings = "temporary_session_recordings"

    fileprivate var sourceLocatorRoot: String {
        switch self {
        case .documentsPhotos:
            return "legacy://documents/photos"
        case .temporarySessionRecordings:
            return "legacy://temporary/TGSessionRecordings"
        }
    }
}

enum AccountPrivateMediaLegacyDisposition: String, Codable, Equatable {
    case quarantined
    case discarded
}

struct AccountPrivateMediaLegacyReceipt: Codable, Equatable {
    static let schemaVersion = 1

    let receiptSchemaVersion: Int
    let receiptId: String
    let surface: AccountPrivateMediaLegacySurface
    let sourceLocator: String
    let sourceLocatorHash: String
    let sourceContentHash: String
    let disposition: AccountPrivateMediaLegacyDisposition
    let quarantineRelativePath: String?
    let processedAt: Date
}

enum AccountPrivateMediaStoreError: Error {
    case invalidScope
    case staleLease
    case invalidFileExtension
    case invalidArtifact
    case emptyPayload
    case fileMissing
    case notRegularFile
    case unsafeLegacySource
    case corruptLegacyReceipt
    case contentHashMismatch
}

final class AccountPrivateMediaStore: @unchecked Sendable {
    typealias LeaseValidator = (AccountLease, AccountLeaseCheckpoint) -> Bool

    static let shared = AccountPrivateMediaStore()

    private static let managedRootComponents = [
        "DreamJourney",
        "AccountPrivateMedia",
        "v1",
    ]
    private static let legacyRetirementComponents = [
        "DreamJourney",
        "AccountPrivateMedia",
        "legacy-retirement",
        "v1",
    ]
    private static let persistentPhotoReferencePrefix = "dj-account-private-media-v1:"

    private let fileManager: FileManager
    private let applicationSupportRootOverride: URL?
    private let cachesRootOverride: URL?
    private let legacyDocumentsRootOverride: URL?
    private let legacyTemporaryRootOverride: URL?
    private let now: () -> Date
    private let leaseValidator: LeaseValidator
    private let legacyRetirementLock = NSLock()

    init(
        fileManager: FileManager = .default,
        applicationSupportRoot: URL? = nil,
        cachesRoot: URL? = nil,
        legacyDocumentsRoot: URL? = nil,
        legacyTemporaryRoot: URL? = nil,
        now: @escaping () -> Date = Date.init,
        leaseValidator: @escaping LeaseValidator = { accountLease, checkpoint in
            AccountLeaseRuntime.shared.validate(accountLease, at: checkpoint).allowed
        }
    ) {
        self.fileManager = fileManager
        applicationSupportRootOverride = applicationSupportRoot
        cachesRootOverride = cachesRoot
        legacyDocumentsRootOverride = legacyDocumentsRoot
        legacyTemporaryRootOverride = legacyTemporaryRoot
        self.now = now
        self.leaseValidator = leaseValidator
    }

    func writePhoto(
        _ data: Data,
        fileExtension: String = "jpg",
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        guard !data.isEmpty else { throw AccountPrivateMediaStoreError.emptyPayload }
        try validateLease(accountLease, at: .request)
        let artifact = try makeArtifact(
            kind: .persistentPhoto,
            fileExtension: fileExtension,
            accountLease: accountLease
        )
        do {
            try data.write(to: artifact.fileURL, options: [.atomic])
            try applyLocalFilePolicy(to: artifact.fileURL)
            try validateLease(accountLease, at: .commit)
            return artifact
        } catch {
            discard(artifact)
            throw error
        }
    }

    func writePhotoStaging(
        _ data: Data,
        fileExtension: String = "jpg",
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        guard !data.isEmpty else { throw AccountPrivateMediaStoreError.emptyPayload }
        try validateLease(accountLease, at: .request)
        let artifact = try makeArtifact(
            kind: .photoStaging,
            fileExtension: fileExtension,
            accountLease: accountLease
        )
        do {
            try data.write(to: artifact.fileURL, options: [.atomic])
            try applyLocalFilePolicy(to: artifact.fileURL)
            try validateLease(accountLease, at: .commit)
            return artifact
        } catch {
            discard(artifact)
            throw error
        }
    }

    func promotePhotoStaging(
        _ artifact: AccountPrivateMediaArtifact,
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        try validateLease(accountLease, at: .request)
        guard artifact.kind == .photoStaging,
              artifact.accountLease == accountLease else {
            throw AccountPrivateMediaStoreError.staleLease
        }
        let sourceURL = try validatedManagedURL(for: artifact)
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw AccountPrivateMediaStoreError.fileMissing
        }
        guard try isRegularFile(at: sourceURL) else {
            throw AccountPrivateMediaStoreError.notRegularFile
        }
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        guard (attributes[.size] as? NSNumber)?.int64Value ?? 0 > 0 else {
            throw AccountPrivateMediaStoreError.emptyPayload
        }

        let destinationArtifact = try makeArtifact(
            kind: .persistentPhoto,
            fileExtension: sourceURL.pathExtension,
            accountLease: accountLease
        )
        do {
            try fileManager.moveItem(at: sourceURL, to: destinationArtifact.fileURL)
            try applyLocalFilePolicy(to: destinationArtifact.fileURL)
            try validateLease(accountLease, at: .commit)
            return destinationArtifact
        } catch {
            discard(destinationArtifact)
            throw error
        }
    }

    func persistentPhotoReference(
        for artifact: AccountPrivateMediaArtifact
    ) throws -> String {
        guard artifact.kind == .persistentPhoto else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }
        try validateLease(artifact.accountLease, at: .runtime)
        let fileURL = try validatedManagedURL(for: artifact)
        guard fileManager.fileExists(atPath: fileURL.path),
              try isRegularFile(at: fileURL) else {
            throw AccountPrivateMediaStoreError.fileMissing
        }
        return Self.persistentPhotoReferencePrefix + artifact.relativePath
    }

    func resolvePersistentPhoto(
        reference: String,
        accountLease: AccountLease
    ) -> URL? {
        do {
            try validateLease(accountLease, at: .runtime)
            guard reference.hasPrefix(Self.persistentPhotoReferencePrefix) else { return nil }
            let relativePath = String(reference.dropFirst(Self.persistentPhotoReferencePrefix.count))
            let components = relativePath
                .split(separator: "/", omittingEmptySubsequences: false)
                .map(String.init)
            let scopeDigest = try Self.scopeDigest(for: accountLease)
            let expectedDirectoryComponents = Self.managedRootComponents
                + [scopeDigest, AccountPrivateMediaKind.persistentPhoto.directoryName]
            guard components.count == expectedDirectoryComponents.count + 1,
                  Array(components.dropLast()) == expectedDirectoryComponents,
                  let fileName = components.last,
                  Self.isUUIDFileName(fileName) else {
                return nil
            }
            let directoryURL = try managedDirectoryURL(
                kind: .persistentPhoto,
                scopeDigest: scopeDigest,
                create: false
            )
            let artifact = AccountPrivateMediaArtifact(
                fileURL: directoryURL.appendingPathComponent(fileName, isDirectory: false),
                kind: .persistentPhoto,
                scopeDigest: scopeDigest,
                relativePath: relativePath,
                accountLease: accountLease
            )
            let resolvedURL = try validatedManagedURL(for: artifact)
            guard fileManager.fileExists(atPath: resolvedURL.path),
                  try isRegularFile(at: resolvedURL) else {
                return nil
            }
            return resolvedURL
        } catch {
            return nil
        }
    }

    func prepareRecordingStaging(
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        try validateLease(accountLease, at: .request)
        return try makeArtifact(
            kind: .recordingStaging,
            fileExtension: "m4a",
            accountLease: accountLease
        )
    }

    func finalizeRecordingStaging(
        _ artifact: AccountPrivateMediaArtifact,
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        do {
            guard artifact.kind == .recordingStaging,
                  artifact.accountLease == accountLease else {
                throw AccountPrivateMediaStoreError.staleLease
            }
            let fileURL = try validatedManagedURL(for: artifact)
            try validateLease(accountLease, at: .commit)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw AccountPrivateMediaStoreError.fileMissing
            }
            guard try isRegularFile(at: fileURL) else {
                throw AccountPrivateMediaStoreError.notRegularFile
            }
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            guard (attributes[.size] as? NSNumber)?.int64Value ?? 0 > 0 else {
                throw AccountPrivateMediaStoreError.emptyPayload
            }
            try applyLocalFilePolicy(to: fileURL)
            return artifact
        } catch {
            discard(artifact)
            throw error
        }
    }

    func discard(_ artifact: AccountPrivateMediaArtifact) {
        guard let fileURL = try? validatedManagedURL(for: artifact) else { return }
        try? fileManager.removeItem(at: fileURL)
    }

    static func scopeDigest(for accountLease: AccountLease) throws -> String {
        let subjectId = normalizedScopeIdentifier(accountLease.subjectId)
        let vaultId = normalizedScopeIdentifier(accountLease.vaultId)
        guard validScopeIdentifier(subjectId), validScopeIdentifier(vaultId) else {
            throw AccountPrivateMediaStoreError.invalidScope
        }
        return pathDigest(
            "account-private-media-scope-v1|"
                + lengthDelimited(subjectId)
                + lengthDelimited(vaultId)
        )
    }

    @discardableResult
    func purgeExpiredStaging(before cutoff: Date) throws -> Int {
        let cachesRoot = try storageRoot(for: .recordingStaging, create: false)
            .standardizedFileURL
        let stagingRoot = Self.managedRootComponents.reduce(cachesRoot) {
            $0.appendingPathComponent($1, isDirectory: true)
        }.standardizedFileURL
        guard fileManager.fileExists(atPath: stagingRoot.path) else { return 0 }
        guard let enumerator = fileManager.enumerator(
            at: stagingRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        let resolvedRoot = stagingRoot.resolvingSymlinksInPath().standardizedFileURL
        var removedCount = 0
        var parentDirectories: Set<URL> = []
        while let fileURL = enumerator.nextObject() as? URL {
            let values = try fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .contentModificationDateKey]
            )
            guard values.isRegularFile == true,
                  let modificationDate = values.contentModificationDate,
                  modificationDate < cutoff else {
                continue
            }
            let relativeComponents = fileURL.standardizedFileURL.path
                .dropFirst(stagingRoot.path.count)
                .split(separator: "/")
                .map(String.init)
            guard relativeComponents.count == 3,
                  Self.isPathDigest(relativeComponents[0]),
                  [
                    AccountPrivateMediaKind.photoStaging.directoryName,
                    AccountPrivateMediaKind.recordingStaging.directoryName,
                  ].contains(relativeComponents[1]),
                  Self.isUUIDFileName(relativeComponents[2]),
                  Self.isDescendant(
                    fileURL.resolvingSymlinksInPath().standardizedFileURL,
                    of: resolvedRoot
                  ) else {
                continue
            }
            try fileManager.removeItem(at: fileURL)
            parentDirectories.insert(fileURL.deletingLastPathComponent())
            removedCount += 1
        }
        for directoryURL in parentDirectories {
            if (try? fileManager.contentsOfDirectory(atPath: directoryURL.path).isEmpty) == true {
                try? fileManager.removeItem(at: directoryURL)
                let scopeURL = directoryURL.deletingLastPathComponent()
                if (try? fileManager.contentsOfDirectory(atPath: scopeURL.path).isEmpty) == true {
                    try? fileManager.removeItem(at: scopeURL)
                }
            }
        }
        return removedCount
    }

    @discardableResult
    func purgeAccountDataForAccountDeletion(accountLease: AccountLease) -> Bool {
        do {
            let scopeDigest = try Self.scopeDigest(for: accountLease)
            let kinds: [AccountPrivateMediaKind] = [
                .persistentPhoto,
                .photoStaging,
                .recordingStaging,
            ]
            var visitedScopeDirectories = Set<URL>()
            for kind in kinds {
                let storageRoot = try storageRoot(for: kind, create: false)
                    .standardizedFileURL
                let scopeDirectory = (Self.managedRootComponents + [scopeDigest]).reduce(
                    storageRoot
                ) { partial, component in
                    partial.appendingPathComponent(component, isDirectory: true)
                }.standardizedFileURL
                guard Self.isDescendant(
                    scopeDirectory.resolvingSymlinksInPath().standardizedFileURL,
                    of: storageRoot.resolvingSymlinksInPath().standardizedFileURL
                ) else {
                    throw AccountPrivateMediaStoreError.invalidScope
                }
                guard visitedScopeDirectories.insert(scopeDirectory).inserted,
                      fileManager.fileExists(atPath: scopeDirectory.path) else {
                    continue
                }
                try fileManager.removeItem(at: scopeDirectory)
            }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func retireLegacyGlobalMedia() throws -> [AccountPrivateMediaLegacyReceipt] {
        legacyRetirementLock.lock()
        defer { legacyRetirementLock.unlock() }

        try retireLegacyDirectory(
            at: legacyPhotosDirectoryURL(),
            surface: .documentsPhotos,
            regularFileDisposition: .quarantined
        )
        try retireLegacyDirectory(
            at: legacySessionRecordingsDirectoryURL(),
            surface: .temporarySessionRecordings,
            regularFileDisposition: .discarded
        )
        return try loadLegacyRetirementReceipts()
    }

    func legacyRetirementReceipts() throws -> [AccountPrivateMediaLegacyReceipt] {
        legacyRetirementLock.lock()
        defer { legacyRetirementLock.unlock() }
        return try loadLegacyRetirementReceipts()
    }

    private func validateLease(
        _ accountLease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) throws {
        _ = try Self.scopeDigest(for: accountLease)
        guard leaseValidator(accountLease, checkpoint) else {
            throw AccountPrivateMediaStoreError.staleLease
        }
    }

    private func makeArtifact(
        kind: AccountPrivateMediaKind,
        fileExtension: String,
        accountLease: AccountLease
    ) throws -> AccountPrivateMediaArtifact {
        let normalizedExtension = try Self.normalizedFileExtension(fileExtension)
        let scopeDigest = try Self.scopeDigest(for: accountLease)
        let directoryURL = try managedDirectoryURL(
            kind: kind,
            scopeDigest: scopeDigest,
            create: true
        )
        for _ in 0..<4 {
            let fileName = "\(UUID().uuidString.lowercased()).\(normalizedExtension)"
            let fileURL = directoryURL.appendingPathComponent(fileName, isDirectory: false)
            guard !fileManager.fileExists(atPath: fileURL.path) else { continue }
            let relativePath = (
                Self.managedRootComponents
                    + [scopeDigest, kind.directoryName, fileName]
            ).joined(separator: "/")
            return AccountPrivateMediaArtifact(
                fileURL: fileURL,
                kind: kind,
                scopeDigest: scopeDigest,
                relativePath: relativePath,
                accountLease: accountLease
            )
        }
        throw AccountPrivateMediaStoreError.invalidArtifact
    }

    private func validatedManagedURL(
        for artifact: AccountPrivateMediaArtifact
    ) throws -> URL {
        let expectedScopeDigest = try Self.scopeDigest(for: artifact.accountLease)
        guard artifact.scopeDigest == expectedScopeDigest else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }
        let expectedComponents = Self.managedRootComponents
            + [artifact.scopeDigest, artifact.kind.directoryName]
        let relativeComponents = artifact.relativePath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard relativeComponents.count == expectedComponents.count + 1,
              Array(relativeComponents.dropLast()) == expectedComponents,
              relativeComponents.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              let fileName = relativeComponents.last,
              Self.isUUIDFileName(fileName) else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }

        let expectedDirectoryURL = try managedDirectoryURL(
            kind: artifact.kind,
            scopeDigest: artifact.scopeDigest,
            create: false
        )
        let expectedURL = expectedDirectoryURL
            .appendingPathComponent(fileName, isDirectory: false)
            .standardizedFileURL
        guard expectedURL == artifact.fileURL.standardizedFileURL else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }
        return expectedURL
    }

    private func managedDirectoryURL(
        kind: AccountPrivateMediaKind,
        scopeDigest: String,
        create: Bool
    ) throws -> URL {
        let storageRoot = try storageRoot(for: kind, create: create).standardizedFileURL
        if create {
            try fileManager.createDirectory(
                at: storageRoot,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        let directoryURL = (Self.managedRootComponents + [scopeDigest, kind.directoryName])
            .reduce(storageRoot) {
                $0.appendingPathComponent($1, isDirectory: true)
            }
            .standardizedFileURL
        if create {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try applyLocalFilePolicy(to: directoryURL)
        } else if !fileManager.fileExists(atPath: directoryURL.path) {
            throw AccountPrivateMediaStoreError.fileMissing
        }

        let resolvedRoot = storageRoot.resolvingSymlinksInPath().standardizedFileURL
        let resolvedDirectory = directoryURL.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isDescendant(resolvedDirectory, of: resolvedRoot) else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }
        return directoryURL
    }

    private func storageRoot(
        for kind: AccountPrivateMediaKind,
        create: Bool
    ) throws -> URL {
        if kind.usesApplicationSupport, let applicationSupportRootOverride {
            return applicationSupportRootOverride
        }
        if !kind.usesApplicationSupport, let cachesRootOverride {
            return cachesRootOverride
        }
        let searchDirectory: FileManager.SearchPathDirectory = kind.usesApplicationSupport
            ? .applicationSupportDirectory
            : .cachesDirectory
        return try fileManager.url(
            for: searchDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: create
        )
    }

    private func legacyPhotosDirectoryURL() -> URL {
        let documentsRoot = legacyDocumentsRootOverride ?? URL(
            fileURLWithPath: NSHomeDirectory(),
            isDirectory: true
        ).appendingPathComponent("Documents", isDirectory: true)
        return documentsRoot.appendingPathComponent("photos", isDirectory: true)
    }

    private func legacySessionRecordingsDirectoryURL() -> URL {
        let temporaryRoot = legacyTemporaryRootOverride ?? fileManager.temporaryDirectory
        return temporaryRoot.appendingPathComponent("TGSessionRecordings", isDirectory: true)
    }

    private func retireLegacyDirectory(
        at directoryURL: URL,
        surface: AccountPrivateMediaLegacySurface,
        regularFileDisposition: AccountPrivateMediaLegacyDisposition
    ) throws {
        guard Self.itemExists(at: directoryURL, fileManager: fileManager) else { return }
        let rootAttributes = try fileManager.attributesOfItem(atPath: directoryURL.path)
        guard rootAttributes[.type] as? FileAttributeType == .typeDirectory else {
            try retireLegacyEntry(
                at: directoryURL,
                relativePath: nil,
                rootURL: directoryURL.deletingLastPathComponent(),
                surface: surface,
                regularFileDisposition: regularFileDisposition
            )
            return
        }

        var enumerationError: Error?
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [],
            errorHandler: { _, error in
                enumerationError = error
                return false
            }
        ) else {
            throw AccountPrivateMediaStoreError.unsafeLegacySource
        }

        var leafURLs: [URL] = []
        var directoryURLs: [URL] = []
        while let entryURL = enumerator.nextObject() as? URL {
            let attributes = try fileManager.attributesOfItem(atPath: entryURL.path)
            if attributes[.type] as? FileAttributeType == .typeDirectory {
                directoryURLs.append(entryURL)
            } else {
                leafURLs.append(entryURL)
            }
        }
        if enumerationError != nil {
            throw AccountPrivateMediaStoreError.unsafeLegacySource
        }

        let standardizedRoot = directoryURL.standardizedFileURL
        for entryURL in leafURLs.sorted(by: { $0.path < $1.path }) {
            let standardizedEntry = entryURL.standardizedFileURL
            guard standardizedEntry.path.hasPrefix(standardizedRoot.path + "/") else {
                throw AccountPrivateMediaStoreError.unsafeLegacySource
            }
            let relativePath = String(
                standardizedEntry.path.dropFirst(standardizedRoot.path.count + 1)
            )
            try retireLegacyEntry(
                at: entryURL,
                relativePath: relativePath,
                rootURL: directoryURL,
                surface: surface,
                regularFileDisposition: regularFileDisposition
            )
        }

        for nestedDirectory in directoryURLs.sorted(by: { $0.path.count > $1.path.count }) {
            if (try? fileManager.contentsOfDirectory(atPath: nestedDirectory.path).isEmpty) == true {
                try fileManager.removeItem(at: nestedDirectory)
            }
        }
        if (try? fileManager.contentsOfDirectory(atPath: directoryURL.path).isEmpty) == true {
            try fileManager.removeItem(at: directoryURL)
        }
    }

    private func retireLegacyEntry(
        at sourceURL: URL,
        relativePath: String?,
        rootURL: URL,
        surface: AccountPrivateMediaLegacySurface,
        regularFileDisposition: AccountPrivateMediaLegacyDisposition
    ) throws {
        let attributes = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let isRegularFile = attributes[.type] as? FileAttributeType == .typeRegular
        let sourceLocator = relativePath.map {
            surface.sourceLocatorRoot + "/" + $0
        } ?? surface.sourceLocatorRoot
        let sourceLocatorHash = Self.sha256(Data(sourceLocator.utf8))
        let sourceContentHash: String
        if isRegularFile {
            let resolvedRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL
            let resolvedSource = sourceURL.resolvingSymlinksInPath().standardizedFileURL
            guard Self.isDescendant(resolvedSource, of: resolvedRoot) else {
                throw AccountPrivateMediaStoreError.unsafeLegacySource
            }
            sourceContentHash = try Self.sha256(of: sourceURL)
        } else {
            sourceContentHash = Self.sha256(
                Data("legacy-non-regular-v1|\(sourceLocatorHash)".utf8)
            )
        }

        let disposition = isRegularFile ? regularFileDisposition : .discarded
        let receiptId = Self.pathDigest(
            [
                "account-private-media-legacy-receipt-v1",
                surface.rawValue,
                sourceLocatorHash,
                sourceContentHash,
                disposition.rawValue,
            ].joined(separator: "|")
        )
        let quarantineRelativePath = disposition == .quarantined
            ? Self.quarantineRelativePath(
                receiptId: receiptId,
                sourceExtension: sourceURL.pathExtension
            )
            : nil

        if let existingReceipt = try loadLegacyRetirementReceipt(receiptId: receiptId) {
            guard existingReceipt.receiptSchemaVersion
                    == AccountPrivateMediaLegacyReceipt.schemaVersion,
                  existingReceipt.surface == surface,
                  existingReceipt.sourceLocator == sourceLocator,
                  existingReceipt.sourceLocatorHash == sourceLocatorHash,
                  existingReceipt.sourceContentHash == sourceContentHash,
                  existingReceipt.disposition == disposition,
                  existingReceipt.quarantineRelativePath == quarantineRelativePath else {
                throw AccountPrivateMediaStoreError.corruptLegacyReceipt
            }
            if disposition == .quarantined {
                try ensureQuarantineCopy(
                    sourceURL: sourceURL,
                    relativePath: quarantineRelativePath!,
                    expectedContentHash: sourceContentHash
                )
            }
            try removeLegacySourceIfPresent(sourceURL)
            return
        }

        let receipt = AccountPrivateMediaLegacyReceipt(
            receiptSchemaVersion: AccountPrivateMediaLegacyReceipt.schemaVersion,
            receiptId: receiptId,
            surface: surface,
            sourceLocator: sourceLocator,
            sourceLocatorHash: sourceLocatorHash,
            sourceContentHash: sourceContentHash,
            disposition: disposition,
            quarantineRelativePath: quarantineRelativePath,
            processedAt: now()
        )
        if disposition == .quarantined {
            try ensureQuarantineCopy(
                sourceURL: sourceURL,
                relativePath: quarantineRelativePath!,
                expectedContentHash: sourceContentHash
            )
        }
        try writeLegacyRetirementReceipt(receipt)
        try removeLegacySourceIfPresent(sourceURL)
    }

    private func ensureQuarantineCopy(
        sourceURL: URL,
        relativePath: String,
        expectedContentHash: String
    ) throws {
        let destinationURL = try applicationSupportURL(
            relativePath: relativePath,
            createParent: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            guard try Self.sha256(of: destinationURL) == expectedContentHash else {
                throw AccountPrivateMediaStoreError.contentHashMismatch
            }
            return
        }

        let temporaryURL = destinationURL.deletingLastPathComponent().appendingPathComponent(
            ".quarantine-\(destinationURL.deletingPathExtension().lastPathComponent).tmp",
            isDirectory: false
        )
        do {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                if try Self.sha256(of: temporaryURL) == expectedContentHash {
                    try applyLocalFilePolicy(to: temporaryURL)
                    try fileManager.moveItem(at: temporaryURL, to: destinationURL)
                    try applyLocalFilePolicy(to: destinationURL)
                    return
                }
                try fileManager.removeItem(at: temporaryURL)
            }
            try fileManager.copyItem(at: sourceURL, to: temporaryURL)
            guard try Self.sha256(of: temporaryURL) == expectedContentHash else {
                throw AccountPrivateMediaStoreError.contentHashMismatch
            }
            try applyLocalFilePolicy(to: temporaryURL)
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            try applyLocalFilePolicy(to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func removeLegacySourceIfPresent(_ sourceURL: URL) throws {
        guard Self.itemExists(at: sourceURL, fileManager: fileManager) else { return }
        try fileManager.removeItem(at: sourceURL)
    }

    private func writeLegacyRetirementReceipt(
        _ receipt: AccountPrivateMediaLegacyReceipt
    ) throws {
        let receiptURL = try legacyReceiptURL(receiptId: receipt.receiptId, createParent: true)
        if fileManager.fileExists(atPath: receiptURL.path) {
            guard try decodeReceipt(at: receiptURL) == receipt else {
                throw AccountPrivateMediaStoreError.corruptLegacyReceipt
            }
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(receipt).write(to: receiptURL, options: [.atomic])
        try applyLocalFilePolicy(to: receiptURL)
    }

    private func loadLegacyRetirementReceipt(
        receiptId: String
    ) throws -> AccountPrivateMediaLegacyReceipt? {
        let receiptURL = try legacyReceiptURL(receiptId: receiptId, createParent: false)
        guard fileManager.fileExists(atPath: receiptURL.path) else { return nil }
        return try decodeReceipt(at: receiptURL)
    }

    private func loadLegacyRetirementReceipts() throws -> [AccountPrivateMediaLegacyReceipt] {
        let receiptDirectory = try legacyReceiptDirectoryURL(create: false)
        guard fileManager.fileExists(atPath: receiptDirectory.path) else { return [] }
        let receiptURLs = try fileManager.contentsOfDirectory(
            at: receiptDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return try receiptURLs
            .filter { $0.pathExtension == "json" }
            .map { try decodeReceipt(at: $0) }
            .sorted { $0.receiptId < $1.receiptId }
    }

    private func decodeReceipt(at receiptURL: URL) throws -> AccountPrivateMediaLegacyReceipt {
        guard try isRegularFile(at: receiptURL),
              let receipt = try? JSONDecoder().decode(
                AccountPrivateMediaLegacyReceipt.self,
                from: Data(contentsOf: receiptURL)
              ),
              receipt.receiptSchemaVersion == AccountPrivateMediaLegacyReceipt.schemaVersion,
              receiptURL.deletingPathExtension().lastPathComponent == receipt.receiptId else {
            throw AccountPrivateMediaStoreError.corruptLegacyReceipt
        }
        return receipt
    }

    private func legacyReceiptURL(
        receiptId: String,
        createParent: Bool
    ) throws -> URL {
        guard Self.isPathDigest(receiptId) else {
            throw AccountPrivateMediaStoreError.corruptLegacyReceipt
        }
        return try legacyReceiptDirectoryURL(create: createParent)
            .appendingPathComponent("\(receiptId).json", isDirectory: false)
    }

    private func legacyReceiptDirectoryURL(create: Bool) throws -> URL {
        let relativePath = (Self.legacyRetirementComponents + ["receipts"])
            .joined(separator: "/")
        return try applicationSupportURL(
            relativePath: relativePath,
            createParent: create,
            targetIsDirectory: true
        )
    }

    private func applicationSupportURL(
        relativePath: String,
        createParent: Bool,
        targetIsDirectory: Bool = false
    ) throws -> URL {
        let components = relativePath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }
        let rootURL = try storageRoot(for: .persistentPhoto, create: createParent)
            .standardizedFileURL
        if createParent {
            try fileManager.createDirectory(
                at: rootURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
        let targetURL = components.enumerated().reduce(rootURL) { partial, item in
            let isDirectory = targetIsDirectory || item.offset < components.count - 1
            return partial.appendingPathComponent(item.element, isDirectory: isDirectory)
        }.standardizedFileURL
        let parentURL = targetIsDirectory ? targetURL : targetURL.deletingLastPathComponent()
        if createParent {
            try fileManager.createDirectory(
                at: parentURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try applyLocalFilePolicy(to: parentURL)
        }
        let resolvedRoot = rootURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedTarget = targetURL.resolvingSymlinksInPath().standardizedFileURL
        guard Self.isDescendant(resolvedTarget, of: resolvedRoot) else {
            throw AccountPrivateMediaStoreError.invalidArtifact
        }
        return targetURL
    }

    private func applyLocalFilePolicy(to url: URL) throws {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)

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

    private static func quarantineRelativePath(
        receiptId: String,
        sourceExtension: String
    ) -> String {
        let normalizedExtension = sourceExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
        let safeExtension = normalizedExtension.count <= 16
            && normalizedExtension.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0)
            }
            ? ".\(normalizedExtension)"
            : ""
        return (legacyRetirementComponents + ["quarantine", "\(receiptId)\(safeExtension)"])
            .joined(separator: "/")
    }

    private static func normalizedFileExtension(_ value: String) throws -> String {
        let normalized = value
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .lowercased()
        guard !normalized.isEmpty,
              normalized.count <= 16,
              normalized.unicodeScalars.allSatisfy({
                CharacterSet.alphanumerics.contains($0)
              }) else {
            throw AccountPrivateMediaStoreError.invalidFileExtension
        }
        return normalized
    }

    private static func normalizedScopeIdentifier(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func lengthDelimited(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private static func validScopeIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return ![
            "default",
            "legacy_unassigned",
            "unknown",
            "user_001",
        ].contains(value.lowercased())
    }

    private static func isUUIDFileName(_ fileName: String) -> Bool {
        let url = URL(fileURLWithPath: fileName)
        return !url.pathExtension.isEmpty
            && UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
    }

    private static func isDescendant(_ candidate: URL, of directory: URL) -> Bool {
        candidate.path.hasPrefix(directory.path + "/")
    }

    private static func itemExists(at url: URL, fileManager: FileManager) -> Bool {
        (try? fileManager.attributesOfItem(atPath: url.path)) != nil
    }

    private static func isPathDigest(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            CharacterSet(charactersIn: "0123456789abcdef").contains($0)
        }
    }

    private static func pathDigest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func sha256(_ data: Data) -> String {
        "sha256:" + SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return "sha256:" + hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
