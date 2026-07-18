import Foundation

// MemoryArchiveItem references the production upload contract. The model gate only
// needs its persisted fields, so keep this compile-only carrier intentionally small.
struct ArchiveMediaUploadIntent {
    let uploadIntentId: String
    let objectKey: String
    let storageProvider: String
    let uploadURL: String
}

struct ArchiveLocalStorageSmokeUser {
    let id: String
}

final class UserManager {
    static let shared = UserManager()
    var currentUser: ArchiveLocalStorageSmokeUser?
}

struct ArchiveLocalStorageSmokeDigitalHumanContext {
    var ownerId: String
}

final class DigitalHumanContextStore {
    static let shared = DigitalHumanContextStore()
    var current = ArchiveLocalStorageSmokeDigitalHumanContext(ownerId: "")
}

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else { fatalError(message) }
}

private func makeLease(
    subjectId: String,
    vaultId: String,
    generation: UInt64 = 1
) -> AccountLease {
    AccountLease(
        subjectId: subjectId,
        vaultId: vaultId,
        sessionId: "session-\(subjectId)-\(generation)",
        generation: generation,
        generationId: UUID(),
        authorityEpoch: "epoch-a"
    )
}

private func makeItem(
    id: String,
    ownerUserId: String,
    localPath: String? = nil
) -> MemoryArchiveItem {
    MemoryArchiveItem(
        id: id,
        kind: .photo,
        title: "item-\(id)",
        note: "note-\(id)",
        localPath: localPath,
        ownerUserId: ownerUserId,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
        analysisStatus: .analyzed
    )
}

private func makeLegacySourceEvidence(
    sourceData: Data,
    scope: ArchiveStorageScope,
    subjectId: String? = nil,
    vaultId: String? = nil
) -> ArchiveLegacySourceEvidence {
    ArchiveLegacySourceEvidence(
        evidenceSchemaVersion: ArchiveLegacySourceEvidence.schemaVersion,
        subjectId: subjectId ?? scope.subjectId,
        vaultId: vaultId ?? scope.vaultId,
        archiveOwnerId: scope.archiveOwnerId,
        sourceLocatorHash: ArchiveLocalStoragePolicy.sha256(
            "archive-legacy-source-v1|\(scope.legacyStorageKey)"
        ),
        sourceContentHash: ArchiveLocalStoragePolicy.sha256(sourceData),
        recordedAt: Date(timeIntervalSince1970: 1_700_000_200)
    )
}

private func installLegacySourceEvidence(
    sourceData: Data,
    scope: ArchiveStorageScope,
    defaults: UserDefaults
) throws {
    let evidence = makeLegacySourceEvidence(sourceData: sourceData, scope: scope)
    defaults.set(
        try JSONEncoder().encode(evidence),
        forKey: scope.legacySourceEvidenceStorageKey
    )
}

