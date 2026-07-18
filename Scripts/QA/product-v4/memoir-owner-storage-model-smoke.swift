import Foundation

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

private func makeMemoir(
    id: String,
    ownerId: String,
    prose: String,
    sessionId: String? = nil
) -> MemoirModel {
    MemoirModel(
        id: id,
        title: "memoir-\(id)",
        prose: prose,
        timeDescription: "1998年6月",
        year: 1998,
        month: 6,
        location: "上海",
        keyPeople: [],
        authorId: ownerId,
        sessionId: sessionId
    )
}

private func encodedLegacyMemoir(_ memoir: MemoirModel) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(memoir)
}

private final class MutableLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    private let lock = NSLock()
    private var activeLease: AccountLease?

    init(activeLease: AccountLease?) {
        self.activeLease = activeLease
    }

    func publish(_ lease: AccountLease?) {
        lock.lock()
        activeLease = lease
        lock.unlock()
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        lock.lock()
        defer { lock.unlock() }
        guard let activeLease,
              subjectId == nil || subjectId == activeLease.subjectId else {
            return nil
        }
        return activeLease
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        lock.lock()
        let activeLease = activeLease
        lock.unlock()
        let allowed = activeLease == lease
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: allowed,
            reason: allowed ? .allowed : .generationMismatch,
            sessionRotated: false
        )
    }
}

