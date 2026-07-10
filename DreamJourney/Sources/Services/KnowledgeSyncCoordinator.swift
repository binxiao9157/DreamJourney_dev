import Foundation

/// 串行协调本地 KBLite 与后端 revision/change-feed，避免 UI 层各自触发网络同步。
final class KnowledgeSyncCoordinator {
    static let shared = KnowledgeSyncCoordinator()

    private let queue = DispatchQueue(label: "com.dreamjourney.knowledge-sync", qos: .utility)
    private let baseStore = KnowledgeRemoteBaseStore()
    private let pendingStore = KnowledgePendingMutationStore()
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
        let revision = loadBase(for: userId)?.revision ?? 0
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
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary() else {
            return false
        }
        let changes = object["changes"] as? [[String: Any]] ?? []
        let currentRevision = Self.intValue(object["currentRevision"])
        guard currentRevision >= 0 else { return false }
        let existingBase = loadBase(for: userId)

        guard let latestChange = changes.max(by: {
            Self.intValue($0["revision"]) < Self.intValue($1["revision"])
        }) else {
            if let existingBase {
                // An empty feed can only be authoritative when the revision is unchanged.
                return currentRevision == existingBase.revision
            }
            guard currentRevision == 0 else { return false }
            let remote = Self.emptyRemoteGraph(localMetadata: localGraph)
            return applyAuthoritativeRemote(
                KnowledgeRemoteBaseSnapshot(revision: 0, graph: remote),
                previousBase: nil,
                userId: userId
            )
        }

