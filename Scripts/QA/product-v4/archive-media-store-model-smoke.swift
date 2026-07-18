import CryptoKit
import Foundation

// MemoryArchiveItem references the production upload contract. This smoke only
// needs the persisted media fields, so a compile-only carrier is sufficient.
struct ArchiveMediaUploadIntent {
    let uploadIntentId: String
    let objectKey: String
    let storageProvider: String
    let uploadURL: String
}

struct ArchiveMediaSmokeUser {
    let id: String
}

final class UserManager {
    static let shared = UserManager()
    var currentUser: ArchiveMediaSmokeUser?
}

struct ArchiveMediaSmokeDigitalHumanContext {
    var ownerId: String
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()
    var current = ArchiveMediaSmokeDigitalHumanContext(ownerId: "")
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else { fatalError(message) }
}

private func expectMediaStoreError(
    _ message: String,
    operation: () throws -> Void,
    matches: (ArchiveMediaStoreError) -> Bool
) {
    do {
        try operation()
    } catch let error as ArchiveMediaStoreError {
        require(matches(error), "\(message): unexpected error \(error)")
        return
    } catch {
        fatalError("\(message): unexpected error \(error)")
    }
    fatalError("\(message): operation unexpectedly succeeded")
}

private func sha256(_ data: Data) -> String {
    "sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func makeLease(subjectId: String, vaultId: String) -> AccountLease {
    AccountLease(
        subjectId: subjectId,
        vaultId: vaultId,
        sessionId: "session-\(subjectId)-\(vaultId)",
        generation: 1,
        generationId: UUID(),
        authorityEpoch: "epoch-a"
    )
}

private func makeItem(
    id: String,
    ownerUserId: String,
    localPath: String?,
    updatedAt: Date
) -> MemoryArchiveItem {
    MemoryArchiveItem(
        id: id,
        kind: .photo,
        title: "item-\(id)",
        note: "",
        localPath: localPath,
        ownerUserId: ownerUserId,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: updatedAt,
        analysisStatus: .analyzed
    )
}

private func makeMigrationReceipt(
    id: String,
    itemIds: [String],
    scope: ArchiveStorageScope
) -> ArchiveLegacyMigrationReceipt {
    ArchiveLegacyMigrationReceipt(
        receiptId: id,
        sourceStorageKey: scope.legacyStorageKey,
        destinationStorageKey: scope.storageKey,
        subjectId: scope.subjectId,
        vaultId: scope.vaultId,
        archiveOwnerId: scope.archiveOwnerId,
        state: .migrated,
        migratedItemIds: itemIds,
        quarantinedItemIds: [],
        sourceContentHash: sha256(Data("legacy-receipt-\(id)".utf8)),
        createdAt: Date()
    )
}