@main
private enum ArchiveLocalStorageModelSmoke {
    static func main() throws {
        let accountLeaseA = makeLease(subjectId: "user-a", vaultId: "vault-a")
        let scopeA = ArchiveStorageScope(
            accountLease: accountLeaseA,
            archiveOwnerId: "family-owner"
        )
        let scopeB = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "user-b", vaultId: "vault-b"),
            archiveOwnerId: "family-owner"
        )
        let scopeDifferentVault = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "user-a", vaultId: "vault-a-rotated"),
            archiveOwnerId: "family-owner"
        )

        require(scopeA.storageKey != scopeB.storageKey, "different viewers must not share an archive key")
        require(
            scopeA.storageKey != scopeDifferentVault.storageKey,
            "different vaults must not share an archive key"
        )
        require(
            scopeA.mediaDirectoryRelativePath != scopeB.mediaDirectoryRelativePath,
            "media directories must be scoped by viewer and vault"
        )

        let mediaRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-media-store-\(UUID().uuidString)", isDirectory: true)
        let applicationSupportRoot = mediaRoot.appendingPathComponent("ApplicationSupport", isDirectory: true)
        let cachesRoot = mediaRoot.appendingPathComponent("Caches", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: mediaRoot) }
        let mediaStore = ArchiveMediaStore(
            applicationSupportRoot: applicationSupportRoot,
            cachesRoot: cachesRoot,
            currentScopeResolver: { ownerId in
                ownerId == scopeA.archiveOwnerId ? scopeA : nil
            }
        )
        let mediaBytesA = Data("scope-a-media".utf8)
        let mediaMetadataA = try mediaStore.write(
            mediaBytesA,
            fileExtension: "jpg",
            scope: scopeA
        )
        require(
            mediaMetadataA.itemMetadata(for: .original).count == 4,
            "media metadata must contain only relative path, checksum, size, and scope digest"
        )
        require(
            !mediaMetadataA.relativePath.hasPrefix("/"),
            "persisted media path must remain relative"
        )
        require(
            UUID(
                uuidString: URL(fileURLWithPath: mediaMetadataA.relativePath)
                    .deletingPathExtension()
                    .lastPathComponent
            ) != nil,
            "media file name must be a UUID"
        )
        let resolvedA = try mediaStore.resolvedFileURL(for: mediaMetadataA, scope: scopeA)
        require(
            resolvedA.path.hasPrefix(applicationSupportRoot.path + "/"),
            "original media must resolve under Application Support"
        )
        let resolvedCurrentA = try mediaStore.resolvedFileURL(
            for: mediaMetadataA,
            archiveOwnerId: scopeA.archiveOwnerId
        )
        require(
            resolvedCurrentA == resolvedA,
            "injected current scope resolver must resolve the matching owner"
        )

        let sharedBasename = URL(fileURLWithPath: mediaMetadataA.relativePath).lastPathComponent
        let scopeBRelativePath = scopeB.mediaDirectoryRelativePath + "/" + sharedBasename
        let scopeBURL = applicationSupportRoot.appendingPathComponent(scopeBRelativePath)
        try FileManager.default.createDirectory(
            at: scopeBURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let mediaBytesB = Data("scope-b-media".utf8)
        try mediaBytesB.write(to: scopeBURL)
        let mediaMetadataB = ArchiveMediaMetadata(
            relativePath: scopeBRelativePath,
            sha256: ArchiveLocalStoragePolicy.sha256(mediaBytesB),
            sizeBytes: Int64(mediaBytesB.count),
            scopeDigest: try ArchiveMediaStore.scopeDigest(for: scopeB)
        )
        let resolvedB = try mediaStore.resolvedFileURL(for: mediaMetadataB, scope: scopeB)
        require(
            resolvedB == scopeBURL,
            "same basename must resolve only inside its own scope"
        )
        do {
            _ = try mediaStore.resolvedFileURL(for: mediaMetadataA, scope: scopeB)
            fatalError("scope mismatch must not recover a same-basename file")
        } catch ArchiveMediaStoreError.scopeMismatch {
            // Expected.
        }

        let checksumMismatch = ArchiveMediaMetadata(
            relativePath: mediaMetadataA.relativePath,
            sha256: "sha256:wrong",
            sizeBytes: mediaMetadataA.sizeBytes,
            scopeDigest: mediaMetadataA.scopeDigest
        )
        do {
            _ = try mediaStore.resolvedFileURL(for: checksumMismatch, scope: scopeA)
            fatalError("checksum mismatch must fail closed")
        } catch ArchiveMediaStoreError.checksumMismatch {
            // Expected.
        }

        let injectedRemoteItem = MemoryArchiveItem(remoteJSON: [
            "id": "remote-injection",
            "kind": "photo",
            "ownerUserId": scopeA.archiveOwnerId,
            "localPath": resolvedA.path,
            "metadata": mediaMetadataA.itemMetadata(for: .original),
        ])
        require(injectedRemoteItem?.localPath == nil, "remote localPath must be ignored")
        require(
            injectedRemoteItem?.localMediaMetadata == nil,
            "remote local media binding metadata must be stripped"
        )

        try FileManager.default.removeItem(at: resolvedA)
        do {
            _ = try mediaStore.resolvedFileURL(for: mediaMetadataA, scope: scopeA)
            fatalError("missing scoped media must fail closed")
        } catch ArchiveMediaStoreError.fileMissing {
            // Expected.
        }

        let ownedItem = makeItem(id: "owned", ownerUserId: "family-owner")
        let envelope = try ArchiveLocalStoragePolicy.makeEnvelope(
            items: [ownedItem],
            scope: scopeA
        )
        require(
            ArchiveLocalStoragePolicy.validate(envelope, expectedScope: scopeA) == .accepted,
            "matching owner envelope must be accepted"
        )
        require(
            ArchiveLocalStoragePolicy.validate(envelope, expectedScope: scopeB) == .mismatch,
            "another viewer must not read an envelope"
        )

        var corruptedEnvelope = envelope
        corruptedEnvelope.contentHash = "sha256:corrupt"
        require(
            ArchiveLocalStoragePolicy.validate(corruptedEnvelope, expectedScope: scopeA) == .corrupt,
            "content hash mismatch must fail closed"
        )

        let legacyItems = [
            ownedItem,
            makeItem(id: "missing", ownerUserId: ""),
            makeItem(id: "legacy", ownerUserId: MemoryArchiveItem.legacyOwnerUserId),
            makeItem(id: "mismatch", ownerUserId: "other-owner"),
        ]
        let legacyItemsData = try JSONEncoder().encode(legacyItems)
        let legacySourceEvidence = makeLegacySourceEvidence(
            sourceData: legacyItemsData,
            scope: scopeA
        )
        guard let verifiedLegacySource = ArchiveLocalStoragePolicy.verifiedLegacySource(
            evidence: legacySourceEvidence,
            sourceData: legacyItemsData,
            expectedScope: scopeA
        ) else {
            fatalError("matching source account evidence must verify")
        }
        let legacyPartition = ArchiveLocalStoragePolicy.partitionLegacyItems(
            legacyItems,
            expectedScope: scopeA,
            verifiedSource: verifiedLegacySource
        )
        require(legacyPartition.accepted.map(\.id) == ["owned"], "only proven owner records migrate")
        require(
            Set(legacyPartition.quarantined.map(\.item.id)) == Set(["missing", "legacy", "mismatch"]),
            "unproven legacy records must enter quarantine"
        )
        require(
            legacyPartition.quarantined.contains {
                $0.item.id == "legacy" && $0.reason == .missingOwner
            },
            "legacy_unassigned must never be auto-claimed"
        )

        require(
            ArchiveLocalStoragePolicy.verifiedLegacySource(
                evidence: legacySourceEvidence,
                sourceData: legacyItemsData,
                expectedScope: scopeB
            ) == nil,
            "source evidence for one viewer must not authorize another viewer"
        )
        let wrongVaultEvidence = makeLegacySourceEvidence(
            sourceData: legacyItemsData,
            scope: scopeA,
            vaultId: "vault-other"
        )
        require(
            ArchiveLocalStoragePolicy.verifiedLegacySource(
                evidence: wrongVaultEvidence,
                sourceData: legacyItemsData,
                expectedScope: scopeA
            ) == nil,
            "source evidence must match the current vault"
        )

        let localOtherOwner = makeItem(
            id: "duplicate",
            ownerUserId: "other-owner",
            localPath: "/tmp/other-owner/photo.jpg"
        )
        let remoteExpectedOwner = makeItem(
            id: "duplicate",
            ownerUserId: "family-owner",
            localPath: nil
        )
        let merged = ArchiveLocalStoragePolicy.merge(
            remoteItems: [remoteExpectedOwner],
            localItems: [localOtherOwner],
            expectedArchiveOwnerId: "family-owner"
        )
        require(merged.count == 1, "expected owner item should remain visible")
        require(merged[0].ownerUserId == "family-owner", "cross-owner item must not replace remote owner")
        require(merged[0].localPath == nil, "cross-owner local path must not be inherited")

        let generationTwo = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "user-a", vaultId: "vault-a", generation: 2),
            archiveOwnerId: "family-owner"
        )
        require(
            generationTwo.storageKey == scopeA.storageKey,
            "session generation rotation must not orphan persistent archive data"
        )
        require(
            envelope.generation == 1,
            "writer generation remains auditable metadata"
        )

        let ambiguousSuiteName = "archive-local-storage-ambiguous-family-\(UUID().uuidString)"
        guard let ambiguousDefaults = UserDefaults(suiteName: ambiguousSuiteName) else {
            fatalError("unable to create ambiguous family suite")
        }
        defer {
            ambiguousDefaults.removePersistentDomain(forName: ambiguousSuiteName)
        }
        let ambiguousStore = ArchiveLocalStorage(defaults: ambiguousDefaults)
        let ambiguousFamilyPayload = try JSONEncoder().encode([ownedItem])
        ambiguousDefaults.set(ambiguousFamilyPayload, forKey: scopeA.legacyStorageKey)

        let ambiguousViewerALoad = ambiguousStore.load(scope: scopeA)
        let ambiguousViewerBLoad = ambiguousStore.load(scope: scopeB)
        require(
            ambiguousViewerALoad.items.isEmpty && ambiguousViewerBLoad.items.isEmpty,
            "unbound family legacy data must not enter either viewer account"
        )
        require(
            !ambiguousViewerALoad.migratedLegacyData && !ambiguousViewerBLoad.migratedLegacyData,
            "unbound family legacy data must not report migration"
        )
        require(
            ambiguousDefaults.data(forKey: scopeA.legacyStorageKey) == ambiguousFamilyPayload,
            "two viewers must not consume an unbound shared legacy source"
        )
        require(
            ambiguousDefaults.data(forKey: scopeA.storageKey) == nil
                && ambiguousDefaults.data(forKey: scopeB.storageKey) == nil,
            "unbound family source must not create either scoped envelope"
        )
        require(
            ambiguousStore.migrationReceipts(scope: scopeA).isEmpty
                && ambiguousStore.migrationReceipts(scope: scopeB).isEmpty,
            "unbound family source must not create an account migration receipt"
        )
        let ambiguousDeviceRecords = ambiguousStore.deviceQuarantineRecords()
        require(
            ambiguousDeviceRecords.count == 1,
            "both viewers must share one device-neutral quarantine record"
        )
        require(
            ambiguousDeviceRecords[0].payload == ambiguousFamilyPayload
                && ambiguousDeviceRecords[0].sourceLocatorHash == ArchiveLocalStoragePolicy.sha256(
                    "archive-legacy-source-v1|\(scopeA.legacyStorageKey)"
                ),
            "device quarantine must preserve the source with a hashed locator"
        )
        require(
            Set(ambiguousDeviceRecords[0].observations.map(\.subjectDigest)) == Set([
                ArchiveLocalStoragePolicy.sha256("archive-subject-v1|user-a"),
                ArchiveLocalStoragePolicy.sha256("archive-subject-v1|user-b"),
            ]),
            "device quarantine must audit both viewer observations without plaintext subjects"
        )
        let quarantineKeys = ambiguousDefaults.dictionaryRepresentation().keys.filter {
            $0.contains("memoryArchive.quarantine")
        }
        require(
            quarantineKeys == [ArchiveLocalStorage.deviceQuarantineStorageKey]
                && quarantineKeys.allSatisfy {
                    !$0.contains("family-owner") && !$0.contains("user-a") && !$0.contains("user-b")
                },
            "device quarantine keys must not contain plaintext owner or subject identifiers"
        )

        let provenSuiteName = "archive-local-storage-proven-family-\(UUID().uuidString)"
        guard let provenDefaults = UserDefaults(suiteName: provenSuiteName) else {
            fatalError("unable to create proven family suite")
        }
        defer {
            provenDefaults.removePersistentDomain(forName: provenSuiteName)
        }
        let provenStore = ArchiveLocalStorage(defaults: provenDefaults)
        let provenFamilyPayload = try JSONEncoder().encode([ownedItem])
        provenDefaults.set(provenFamilyPayload, forKey: scopeA.legacyStorageKey)
        try installLegacySourceEvidence(
            sourceData: provenFamilyPayload,
            scope: scopeA,
            defaults: provenDefaults
        )
        require(
            !scopeA.legacySourceEvidenceStorageKey.contains("family-owner")
                && !scopeA.legacySourceEvidenceStorageKey.contains("user-a"),
            "source evidence key must use only the hashed legacy locator"
        )

        let wrongViewerLoad = provenStore.load(scope: scopeB)
        require(wrongViewerLoad.items.isEmpty, "viewer B must not import viewer A's proven source")
        require(
            provenDefaults.data(forKey: scopeA.legacyStorageKey) == provenFamilyPayload
                && provenDefaults.data(forKey: scopeA.legacySourceEvidenceStorageKey) != nil,
            "a non-matching viewer must preserve both source and source evidence"
        )
        let wrongVaultLoad = provenStore.load(scope: scopeDifferentVault)
        require(wrongVaultLoad.items.isEmpty, "a mismatched vault must not import proven source data")
        require(
            provenDefaults.data(forKey: scopeA.legacyStorageKey) == provenFamilyPayload,
            "a mismatched vault must not delete the shared source"
        )

        let matchingViewerLoad = provenStore.load(scope: scopeA)
        require(
            matchingViewerLoad.items.map(\.id) == ["owned"] && matchingViewerLoad.migratedLegacyData,
            "only the viewer and vault named by source evidence may migrate"
        )
        require(
            provenDefaults.data(forKey: scopeA.legacyStorageKey) == nil
                && provenDefaults.data(forKey: scopeA.legacySourceEvidenceStorageKey) == nil,
            "matching migration may retire source and evidence after receipt commit"
        )
        require(
            provenStore.migrationReceipts(scope: scopeA).count == 1
                && provenStore.migrationReceipts(scope: scopeB).isEmpty,
            "only the matching account may receive a migration receipt"
        )
        require(
            provenStore.load(scope: scopeB).items.isEmpty,
            "viewer B must remain empty after viewer A migrates the shared source"
        )

        let suiteName = "archive-local-storage-smoke-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("unable to create isolated UserDefaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = ArchiveLocalStorage(defaults: defaults)
        let selfScope = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "user-a", vaultId: "vault-a"),
            archiveOwnerId: "user-a"
        )
        let selfOwnedItem = makeItem(id: "owned", ownerUserId: "user-a")
        let legacyPayload = try JSONEncoder().encode([
            selfOwnedItem,
            makeItem(id: "ownerless", ownerUserId: MemoryArchiveItem.legacyOwnerUserId),
        ])
        defaults.set(legacyPayload, forKey: selfScope.legacyStorageKey)

        let firstLoad = store.load(scope: selfScope)
        require(
            firstLoad.items.map(\.id) == ["owned"],
            "explicit self-owned legacy data may migrate without claiming ownerless data"
        )
        require(firstLoad.migratedLegacyData, "legacy data should be migrated once")
        require(firstLoad.quarantinedItemCount == 1, "ownerless legacy item should be quarantined")
        require(defaults.data(forKey: selfScope.legacyStorageKey) == nil, "legacy key should retire after receipt commit")
        require(store.migrationReceipts(scope: selfScope).count == 1, "migration must create one receipt")
        require(
            defaults.data(forKey: selfScope.legacySourceEvidenceStorageKey) == nil,
            "self-owned migration must not synthesize reusable source evidence"
        )
        require(store.quarantineRecords(scope: selfScope).isEmpty, "legacy quarantine must not be account-scoped")
        require(store.deviceQuarantineRecords().count == 1, "migration must preserve one device quarantine record")

        let selfGenerationTwo = ArchiveStorageScope(
            accountLease: makeLease(subjectId: "user-a", vaultId: "vault-a", generation: 2),
            archiveOwnerId: "user-a"
        )
        let secondLoad = store.load(scope: selfGenerationTwo)
        require(secondLoad.items.map(\.id) == ["owned"], "generation rotation should retain scoped data")
        require(!secondLoad.migratedLegacyData, "migration must be idempotent")
        require(store.migrationReceipts(scope: selfScope).count == 1, "migration must not duplicate receipts")
        require(store.load(scope: scopeB).items.isEmpty, "another account must not read scoped data")

        let interruptedSuiteName = "archive-local-storage-interrupted-\(UUID().uuidString)"
        guard let interruptedDefaults = UserDefaults(suiteName: interruptedSuiteName) else {
            fatalError("unable to create interrupted migration suite")
        }
        defer {
            interruptedDefaults.removePersistentDomain(forName: interruptedSuiteName)
        }
        let interruptedStore = ArchiveLocalStorage(defaults: interruptedDefaults)
        try interruptedStore.save(items: [selfOwnedItem], scope: selfScope)
        interruptedDefaults.set(legacyPayload, forKey: selfScope.legacyStorageKey)
        let resumedLoad = interruptedStore.load(scope: selfScope)
        require(resumedLoad.items.map(\.id) == ["owned"], "envelope remains authority after interruption")
        require(resumedLoad.migratedLegacyData, "cold start should finish interrupted legacy retirement")
        require(
            interruptedDefaults.data(forKey: selfScope.legacyStorageKey) == nil,
            "cold start should retire the leftover legacy key"
        )
        require(
            interruptedStore.migrationReceipts(scope: selfScope).count == 1,
            "interrupted retirement should remain idempotent"
        )

        let untrustedInterruptedSuiteName =
            "archive-local-storage-untrusted-interrupted-\(UUID().uuidString)"
        guard let untrustedInterruptedDefaults = UserDefaults(
            suiteName: untrustedInterruptedSuiteName
        ) else {
            fatalError("unable to create untrusted interrupted suite")
        }
        defer {
            untrustedInterruptedDefaults.removePersistentDomain(
                forName: untrustedInterruptedSuiteName
            )
        }
        let untrustedInterruptedStore = ArchiveLocalStorage(
            defaults: untrustedInterruptedDefaults
        )
        try untrustedInterruptedStore.save(items: [ownedItem], scope: scopeA)
        untrustedInterruptedDefaults.set(
            ambiguousFamilyPayload,
            forKey: scopeA.legacyStorageKey
        )
        let untrustedResumedLoad = untrustedInterruptedStore.load(scope: scopeA)
        require(
            untrustedResumedLoad.items.map(\.id) == ["owned"]
                && !untrustedResumedLoad.migratedLegacyData,
            "an existing envelope must not authorize unbound legacy retirement"
        )
        require(
            untrustedInterruptedDefaults.data(forKey: scopeA.legacyStorageKey)
                == ambiguousFamilyPayload,
            "cold start must retain an unbound legacy source beside an existing envelope"
        )
        require(
            untrustedInterruptedStore.migrationReceipts(scope: scopeA).isEmpty,
            "unbound interrupted source must not receive an account receipt"
        )

        do {
            try store.save(
                items: [makeItem(id: "wrong", ownerUserId: "other-owner")],
                scope: scopeA
            )
            fatalError("cross-owner save should be rejected")
        } catch ArchiveLocalStorageError.ownerMismatch {
            // Expected.
        }

        try store.save(items: [ownedItem], scope: scopeA)
        try store.save(
            items: [makeItem(id: "owned-b", ownerUserId: "family-owner")],
            scope: scopeB
        )
        let unboundPurgePayload = try JSONEncoder().encode([selfOwnedItem])
        defaults.set(unboundPurgePayload, forKey: selfScope.legacyStorageKey)
        let purgedMediaPaths = store.purgeAccount(accountLease: accountLeaseA)
        require(
            Set(purgedMediaPaths) == Set([
                selfScope.mediaDirectoryRelativePath,
                scopeA.mediaDirectoryRelativePath,
            ]),
            "purge should return every registered owner scope for account A"
        )
        require(
            defaults.data(forKey: selfScope.legacyStorageKey) == unboundPurgePayload,
            "account purge must not delete an unbound legacy key"
        )
        require(store.load(scope: scopeA).items.isEmpty, "account purge must delete account A envelope")
        require(store.load(scope: scopeB).items.map(\.id) == ["owned-b"], "account purge must preserve account B")

        print("Archive local storage model smoke passed")
    }
}
