import CryptoKit
import Foundation

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else { fatalError(message) }
}

private func expectStoreError(
    _ message: String,
    operation: () throws -> Void,
    matches: (AccountPrivateMediaStoreError) -> Bool
) {
    do {
        try operation()
    } catch let error as AccountPrivateMediaStoreError {
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

private func makeLease(
    subjectId: String,
    vaultId: String,
    sessionId: String,
    generation: UInt64,
    generationId: UUID
) -> AccountLease {
    AccountLease(
        subjectId: subjectId,
        vaultId: vaultId,
        sessionId: sessionId,
        generation: generation,
        generationId: generationId,
        authorityEpoch: "epoch-a"
    )
}

private func regularFiles(
    below root: URL,
    fileManager: FileManager
) -> [URL] {
    guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: []
    ) else {
        return []
    }
    return enumerator.compactMap { element in
        guard let url = element as? URL,
              (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
            return nil
        }
        return url
    }
}

@main
private enum AccountPrivateMediaStoreModelSmoke {
    static func main() throws {
        let fileManager = FileManager.default
        let testRoot = fileManager.temporaryDirectory.appendingPathComponent(
            "account-private-media-store-\(UUID().uuidString)",
            isDirectory: true
        )
        let applicationSupportRoot = testRoot.appendingPathComponent("app-support", isDirectory: true)
        let cachesRoot = testRoot.appendingPathComponent("caches", isDirectory: true)
        let legacyDocumentsRoot = testRoot.appendingPathComponent("documents", isDirectory: true)
        let legacyTemporaryRoot = testRoot.appendingPathComponent("temporary", isDirectory: true)
        let receiptDate = Date(timeIntervalSince1970: 1_725_000_000)
        defer { try? fileManager.removeItem(at: testRoot) }

        let leaseA1 = makeLease(
            subjectId: "subject-a",
            vaultId: "vault-a",
            sessionId: "session-a-1",
            generation: 7,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        )
        let leaseA2 = makeLease(
            subjectId: "subject-a",
            vaultId: "vault-a",
            sessionId: "session-a-rotated",
            generation: 8,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        )
        let leaseB = makeLease(
            subjectId: "subject-b",
            vaultId: "vault-b",
            sessionId: "session-b-1",
            generation: 1,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        )

        let delimiterCollisionA = makeLease(
            subjectId: "subject|vault",
            vaultId: "leaf",
            sessionId: "collision-a",
            generation: 1,
            generationId: UUID()
        )
        let delimiterCollisionB = makeLease(
            subjectId: "subject",
            vaultId: "vault|leaf",
            sessionId: "collision-b",
            generation: 1,
            generationId: UUID()
        )
        let collisionScopeA = try AccountPrivateMediaStore.scopeDigest(for: delimiterCollisionA)
        let collisionScopeB = try AccountPrivateMediaStore.scopeDigest(for: delimiterCollisionB)
        require(
            collisionScopeA != collisionScopeB,
            "length-delimited subject/vault encoding must prevent scope collisions"
        )

        var activeLease: AccountLease? = leaseA1
        let store = AccountPrivateMediaStore(
            fileManager: fileManager,
            applicationSupportRoot: applicationSupportRoot,
            cachesRoot: cachesRoot,
            legacyDocumentsRoot: legacyDocumentsRoot,
            legacyTemporaryRoot: legacyTemporaryRoot,
            now: { receiptDate },
            leaseValidator: { lease, _ in lease == activeLease }
        )

        let photoBytesA = Data("account-a-photo".utf8)
        let photoA1 = try store.writePhoto(
            photoBytesA,
            fileExtension: "jpg",
            accountLease: leaseA1
        )
        require(photoA1.kind == .persistentPhoto, "photo writes must return a persistent artifact")
        require(
            photoA1.fileURL.path.hasPrefix(applicationSupportRoot.path + "/"),
            "persistent photos must live under Application Support"
        )
        require(
            !photoA1.fileURL.path.hasPrefix(cachesRoot.path + "/"),
            "persistent photos must not live under Caches"
        )
        let persistedPhotoBytesA = try Data(contentsOf: photoA1.fileURL)
        require(persistedPhotoBytesA == photoBytesA, "account A photo bytes mismatch")

        let stagedPhoto = try store.writePhotoStaging(
            Data("account-a-staged-photo".utf8),
            fileExtension: "jpg",
            accountLease: leaseA1
        )
        require(stagedPhoto.kind == .photoStaging, "uncommitted Home photos must use staging")
        require(
            stagedPhoto.fileURL.path.hasPrefix(cachesRoot.path + "/"),
            "photo staging must live under Caches"
        )
        let promotedPhoto = try store.promotePhotoStaging(
            stagedPhoto,
            accountLease: leaseA1
        )
        require(
            !fileManager.fileExists(atPath: stagedPhoto.fileURL.path),
            "promotion must retire the staging source"
        )
        let promotedReference = try store.persistentPhotoReference(for: promotedPhoto)
        require(
            store.resolvePersistentPhoto(
                reference: promotedReference,
                accountLease: leaseA1
            ) == promotedPhoto.fileURL,
            "the originating account must resolve its persistent photo reference"
        )
        activeLease = leaseA2
        require(
            store.resolvePersistentPhoto(
                reference: promotedReference,
                accountLease: leaseA2
            ) == promotedPhoto.fileURL,
            "session/generation rotation must preserve persistent photo resolution"
        )
        activeLease = leaseB
        require(
            store.resolvePersistentPhoto(
                reference: promotedReference,
                accountLease: leaseB
            ) == nil,
            "another account must not resolve a persistent photo reference"
        )

        activeLease = leaseB
        let photoB = try store.writePhoto(
            Data("account-b-photo".utf8),
            fileExtension: "jpg",
            accountLease: leaseB
        )
        require(
            photoA1.fileURL.deletingLastPathComponent() != photoB.fileURL.deletingLastPathComponent(),
            "account A and B photos must use different scope directories"
        )
        require(photoA1.scopeDigest != photoB.scopeDigest, "account A and B scope digests must differ")

        activeLease = leaseA2
        let photoA2 = try store.writePhoto(
            Data("account-a-generation-two".utf8),
            fileExtension: "jpeg",
            accountLease: leaseA2
        )
        require(
            photoA1.scopeDigest == photoA2.scopeDigest,
            "generation rotation must preserve the subject+vault scope digest"
        )
        require(
            photoA1.fileURL.deletingLastPathComponent() == photoA2.fileURL.deletingLastPathComponent(),
            "generation rotation must preserve the photo directory"
        )
        for forbiddenComponent in [
            leaseA2.sessionId,
            leaseA2.generationId.uuidString,
            leaseA2.generationId.uuidString.lowercased(),
        ] {
            require(
                !photoA2.fileURL.path.contains(forbiddenComponent),
                "managed paths must not include session or generation identity"
            )
        }

        let recordingA1 = try store.prepareRecordingStaging(accountLease: leaseA2)
        require(recordingA1.kind == .recordingStaging, "recording must be a staging artifact")
        require(
            recordingA1.fileURL.path.hasPrefix(cachesRoot.path + "/"),
            "recording staging must live under Caches"
        )
        let recordingBytes = Data("account-a-recording".utf8)
        try recordingBytes.write(to: recordingA1.fileURL, options: [.atomic])
        let finalizedRecording = try store.finalizeRecordingStaging(
            recordingA1,
            accountLease: leaseA2
        )
        let finalizedRecordingBytes = try Data(contentsOf: finalizedRecording.fileURL)
        require(finalizedRecordingBytes == recordingBytes, "finalized recording bytes mismatch")

        activeLease = leaseA1
        let recordingA2 = try store.prepareRecordingStaging(accountLease: leaseA1)
        require(
            recordingA1.fileURL.deletingLastPathComponent()
                == recordingA2.fileURL.deletingLastPathComponent(),
            "generation rotation must preserve the recording staging directory"
        )
        store.discard(recordingA2)

        activeLease = leaseB
        let recordingB = try store.prepareRecordingStaging(accountLease: leaseB)
        require(
            recordingA1.fileURL.deletingLastPathComponent()
                != recordingB.fileURL.deletingLastPathComponent(),
            "account A and B recording staging must be isolated"
        )
        store.discard(recordingB)

        activeLease = leaseA2
        let expiredPhoto = try store.writePhotoStaging(
            Data("expired-photo".utf8),
            accountLease: leaseA2
        )
        let expiredRecording = try store.prepareRecordingStaging(accountLease: leaseA2)
        try Data("expired-recording".utf8).write(to: expiredRecording.fileURL)
        let oldDate = Date(timeIntervalSince1970: 100)
        try fileManager.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: expiredPhoto.fileURL.path
        )
        try fileManager.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: expiredRecording.fileURL.path
        )
        let purgedCount = try store.purgeExpiredStaging(before: Date(timeIntervalSince1970: 200))
        require(purgedCount == 2, "expired photo and recording staging must be purged")
        require(
            !fileManager.fileExists(atPath: expiredPhoto.fileURL.path)
                && !fileManager.fileExists(atPath: expiredRecording.fileURL.path),
            "expired staging bytes must be removed"
        )

        expectStoreError(
            "a stale lease must be rejected before a photo write",
            operation: {
                _ = try store.writePhoto(
                    Data("stale-photo".utf8),
                    fileExtension: "jpg",
                    accountLease: leaseA1
                )
            },
            matches: {
                if case .staleLease = $0 { return true }
                return false
            }
        )

        activeLease = leaseA2
        let staleRecording = try store.prepareRecordingStaging(accountLease: leaseA2)
        try Data("stale-recording".utf8).write(to: staleRecording.fileURL, options: [.atomic])
        activeLease = leaseB
        expectStoreError(
            "a stale lease must be rejected after a recording write",
            operation: {
                _ = try store.finalizeRecordingStaging(staleRecording, accountLease: leaseA2)
            },
            matches: {
                if case .staleLease = $0 { return true }
                return false
            }
        )
        require(
            !fileManager.fileExists(atPath: staleRecording.fileURL.path),
            "stale recording output must be deleted"
        )

        var postWriteCheckpoints: [AccountLeaseCheckpoint] = []
        let postWriteRoot = testRoot.appendingPathComponent("post-write-race", isDirectory: true)
        let postWriteStore = AccountPrivateMediaStore(
            fileManager: fileManager,
            applicationSupportRoot: postWriteRoot.appendingPathComponent("app-support"),
            cachesRoot: postWriteRoot.appendingPathComponent("caches"),
            legacyDocumentsRoot: postWriteRoot.appendingPathComponent("documents"),
            legacyTemporaryRoot: postWriteRoot.appendingPathComponent("temporary"),
            leaseValidator: { _, checkpoint in
                postWriteCheckpoints.append(checkpoint)
                return checkpoint == .request
            }
        )
        expectStoreError(
            "a lease invalidated during a photo write must fail closed",
            operation: {
                _ = try postWriteStore.writePhoto(
                    Data("post-write-race".utf8),
                    fileExtension: "jpg",
                    accountLease: leaseA1
                )
            },
            matches: {
                if case .staleLease = $0 { return true }
                return false
            }
        )
        require(
            postWriteCheckpoints == [.request, .commit],
            "photo writes must validate the lease before and after writing"
        )
        require(
            regularFiles(below: postWriteRoot, fileManager: fileManager).isEmpty,
            "post-write lease rejection must remove the attempted photo"
        )

        let legacyPhotoDirectory = legacyDocumentsRoot
            .appendingPathComponent("photos", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
        let legacyRecordingDirectory = legacyTemporaryRoot
            .appendingPathComponent("TGSessionRecordings", isDirectory: true)
        try fileManager.createDirectory(
            at: legacyPhotoDirectory,
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: legacyRecordingDirectory,
            withIntermediateDirectories: true
        )
        let legacyPhotoURL = legacyPhotoDirectory.appendingPathComponent("legacy.jpg")
        let legacyRecordingURL = legacyRecordingDirectory.appendingPathComponent("legacy.m4a")
        let legacyPhotoBytes = Data("unassigned-legacy-photo".utf8)
        let legacyRecordingBytes = Data("unassigned-legacy-recording".utf8)
        try fileManager.createDirectory(
            at: legacyPhotoURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try legacyPhotoBytes.write(to: legacyPhotoURL, options: [.atomic])
        try legacyRecordingBytes.write(to: legacyRecordingURL, options: [.atomic])

        let receipts = try store.retireLegacyGlobalMedia()
        require(receipts.count == 2, "each legacy file must produce one receipt")
        let photoReceipt = receipts.first { $0.surface == .documentsPhotos }
        let recordingReceipt = receipts.first { $0.surface == .temporarySessionRecordings }
        require(photoReceipt?.disposition == .quarantined, "legacy photos must be quarantined")
        require(recordingReceipt?.disposition == .discarded, "legacy recordings must be discarded")
        require(
            photoReceipt?.sourceLocator == "legacy://documents/photos/nested/legacy.jpg",
            "legacy photo locator must be stable and sandbox-independent"
        )
        require(
            recordingReceipt?.sourceLocator
                == "legacy://temporary/TGSessionRecordings/legacy.m4a",
            "legacy recording locator must be stable and sandbox-independent"
        )
        require(photoReceipt?.sourceContentHash == sha256(legacyPhotoBytes), "photo receipt hash mismatch")
        require(
            recordingReceipt?.sourceContentHash == sha256(legacyRecordingBytes),
            "recording receipt hash mismatch"
        )
        require(
            photoReceipt?.sourceLocatorHash == sha256(Data(photoReceipt!.sourceLocator.utf8)),
            "photo locator hash mismatch"
        )
        require(receipts.allSatisfy { $0.processedAt == receiptDate }, "receipt time must be recorded")
        require(!fileManager.fileExists(atPath: legacyPhotoURL.path), "legacy photo must be unmounted")
        require(
            !fileManager.fileExists(atPath: legacyRecordingURL.path),
            "legacy recording must be removed"
        )

        guard let quarantineRelativePath = photoReceipt?.quarantineRelativePath else {
            fatalError("quarantined photo receipt must retain its quarantine locator")
        }
        let quarantinedPhotoURL = applicationSupportRoot.appendingPathComponent(quarantineRelativePath)
        let quarantinedPhotoBytes = try Data(contentsOf: quarantinedPhotoURL)
        require(quarantinedPhotoBytes == legacyPhotoBytes, "quarantined photo bytes mismatch")
        require(
            recordingReceipt?.quarantineRelativePath == nil,
            "discarded recordings must not be copied into quarantine"
        )

        let repeatedReceipts = try store.retireLegacyGlobalMedia()
        require(repeatedReceipts == receipts, "legacy retirement must be deterministic and idempotent")
        let receiptReadback = try store.legacyRetirementReceipts()
        require(
            receiptReadback == receipts,
            "durable receipt readback must match retirement output"
        )

        try fileManager.createDirectory(
            at: legacyPhotoURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try legacyPhotoBytes.write(to: legacyPhotoURL, options: [.atomic])
        let interruptedTemporaryURL = quarantinedPhotoURL.deletingLastPathComponent()
            .appendingPathComponent(".quarantine-\(photoReceipt!.receiptId).tmp")
        try fileManager.moveItem(at: quarantinedPhotoURL, to: interruptedTemporaryURL)
        let resumedReceipts = try store.retireLegacyGlobalMedia()
        require(resumedReceipts == receipts, "interrupted quarantine must preserve its receipt")
        require(
            fileManager.fileExists(atPath: quarantinedPhotoURL.path)
                && !fileManager.fileExists(atPath: interruptedTemporaryURL.path),
            "a deterministic quarantine temporary copy must resume without duplication"
        )

        print("Account private media store model smoke passed")
    }
}