@main
private enum MemoirOwnerStorageModelSmoke {
    static func main() throws {
        let leaseA = makeLease(subjectId: "user-a", vaultId: "vault-a")
        let leaseB = makeLease(subjectId: "user-b", vaultId: "vault-b")
        let scopeA = MemoirStorageScope(accountLease: leaseA, ownerId: "owner-a")
        let scopeB = MemoirStorageScope(accountLease: leaseB, ownerId: "owner-b")
        let rotatedVaultScope = MemoirStorageScope(
            accountLease: makeLease(subjectId: "user-a", vaultId: "vault-a-rotated"),
            ownerId: "owner-a"
        )

        require(scopeA.scopeDigest != scopeB.scopeDigest, "accounts must not share a memoir scope")
        require(
            scopeA.scopeDigest != rotatedVaultScope.scopeDigest,
            "vault rotation must not mount the prior memoir scope"
        )
        require(
            scopeA.recordsDirectoryRelativePath != scopeB.recordsDirectoryRelativePath,
            "memoir JSON directories must include subject, vault, and owner scope"
        )
        require(
            scopeA.recordingsDirectoryRelativePath != scopeB.recordingsDirectoryRelativePath,
            "memoir recording directories must include subject, vault, and owner scope"
        )

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("memoir-owner-storage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let storage = MemoirOwnerStorage(rootDirectory: root)

        let sharedId = "same-id"
        let memoirA = makeMemoir(id: sharedId, ownerId: "owner-a", prose: "account-a")
        let memoirB = makeMemoir(id: sharedId, ownerId: "owner-b", prose: "account-b")
        try storage.save(memoirA, scope: scopeA)
        try storage.save(memoirB, scope: scopeB)

        require(storage.get(id: sharedId, scope: scopeA)?.prose == "account-a", "A must read only A")
        require(storage.get(id: sharedId, scope: scopeB)?.prose == "account-b", "B must read only B")
        require(
            storage.get(id: sharedId, scope: rotatedVaultScope) == nil,
            "another vault must not read an equal memoir id"
        )

        let recordingSourceA = root.appendingPathComponent("recording-a.tmp")
        let recordingSourceB = root.appendingPathComponent("recording-b.tmp")
        try Data("recording-a".utf8).write(to: recordingSourceA)
        try Data("recording-b".utf8).write(to: recordingSourceB)
        let recordingA = try storage.saveRecording(
            from: recordingSourceA,
            sessionId: "same-session",
            scope: scopeA
        )
        let recordingB = try storage.saveRecording(
            from: recordingSourceB,
            sessionId: "same-session",
            scope: scopeB
        )
        require(recordingA != recordingB, "equal recording ids must resolve to different account paths")
        let persistedRecordingA = try Data(
            contentsOf: storage.getRecordingURL(sessionId: "same-session", scope: scopeA)!
        )
        require(
            persistedRecordingA == Data("recording-a".utf8),
            "A recording bytes must remain isolated"
        )
        let deletedRecordingA = try storage.deleteRecording(
            sessionId: "same-session",
            scope: scopeA
        )
        require(
            deletedRecordingA,
            "A should delete its own recording"
        )
        require(
            storage.getRecordingURL(sessionId: "same-session", scope: scopeB) == recordingB,
            "deleting A must preserve B's equal recording id"
        )

        let deletedMemoirA = try storage.delete(id: sharedId, scope: scopeA)
        require(deletedMemoirA, "A should delete its own memoir")
        require(storage.get(id: sharedId, scope: scopeA) == nil, "A memoir should be deleted")
        require(storage.get(id: sharedId, scope: scopeB)?.prose == "account-b", "B must survive A delete")

        let envelope = try MemoirOwnerStoragePolicy.makeEnvelope(memoir: memoirB, scope: scopeB)
        require(
            MemoirOwnerStoragePolicy.validate(envelope, expectedScope: scopeB) == .accepted,
            "matching owner envelope must validate"
        )
        require(
            MemoirOwnerStoragePolicy.validate(envelope, expectedScope: scopeA) == .mismatch,
            "another account must reject the envelope"
        )
        var corruptEnvelope = envelope
        corruptEnvelope.contentHash = "sha256:corrupt"
        require(
            MemoirOwnerStoragePolicy.validate(corruptEnvelope, expectedScope: scopeB) == .corrupt,
            "content corruption must fail closed"
        )

        let legacyRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("memoir-owner-legacy-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: legacyRoot) }
        try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
        let legacyRecordings = legacyRoot.appendingPathComponent("recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyRecordings, withIntermediateDirectories: true)

        let ownedLegacy = makeMemoir(
            id: "owned-legacy",
            ownerId: "owner-a",
            prose: "owned",
            sessionId: "owned-session"
        )
        let otherOwnerLegacy = makeMemoir(
            id: "other-legacy",
            ownerId: "owner-b",
            prose: "other",
            sessionId: "other-session"
        )
        let seedLegacy = makeMemoir(
            id: "seed-legacy",
            ownerId: "user_001",
            prose: "fixture",
            sessionId: "seed-session"
        )
        let ownerlessLegacy = makeMemoir(
            id: "ownerless-legacy",
            ownerId: "owner-placeholder",
            prose: "ownerless",
            sessionId: "ownerless-session"
        )
        try encodedLegacyMemoir(ownedLegacy).write(
            to: legacyRoot.appendingPathComponent("owned-legacy.json")
        )
        try encodedLegacyMemoir(otherOwnerLegacy).write(
            to: legacyRoot.appendingPathComponent("other-legacy.json")
        )
        try encodedLegacyMemoir(seedLegacy).write(
            to: legacyRoot.appendingPathComponent("seed-legacy.json")
        )
        var ownerlessObject = try JSONSerialization.jsonObject(
            with: encodedLegacyMemoir(ownerlessLegacy)
        ) as! [String: Any]
        ownerlessObject.removeValue(forKey: "authorId")
        try JSONSerialization.data(withJSONObject: ownerlessObject).write(
            to: legacyRoot.appendingPathComponent("ownerless-legacy.json")
        )
        try Data("not-json".utf8).write(to: legacyRoot.appendingPathComponent("corrupt.json"))

        for (sessionId, payload) in [
            ("owned-session", "owned-recording"),
            ("other-session", "other-recording"),
            ("seed-session", "seed-recording"),
            ("ownerless-session", "ownerless-recording"),
            ("orphan-session", "orphan-recording"),
        ] {
            try Data(payload.utf8).write(
                to: legacyRecordings.appendingPathComponent("\(sessionId).m4a")
            )
        }

        let legacyStorage = MemoirOwnerStorage(rootDirectory: legacyRoot)
        let migrated = legacyStorage.loadAll(scope: scopeA)
        require(migrated.map(\.id) == ["owned-legacy"], "only proven owner legacy data may migrate")
        require(
            legacyStorage.getRecordingURL(sessionId: "owned-session", scope: scopeA) != nil,
            "a migrated owned memoir may carry its referenced recording"
        )
        require(
            FileManager.default.fileExists(
                atPath: legacyRecordings.appendingPathComponent("other-session.m4a").path
            ),
            "another owner's referenced legacy recording must remain unclaimed"
        )
        require(
            FileManager.default.fileExists(
                atPath: legacyRoot.appendingPathComponent("other-legacy.json").path
            ),
            "another owner's legacy JSON must remain available to its proven scope"
        )

        let quarantineReasons = Set(legacyStorage.quarantineRecords().map(\.reason))
        require(quarantineReasons.contains(.missingOwner), "ownerless legacy must be quarantined")
        require(quarantineReasons.contains(.seedFixture), "seed legacy must be quarantined")
        require(quarantineReasons.contains(.corrupt), "corrupt legacy must be quarantined")
        require(quarantineReasons.contains(.orphanRecording), "unowned recordings must be quarantined")
        require(
            legacyStorage.quarantineRecords().allSatisfy {
                FileManager.default.fileExists(atPath: legacyRoot.appendingPathComponent($0.payloadRelativePath).path)
            },
            "quarantine records must point to retained payload evidence"
        )

        let receipts = legacyStorage.migrationReceipts()
        require(
            receipts.contains {
                $0.memoirId == "owned-legacy"
                    && $0.state == .migrated
                    && $0.subjectId == scopeA.subjectId
                    && $0.vaultId == scopeA.vaultId
                    && $0.ownerId == scopeA.ownerId
            },
            "owned migration must leave a scoped receipt"
        )
        require(
            receipts.filter { $0.state == .quarantined }.allSatisfy {
                $0.subjectId == nil && $0.vaultId == nil && $0.ownerId == nil
            },
            "unclaimed quarantine receipts must remain device-neutral"
        )

        let runtime = MutableLeaseRuntime(activeLease: leaseA)
        let repositoryRoot = root.appendingPathComponent("repository", isDirectory: true)
        let repository = MemoirRepository(
            storage: MemoirOwnerStorage(rootDirectory: repositoryRoot),
            accountLeaseRuntime: runtime,
            ownerResolver: { lease in lease.subjectId == "user-a" ? "owner-a" : "owner-b" }
        )
        let asyncMemoir = makeMemoir(id: "async-id", ownerId: "owner-a", prose: "captured-a")
        runtime.publish(leaseB)
        require(
            !repository.save(asyncMemoir, accountLease: leaseA, ownerId: "owner-a"),
            "a stale captured lease must not commit after account switch"
        )
        require(
            repository.get(by: "async-id", accountLease: leaseB, ownerId: "owner-b") == nil,
            "stale A completion must not write into B"
        )

        runtime.publish(leaseA)
        require(
            repository.save(asyncMemoir, accountLease: leaseA, ownerId: "owner-a"),
            "the active captured lease should commit"
        )
        runtime.publish(leaseB)
        require(
            repository.get(by: "async-id", accountLease: leaseA, ownerId: "owner-a") == nil,
            "stale lease reads must be rejected"
        )
        require(
            !repository.delete(id: "async-id", accountLease: leaseA, ownerId: "owner-a"),
            "stale lease deletes must be rejected"
        )

        print("Memoir owner storage model smoke passed")
    }
}
