#if UI_QA_SIMULATOR && targetEnvironment(simulator)
import Foundation
import UIKit

struct GlobalPrivateStoreRetirementUIQAResult: Codable {
    static let fileName = "global-private-store-retirement-uiqa-result.json"

    let completed: Bool
    let accountA: String
    let accountB: String
    let conversationAccountIsolation: Bool
    let conversationGenerationContinuity: Bool
    let memoirAccountIsolation: Bool
    let memoryAccountIsolation: Bool
    let mapPresentationAccountIsolation: Bool
    let privatePhotoAccountIsolation: Bool
    let staleLeaseRejected: Bool
    let legacyGlobalConversationQuarantined: Bool
    let legacyHomeMediaRetired: Bool
    let reservedFallbackOwnerRejected: Bool
    let legacyReceiptCount: Int
    let failureReason: String?

    func writeToDocuments(fileManager: FileManager = .default) throws -> URL {
        let documentsURL = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let resultURL = documentsURL.appendingPathComponent(Self.fileName, isDirectory: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(self).write(to: resultURL, options: [.atomic])
        return resultURL
    }
}

enum ProductV4GlobalPrivateStoreRetirementUIQASmoke {
    private static let accountA = "uiqa-account-a"
    private static let accountB = "uiqa-account-b"

