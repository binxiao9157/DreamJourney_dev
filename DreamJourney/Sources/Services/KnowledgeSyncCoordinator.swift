import Foundation
import CryptoKit

/// 串行协调本地 KBLite 与后端 revision/change-feed，避免 UI 层各自触发网络同步。
final class KnowledgeSyncCoordinator {
    static let shared = KnowledgeSyncCoordinator()

    private let queue = DispatchQueue(label: "com.dreamjourney.knowledge-sync", qos: .utility)
    private let defaults = UserDefaults.standard
    private var activeUserId: String?
    private var syncGeneration = UUID()
    private var isSyncing = false
    private var needsResync = false
    private var debounceWorkItem: DispatchWorkItem?

    private init() {}

    func userDidChange(to userId: String?) {
        // 必须在 KBLite 切换图谱前同步失效旧 generation，避免已排队的旧用户回调
        // 通过检查后写入新用户文件。
        queue.sync {
            self.activeUserId = userId
            self.syncGeneration = UUID()
            self.isSyncing = false
            self.needsResync = false
            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = nil
        }
        guard userId != nil else { return }
        DispatchQueue.main.async {
            self.synchronizeCurrentUser(reason: "userChanged")
        }
    }

    func synchronizeCurrentUser(reason: String) {
        guard DreamJourneyBackendClient.shared.isKnowledgeSyncConfigured,
              let userId = UserManager.shared.currentUser?.id,
              BackendAuthSessionStore.shared.currentSession?.userId == userId else {
            print("[KnowledgeSync] skip reason=missingBackendOrUserSession trigger=\(reason)")
            return
        }
        queue.async {
            if self.activeUserId != userId {
                self.activeUserId = userId
                self.syncGeneration = UUID()
            }
            self.enqueueSync(reason: reason)
        }
    }

