import Foundation

#if canImport(WidgetKit)
import WidgetKit
#endif

final class KnowledgeWidgetSnapshotStore {
    static let activeOwnerDigestKey = "DreamJourneyKnowledgeWidgetActiveOwnerDigestV2"
    static let snapshotFileName = "kb_widget_snapshot_v2.json"
    static let widgetKind = "TodayInHistory"

    static let shared = KnowledgeWidgetSnapshotStore(
        containerURLProvider: {
            FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: configuredAppGroupIdentifier
            )
        },
        sharedDefaultsProvider: {
            UserDefaults(suiteName: configuredAppGroupIdentifier)
        },
        timelineReloader: {
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
            #endif
        }
    )

    private static var configuredAppGroupIdentifier: String {
        let configured = Bundle.main.object(
            forInfoDictionaryKey: "DreamJourneyAppGroupIdentifier"
        ) as? String
        let normalized = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? "group.com.dreamjourney.shared" : normalized
    }

    private let queue = DispatchQueue(label: "com.dreamjourney.knowledge-widget-snapshot")
    private let containerURLProvider: () -> URL?
    private let sharedDefaultsProvider: () -> UserDefaults?
    private let timelineReloader: () -> Void
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private var activeOwnerDigest: String?
    private var activeGeneration = UUID()
    private var activeAccountLease: AccountLease?

    init(
        containerURLProvider: @escaping () -> URL?,
        sharedDefaultsProvider: @escaping () -> UserDefaults?,
        timelineReloader: @escaping () -> Void,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.containerURLProvider = containerURLProvider
        self.sharedDefaultsProvider = sharedDefaultsProvider
        self.timelineReloader = timelineReloader
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func activate(ownerUserId: String?, generation: UUID) {
        let capturedLease = accountLeaseRuntime.capture(forSubjectId: ownerUserId)
        queue.sync {
            let digest = ownerUserId.flatMap(KnowledgeWidgetPrivacyPolicy.ownerDigest(for:))
            activeOwnerDigest = digest
            activeGeneration = generation
            activeAccountLease = capturedLease

            if let defaults = sharedDefaultsProvider() {
                if let digest {
                    defaults.set(digest, forKey: Self.activeOwnerDigestKey)
                } else {
                    defaults.removeObject(forKey: Self.activeOwnerDigestKey)
                }
            } else {
                activeOwnerDigest = nil
            }

            removeSnapshotIfPresent()
            timelineReloader()
        }
    }

    @discardableResult
    func publish(
        graph: KBLiteGraph,
        ownerUserId: String,
        generation: UUID
    ) -> Bool {
        queue.sync {
            guard generation == activeGeneration,
                  let expectedOwnerDigest = KnowledgeWidgetPrivacyPolicy.ownerDigest(for: ownerUserId),
                  expectedOwnerDigest == activeOwnerDigest,
                  sharedDefaultsProvider()?.string(forKey: Self.activeOwnerDigestKey) == expectedOwnerDigest,
                  let containerURL = containerURLProvider(),
                  let accountLease = validatedAccountLease(
                    ownerUserId: ownerUserId,
                    at: .commit
                  ),
                  let snapshot = KnowledgeWidgetPrivacyPolicy.snapshot(
                    graph: graph,
                    ownerUserId: ownerUserId
                  ) else {
                return false
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(snapshot)
                let fileURL = containerURL.appendingPathComponent(Self.snapshotFileName)
                let stagingURL = containerURL.appendingPathComponent(
                    ".\(Self.snapshotFileName).\(UUID().uuidString).staging"
                )
                defer { try? FileManager.default.removeItem(at: stagingURL) }
                try data.write(to: stagingURL, options: .atomic)
                try protectSnapshot(at: stagingURL)
                guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else {
                    revokeSnapshotForInvalidLease(containerURL: containerURL)
                    return false
                }
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: stagingURL)
                } else {
                    try FileManager.default.moveItem(at: stagingURL, to: fileURL)
                }
                guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
                      accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                    revokeSnapshotForInvalidLease(containerURL: containerURL)
                    return false
                }
                timelineReloader()
                return true
            } catch {
                removeSnapshotIfPresent(containerURL: containerURL)
                timelineReloader()
                print("[KBLite] Widget snapshot publish failed: \(error.localizedDescription)")
                return false
            }
        }
    }

    func invalidateSnapshot(ownerUserId: String, generation: UUID) {
        queue.sync {
            guard generation == activeGeneration,
                  KnowledgeWidgetPrivacyPolicy.ownerDigest(for: ownerUserId) == activeOwnerDigest else {
                return
            }
            if let accountLease = activeAccountLease {
                _ = accountLeaseRuntime.validate(accountLease, at: .commit)
            }
            removeSnapshotIfPresent()
            timelineReloader()
        }
    }

    var snapshotURLForTesting: URL {
        queue.sync {
            (containerURLProvider() ?? FileManager.default.temporaryDirectory)
                .appendingPathComponent(Self.snapshotFileName)
        }
    }

    private func removeSnapshotIfPresent(containerURL: URL? = nil) {
        guard let containerURL = containerURL ?? containerURLProvider() else { return }
        let fileURL = containerURL.appendingPathComponent(Self.snapshotFileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func validatedAccountLease(
        ownerUserId: String,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLease? {
        let lease = activeAccountLease
            ?? accountLeaseRuntime.capture(forSubjectId: ownerUserId)
        guard let lease,
              lease.subjectId == ownerUserId,
              accountLeaseRuntime.validate(lease, at: checkpoint).allowed else {
            revokeSnapshotForInvalidLease()
            return nil
        }
        activeAccountLease = lease
        return lease
    }

    private func revokeSnapshotForInvalidLease(containerURL: URL? = nil) {
        activeAccountLease = nil
        activeOwnerDigest = nil
        sharedDefaultsProvider()?.removeObject(forKey: Self.activeOwnerDigestKey)
        removeSnapshotIfPresent(containerURL: containerURL)
        timelineReloader()
    }

    private func protectSnapshot(at fileURL: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try mutableURL.setResourceValues(values)

        #if os(iOS) || os(tvOS) || os(watchOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: fileURL.path
        )
        #endif
    }
}