    static func run() -> GlobalPrivateStoreRetirementUIQAResult {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "product-v4-global-private-store-\(UUID().uuidString)",
            isDirectory: true
        )
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: root) }

            let leaseA = makeLease(subjectId: accountA, vaultId: "uiqa-vault-a", generation: 1)
            let leaseANext = makeLease(subjectId: accountA, vaultId: "uiqa-vault-a", generation: 2)
            let leaseB = makeLease(subjectId: accountB, vaultId: "uiqa-vault-b", generation: 1)
            let runtime = ProductV4UIQAMutableLeaseRuntime(activeLease: leaseA)

            let conversationResult = try verifyConversationStorage(
                root: root,
                leaseA: leaseA,
                leaseANext: leaseANext,
                leaseB: leaseB
            )
            let memoirResult = verifyMemoirStorage(
                root: root,
                runtime: runtime,
                leaseA: leaseA,
                leaseB: leaseB
            )
            let memoryMapResult = verifyMemoryAndMapStorage(
                runtime: runtime,
                leaseA: leaseA,
                leaseB: leaseB
            )
            let mediaResult = try verifyPrivateMediaStorage(
                root: root,
                runtime: runtime,
                leaseA: leaseA,
                leaseB: leaseB
            )
            let reservedFallbackOwner = ["user", "001"].joined(separator: "_")
            let reservedFallbackOwnerRejected = ConversationStorageScope(
                accountLease: leaseA,
                ownerId: reservedFallbackOwner,
                personaScope: .family
            ) == nil

            let staleLeaseRejected = memoirResult.staleLeaseRejected
                && memoryMapResult.staleLeaseRejected
                && mediaResult.staleLeaseRejected
            let completed = conversationResult.accountIsolation
                && conversationResult.generationContinuity
                && memoirResult.accountIsolation
                && memoryMapResult.memoryIsolation
                && memoryMapResult.mapIsolation
                && mediaResult.photoIsolation
                && staleLeaseRejected
                && conversationResult.legacyGlobalQuarantined
                && mediaResult.legacyRetired
                && reservedFallbackOwnerRejected

            return GlobalPrivateStoreRetirementUIQAResult(
                completed: completed,
                accountA: accountA,
                accountB: accountB,
                conversationAccountIsolation: conversationResult.accountIsolation,
                conversationGenerationContinuity: conversationResult.generationContinuity,
                memoirAccountIsolation: memoirResult.accountIsolation,
                memoryAccountIsolation: memoryMapResult.memoryIsolation,
                mapPresentationAccountIsolation: memoryMapResult.mapIsolation,
                privatePhotoAccountIsolation: mediaResult.photoIsolation,
                staleLeaseRejected: staleLeaseRejected,
                legacyGlobalConversationQuarantined: conversationResult.legacyGlobalQuarantined,
                legacyHomeMediaRetired: mediaResult.legacyRetired,
                reservedFallbackOwnerRejected: reservedFallbackOwnerRejected,
                legacyReceiptCount: mediaResult.legacyReceiptCount,
                failureReason: nil
            )
        } catch {
            try? fileManager.removeItem(at: root)
            return failedResult(reason: String(describing: error))
        }
    }

    static func makeResultViewController(
        result: GlobalPrivateStoreRetirementUIQAResult
    ) -> UIViewController {
        GlobalPrivateStoreRetirementUIQAViewController(result: result)
    }

    private static func verifyConversationStorage(
        root: URL,
        leaseA: AccountLease,
        leaseANext: AccountLease,
        leaseB: AccountLease
    ) throws -> (accountIsolation: Bool, generationContinuity: Bool, legacyGlobalQuarantined: Bool) {
        let support = root.appendingPathComponent("conversation-support", isDirectory: true)
        let documents = root.appendingPathComponent("conversation-documents", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let storage = ConversationLocalStorage(
            applicationSupportRoot: support,
            legacyDocumentsRoot: documents
        )
        guard let scopeA = ConversationStorageScope(
            accountLease: leaseA,
            ownerId: accountA,
            personaScope: .personal
        ), let scopeANext = ConversationStorageScope(
            accountLease: leaseANext,
            ownerId: accountA,
            personaScope: .personal
        ), let scopeB = ConversationStorageScope(
            accountLease: leaseB,
            ownerId: accountB,
            personaScope: .personal
        ) else {
            throw ProductV4GlobalPrivateStoreUIQASmokeError.invalidScope
        }

        var memoryA = ConversationMemory()
        memoryA.sessionCount = 2
        memoryA.lastSummary.event = "account-a-event"
        try storage.save(memory: memoryA, scope: scopeA)

        var legacyGlobal = ConversationMemory()
        legacyGlobal.sessionCount = 99
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(legacyGlobal).write(to: storage.globalLegacyURL, options: [.atomic])

        let loadedA = storage.mount(scope: scopeA)
        let loadedANext = storage.mount(scope: scopeANext)
        let loadedB = storage.mount(scope: scopeB)
        let accountIsolation = loadedA.lastSummary.event == "account-a-event"
            && loadedB.sessionCount == 0
            && storage.memoryURL(scope: scopeA) != storage.memoryURL(scope: scopeB)
        let generationContinuity = loadedANext.lastSummary.event == "account-a-event"
            && storage.memoryURL(scope: scopeA) == storage.memoryURL(scope: scopeANext)
        let legacyGlobalQuarantined = storage.quarantineRecord(
            sourceURL: storage.globalLegacyURL
        )?.reason == .ambiguousOwner
        return (accountIsolation, generationContinuity, legacyGlobalQuarantined)
    }

    private static func verifyMemoirStorage(
        root: URL,
        runtime: ProductV4UIQAMutableLeaseRuntime,
        leaseA: AccountLease,
        leaseB: AccountLease
    ) -> (accountIsolation: Bool, staleLeaseRejected: Bool) {
        let repository = MemoirRepository(
            storage: MemoirOwnerStorage(
                rootDirectory: root.appendingPathComponent("memoirs", isDirectory: true)
            ),
            accountLeaseRuntime: runtime,
            ownerResolver: { $0.subjectId }
        )
        let sharedId = "uiqa-shared-memoir"
        runtime.publish(leaseA)
        let savedA = repository.save(
            makeMemoir(id: sharedId, ownerId: accountA, prose: "memoir-a"),
            accountLease: leaseA,
            ownerId: accountA
        )
        runtime.publish(leaseB)
        let staleReadRejected = repository.get(
            by: sharedId,
            accountLease: leaseA,
            ownerId: accountA
        ) == nil
        let savedB = repository.save(
            makeMemoir(id: sharedId, ownerId: accountB, prose: "memoir-b"),
            accountLease: leaseB,
            ownerId: accountB
        )
        let loadedB = repository.get(
            by: sharedId,
            accountLease: leaseB,
            ownerId: accountB
        )?.prose
        runtime.publish(leaseA)
        let loadedA = repository.get(
            by: sharedId,
            accountLease: leaseA,
            ownerId: accountA
        )?.prose
        return (
            savedA && savedB && loadedA == "memoir-a" && loadedB == "memoir-b",
            staleReadRejected
        )
    }

    private static func verifyMemoryAndMapStorage(
        runtime: ProductV4UIQAMutableLeaseRuntime,
        leaseA: AccountLease,
        leaseB: AccountLease
    ) -> (memoryIsolation: Bool, mapIsolation: Bool, staleLeaseRejected: Bool) {
        let suiteName = "product-v4-global-private-store-uiqa.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return (false, false, false)
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = MemoryRepository(
            defaults: defaults,
            accountLeaseRuntime: runtime,
            notificationCenter: NotificationCenter()
        )
        let mapStore = MemoryMapPresentationStore(
            defaults: defaults,
            accountLeaseRuntime: runtime
        )
        let sharedId = "uiqa-shared-memory"

        runtime.publish(leaseA)
        let savedA = repository.add(
            makeMemory(id: sharedId, ownerId: accountA, title: "memory-a"),
            ownerId: accountA,
            accountLease: leaseA
        )
        let markedA = mapStore.markRead(
            memoryId: sharedId,
            ownerId: accountA,
            accountLease: leaseA
        )

        runtime.publish(leaseB)
        let staleMemoryRejected = repository.getAllByOwner(
            accountA,
            accountLease: leaseA
        ).isEmpty
        let bInitiallyEmpty = repository.getAllByOwner(
            accountB,
            accountLease: leaseB
        ).isEmpty
        let mapBInitiallyEmpty = mapStore.load(
            ownerId: accountB,
            accountLease: leaseB
        ).readMemoryIds.isEmpty
        let savedB = repository.add(
            makeMemory(id: sharedId, ownerId: accountB, title: "memory-b"),
            ownerId: accountB,
            accountLease: leaseB
        )

        runtime.publish(leaseA)
        let loadedA = repository.get(
            by: sharedId,
            ownerId: accountA,
            accountLease: leaseA
        )?.title
        let mapA = mapStore.load(ownerId: accountA, accountLease: leaseA)
        return (
            savedA && savedB && bInitiallyEmpty && loadedA == "memory-a",
            markedA && mapBInitiallyEmpty && mapA.readMemoryIds == [sharedId],
            staleMemoryRejected
        )
    }

    private static func verifyPrivateMediaStorage(
        root: URL,
        runtime: ProductV4UIQAMutableLeaseRuntime,
        leaseA: AccountLease,
        leaseB: AccountLease
    ) throws -> (photoIsolation: Bool, staleLeaseRejected: Bool, legacyRetired: Bool, legacyReceiptCount: Int) {
        let support = root.appendingPathComponent("media-support", isDirectory: true)
        let caches = root.appendingPathComponent("media-caches", isDirectory: true)
        let documents = root.appendingPathComponent("media-documents", isDirectory: true)
        let temporary = root.appendingPathComponent("media-temporary", isDirectory: true)
        for directory in [support, caches, documents, temporary] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let store = AccountPrivateMediaStore(
            applicationSupportRoot: support,
            cachesRoot: caches,
            legacyDocumentsRoot: documents,
            legacyTemporaryRoot: temporary,
            leaseValidator: { lease, checkpoint in
                runtime.validate(lease, at: checkpoint).allowed
            }
        )

        runtime.publish(leaseA)
        let photoA = try store.writePhoto(Data("photo-a".utf8), accountLease: leaseA)
        let referenceA = try store.persistentPhotoReference(for: photoA)
        let recordingA = try store.prepareRecordingStaging(accountLease: leaseA)
        try Data("recording-a".utf8).write(to: recordingA.fileURL)

        runtime.publish(leaseB)
        let aHiddenFromB = store.resolvePersistentPhoto(
            reference: referenceA,
            accountLease: leaseB
        ) == nil
        var staleLeaseRejected = false
        do {
            _ = try store.finalizeRecordingStaging(recordingA, accountLease: leaseA)
        } catch AccountPrivateMediaStoreError.staleLease {
            staleLeaseRejected = !FileManager.default.fileExists(atPath: recordingA.fileURL.path)
        }
        let photoB = try store.writePhoto(Data("photo-b".utf8), accountLease: leaseB)
        let referenceB = try store.persistentPhotoReference(for: photoB)

        runtime.publish(leaseA)
        let aRestoredForA = store.resolvePersistentPhoto(
            reference: referenceA,
            accountLease: leaseA
        ) != nil
        let photoIsolation = aHiddenFromB && aRestoredForA && referenceA != referenceB

        let legacyPhotos = documents.appendingPathComponent("photos", isDirectory: true)
        let legacyRecordings = temporary.appendingPathComponent("TGSessionRecordings", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyPhotos, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyRecordings, withIntermediateDirectories: true)
        try Data("legacy-photo".utf8).write(
            to: legacyPhotos.appendingPathComponent("legacy.jpg", isDirectory: false)
        )
        try Data("legacy-recording".utf8).write(
            to: legacyRecordings.appendingPathComponent("legacy.m4a", isDirectory: false)
        )
        let receipts = try store.retireLegacyGlobalMedia()
        let legacyRetired = receipts.contains {
            $0.surface == .documentsPhotos && $0.disposition == .quarantined
        } && receipts.contains {
            $0.surface == .temporarySessionRecordings && $0.disposition == .discarded
        }
        return (photoIsolation, staleLeaseRejected, legacyRetired, receipts.count)
    }

    private static func makeLease(
        subjectId: String,
        vaultId: String,
        generation: UInt64
    ) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: vaultId,
            sessionId: "uiqa-session-\(subjectId)-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "uiqa-authority-epoch"
        )
    }

    private static func makeMemoir(id: String, ownerId: String, prose: String) -> MemoirModel {
        MemoirModel(
            id: id,
            title: "UIQA Memoir",
            prose: prose,
            timeDescription: "2026年7月",
            year: 2026,
            month: 7,
            location: "UIQA",
            authorId: ownerId
        )
    }

    private static func makeMemory(id: String, ownerId: String, title: String) -> MemoryModel {
        MemoryModel(
            id: id,
            title: title,
            subtitle: "UIQA owner isolation",
            location: "UIQA",
            year: 2026,
            month: 7,
            authorId: ownerId
        )
    }

    private static func failedResult(reason: String) -> GlobalPrivateStoreRetirementUIQAResult {
        GlobalPrivateStoreRetirementUIQAResult(
            completed: false,
            accountA: accountA,
            accountB: accountB,
            conversationAccountIsolation: false,
            conversationGenerationContinuity: false,
            memoirAccountIsolation: false,
            memoryAccountIsolation: false,
            mapPresentationAccountIsolation: false,
            privatePhotoAccountIsolation: false,
            staleLeaseRejected: false,
            legacyGlobalConversationQuarantined: false,
            legacyHomeMediaRetired: false,
            reservedFallbackOwnerRejected: false,
            legacyReceiptCount: 0,
            failureReason: reason
        )
    }
}