    private func enqueueSync(reason: String) {
        guard let userId = activeUserId else { return }
        if isSyncing {
            needsResync = true
            return
        }
        debounceWorkItem?.cancel()
        let generation = syncGeneration
        let workItem = DispatchWorkItem { [weak self] in
            self?.startSync(userId: userId, generation: generation, reason: reason)
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func startSync(userId: String, generation: UUID, reason: String) {
        guard isCurrent(userId: userId, generation: generation), !isSyncing else { return }
        isSyncing = true
        let revision = storedRevision(for: userId)
        print("[KnowledgeSync] start user=\(userId) revision=\(revision) reason=\(reason)")
        DreamJourneyBackendClient.shared.fetchKnowledgeChanges(
            userId: userId,
            sinceRevision: revision
        ) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    guard self.didApplyChanges(object, userId: userId) else {
                        self.finishSync(
                            userId: userId,
                            generation: generation,
                            error: KnowledgeSyncError.invalidChangeFeed
                        )
                        return
                    }
                    self.pushLocalGraph(userId: userId, generation: generation, retryOnConflict: true)
                case .failure(let error):
                    if Self.isUnsupportedEndpoint(error) {
                        self.pushLegacySnapshot(userId: userId, generation: generation)
                    } else {
                        self.finishSync(userId: userId, generation: generation, error: error)
                    }
                }
            }
        }
    }

    private func didApplyChanges(_ object: [String: Any], userId: String) -> Bool {
        guard KBLiteManager.shared.loadedUserId == userId else { return false }
        let changes = object["changes"] as? [[String: Any]] ?? []
        let currentRevision = Self.intValue(object["currentRevision"])
        guard currentRevision >= 0 else { return false }

        guard let latestChange = changes.max(by: {
            Self.intValue($0["revision"]) < Self.intValue($1["revision"])
        }) else {
            guard currentRevision <= storedRevision(for: userId) else { return false }
            storeRevision(currentRevision, for: userId)
            return true
        }

        guard Self.intValue(latestChange["revision"]) == currentRevision,
              let graph = latestChange["graph"] as? [String: Any],
              let localGraph = KBLiteManager.shared.exportGraphDictionary(),
              let localFingerprint = Self.graphFingerprint(localGraph) else {
            return false
        }
        let previousFingerprint = storedFingerprint(for: userId)
        let localHasKnowledge = Self.graphHasKnowledge(localGraph)
        let preserveLocalChanges = previousFingerprint.map { $0 != localFingerprint }
            ?? localHasKnowledge
        guard KBLiteManager.shared.applySyncedGraph(
            graph,
            preservingLocalChanges: preserveLocalChanges
        ), KBLiteManager.shared.loadedUserId == userId,
           let appliedGraph = KBLiteManager.shared.exportGraphDictionary(),
           let appliedFingerprint = Self.graphFingerprint(appliedGraph) else {
            return false
        }
        storeRevision(currentRevision, for: userId)
        if !preserveLocalChanges {
            markGraphSynced(userId: userId, fingerprint: appliedFingerprint)
        }
        return true
    }

    private func pushLocalGraph(userId: String, generation: UUID, retryOnConflict: Bool) {
        guard isCurrent(userId: userId, generation: generation),
              KBLiteManager.shared.loadedUserId == userId,
              let graph = KBLiteManager.shared.exportGraphDictionary(),
              let fingerprint = Self.graphFingerprint(graph) else {
            finishSync(userId: userId, generation: generation, error: nil)
            return
        }
        if storedFingerprint(for: userId) == fingerprint {
            finishSync(userId: userId, generation: generation, error: nil)
            return
        }
        let revision = storedRevision(for: userId)
        let operationId = pendingOperationId(for: userId, fingerprint: fingerprint)
        DreamJourneyBackendClient.shared.mutateKnowledge(
            userId: userId,
            graph: graph,
            operationId: operationId,
            baseRevision: revision
        ) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    self.storeRevision(Self.intValue(object["revision"]), for: userId)
                    self.markGraphSynced(userId: userId, fingerprint: fingerprint)
                    self.finishSync(userId: userId, generation: generation, error: nil)
                case .failure(let error):
                    if retryOnConflict, Self.isRevisionConflict(error) {
                        self.refreshAfterConflict(userId: userId, generation: generation)
                    } else if Self.isUnsupportedEndpoint(error) {
                        self.pushLegacySnapshot(userId: userId, generation: generation)
                    } else {
                        self.finishSync(userId: userId, generation: generation, error: error)
                    }
                }
            }
        }
    }

    private func refreshAfterConflict(userId: String, generation: UUID) {
        DreamJourneyBackendClient.shared.fetchKnowledgeChanges(userId: userId, sinceRevision: 0) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    guard self.didApplyChanges(object, userId: userId) else {
                        self.finishSync(
                            userId: userId,
                            generation: generation,
                            error: KnowledgeSyncError.invalidChangeFeed
                        )
                        return
                    }
                    self.pushLocalGraph(userId: userId, generation: generation, retryOnConflict: false)
                case .failure(let error):
                    self.finishSync(userId: userId, generation: generation, error: error)
                }
            }
        }
    }

    private func pushLegacySnapshot(userId: String, generation: UUID) {
        guard KBLiteManager.shared.loadedUserId == userId,
              let graph = KBLiteManager.shared.exportGraphDictionary(),
              let fingerprint = Self.graphFingerprint(graph) else {
            finishSync(userId: userId, generation: generation, error: nil)
            return
        }
        DreamJourneyBackendClient.shared.syncKnowledge(userId: userId, graph: graph) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    let revision = Self.intValue(object["revision"])
                    if revision > 0 { self.storeRevision(revision, for: userId) }
                    self.markGraphSynced(userId: userId, fingerprint: fingerprint)
                    self.finishSync(userId: userId, generation: generation, error: nil)
                case .failure(let error):
                    self.finishSync(userId: userId, generation: generation, error: error)
                }
            }
        }
    }

    private func finishSync(userId: String, generation: UUID, error: Error?) {
        guard isCurrent(userId: userId, generation: generation) else { return }
        isSyncing = false
        if let error {
            print("[KnowledgeSync] failed user=\(userId) error=\(error.localizedDescription)")
        } else {
            print("[KnowledgeSync] completed user=\(userId) revision=\(storedRevision(for: userId))")
        }
        if needsResync {
            needsResync = false
            enqueueSync(reason: "coalescedUpdate")
        }
    }

    private func isCurrent(userId: String, generation: UUID) -> Bool {
        activeUserId == userId && syncGeneration == generation
    }

    private func storedRevision(for userId: String) -> Int {
        defaults.integer(forKey: revisionKey(userId))
    }

    private func storeRevision(_ revision: Int, for userId: String) {
        defaults.set(max(0, revision), forKey: revisionKey(userId))
    }

    private func revisionKey(_ userId: String) -> String {
        "DreamJourney.KnowledgeSync.revision.\(userId)"
    }

    private func storedFingerprint(for userId: String) -> String? {
        defaults.string(forKey: fingerprintKey(userId))
    }

    private func pendingOperationId(for userId: String, fingerprint: String) -> String {
        if defaults.string(forKey: pendingFingerprintKey(userId)) == fingerprint,
           let operationId = defaults.string(forKey: pendingOperationKey(userId)),
           !operationId.isEmpty {
            return operationId
        }
        let operationId = "ios-\(UUID().uuidString.lowercased())"
        defaults.set(fingerprint, forKey: pendingFingerprintKey(userId))
        defaults.set(operationId, forKey: pendingOperationKey(userId))
        return operationId
    }

    private func markGraphSynced(userId: String, fingerprint: String) {
        defaults.set(fingerprint, forKey: fingerprintKey(userId))
        defaults.removeObject(forKey: pendingFingerprintKey(userId))
        defaults.removeObject(forKey: pendingOperationKey(userId))
    }

    private func fingerprintKey(_ userId: String) -> String {
        "DreamJourney.KnowledgeSync.fingerprint.\(userId)"
    }

    private func pendingFingerprintKey(_ userId: String) -> String {
        "DreamJourney.KnowledgeSync.pendingFingerprint.\(userId)"
    }

    private func pendingOperationKey(_ userId: String) -> String {
        "DreamJourney.KnowledgeSync.pendingOperation.\(userId)"
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }

    private static func graphFingerprint(_ graph: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(graph),
              let data = try? JSONSerialization.data(withJSONObject: graph, options: [.sortedKeys]) else {
            return nil
        }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func graphHasKnowledge(_ graph: [String: Any]) -> Bool {
        ["people", "places", "events", "facts"].contains { key in
            !(graph[key] as? [Any] ?? []).isEmpty
        }
    }

    private static func isUnsupportedEndpoint(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, _) = clientError else {
            return false
        }
        return statusCode == 404 || statusCode == 405
    }

    private static func isRevisionConflict(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, let detail) = clientError else {
            return false
        }
        return statusCode == 409 && detail.contains("knowledgeRevisionConflict")
    }
}

private enum KnowledgeSyncError: LocalizedError {
    case invalidChangeFeed

    var errorDescription: String? {
        switch self {
        case .invalidChangeFeed:
            return "知识增量响应无法安全应用"
        }
    }
}