@main
private enum ArchiveMediaStoreModelSmoke {
    static func main() throws {
        let fileManager = FileManager.default
        let leaseA = makeLease(subjectId: "subject-a", vaultId: "vault-a")
        let scopeA = ArchiveStorageScope(accountLease: leaseA, archiveOwnerId: "owner-a")
        let scopeOtherOwner = ArchiveStorageScope(accountLease: leaseA, archiveOwnerId: "owner-b")
        let scopeOtherVault = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "subject-a", vaultId: "vault-b"),
            archiveOwnerId: "owner-a"
        )
        let scopeB = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "subject-b", vaultId: "vault-b"),
            archiveOwnerId: "owner-b"
        )

        require(
            scopeA.mediaDirectoryRelativePath != scopeOtherOwner.mediaDirectoryRelativePath,
            "owner scope must change the media directory"
        )
        require(
            scopeA.mediaDirectoryRelativePath != scopeOtherVault.mediaDirectoryRelativePath,
            "vault scope must change the media directory"
        )
        require(
            scopeA.mediaDirectoryRelativePath != scopeB.mediaDirectoryRelativePath,
            "account A/B media directories must remain isolated"
        )

        let testRoot = fileManager.temporaryDirectory
            .appendingPathComponent("archive-media-store-smoke-\(UUID().uuidString)", isDirectory: true)
        let applicationSupportRoot = testRoot.appendingPathComponent("ApplicationSupport", isDirectory: true)
        let cachesRoot = testRoot.appendingPathComponent("Caches", isDirectory: true)
        let legacyDocumentsRoot = testRoot.appendingPathComponent("Documents", isDirectory: true)
        defer { try? fileManager.removeItem(at: testRoot) }

        let mediaStore = ArchiveMediaStore(
            fileManager: fileManager,
            applicationSupportRoot: applicationSupportRoot,
            cachesRoot: cachesRoot,
            legacyDocumentsRoot: legacyDocumentsRoot,
            currentScopeResolver: { ownerId in
                switch ownerId {
                case scopeA.archiveOwnerId:
                    return scopeA
                case scopeB.archiveOwnerId:
                    return scopeB
                default:
                    return nil
                }
            }
        )

        let mediaBytesA = Data("account-a-original-media".utf8)
        let metadataA = try mediaStore.write(
            mediaBytesA,
            fileExtension: ".JPG",
            scope: scopeA
        )
        let scopeDigestA = try ArchiveMediaStore.scopeDigest(for: scopeA)
        let fileName = URL(fileURLWithPath: metadataA.relativePath).lastPathComponent
        let fileStem = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent

        require(!metadataA.relativePath.hasPrefix("/"), "persisted media path must remain relative")
        require(
            metadataA.relativePath.hasPrefix(scopeA.mediaDirectoryRelativePath + "/"),
            "persisted media path must remain inside its owner/vault scope"
        )
        require(UUID(uuidString: fileStem) != nil, "media file name must be a UUID")
        require(metadataA.sha256 == sha256(mediaBytesA), "persisted SHA256 must match written bytes")
        require(
            metadataA.sizeBytes == Int64(mediaBytesA.count),
            "persisted byteCount must match written bytes"
        )
        require(metadataA.scopeDigest == scopeDigestA, "persisted scope digest must match owner/vault scope")

        let persistedMetadata = metadataA.itemMetadata(for: .original)
        require(persistedMetadata.count == 4, "persisted media metadata must have four binding fields")
        require(
            ArchiveMediaMetadata(itemMetadata: persistedMetadata, role: .original) == metadataA,
            "relative path, SHA256, byteCount, and scope digest must round-trip"
        )

        let resolvedA = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeA)
        require(
            resolvedA.path.hasPrefix(applicationSupportRoot.path + "/"),
            "original media must resolve under Application Support"
        )
        let resolvedBytesA = try Data(contentsOf: resolvedA)
        require(
            resolvedBytesA == mediaBytesA,
            "resolved account A media must preserve its bytes"
        )
        let resolvedCurrentA = try mediaStore.resolvedFileURL(
            for: metadataA,
            archiveOwnerId: scopeA.archiveOwnerId
        )
        require(
            resolvedCurrentA == resolvedA,
            "current owner resolution must retain the same scope"
        )

        expectMediaStoreError(
            "cross-owner metadata resolution must fail closed",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeOtherOwner)
            },
            matches: {
                if case .scopeMismatch = $0 { return true }
                return false
            }
        )
        expectMediaStoreError(
            "cross-vault metadata resolution must fail closed",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeOtherVault)
            },
            matches: {
                if case .scopeMismatch = $0 { return true }
                return false
            }
        )

        let scopeBDirectory = applicationSupportRoot
            .appendingPathComponent(scopeB.mediaDirectoryRelativePath, isDirectory: true)
        try fileManager.createDirectory(
            at: scopeBDirectory,
            withIntermediateDirectories: true
        )
        let sameBasenameURLB = scopeBDirectory.appendingPathComponent(fileName)
        let mediaBytesB = Data("account-b-different-media".utf8)
        try mediaBytesB.write(to: sameBasenameURLB, options: [.atomic])
        let metadataB = ArchiveMediaMetadata(
            relativePath: scopeB.mediaDirectoryRelativePath + "/" + fileName,
            sha256: sha256(mediaBytesB),
            sizeBytes: Int64(mediaBytesB.count),
            scopeDigest: try ArchiveMediaStore.scopeDigest(for: scopeB)
        )
        let resolvedB = try mediaStore.resolvedFileURL(for: metadataB, scope: scopeB)
        require(
            resolvedB.standardizedFileURL == sameBasenameURLB.standardizedFileURL,
            "same basename must resolve only inside its own scope"
        )
        let resolvedBytesB = try Data(contentsOf: resolvedB)
        require(
            resolvedBytesB == mediaBytesB,
            "same-basename account B media must not resolve account A bytes"
        )

        expectMediaStoreError(
            "cross-scope delete must not remove another owner's media",
            operation: {
                try mediaStore.remove(metadataA, scope: scopeB)
            },
            matches: {
                if case .scopeMismatch = $0 { return true }
                return false
            }
        )
        require(fileManager.fileExists(atPath: resolvedA.path), "cross-scope delete must preserve account A")
        require(fileManager.fileExists(atPath: resolvedB.path), "cross-scope delete must preserve account B")

        let outsideURL = testRoot.appendingPathComponent("outside-\(UUID().uuidString).jpg")
        try mediaBytesA.write(to: outsideURL, options: [.atomic])
        let absolutePathMetadata = ArchiveMediaMetadata(
            relativePath: outsideURL.path,
            sha256: sha256(mediaBytesA),
            sizeBytes: Int64(mediaBytesA.count),
            scopeDigest: scopeDigestA
        )
        expectMediaStoreError(
            "absolute paths must be rejected",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: absolutePathMetadata, scope: scopeA)
            },
            matches: {
                if case .invalidRelativePath = $0 { return true }
                return false
            }
        )

        let traversalMetadata = ArchiveMediaMetadata(
            relativePath: "DreamJourney/Archive/v2/../\(UUID().uuidString).jpg",
            sha256: sha256(mediaBytesA),
            sizeBytes: Int64(mediaBytesA.count),
            scopeDigest: scopeDigestA
        )
        expectMediaStoreError(
            "path traversal must be rejected",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: traversalMetadata, scope: scopeA)
            },
            matches: {
                if case .invalidRelativePath = $0 { return true }
                return false
            }
        )

        let scopeADirectory = resolvedA.deletingLastPathComponent()
        let symlinkName = "\(UUID().uuidString).jpg"
        let symlinkURL = scopeADirectory.appendingPathComponent(symlinkName)
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideURL)
        let symlinkMetadata = ArchiveMediaMetadata(
            relativePath: scopeA.mediaDirectoryRelativePath + "/" + symlinkName,
            sha256: sha256(mediaBytesA),
            sizeBytes: Int64(mediaBytesA.count),
            scopeDigest: scopeDigestA
        )
        expectMediaStoreError(
            "symlink traversal must be rejected",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: symlinkMetadata, scope: scopeA)
            },
            matches: {
                if case .invalidRelativePath = $0 { return true }
                return false
            }
        )

        let wrongSizeMetadata = ArchiveMediaMetadata(
            relativePath: metadataA.relativePath,
            sha256: metadataA.sha256,
            sizeBytes: metadataA.sizeBytes + 1,
            scopeDigest: metadataA.scopeDigest
        )
        expectMediaStoreError(
            "persisted byteCount mismatch must be rejected",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: wrongSizeMetadata, scope: scopeA)
            },
            matches: {
                if case .sizeMismatch = $0 { return true }
                return false
            }
        )

        let wrongChecksumMetadata = ArchiveMediaMetadata(
            relativePath: metadataA.relativePath,
            sha256: "sha256:" + String(repeating: "0", count: 64),
            sizeBytes: metadataA.sizeBytes,
            scopeDigest: metadataA.scopeDigest
        )
        expectMediaStoreError(
            "persisted SHA256 mismatch must be rejected",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: wrongChecksumMetadata, scope: scopeA)
            },
            matches: {
                if case .checksumMismatch = $0 { return true }
                return false
            }
        )

        let sameLengthTamper = Data(repeating: 0x58, count: mediaBytesA.count)
        try sameLengthTamper.write(to: resolvedA, options: [.atomic])
        expectMediaStoreError(
            "same-length tamper must fail SHA256 validation",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeA)
            },
            matches: {
                if case .checksumMismatch = $0 { return true }
                return false
            }
        )

        var sizeTamper = mediaBytesA
        sizeTamper.append(0x00)
        try sizeTamper.write(to: resolvedA, options: [.atomic])
        expectMediaStoreError(
            "byteCount tamper must fail size validation",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeA)
            },
            matches: {
                if case .sizeMismatch = $0 { return true }
                return false
            }
        )
        try mediaBytesA.write(to: resolvedA, options: [.atomic])
        _ = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeA)

        let remoteOwnerA = makeItem(
            id: "shared-item",
            ownerUserId: scopeA.archiveOwnerId,
            localPath: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let localOwnerB = makeItem(
            id: "shared-item",
            ownerUserId: scopeB.archiveOwnerId,
            localPath: metadataB.relativePath,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
        let merged = ArchiveLocalStoragePolicy.merge(
            remoteItems: [remoteOwnerA],
            localItems: [localOwnerB],
            expectedArchiveOwnerId: scopeA.archiveOwnerId
        )
        require(merged.count == 1, "expected owner item must remain visible")
        require(merged[0].ownerUserId == scopeA.archiveOwnerId, "cross-owner item must be excluded")
        require(merged[0].localPath == nil, "cross-owner localPath must not be inherited")

        let remoteAbsolutePath = MemoryArchiveItem(remoteJSON: [
            "id": "remote-absolute-path",
            "kind": "photo",
            "ownerUserId": scopeA.archiveOwnerId,
            "localPath": outsideURL.path,
            "metadata": absolutePathMetadata.itemMetadata(for: .original),
        ])
        require(remoteAbsolutePath?.localPath == nil, "remote absolute localPath must be ignored")
        require(
            remoteAbsolutePath?.localMediaMetadata == nil,
            "remote local media metadata must be stripped"
        )

        try fileManager.createDirectory(
            at: legacyDocumentsRoot,
            withIntermediateDirectories: true
        )
        let sensitiveURL = legacyDocumentsRoot.appendingPathComponent("private-account-token.txt")
        try Data("sensitive-document".utf8).write(to: sensitiveURL, options: [.atomic])
        let sensitiveItem = makeItem(
            id: "legacy-sensitive-document",
            ownerUserId: scopeA.archiveOwnerId,
            localPath: sensitiveURL.path,
            updatedAt: Date()
        )
        let sensitiveReceipt = makeMigrationReceipt(
            id: "receipt-sensitive-document",
            itemIds: [sensitiveItem.id],
            scope: scopeA
        )
        expectMediaStoreError(
            "an arbitrary Documents file must not migrate",
            operation: {
                let binding = try mediaStore.legacyMigrationBinding(
                    for: sensitiveItem,
                    receipt: sensitiveReceipt,
                    scope: scopeA
                )
                _ = try mediaStore.migrateLegacyOriginal(
                    for: sensitiveItem,
                    receipt: sensitiveReceipt,
                    binding: binding,
                    scope: scopeA
                )
            },
            matches: {
                if case .legacyOwnerProofRejected = $0 { return true }
                return false
            }
        )

        let legacyImagesRoot = legacyDocumentsRoot.appendingPathComponent(
            "archive-images",
            isDirectory: true
        )
        try fileManager.createDirectory(at: legacyImagesRoot, withIntermediateDirectories: true)
        let traversalItem = makeItem(
            id: "legacy-path-traversal",
            ownerUserId: scopeA.archiveOwnerId,
            localPath: legacyImagesRoot.path + "/../" + sensitiveURL.lastPathComponent,
            updatedAt: Date()
        )
        let traversalReceipt = makeMigrationReceipt(
            id: "receipt-path-traversal",
            itemIds: [traversalItem.id],
            scope: scopeA
        )
        expectMediaStoreError(
            "legacy path traversal must not migrate",
            operation: {
                let binding = try mediaStore.legacyMigrationBinding(
                    for: traversalItem,
                    receipt: traversalReceipt,
                    scope: scopeA
                )
                _ = try mediaStore.migrateLegacyOriginal(
                    for: traversalItem,
                    receipt: traversalReceipt,
                    binding: binding,
                    scope: scopeA
                )
            },
            matches: {
                if case .legacyOwnerProofRejected = $0 { return true }
                return false
            }
        )

        let legacySymlinkURL = legacyImagesRoot.appendingPathComponent("linked-sensitive.jpg")
        try fileManager.createSymbolicLink(at: legacySymlinkURL, withDestinationURL: sensitiveURL)
        let symlinkLegacyItem = makeItem(
            id: "legacy-symlink",
            ownerUserId: scopeA.archiveOwnerId,
            localPath: legacySymlinkURL.path,
            updatedAt: Date()
        )
        let symlinkLegacyReceipt = makeMigrationReceipt(
            id: "receipt-symlink",
            itemIds: [symlinkLegacyItem.id],
            scope: scopeA
        )
        expectMediaStoreError(
            "legacy symlink must not migrate",
            operation: {
                let binding = try mediaStore.legacyMigrationBinding(
                    for: symlinkLegacyItem,
                    receipt: symlinkLegacyReceipt,
                    scope: scopeA
                )
                _ = try mediaStore.migrateLegacyOriginal(
                    for: symlinkLegacyItem,
                    receipt: symlinkLegacyReceipt,
                    binding: binding,
                    scope: scopeA
                )
            },
            matches: {
                if case .legacyOwnerProofRejected = $0 { return true }
                return false
            }
        )

        let legacyDirectoryURL = legacyImagesRoot.appendingPathComponent(
            "not-a-regular-file.jpg",
            isDirectory: true
        )
        try fileManager.createDirectory(at: legacyDirectoryURL, withIntermediateDirectories: true)
        let nonRegularLegacyItem = makeItem(
            id: "legacy-non-regular",
            ownerUserId: scopeA.archiveOwnerId,
            localPath: legacyDirectoryURL.path,
            updatedAt: Date()
        )
        let nonRegularReceipt = makeMigrationReceipt(
            id: "receipt-non-regular",
            itemIds: [nonRegularLegacyItem.id],
            scope: scopeA
        )
        expectMediaStoreError(
            "legacy non-regular file must not migrate",
            operation: {
                let binding = try mediaStore.legacyMigrationBinding(
                    for: nonRegularLegacyItem,
                    receipt: nonRegularReceipt,
                    scope: scopeA
                )
                _ = try mediaStore.migrateLegacyOriginal(
                    for: nonRegularLegacyItem,
                    receipt: nonRegularReceipt,
                    binding: binding,
                    scope: scopeA
                )
            },
            matches: {
                if case .notRegularFile = $0 { return true }
                return false
            }
        )

        let legacyBytes = Data("allowed-legacy-photo".utf8)
        let legalLegacyURL = legacyImagesRoot.appendingPathComponent("legacy-photo.jpg")
        try legacyBytes.write(to: legalLegacyURL, options: [.atomic])
        let legalLegacyItem = makeItem(
            id: "legal-legacy-media",
            ownerUserId: scopeA.archiveOwnerId,
            localPath: legalLegacyURL.path,
            updatedAt: Date()
        )
        let legalLegacyReceipt = makeMigrationReceipt(
            id: "receipt-legal-media",
            itemIds: [legalLegacyItem.id],
            scope: scopeA
        )
        let legalBinding = try mediaStore.legacyMigrationBinding(
            for: legalLegacyItem,
            receipt: legalLegacyReceipt,
            scope: scopeA
        )
        let expectedCanonicalPathDigest = sha256(
            Data(
                "archive-legacy-canonical-path-v1|\(legalLegacyURL.resolvingSymlinksInPath().path)".utf8
            )
        )
        require(legalBinding.itemId == legalLegacyItem.id, "legacy binding must include item ID")
        require(
            legalBinding.canonicalPathDigest == expectedCanonicalPathDigest,
            "legacy binding must include the canonical path digest"
        )
        require(
            legalBinding.contentHash == sha256(legacyBytes),
            "legacy binding must include the source content hash"
        )

        let migratedLegacyMetadata = try mediaStore.migrateLegacyOriginal(
            for: legalLegacyItem,
            receipt: legalLegacyReceipt,
            binding: legalBinding,
            scope: scopeA
        )
        let migratedLegacyURL = try mediaStore.resolvedFileURL(
            for: migratedLegacyMetadata,
            scope: scopeA
        )
        let migratedLegacyBytes = try Data(contentsOf: migratedLegacyURL)
        require(
            migratedLegacyBytes == legacyBytes,
            "allowlisted legacy media must migrate into scoped storage"
        )
        let idempotentLegacyMetadata = try mediaStore.migrateLegacyOriginal(
            for: legalLegacyItem,
            receipt: legalLegacyReceipt,
            binding: legalBinding,
            scope: scopeA
        )
        require(
            idempotentLegacyMetadata == migratedLegacyMetadata,
            "an unchanged migration binding must resolve its existing scoped copy"
        )

        try Data("replacement-legacy-photo".utf8).write(to: legalLegacyURL, options: [.atomic])
        expectMediaStoreError(
            "a stale binding must reject replaced legacy content",
            operation: {
                _ = try mediaStore.migrateLegacyOriginal(
                    for: legalLegacyItem,
                    receipt: legalLegacyReceipt,
                    binding: legalBinding,
                    scope: scopeA
                )
            },
            matches: {
                if case .legacyOwnerProofRejected = $0 { return true }
                return false
            }
        )
        try legacyBytes.write(to: legalLegacyURL, options: [.atomic])
        expectMediaStoreError(
            "a receipt must not migrate a replacement file even when bytes match",
            operation: {
                let replacementBinding = try mediaStore.legacyMigrationBinding(
                    for: legalLegacyItem,
                    receipt: legalLegacyReceipt,
                    scope: scopeA
                )
                _ = try mediaStore.migrateLegacyOriginal(
                    for: legalLegacyItem,
                    receipt: legalLegacyReceipt,
                    binding: replacementBinding,
                    scope: scopeA
                )
            },
            matches: {
                if case .legacyOwnerProofRejected = $0 { return true }
                return false
            }
        )
        let retainedMigratedLegacyBytes = try Data(contentsOf: migratedLegacyURL)
        require(
            retainedMigratedLegacyBytes == legacyBytes,
            "a rejected replacement must not alter the migrated scoped copy"
        )

        try mediaStore.remove(metadataA, scope: scopeA)
        require(!fileManager.fileExists(atPath: resolvedA.path), "delete must remove scoped account A media")
        require(fileManager.fileExists(atPath: resolvedB.path), "delete must preserve same-basename account B media")
        expectMediaStoreError(
            "deleted media must not recover by global basename search",
            operation: {
                _ = try mediaStore.resolvedFileURL(for: metadataA, scope: scopeA)
            },
            matches: {
                if case .fileMissing = $0 { return true }
                return false
            }
        )
        let resolvedBAfterDelete = try mediaStore.resolvedFileURL(for: metadataB, scope: scopeB)
        require(
            resolvedBAfterDelete == resolvedB,
            "account B media must remain resolvable after account A deletion"
        )
        try mediaStore.remove(metadataA, scope: scopeA)

        let purgeOriginalA = try mediaStore.write(
            Data("account-a-purge-original".utf8),
            fileExtension: "jpg",
            scope: scopeA
        )
        let purgeThumbnailA = try mediaStore.write(
            Data("account-a-purge-thumbnail".utf8),
            fileExtension: "jpg",
            scope: scopeA,
            storageClass: .thumbnail
        )
        let purgeOriginalB = try mediaStore.write(
            Data("account-b-retained-original".utf8),
            fileExtension: "jpg",
            scope: scopeB
        )
        let purgeThumbnailB = try mediaStore.write(
            Data("account-b-retained-thumbnail".utf8),
            fileExtension: "jpg",
            scope: scopeB,
            storageClass: .thumbnail
        )
        expectMediaStoreError(
            "account purge must reject absolute directory paths",
            operation: {
                try mediaStore.purgeScopedDirectories(relativePaths: [outsideURL.path])
            },
            matches: {
                if case .invalidRelativePath = $0 { return true }
                return false
            }
        )
        expectMediaStoreError(
            "account purge must reject traversal directory paths",
            operation: {
                try mediaStore.purgeScopedDirectories(
                    relativePaths: ["DreamJourney/Archive/v2/../escape"]
                )
            },
            matches: {
                if case .invalidRelativePath = $0 { return true }
                return false
            }
        )
        try mediaStore.purgeScopedDirectories(
            relativePaths: [scopeA.mediaDirectoryRelativePath]
        )
        for purgedMetadata in [purgeOriginalA, purgeThumbnailA] {
            let storageRoot = purgedMetadata == purgeOriginalA ? applicationSupportRoot : cachesRoot
            let purgedURL = storageRoot.appendingPathComponent(purgedMetadata.relativePath)
            require(
                !fileManager.fileExists(atPath: purgedURL.path),
                "account-scoped purge must delete every A media class"
            )
        }
        for retainedMetadata in [purgeOriginalB, purgeThumbnailB] {
            let storageRoot = retainedMetadata == purgeOriginalB ? applicationSupportRoot : cachesRoot
            let retainedURL = storageRoot.appendingPathComponent(retainedMetadata.relativePath)
            require(
                fileManager.fileExists(atPath: retainedURL.path),
                "account-scoped purge must preserve every B media class"
            )
        }

        print("Archive media store model smoke passed")
    }
}
