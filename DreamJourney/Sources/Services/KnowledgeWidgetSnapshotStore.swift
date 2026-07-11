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
    private var activeOwnerDigest: String?
    private var activeGeneration = UUID()

    init(
        containerURLProvider: @escaping () -> URL?,
        sharedDefaultsProvider: @escaping () -> UserDefaults?,
        timelineReloader: @escaping () -> Void
    ) {
        self.containerURLProvider = containerURLProvider
        self.sharedDefaultsProvider = sharedDefaultsProvider
        self.timelineReloader = timelineReloader
    }

    func activate(ownerUserId: String?, generation: UUID) {
        queue.sync {
            let digest = ownerUserId.flatMap(KnowledgeWidgetPrivacyPolicy.ownerDigest(for:))
            activeOwnerDigest = digest
            activeGeneration = generation

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
                try data.write(to: fileURL, options: .atomic)
                try protectSnapshot(at: fileURL)
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