        guard Self.intValue(latestChange["revision"]) == currentRevision,
              let remoteGraph = latestChange["graph"] as? [String: Any],
              Self.hasValidChangeMetadata(latestChange) else {
            return false
        }
        return applyAuthoritativeRemote(
            KnowledgeRemoteBaseSnapshot(revision: currentRevision, graph: remoteGraph),
            previousBase: existingBase,
            userId: userId
        )
    }

    private func applyAuthoritativeRemote(
        _ remote: KnowledgeRemoteBaseSnapshot,
        previousBase: KnowledgeRemoteBaseSnapshot?,
        userId: String
    ) -> Bool {
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary() else {
            return false
        }
        do {
            let result: KnowledgeSyncMergeResult
            if let previousBase {
                result = try KnowledgeSyncGraphEngine.merge(
                    base: previousBase.graph,
                    local: localGraph,
                    remote: remote.graph
                )
            } else {
                result = try KnowledgeSyncGraphEngine.bootstrap(
                    local: localGraph,
                    remote: remote.graph
                )
            }
            guard KBLiteManager.shared.applySyncedGraph(
                result.graph,
                preservingLocalChanges: false
            ), KBLiteManager.shared.loadedUserId == userId else {
                return false
            }
            try baseStore.save(remote, for: userId)
            try? pendingStore.remove(for: userId)
            if !result.conflicts.isEmpty {
                // Do not log entity content. This summary is QA-only type/ID evidence.
                print("[KnowledgeSync] threeWayConflicts \(result.qaConflictSummary)")
            }
            return true
        } catch {
            print("[KnowledgeSync] authoritativeMergeFailed user=\(userId) error=\(error.localizedDescription)")
            return false
        }
    }

    private func pushLocalGraph(userId: String, generation: UUID, retryOnConflict: Bool) {
        guard isCurrent(userId: userId, generation: generation),
              KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary(),
              let base = loadBase(for: userId) else {
            finishSync(userId: userId, generation: generation, error: KnowledgeSyncError.missingRemoteBase)
            return
        }

        let pending: KnowledgePendingMutation
        do {
            let syncableGraph = try KnowledgeSyncGraphEngine.syncPayloadGraph(from: localGraph)
            guard let fingerprint = KnowledgeSyncGraphEngine.fingerprint(of: syncableGraph) else {
                throw KnowledgeSyncError.invalidLocalGraph
            }
            if let stored = loadPending(for: userId),
               stored.baseRevision == base.revision,
               stored.localFingerprint == fingerprint,
               Self.mutationComponents(from: stored.payload) != nil {
                pending = stored
            } else {
                let deletedAt = Self.isoTimestamp(Date())
                let delta = try KnowledgeSyncGraphEngine.makeDelta(
                    base: base.graph,
                    local: localGraph,
                    deletedAt: deletedAt
                )
                if delta.isEmpty {
                    try? pendingStore.remove(for: userId)
                    finishSync(userId: userId, generation: generation, error: nil)
                    return
                }
                var payload = delta.jsonObject
                payload["mutationSchemaVersion"] = 2
                let created = KnowledgePendingMutation(
                    operationId: "ios-v2-\(UUID().uuidString.lowercased())",
                    baseRevision: base.revision,
                    localFingerprint: fingerprint,
                    deletedAt: deletedAt,
                    payload: payload
                )
                try pendingStore.save(created, for: userId)
                pending = created
            }
        } catch {
            finishSync(userId: userId, generation: generation, error: error)
            return
        }

        guard let components = Self.mutationComponents(from: pending.payload) else {
            finishSync(userId: userId, generation: generation, error: KnowledgeSyncError.invalidPendingMutation)
            return
        }
        DreamJourneyBackendClient.shared.mutateKnowledgeV2(
            userId: userId,
            upserts: components.upserts,
            tombstones: components.tombstones,
            operationId: pending.operationId,
            baseRevision: pending.baseRevision
        ) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    guard let snapshot = KnowledgeMutationV2Contract.authoritativeSnapshot(from: object),
                          self.applyAuthoritativeRemote(
                              snapshot,
                              previousBase: base,
                              userId: userId
                          ) else {
                        self.finishSync(
                            userId: userId,
                            generation: generation,
                            error: KnowledgeSyncError.invalidMutationResponse
                        )
                        return
                    }
                    self.finishSync(userId: userId, generation: generation, error: nil)
                case .failure(let error):
                    if retryOnConflict, Self.isRevisionConflict(error) {
                        self.refreshAfterConflict(userId: userId, generation: generation)
                    } else if Self.shouldFallbackV2(error) {
                        self.pushLegacyMutation(
                            userId: userId,
                            generation: generation,
                            retryOnConflict: retryOnConflict
                        )
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

    private func pushLegacyMutation(
        userId: String,
        generation: UUID,
        retryOnConflict: Bool
    ) {
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary() else {
            finishSync(userId: userId, generation: generation, error: KnowledgeSyncError.invalidLocalGraph)
            return
        }
        let graph: [String: Any]
        do {
            graph = try KnowledgeSyncGraphEngine.syncPayloadGraph(from: localGraph)
        } catch {
            finishSync(userId: userId, generation: generation, error: error)
            return
        }
        let baseRevision = loadBase(for: userId)?.revision ?? 0
        let operationId = loadPending(for: userId)?.operationId
            ?? "ios-v1-\(UUID().uuidString.lowercased())"
        DreamJourneyBackendClient.shared.mutateKnowledge(
            userId: userId,
            graph: graph,
            operationId: operationId,
            baseRevision: baseRevision
        ) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    let revision = Self.intValue(object["revision"])
                    guard self.saveLegacyBase(graph: graph, revision: revision, userId: userId) else {
                        self.finishSync(userId: userId, generation: generation, error: KnowledgeSyncError.basePersistenceFailed)
                        return
                    }
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

    private func pushLegacySnapshot(userId: String, generation: UUID) {
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary() else {
            finishSync(userId: userId, generation: generation, error: KnowledgeSyncError.invalidLocalGraph)
            return
        }
        let graph: [String: Any]
        do {
            graph = try KnowledgeSyncGraphEngine.syncPayloadGraph(from: localGraph)
        } catch {
            finishSync(userId: userId, generation: generation, error: error)
            return
        }
        DreamJourneyBackendClient.shared.syncKnowledge(userId: userId, graph: graph) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(userId: userId, generation: generation) else { return }
                switch result {
                case .success(let object):
                    let revision = Self.intValue(object["revision"])
                    guard self.saveLegacyBase(graph: graph, revision: revision, userId: userId) else {
                        self.finishSync(userId: userId, generation: generation, error: KnowledgeSyncError.basePersistenceFailed)
                        return
                    }
                    self.finishSync(userId: userId, generation: generation, error: nil)
                case .failure(let error):
                    self.finishSync(userId: userId, generation: generation, error: error)
                }
            }
        }
    }

    private func saveLegacyBase(graph: [String: Any], revision: Int, userId: String) -> Bool {
        do {
            try baseStore.save(
                KnowledgeRemoteBaseSnapshot(revision: max(0, revision), graph: graph),
                for: userId
            )
            try? pendingStore.remove(for: userId)
            return true
        } catch {
            print("[KnowledgeSync] legacyBaseSaveFailed user=\(userId) error=\(error.localizedDescription)")
            return false
        }
    }

    private func finishSync(userId: String, generation: UUID, error: Error?) {
        guard isCurrent(userId: userId, generation: generation) else { return }
        isSyncing = false
        if let error {
            print("[KnowledgeSync] failed user=\(userId) error=\(error.localizedDescription)")
        } else {
            print("[KnowledgeSync] completed user=\(userId) revision=\(loadBase(for: userId)?.revision ?? 0)")
        }
        if needsResync {
            needsResync = false
            enqueueSync(reason: "coalescedUpdate")
        }
    }

    private func isCurrent(userId: String, generation: UUID) -> Bool {
        activeUserId == userId && syncGeneration == generation
    }

    private func loadBase(for userId: String) -> KnowledgeRemoteBaseSnapshot? {
        do {
            return try baseStore.load(for: userId)
        } catch {
            print("[KnowledgeSync] invalidBaseRemoved user=\(userId) error=\(error.localizedDescription)")
            try? baseStore.remove(for: userId)
            try? pendingStore.remove(for: userId)
            return nil
        }
    }

    private func loadPending(for userId: String) -> KnowledgePendingMutation? {
        do {
            return try pendingStore.load(for: userId)
        } catch {
            print("[KnowledgeSync] invalidPendingRemoved user=\(userId) error=\(error.localizedDescription)")
            try? pendingStore.remove(for: userId)
            return nil
        }
    }

    private static func mutationComponents(
        from payload: [String: Any]
    ) -> (upserts: [String: [[String: Any]]], tombstones: [[String: Any]])? {
        guard intValue(payload["mutationSchemaVersion"]) == 2,
              let rawUpserts = payload["upserts"] as? [String: Any],
              let tombstones = payload["tombstones"] as? [[String: Any]] else {
            return nil
        }
        var upserts: [String: [[String: Any]]] = [:]
        for entityType in KnowledgeSyncGraphEngine.entityTypes {
            guard let values = rawUpserts[entityType] as? [[String: Any]] else { return nil }
            upserts[entityType] = values
        }
        return (upserts, tombstones)
    }

    private static func hasValidChangeMetadata(_ change: [String: Any]) -> Bool {
        guard let rawVersion = change["mutationSchemaVersion"] else { return true }
        let version = intValue(rawVersion)
        if version == 1 { return true }
        return version == 2 && change["mutation"] is [String: Any]
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? -1 }
        return -1
    }

    private static func emptyRemoteGraph(localMetadata: [String: Any]) -> [String: Any] {
        [
            "version": max(1, intValue(localMetadata["version"])),
            "lastUpdated": localMetadata["lastUpdated"] ?? isoTimestamp(Date()),
            "sessionCount": 0,
            "people": [],
            "places": [],
            "events": [],
            "facts": [],
        ]
    }

    private static func isoTimestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func shouldFallbackV2(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, let detail) = clientError else {
            return false
        }
        return KnowledgeMutationV2FallbackPolicy.shouldFallback(
            statusCode: statusCode,
            detail: detail
        )
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
    case invalidLocalGraph
    case missingRemoteBase
    case invalidPendingMutation
    case invalidMutationResponse
    case basePersistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalidChangeFeed:
            return "知识增量响应无法安全应用"
        case .invalidLocalGraph:
            return "本地知识图谱无法安全同步"
        case .missingRemoteBase:
            return "知识远端基线尚未建立"
        case .invalidPendingMutation:
            return "待重试的知识变更合同无效"
        case .invalidMutationResponse:
            return "知识 V2 变更响应缺少权威图谱"
        case .basePersistenceFailed:
            return "知识远端基线无法持久化"
        }
    }
}