private enum ProductV4GlobalPrivateStoreUIQASmokeError: Error {
    case invalidScope
}

private final class ProductV4UIQAMutableLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
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

private final class GlobalPrivateStoreRetirementUIQAViewController: UIViewController {
    private let result: GlobalPrivateStoreRetirementUIQAResult

    init(result: GlobalPrivateStoreRetirementUIQAResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .warmBackground

        let titleLabel = UILabel()
        titleLabel.text = "V4 本地私有存储隔离"
        titleLabel.font = .systemFont(ofSize: 25, weight: .bold)
        titleLabel.textColor = TGColors.textPrimary

        let statusLabel = UILabel()
        statusLabel.text = result.completed ? "G1 UIQA 通过" : "G1 UIQA 失败"
        statusLabel.font = .systemFont(ofSize: 21, weight: .semibold)
        statusLabel.textColor = result.completed ? .systemGreen : .systemRed

        let detailLabel = UILabel()
        detailLabel.numberOfLines = 0
        detailLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        detailLabel.textColor = TGColors.textSecondary
        detailLabel.text = [
            "Conversation A/B: \(mark(result.conversationAccountIsolation))",
            "Memoir A/B: \(mark(result.memoirAccountIsolation))",
            "Memory/Map A/B: \(mark(result.memoryAccountIsolation && result.mapPresentationAccountIsolation))",
            "Home photo A/B: \(mark(result.privatePhotoAccountIsolation))",
            "Stale lease: \(mark(result.staleLeaseRejected))",
            "Legacy receipts: \(result.legacyReceiptCount)",
            "Reserved writer: \(mark(result.reservedFallbackOwnerRejected))",
        ].joined(separator: "\n")

        let stack = UIStackView(arrangedSubviews: [titleLabel, statusLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func mark(_ passed: Bool) -> String {
        passed ? "PASS" : "FAIL"
    }
}
#endif
