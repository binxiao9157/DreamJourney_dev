import Foundation

struct KBLiteGraphSnapshot {
    let dictionary: [String: Any]
    let mutationToken: UInt64
    let userId: String
}

enum KBLiteSyncedGraphApplyResult: Equatable {
    case applied
    case staleLocalMutation
    case invalidGraph
}

private struct KBLiteAccountLeaseScope {
    let accountLease: AccountLease
    let ownerUserId: String
    let graphGeneration: UUID
}

private struct KBLiteStagedGraph {
    let fileURL: URL
    let stagingURL: URL
    let previousData: Data?
    let mutationToken: UInt64
}

private enum KBLitePersistenceCommitResult {
    case committed
    case staleLease
    case staleMutation
    case storageFailure
}

// MARK: - KBLiteManager

/// Lite 版知识库中央管理器 — 单例
///
/// 职责：
/// 1. JSON 持久化（kb_graph.json）
/// 2. 后端优先知识提取（本地规则作为离线降级）
/// 3. 实体合并去重
/// 4. 关键词检索
/// 5. 组装上下文文本（供 system_prompt 注入）
final class KBLiteManager {

    // MARK: - Singleton

    static let shared = KBLiteManager()

    private let accountLeaseRuntime: AccountLeaseRuntimePort

    private init(accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared) {
        self.accountLeaseRuntime = accountLeaseRuntime
        loadedUserId = Self.normalizedUserId(UserManager.shared.currentUser?.id)
        graph = loadGraph(for: loadedUserId)
        let semanticScope = semanticCacheScopeLocked()
        KBLiteSemanticSearch.shared.activate(scope: semanticScope)
        let activeOwner = loadedUserId == Self.signedOutUserId ? nil : loadedUserId
        widgetSnapshotStore.activate(ownerUserId: activeOwner, generation: userGeneration)
        if let activeOwner,
           let accountScope = captureAccountLeaseScope(expectedOwnerUserId: activeOwner),
           validateAccountLeaseScope(accountScope, at: .runtime) {
            widgetSnapshotStore.publish(
                graph: graph,
                ownerUserId: activeOwner,
                generation: userGeneration
            )
            warmSemanticCache(
                for: graph,
                scope: semanticScope,
                accountScope: accountScope
            )
        }
    }

    // MARK: - Constants

    /// 每类实体数量上限（超出后不再新增，防止 JSON 文件膨胀）
    private let maxPeople = 200
    private let maxPlaces = 100
    private let maxEvents = 100
    private let maxFacts = 500

    // MARK: - Properties

    /// 内存中的知识图谱
    private(set) var graph = KBLiteGraph()

    /// 当前内存图谱所属用户。登出态使用独立占位值，绝不沿用上一用户图谱。
    private(set) var loadedUserId = KBLiteManager.signedOutUserId

    /// 用户切换代次，用于丢弃旧用户尚未返回的异步提取结果。
    private var userGeneration = UUID()

    /// 当前角色及其代次。异步提取只能比较这份锁内状态，不能在后台重读 FamilyRepository。
    private var activePersonaIdentity: KBPersonaIdentity?
    private var personaGeneration = UUID()
    private var familyAuthorizationGeneration: UUID?

    /// 只向 Widget 发布当前账号明确授权的最小知识摘要。
    private let widgetSnapshotStore = KnowledgeWidgetSnapshotStore.shared

    /// 读写锁，保护 graph 的并发访问
    private let graphLock = NSLock()

    /// 是否正在进行提取（避免并发）
    private var isExtracting = false

    /// 提取队列（串行）
    private let extractQueue = DispatchQueue(label: "com.dreamjourney.kblite.extract")

    /// 是否已输出过容量警告
    private var didWarnCapacity = false

    // MARK: - Thread-Safe Graph Access

    /// 线程安全地读取 graph
    func readGraph<T>(_ block: (KBLiteGraph) -> T) -> T {
        graphLock.lock()
        defer { graphLock.unlock() }
        return block(graph)
    }

    /// 线程安全地修改 graph（修改后自动保存并发送通知）
    func writeGraph(_ block: (inout KBLiteGraph) -> Void) {
        guard let accountScope = captureAccountLeaseScope(at: .request) else { return }
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graphLock.unlock()
            return
        }
        let rollbackGraph = graph
        block(&graph)
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graph = rollbackGraph
            graphLock.unlock()
            return
        }
        graphLock.unlock()
        save(accountScope: accountScope, rollbackGraph: rollbackGraph)
    }

    // MARK: - File Path

    private static let signedOutUserId = "signed-out"

    private static func normalizedUserId(_ userId: String?) -> String {
        let value = userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? signedOutUserId : value
    }

    private func captureAccountLeaseScope(
        expectedOwnerUserId: String? = nil,
        at checkpoint: AccountLeaseCheckpoint = .request
    ) -> KBLiteAccountLeaseScope? {
        graphLock.lock()
        let ownerUserId = loadedUserId
        let graphGeneration = userGeneration
        let normalizedExpectedOwner = expectedOwnerUserId.map(Self.normalizedUserId)
        let expectedOwnerMatches = normalizedExpectedOwner == nil || normalizedExpectedOwner == ownerUserId
        graphLock.unlock()

        guard ownerUserId != Self.signedOutUserId,
              expectedOwnerMatches,
              let accountLease = accountLeaseRuntime.capture(forSubjectId: ownerUserId) else {
            logAccountLeaseDrop(checkpoint: checkpoint, reason: "leaseUnavailable")
            return nil
        }
        let scope = KBLiteAccountLeaseScope(
            accountLease: accountLease,
            ownerUserId: ownerUserId,
            graphGeneration: graphGeneration
        )
        return validateAccountLeaseScope(scope, at: checkpoint) ? scope : nil
    }

    private func validateAccountLeaseScope(
        _ scope: KBLiteAccountLeaseScope,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        let decision = accountLeaseRuntime.validate(scope.accountLease, at: checkpoint)
        guard decision.allowed else {
            logAccountLeaseDrop(checkpoint: checkpoint, reason: decision.reason.rawValue)
            return false
        }
        graphLock.lock()
        let graphMatches = accountLeaseScopeMatchesGraphLocked(scope)
        graphLock.unlock()
        guard graphMatches else {
            logAccountLeaseDrop(checkpoint: checkpoint, reason: "graphGenerationMismatch")
            return false
        }
        return true
    }

    private func accountLeaseScopeMatchesGraphLocked(_ scope: KBLiteAccountLeaseScope) -> Bool {
        loadedUserId == scope.ownerUserId && userGeneration == scope.graphGeneration
    }

    private func validateAccountLeaseScopeLocked(
        _ scope: KBLiteAccountLeaseScope,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        let decision = accountLeaseRuntime.validate(scope.accountLease, at: checkpoint)
        guard decision.allowed, accountLeaseScopeMatchesGraphLocked(scope) else {
            let reason = decision.allowed ? "graphGenerationMismatch" : decision.reason.rawValue
            logAccountLeaseDrop(checkpoint: checkpoint, reason: reason)
            return false
        }
        return true
    }

    private func logAccountLeaseDrop(checkpoint: AccountLeaseCheckpoint, reason: String) {
        print("[KBLite] AccountLease drop checkpoint=\(checkpoint.rawValue) reason=\(reason)")
    }

    static func resolvePersonaIdentity(for context: DigitalHumanContext) -> KBPersonaIdentity {
        if let authorizedIdentity = resolveAuthorizedPersonaIdentity(for: context) {
            return authorizedIdentity
        }
        let viewerUserId = UserManager.shared.currentUser?.id ?? context.viewerUserId ?? context.ownerId
        return KBPersonaIdentity(
            ownerUserId: viewerUserId,
            personaScope: "personal",
            digitalHumanId: viewerUserId
        )
    }

    static func resolveAuthorizedPersonaIdentity(for context: DigitalHumanContext) -> KBPersonaIdentity? {
        let viewerUserId = UserManager.shared.currentUser?.id ?? context.viewerUserId
        let normalizedViewer = viewerUserId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedOwner = context.ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedViewer.isEmpty, !normalizedOwner.isEmpty else { return nil }

        if context.isSelfAssistant || normalizedOwner == normalizedViewer {
            return KBPersonaIdentityResolver.resolve(
                viewerUserId: normalizedViewer,
                ownerId: normalizedOwner,
                relation: context.relation,
                isSelfAssistant: true,
                familyMemberDigitalHumanId: nil
            )
        }

        guard let acceptedMember = FamilyRepository.shared.acceptedMember(by: normalizedOwner) else {
            return nil
        }
        return KBPersonaIdentityResolver.resolve(
            viewerUserId: normalizedViewer,
            ownerId: acceptedMember.id,
            relation: acceptedMember.relation,
            isSelfAssistant: false,
            familyMemberDigitalHumanId: acceptedMember.digitalHumanId
        )
    }

    static func resolveCurrentPersonaIdentity() -> KBPersonaIdentity {
        resolvePersonaIdentity(for: DigitalHumanContextStore.shared.current)
    }

    /// 必须在主线程捕获：FamilyRepository 与持久化角色均为主线程状态。
    static func captureCurrentPersonaAuthorizationSnapshot() -> KBPersonaAuthorizationSnapshot? {
        guard Thread.isMainThread,
              let identity = resolveAuthorizedPersonaIdentity(for: DigitalHumanContextStore.shared.current) else {
            return nil
        }
        let familyGeneration = identity.isPersonal
            ? nil
            : FamilyRepository.shared.authorizationGeneration(for: identity.ownerUserId)
        return shared.captureAuthorizationSnapshot(
            identity: identity,
            familyAuthorizationGeneration: familyGeneration
        )
    }

    func personaContextDidChange(to identity: KBPersonaIdentity?) {
        graphLock.lock()
        defer { graphLock.unlock() }
        let authorizedIdentity = identity?.ownerUserId == loadedUserId ? identity : nil
        guard activePersonaIdentity != authorizedIdentity else { return }
        activePersonaIdentity = authorizedIdentity
        personaGeneration = UUID()
    }

    func familyAuthorizationGenerationDidChange(ownerUserId: String, generation: UUID?) {
        let normalizedOwner = Self.normalizedUserId(ownerUserId)
        graphLock.lock()
        defer { graphLock.unlock() }
        guard normalizedOwner == loadedUserId else { return }
        familyAuthorizationGeneration = generation
    }

    private func captureAuthorizationSnapshot(
        identity: KBPersonaIdentity,
        familyAuthorizationGeneration: UUID?
    ) -> KBPersonaAuthorizationSnapshot? {
        graphLock.lock()
        defer { graphLock.unlock() }
        guard loadedUserId != Self.signedOutUserId,
              identity.ownerUserId == loadedUserId else {
            return nil
        }
        if activePersonaIdentity != identity {
            activePersonaIdentity = identity
            personaGeneration = UUID()
        }
        if !identity.isPersonal {
            self.familyAuthorizationGeneration = familyAuthorizationGeneration
        }
        let snapshot = KBPersonaAuthorizationSnapshot(
            identity: identity,
            userGeneration: userGeneration,
            personaGeneration: personaGeneration,
            familyAuthorizationGeneration: identity.isPersonal ? nil : familyAuthorizationGeneration
        )
        return snapshot.isComplete ? snapshot : nil
    }

    private func isCurrentAuthorizationSnapshotLocked(_ snapshot: KBPersonaAuthorizationSnapshot) -> Bool {
        loadedUserId == snapshot.identity.ownerUserId
            && KBPersonaAuthorizationSnapshotPolicy.isCurrent(
                snapshot,
                currentIdentity: activePersonaIdentity,
                userGeneration: userGeneration,
                personaGeneration: personaGeneration,
                familyAuthorizationGeneration: familyAuthorizationGeneration
            )
    }

    private func graphFilePath(for userId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let kbDir = docs.appendingPathComponent("knowledge_base")
        try? KnowledgeLocalStoragePolicy.prepareDirectory(at: kbDir)
        let userFile = kbDir.appendingPathComponent("kb_graph_\(userId).json")

        // 旧文件没有 owner/persona/evidence 证明，不能自动归给下一位登录用户。
        let legacyFile = kbDir.appendingPathComponent("kb_graph.json")
        if userId != Self.signedOutUserId &&
            FileManager.default.fileExists(atPath: legacyFile.path) {
            let preferredQuarantine = kbDir.appendingPathComponent("kb_graph_legacy_quarantine.json")
            let quarantineFile = FileManager.default.fileExists(atPath: preferredQuarantine.path)
                ? kbDir.appendingPathComponent("kb_graph_legacy_quarantine_\(UUID().uuidString).json")
                : preferredQuarantine
            do {
                try FileManager.default.moveItem(at: legacyFile, to: quarantineFile)
                try? KnowledgeLocalStoragePolicy.hardenExistingItem(at: quarantineFile)
                print("[KBLite] 已隔离无 owner 证明的旧知识库: \(quarantineFile.lastPathComponent)")
            } catch {
                print("[KBLite] 旧知识库隔离失败: \(error.localizedDescription)")
            }
        }

        return userFile
    }

    // MARK: - Persistence

    @discardableResult
    private func save(
        accountScope: KBLiteAccountLeaseScope,
        rollbackGraph: KBLiteGraph? = nil
    ) -> Bool {
        guard validateAccountLeaseScope(accountScope, at: .commit) else {
            rollbackInMemoryGraphIfCurrent(
                accountScope: accountScope,
                expectedMutationToken: nil,
                rollbackGraph: rollbackGraph
            )
            return false
        }
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            if let rollbackGraph {
                graph = rollbackGraph
            }
            graphLock.unlock()
            return false
        }
        graph.lastUpdated = Date()
        let graphSnapshot = graph
        let userId = loadedUserId
        let generation = userGeneration
        let semanticScope = semanticCacheScopeLocked()
        graphLock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(graphSnapshot),
              let mutationToken = Self.graphMutationToken(for: graphSnapshot) else {
            print("[KBLite] ❌ JSON 编码失败")
            if validateAccountLeaseScope(accountScope, at: .runtime) {
                widgetSnapshotStore.invalidateSnapshot(ownerUserId: userId, generation: generation)
            }
            return false
        }

        let stagedGraph: KBLiteStagedGraph
        do {
            guard let staged = try stagePersistedGraph(
                data,
                mutationToken: mutationToken,
                accountScope: accountScope
            ) else {
                rollbackInMemoryGraphIfCurrent(
                    accountScope: accountScope,
                    expectedMutationToken: mutationToken,
                    rollbackGraph: rollbackGraph
                )
                return false
            }
            stagedGraph = staged
        } catch {
            print("[KBLite] ❌ 保存失败: \(error.localizedDescription)")
            if validateAccountLeaseScope(accountScope, at: .runtime) {
                widgetSnapshotStore.invalidateSnapshot(ownerUserId: userId, generation: generation)
            }
            return false
        }

        switch commitStagedGraph(
            stagedGraph,
            accountScope: accountScope,
            rollbackGraph: rollbackGraph
        ) {
        case .committed:
            print("[KBLite] 💾 知识库已保存: \(graphSnapshot.people.count)人, \(graphSnapshot.places.count)地, \(graphSnapshot.events.count)事, \(graphSnapshot.facts.count)实")
            publishGraphEffects(
                graph: graphSnapshot,
                ownerUserId: userId,
                generation: generation,
                semanticScope: semanticScope,
                accountScope: accountScope
            )
            return true
        case .staleLease:
            return false
        case .staleMutation:
            print("[KBLite] 跳过已被更新图谱取代的持久化提交")
            return false
        case .storageFailure:
            if validateAccountLeaseScope(accountScope, at: .runtime) {
                widgetSnapshotStore.invalidateSnapshot(ownerUserId: userId, generation: generation)
            }
            return false
        }
    }

    private func stagePersistedGraph(
        _ data: Data,
        mutationToken: UInt64,
        accountScope: KBLiteAccountLeaseScope
    ) throws -> KBLiteStagedGraph? {
        guard validateAccountLeaseScope(accountScope, at: .commit) else { return nil }
        let fileURL = graphFilePath(for: accountScope.ownerUserId)
        let stagingURL = fileURL.deletingLastPathComponent().appendingPathComponent(
            ".\(fileURL.lastPathComponent).\(UUID().uuidString).staging"
        )
        let previousData: Data?
        if FileManager.default.fileExists(atPath: fileURL.path) {
            previousData = try Data(contentsOf: fileURL)
        } else {
            previousData = nil
        }
        do {
            try KnowledgeLocalStoragePolicy.write(data, to: stagingURL)
        } catch {
            try? FileManager.default.removeItem(at: stagingURL)
            throw error
        }
        guard validateAccountLeaseScope(accountScope, at: .commit) else {
            try? FileManager.default.removeItem(at: stagingURL)
            return nil
        }
        return KBLiteStagedGraph(
            fileURL: fileURL,
            stagingURL: stagingURL,
            previousData: previousData,
            mutationToken: mutationToken
        )
    }

    private func commitStagedGraph(
        _ stagedGraph: KBLiteStagedGraph,
        accountScope: KBLiteAccountLeaseScope,
        rollbackGraph: KBLiteGraph?
    ) -> KBLitePersistenceCommitResult {
        defer { try? FileManager.default.removeItem(at: stagedGraph.stagingURL) }
        graphLock.lock()
        defer { graphLock.unlock() }

        guard accountLeaseScopeMatchesGraphLocked(accountScope),
              Self.graphMutationToken(for: graph) == stagedGraph.mutationToken else {
            return .staleMutation
        }
        let beforeCommit = accountLeaseRuntime.validate(accountScope.accountLease, at: .commit)
        guard beforeCommit.allowed else {
            logAccountLeaseDrop(checkpoint: .commit, reason: beforeCommit.reason.rawValue)
            if let rollbackGraph {
                graph = rollbackGraph
            }
            return .staleLease
        }

        do {
            if FileManager.default.fileExists(atPath: stagedGraph.fileURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    stagedGraph.fileURL,
                    withItemAt: stagedGraph.stagingURL
                )
            } else {
                try FileManager.default.moveItem(
                    at: stagedGraph.stagingURL,
                    to: stagedGraph.fileURL
                )
            }
            try? KnowledgeLocalStoragePolicy.hardenExistingItem(at: stagedGraph.fileURL)
        } catch {
            print("[KBLite] ❌ 保存失败: \(error.localizedDescription)")
            return .storageFailure
        }

        let afterCommit = accountLeaseRuntime.validate(accountScope.accountLease, at: .commit)
        guard afterCommit.allowed, accountLeaseScopeMatchesGraphLocked(accountScope) else {
            let reason = afterCommit.allowed ? "graphGenerationMismatch" : afterCommit.reason.rawValue
            logAccountLeaseDrop(checkpoint: .commit, reason: reason)
            restorePersistedGraph(stagedGraph)
            if let rollbackGraph {
                graph = rollbackGraph
            }
            return .staleLease
        }
        return .committed
    }

    private func restorePersistedGraph(_ stagedGraph: KBLiteStagedGraph) {
        do {
            if let previousData = stagedGraph.previousData {
                try KnowledgeLocalStoragePolicy.write(previousData, to: stagedGraph.fileURL)
            } else if FileManager.default.fileExists(atPath: stagedGraph.fileURL.path) {
                try FileManager.default.removeItem(at: stagedGraph.fileURL)
            }
        } catch {
            print("[KBLite] stale persistence rollback failed reason=storageFailure")
        }
    }

    private func rollbackInMemoryGraphIfCurrent(
        accountScope: KBLiteAccountLeaseScope,
        expectedMutationToken: UInt64?,
        rollbackGraph: KBLiteGraph?
    ) {
        guard let rollbackGraph else { return }
        graphLock.lock()
        defer { graphLock.unlock() }
        guard accountLeaseScopeMatchesGraphLocked(accountScope),
              expectedMutationToken == nil || Self.graphMutationToken(for: graph) == expectedMutationToken else {
            return
        }
        graph = rollbackGraph
    }

    private func publishGraphEffects(
        graph: KBLiteGraph,
        ownerUserId: String,
        generation: UUID,
        semanticScope: KBLiteSemanticCacheScope?,
        accountScope: KBLiteAccountLeaseScope
    ) {
        guard validateAccountLeaseScope(accountScope, at: .runtime) else { return }
        widgetSnapshotStore.publish(
            graph: graph,
            ownerUserId: ownerUserId,
            generation: generation
        )
        warmSemanticCache(
            for: graph,
            scope: semanticScope,
            accountScope: accountScope
        )
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateAccountLeaseScope(accountScope, at: .ui) else {
                return
            }
            NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
            KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: "graphSaved")
        }
    }

    private func loadGraph(for userId: String) -> KBLiteGraph {
        guard userId != Self.signedOutUserId else {
            return KBLiteGraph()
        }
        let filePath = graphFilePath(for: userId)
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("[KBLite] 📂 知识库文件不存在，使用空图谱")
            return KBLiteGraph()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            try? KnowledgeLocalStoragePolicy.hardenExistingItem(at: filePath)
            let data = try Data(contentsOf: filePath)
            let loaded = try decoder.decode(KBLiteGraph.self, from: data)
            print("[KBLite] 📂 已加载知识库: v\(loaded.version), \(loaded.people.count)人, \(loaded.places.count)地, \(loaded.events.count)事, \(loaded.facts.count)实, 共\(loaded.sessionCount)次会话")
            return loaded
        } catch {
            print("[KBLite] ⚠️ 知识库加载失败: \(error.localizedDescription)，使用空图谱")
            // 备份损坏文件
            let backupPath = filePath.appendingPathExtension("corrupted")
            try? FileManager.default.moveItem(at: filePath, to: backupPath)
            try? KnowledgeLocalStoragePolicy.hardenExistingItem(at: backupPath)
            print("[KBLite] 📦 已备份损坏文件到: \(backupPath.lastPathComponent)")
            return KBLiteGraph()
        }
    }

    private func semanticCacheScopeLocked() -> KBLiteSemanticCacheScope? {
        KBLiteSemanticCacheScope(ownerUserId: loadedUserId, generation: userGeneration)
    }

    private func isCurrentSemanticCacheScope(_ scope: KBLiteSemanticCacheScope) -> Bool {
        graphLock.lock()
        defer { graphLock.unlock() }
        return semanticCacheScopeLocked() == scope
    }

    private func warmSemanticCache(
        for graph: KBLiteGraph,
        scope semanticScope: KBLiteSemanticCacheScope?,
        accountScope: KBLiteAccountLeaseScope
    ) {
        guard let semanticScope else { return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self,
                  self.validateAccountLeaseScope(accountScope, at: .runtime) else {
                return
            }
            KBLiteSemanticSearch.shared.warmCache(
                scope: semanticScope,
                people: graph.people,
                places: graph.places,
                events: graph.events,
                facts: graph.facts
            )
            _ = self.validateAccountLeaseScope(accountScope, at: .runtime)
        }
    }

    /// 在进程内切换知识所有者；旧用户异步结果会因 generation 不匹配而被丢弃。
    func switchUser(to userId: String?) {
        let normalized = Self.normalizedUserId(userId)
        var loadedGraph: KBLiteGraph?
        var activatedGeneration: UUID?
        var semanticScope: KBLiteSemanticCacheScope?
        extractQueue.sync {
            graphLock.lock()
            defer { graphLock.unlock() }
            guard normalized != loadedUserId else { return }
            loadedUserId = normalized
            userGeneration = UUID()
            activePersonaIdentity = normalized == Self.signedOutUserId
                ? nil
                : KBPersonaIdentity(
                    ownerUserId: normalized,
                    personaScope: "personal",
                    digitalHumanId: normalized
                )
            personaGeneration = UUID()
            familyAuthorizationGeneration = nil
            activatedGeneration = userGeneration
            semanticScope = semanticCacheScopeLocked()
            graph = loadGraph(for: normalized)
            didWarnCapacity = false
            isExtracting = false
            loadedGraph = graph
            // Keep manager state and cache activation in the same serialized switch.
            KBLiteSemanticSearch.shared.activate(scope: semanticScope)
        }
        guard let loadedGraph, let activatedGeneration else { return }
        let activeOwner = normalized == Self.signedOutUserId ? nil : normalized
        widgetSnapshotStore.activate(
            ownerUserId: activeOwner,
            generation: activatedGeneration
        )
        if let activeOwner,
           let accountScope = captureAccountLeaseScope(expectedOwnerUserId: activeOwner),
           validateAccountLeaseScope(accountScope, at: .runtime) {
            widgetSnapshotStore.publish(
                graph: loadedGraph,
                ownerUserId: activeOwner,
                generation: activatedGeneration
            )
            warmSemanticCache(
                for: loadedGraph,
                scope: semanticScope,
                accountScope: accountScope
            )
            DispatchQueue.main.async { [weak self] in
                guard let self,
                      self.validateAccountLeaseScope(accountScope, at: .ui) else {
                    return
                }
                NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
            }
        } else if activeOwner == nil {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .kbLiteDidUpdate, object: nil)
            }
        }
        print("[KBLite] 已切换知识所有者: \(normalized)")
    }

    // MARK: - Public API: Stats

    /// 获取知识库统计
    var stats: String {
        "\(graph.people.count)人 · \(graph.places.count)地 · \(graph.events.count)事 · \(graph.facts.count)实 · 共\(graph.sessionCount)次会话"
    }

    /// 是否为空
    var isEmpty: Bool {
        graph.people.isEmpty && graph.places.isEmpty && graph.events.isEmpty && graph.facts.isEmpty
    }

    /// QA-only aggregate. It deliberately returns counts rather than source IDs or entity content.
    func sourceRefAuditCounts() -> KBKnowledgeSourceAuditCounts {
        readGraph { graph in
            var references: [KBSourceReference] = []
            references.append(contentsOf: graph.people.flatMap { $0.privacyMetadata?.sourceRefs ?? [] })
            references.append(contentsOf: graph.places.flatMap { $0.privacyMetadata?.sourceRefs ?? [] })
            references.append(contentsOf: graph.events.flatMap { $0.privacyMetadata?.sourceRefs ?? [] })
            references.append(contentsOf: graph.facts.flatMap { $0.privacyMetadata?.sourceRefs ?? [] })
            return KBKnowledgeSourceIdentityPolicy.audit(sourceReferences: references)
        }
    }

    // MARK: - Public API: Knowledge Extraction

    /// 从对话 transcript 提取知识（异步，不阻塞 UI）
    /// - Parameters:
    ///   - turns: 本轮对话记录
    ///   - sessionId: 会话序号
    ///   - completion: 提取完成后回调（主线程），参数为新增实体数
    func extractFromTranscript(
        turns: [ConversationTurn],
        sessionId: Int,
        identity: KBPersonaIdentity? = nil,
        authorizationSnapshot: KBPersonaAuthorizationSnapshot? = nil,
        completion: @escaping (Int) -> Void = { _ in }
    ) {
        guard !turns.isEmpty else {
            print("[KBLite] ⚠️ 空 transcript，跳过提取")
            completion(0)
            return
        }

        let capturedAuthorization = authorizationSnapshot
            ?? Self.captureCurrentPersonaAuthorizationSnapshot()
        guard let capturedAuthorization,
              capturedAuthorization.isComplete,
              identity == nil || identity == capturedAuthorization.identity else {
            print("[KBLite] 缺少当前角色授权快照，跳过知识提取")
            completion(0)
            return
        }
        let capturedIdentity = capturedAuthorization.identity

        graphLock.lock()
        let ownerUserId = loadedUserId
        let lastBackendExtractionSessionId = graph.lastBackendExtractionSessionId
        let lastBackendExtractionAt = graph.lastBackendExtractionAt
        let isCurrentAuthorization = isCurrentAuthorizationSnapshotLocked(capturedAuthorization)
        graphLock.unlock()

        guard ownerUserId != Self.signedOutUserId,
              isCurrentAuthorization,
              capturedIdentity.ownerUserId == ownerUserId else {
            print("[KBLite] 用户或角色授权已变化，跳过知识提取")
            completion(0)
            return
        }
        guard let accountScope = captureAccountLeaseScope(
            expectedOwnerUserId: ownerUserId,
            at: .request
        ) else {
            completion(0)
            return
        }

        // 后端精提取使用独立水位；本地轻量提取仍可推进总 sessionCount。
        let shouldForceExtract: Bool
        if let lastBackendExtractionSessionId, let lastBackendExtractionAt {
            shouldForceExtract = sessionId - lastBackendExtractionSessionId >= 3
                || Date().timeIntervalSince(lastBackendExtractionAt) > 86400
        } else {
            shouldForceExtract = true
        }

        guard shouldForceExtract else {
            print("[KBLite] ⏭️ 后端提取频率控制：会话#\(sessionId)使用本地轻量提取")
            extractQueue.async { [weak self] in
                guard let self,
                      self.validateAccountLeaseScope(accountScope, at: .runtime) else {
                    return
                }
                self.finishExtraction(
                    result: nil,
                    turns: turns,
                    sessionId: sessionId,
                    authorizationSnapshot: capturedAuthorization,
                    accountScope: accountScope,
                    fallbackReason: "frequencyControlled",
                    completion: completion
                )
            }
            return
        }

        extractQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.validateAccountLeaseScope(accountScope, at: .runtime) else { return }

            guard !self.isExtracting else {
                print("[KBLite] ⏳ 上一次提取尚未完成，跳过")
                self.deliverExtractionCompletion(
                    0,
                    accountScope: accountScope,
                    completion: completion
                )
                return
            }

            self.isExtracting = true
            print("[KBLite] 🔍 开始后端知识提取 (会话#\(sessionId), \(turns.count)轮)")

            // 旧后端只读取 transcript；兼容字段同样只携带用户证据，避免 assistant 回灌。
            let transcript = turns.filter { $0.role == "user" }.map { turn in
                "[长辈]: \(turn.text)"
            }.joined(separator: "\n")

            self.graphLock.lock()
            let existingSummary = self.buildExistingSummary(for: capturedIdentity)
            self.graphLock.unlock()
            guard self.validateAccountLeaseScope(accountScope, at: .request) else {
                self.isExtracting = false
                return
            }

            guard DreamJourneyBackendClient.shared.isKnowledgeSyncConfigured else {
                self.finishExtraction(
                    result: nil,
                    turns: turns,
                    sessionId: sessionId,
                    authorizationSnapshot: capturedAuthorization,
                    accountScope: accountScope,
                    fallbackReason: "backendNotConfigured",
                    completion: completion
                )
                return
            }

            DreamJourneyBackendClient.shared.extractKnowledgeEnvelope(
                userId: ownerUserId,
                transcript: transcript,
                turns: turns,
                existingSummary: existingSummary,
                sessionId: sessionId,
                personaScope: capturedIdentity.personaScope,
                digitalHumanId: capturedIdentity.digitalHumanId
            ) { [weak self] result in
                self?.extractQueue.async { [weak self] in
                    guard let self else { return }
                    guard self.validateAccountLeaseScope(accountScope, at: .runtime) else {
                        self.isExtracting = false
                        return
                    }
                    let envelope: KBKnowledgeExtractionEnvelope?
                    let fallbackReason: String?
                    switch result {
                    case .success(let value):
                        envelope = value
                        fallbackReason = nil
                    case .failure:
                        envelope = nil
                        fallbackReason = "backendFailure"
                        print("[KBLite] backend extraction failed reason=providerFailure")
                    }
                    self.finishExtraction(
                        result: envelope,
                        turns: turns,
                        sessionId: sessionId,
                        authorizationSnapshot: capturedAuthorization,
                        accountScope: accountScope,
                        fallbackReason: fallbackReason,
                        completion: completion
                    )
                }
            }
        }
    }

    private func finishExtraction(
        result: KBKnowledgeExtractionEnvelope?,
        turns: [ConversationTurn],
        sessionId: Int,
        authorizationSnapshot: KBPersonaAuthorizationSnapshot,
        accountScope: KBLiteAccountLeaseScope,
        fallbackReason: String?,
        completion: @escaping (Int) -> Void
    ) {
        guard validateAccountLeaseScope(accountScope, at: .commit) else {
            isExtracting = false
            return
        }
        let identity = authorizationSnapshot.identity
        graphLock.lock()
        guard isCurrentAuthorizationSnapshotLocked(authorizationSnapshot),
              validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graphLock.unlock()
            isExtracting = false
            print("[KBLite] 丢弃授权代次变化后的知识提取结果 reason=authorizationGenerationChanged")
            deliverExtractionCompletion(
                0,
                accountScope: accountScope,
                completion: completion
            )
            return
        }

        let rollbackGraph = graph
        let addedCount: Int
        let completionMode: String
        let acceptedBackendExtraction: Bool
        if let result, let proposal = result.proposal {
            if KBPersonaPolicy.isValidProposal(proposal, for: identity) {
                addedCount = mergeProposal(proposal, sessionId: sessionId, identity: identity)
                completionMode = "proposal"
                acceptedBackendExtraction = true
            } else {
                addedCount = quickExtract(
                    turns: turns,
                    sessionId: sessionId,
                    identity: identity
                )
                completionMode = "invalidProposalQuickFallback"
                acceptedBackendExtraction = false
            }
        } else if let result {
            addedCount = mergeExtractionResult(
                result.extraction,
                sessionId: sessionId,
                identity: identity
            )
            completionMode = "legacyExtraction"
            acceptedBackendExtraction = true
        } else {
            addedCount = quickExtract(turns: turns, sessionId: sessionId, identity: identity)
            completionMode = "quickFallback"
            acceptedBackendExtraction = false
        }
        if acceptedBackendExtraction {
            graph.lastBackendExtractionSessionId = max(
                graph.lastBackendExtractionSessionId ?? 0,
                sessionId
            )
            graph.lastBackendExtractionAt = Date()
        }
        graph.sessionCount = max(graph.sessionCount, sessionId)
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graph = rollbackGraph
            graphLock.unlock()
            isExtracting = false
            return
        }
        graphLock.unlock()
        isExtracting = false
        guard save(accountScope: accountScope, rollbackGraph: rollbackGraph) else { return }

        if let fallbackReason {
            print("[KBLite] ⚠️ 后端提取降级为本地规则 reason=\(fallbackReason)")
        } else {
            print("[KBLite] ✅ 后端知识提取完成 mode=\(completionMode): 新增 \(addedCount) 实体")
        }
        deliverExtractionCompletion(
            addedCount,
            accountScope: accountScope,
            shouldSynchronize: true,
            completion: completion
        )
    }

    private func deliverExtractionCompletion(
        _ addedCount: Int,
        accountScope: KBLiteAccountLeaseScope,
        shouldSynchronize: Bool = false,
        completion: @escaping (Int) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.validateAccountLeaseScope(accountScope, at: .ui) else {
                return
            }
            if shouldSynchronize {
                KnowledgeSyncCoordinator.shared.synchronizeCurrentUser(reason: "extractionCompleted")
            }
            completion(addedCount)
        }
    }

    /// 本地正则快速提取（LLM 不可用时的 fallback）
    /// 复用 ConversationMemoryManager 的维度提取逻辑，但存入知识库
    private func quickExtract(
        turns: [ConversationTurn],
        sessionId: Int,
        identity: KBPersonaIdentity
    ) -> Int {
        let userTexts = turns.filter { $0.role == "user" }.map { $0.text }
        let allText = userTexts.joined(separator: " ")

        var addedCount = 0

        // 提取人物
        let peopleKeywords = ["爷爷", "奶奶", "外婆", "外公", "姥姥", "姥爷",
                              "爸爸", "妈妈", "父亲", "母亲", "老伴", "老公", "老婆",
                              "哥哥", "姐姐", "弟弟", "妹妹", "叔叔", "阿姨", "舅舅", "姑姑",
                              "儿子", "女儿", "孙子", "孙女", "老师", "师傅", "同学", "战友"]
        for kw in peopleKeywords {
            if allText.contains(kw) {
                let turnIndices = sourceTurnIndices(containing: kw, in: turns)
                let existing = findMatchingPerson(name: kw, aliases: [], identity: identity)
                if existing == nil {
                    var person = KBPerson(id: UUID().uuidString, name: kw, aliases: [], relation: nil,
                                          traits: [], sourceSessionIds: [sessionId],
                                          createdAt: Date(), updatedAt: Date())
                    person.privacyMetadata = conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: turnIndices
                    )
                    applyIdentity(
                        identity,
                        evidenceStatus: "candidate",
                        sourceTurnIndices: turnIndices,
                        to: &person
                    )
                    graph.people.append(person)
                    addedCount += 1
                } else {
                    // 更新 sessionId
                    if let idx = graph.people.firstIndex(where: { $0.id == existing!.id }) {
                        if !graph.people[idx].sourceSessionIds.contains(sessionId) {
                            graph.people[idx].sourceSessionIds.append(sessionId)
                            graph.people[idx].updatedAt = Date()
                        }
                        graph.people[idx].privacyMetadata = mergedPrivacy(
                            graph.people[idx].privacyMetadata,
                            conversationPrivacyMetadata(
                                sessionId: sessionId,
                                sourceTurnIndices: turnIndices
                            )
                        )
                        applyIdentity(
                            identity,
                            evidenceStatus: "candidate",
                            sourceTurnIndices: turnIndices,
                            to: &graph.people[idx]
                        )
                    }
                }
            }
        }

        // 提取地点
        let cities = ["北京", "上海", "广州", "深圳", "杭州", "南京", "苏州",
                      "成都", "重庆", "武汉", "长沙", "西安", "天津", "青岛",
                      "东北", "四川", "湖南", "湖北", "广东", "江西", "安徽", "河南", "山东"]
        for city in cities {
            if allText.contains(city) {
                let turnIndices = sourceTurnIndices(containing: city, in: turns)
                let existing = findMatchingPlace(name: city, identity: identity)
                if existing == nil {
                    var place = KBPlace(id: UUID().uuidString, name: city, sourceSessionIds: [sessionId])
                    place.privacyMetadata = conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: turnIndices
                    )
                    applyIdentity(
                        identity,
                        evidenceStatus: "candidate",
                        sourceTurnIndices: turnIndices,
                        to: &place
                    )
                    graph.places.append(place)
                    addedCount += 1
                } else if let idx = graph.places.firstIndex(where: { $0.id == existing?.id }) {
                    graph.places[idx].sourceSessionIds = merged(
                        graph.places[idx].sourceSessionIds,
                        [sessionId]
                    )
                    graph.places[idx].privacyMetadata = mergedPrivacy(
                        graph.places[idx].privacyMetadata,
                        conversationPrivacyMetadata(
                            sessionId: sessionId,
                            sourceTurnIndices: turnIndices
                        )
                    )
                    applyIdentity(
                        identity,
                        evidenceStatus: "candidate",
                        sourceTurnIndices: turnIndices,
                        to: &graph.places[idx]
                    )
                }
            }
        }

        // 提取事件
        let eventKeywords = ["结婚", "上学", "工作", "退休", "当兵", "搬家",
                             "生孩子", "做饭", "种地", "打工", "赶集", "学手艺", "出国", "下海"]
        for kw in eventKeywords {
            if allText.contains(kw) {
                let turnIndices = sourceTurnIndices(containing: kw, in: turns)
                let existing = graph.events.first {
                    entityIsVisible($0, for: identity) && $0.title.contains(kw)
                }
                if existing == nil {
                    var event = KBEvent(id: UUID().uuidString, title: kw, sourceSessionIds: [sessionId])
                    event.privacyMetadata = conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: turnIndices
                    )
                    applyIdentity(
                        identity,
                        evidenceStatus: "candidate",
                        sourceTurnIndices: turnIndices,
                        to: &event
                    )
                    graph.events.append(event)
                    addedCount += 1
                } else if let idx = graph.events.firstIndex(where: { $0.id == existing?.id }) {
                    graph.events[idx].sourceSessionIds = merged(
                        graph.events[idx].sourceSessionIds,
                        [sessionId]
                    )
                    graph.events[idx].privacyMetadata = mergedPrivacy(
                        graph.events[idx].privacyMetadata,
                        conversationPrivacyMetadata(
                            sessionId: sessionId,
                            sourceTurnIndices: turnIndices
                        )
                    )
                    applyIdentity(
                        identity,
                        evidenceStatus: "candidate",
                        sourceTurnIndices: turnIndices,
                        to: &graph.events[idx]
                    )
                }
            }
        }

        print("[KBLite] 📝 正则快速提取: 新增 \(addedCount) 实体")
        return addedCount
    }

    private func sourceTurnIndices(containing value: String, in turns: [ConversationTurn]) -> [Int] {
        turns.enumerated().compactMap { index, turn in
            turn.role == "user" && turn.text.contains(value) ? index : nil
        }
    }

    private func conversationPrivacyMetadata(
        sessionId: Int,
        sourceTurnIndices: [Int]
    ) -> KBPrivacyMetadata {
        .generationAllowed(
            sourceRefs: KBKnowledgeSourceIdentityPolicy.conversationTurnReferences(
                sessionId: sessionId,
                turnIndices: sourceTurnIndices
            )
        )
    }

    // MARK: - Private: Prompt Building

    /// 构建已有知识摘要（供 LLM prompt 使用）
    private func buildExistingSummary(for identity: KBPersonaIdentity) -> String {
        let people = graph.people.filter {
            entityIsVisible($0, for: identity)
                && KnowledgeGenerationPolicy.allowsEntity(privacyScope: $0.privacyMetadata?.scope)
        }
        let places = graph.places.filter {
            entityIsVisible($0, for: identity)
                && KnowledgeGenerationPolicy.allowsEntity(privacyScope: $0.privacyMetadata?.scope)
        }
        let events = graph.events.filter {
            entityIsVisible($0, for: identity)
                && KnowledgeGenerationPolicy.allowsEntity(privacyScope: $0.privacyMetadata?.scope)
        }
        let facts = graph.facts.filter {
            entityIsVisible($0, for: identity)
                && KnowledgeGenerationPolicy.allowsEntity(privacyScope: $0.privacyMetadata?.scope)
        }
        if people.isEmpty && places.isEmpty && events.isEmpty && facts.isEmpty {
            return "（暂无已有知识）"
        }

        var lines: [String] = []

        if !people.isEmpty {
            lines.append("已知人物：")
            for p in people.prefix(15) {
                let traits = p.traits.isEmpty ? "" : "（\(p.traits.joined(separator: "、"))）"
                lines.append("  - \(p.name)\(traits)")
            }
        }

        if !places.isEmpty {
            lines.append("已知地点：\(places.prefix(10).map { $0.name }.joined(separator: "、"))")
        }

        if !events.isEmpty {
            lines.append("已知事件：\(events.prefix(10).map { $0.title }.joined(separator: "、"))")
        }

        if !facts.isEmpty {
            let recentFacts = facts.sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            lines.append("最近事实：")
            for f in recentFacts.prefix(5) {
                lines.append("  - \(f.statement)")
            }
        }

        let result = lines.joined(separator: "\n")
        // 限制 prompt 长度
        if result.count > 800 {
            return String(result.prefix(800)) + "\n..."
        }
        return result
    }

    /// 构建知识提取 prompt
    private func buildExtractionPrompt(transcript: String, existingSummary: String) -> String {
        return """
你是一个家庭记忆提取器。从以下对话中提取**本轮新出现的**信息。

【已有知识】（避免重复提取，只提取新信息）
\(existingSummary)

【本轮对话】
\(transcript)

请输出**严格的 JSON**（不要任何其他文字，不要 markdown 代码块标记）：
{
  "people": [
    {
      "name": "称呼或姓名",
      "aliases": ["其他称呼1", "其他称呼2"],
      "relation": "与用户的关系",
      "traits": ["特征1", "特征2"],
      "briefBio": "一两句话简介",
      "sourceTurnIndices": [对话行号]
    }
  ],
  "places": [
    {
      "name": "地点名",
      "category": "hometown/lived/visited/worked",
      "latitude": null,
      "longitude": null,
      "description": "简短描述",
      "relatedPeople": ["关联人物名"],
      "sourceTurnIndices": [对话行号]
    }
  ],
  "events": [
    {
      "title": "事件简短标题",
      "description": "详细描述",
      "year": null,
      "month": null,
      "location": "地点名",
      "participants": ["参与人物名"],
      "sourceTurnIndices": [对话行号]
    }
  ],
  "facts": [
    {
      "statement": "一句事实陈述",
      "confidence": "high/medium/low",
      "relatedPeople": [],
      "relatedPlaces": [],
      "relatedEvents": [],
      "sourceTurnIndices": [对话行号]
    }
  ]
}

【规则】
1. 只提取**本轮新出现**的信息，已有知识中已涵盖的不要重复。
2. confidence: 用户明确陈述 = "high"，推测/模糊 = "medium"，不确定 = "low"。
3. aliases: 收集对方在对话中出现过的所有称呼方式。
4. traits: 从行为和描述中提取特征词（如"手艺人"、"爱喝酒"、"当过兵"）。
5. briefBio: 用 1-2 句话简短总结此人（基于本轮对话）。
6. json 中所有的中文key前后不可以有空格
7. 如果本轮没有新信息，输出空数组。
8. 不要输出任何 JSON 之外的文字。
"""
    }

    // MARK: - Private: Entity Merging

    /// 将 LLM 提取结果合并到知识图谱
    /// - Returns: 新增实体数量
    private func mergeExtractionResult(
        _ result: KBExtractionResult,
        sessionId: Int,
        identity: KBPersonaIdentity
    ) -> Int {
        var addedCount = 0
        let now = Date()
        checkCapacity()

        for extracted in result.people {
            let name = extracted.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if let existing = findMatchingPerson(name: name, aliases: extracted.aliases, identity: identity),
               let index = graph.people.firstIndex(where: { $0.id == existing.id }) {
                graph.people[index].aliases = merged(graph.people[index].aliases, extracted.aliases)
                    .filter { $0 != graph.people[index].name }
                graph.people[index].traits = merged(graph.people[index].traits, extracted.traits)
                if graph.people[index].relation == nil { graph.people[index].relation = extracted.relation }
                if graph.people[index].briefBio == nil { graph.people[index].briefBio = extracted.briefBio }
                graph.people[index].sourceSessionIds = merged(
                    graph.people[index].sourceSessionIds,
                    [sessionId]
                )
                graph.people[index].privacyMetadata = mergedPrivacy(
                    graph.people[index].privacyMetadata,
                    conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: extracted.sourceTurnIndices
                    )
                )
                graph.people[index].updatedAt = now
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &graph.people[index]
                )
            } else {
                var person = KBPerson(
                    id: UUID().uuidString,
                    name: name,
                    aliases: extracted.aliases,
                    relation: extracted.relation,
                    traits: extracted.traits,
                    briefBio: extracted.briefBio,
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    updatedAt: now
                )
                person.privacyMetadata = conversationPrivacyMetadata(
                    sessionId: sessionId,
                    sourceTurnIndices: extracted.sourceTurnIndices
                )
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &person
                )
                graph.people.append(person)
                addedCount += 1
            }
        }

        for extracted in result.places {
            let name = extracted.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let relatedPersonIds = extracted.relatedPeople.compactMap {
                findMatchingPerson(name: $0, aliases: [], identity: identity)?.id
            }
            if let existing = findMatchingPlace(name: name, identity: identity),
               let index = graph.places.firstIndex(where: { $0.id == existing.id }) {
                if graph.places[index].description == nil { graph.places[index].description = extracted.description }
                if graph.places[index].category == nil { graph.places[index].category = extracted.category }
                if graph.places[index].latitude == nil { graph.places[index].latitude = extracted.latitude }
                if graph.places[index].longitude == nil { graph.places[index].longitude = extracted.longitude }
                graph.places[index].relatedPersonIds = merged(
                    graph.places[index].relatedPersonIds,
                    relatedPersonIds
                )
                graph.places[index].sourceSessionIds = merged(
                    graph.places[index].sourceSessionIds,
                    [sessionId]
                )
                graph.places[index].privacyMetadata = mergedPrivacy(
                    graph.places[index].privacyMetadata,
                    conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: extracted.sourceTurnIndices
                    )
                )
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &graph.places[index]
                )
            } else {
                var place = KBPlace(
                    id: UUID().uuidString,
                    name: name,
                    category: extracted.category,
                    latitude: extracted.latitude,
                    longitude: extracted.longitude,
                    description: extracted.description,
                    relatedPersonIds: relatedPersonIds,
                    sourceSessionIds: [sessionId],
                    createdAt: now
                )
                place.privacyMetadata = conversationPrivacyMetadata(
                    sessionId: sessionId,
                    sourceTurnIndices: extracted.sourceTurnIndices
                )
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &place
                )
                graph.places.append(place)
                addedCount += 1
            }
        }

        for extracted in result.events {
            let title = extracted.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let locationId = extracted.location.flatMap {
                findMatchingPlace(name: $0, identity: identity)?.id
            }
            let participantIds = extracted.participants.compactMap {
                findMatchingPerson(name: $0, aliases: [], identity: identity)?.id
            }
            if let existing = findMatchingEvent(
                title: title,
                year: extracted.year,
                month: extracted.month,
                identity: identity
            ), let index = graph.events.firstIndex(where: { $0.id == existing.id }) {
                if graph.events[index].description == nil { graph.events[index].description = extracted.description }
                if graph.events[index].year == nil { graph.events[index].year = extracted.year }
                if graph.events[index].month == nil { graph.events[index].month = extracted.month }
                if graph.events[index].locationId == nil { graph.events[index].locationId = locationId }
                graph.events[index].participantIds = merged(
                    graph.events[index].participantIds,
                    participantIds
                )
                graph.events[index].sourceSessionIds = merged(
                    graph.events[index].sourceSessionIds,
                    [sessionId]
                )
                graph.events[index].privacyMetadata = mergedPrivacy(
                    graph.events[index].privacyMetadata,
                    conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: extracted.sourceTurnIndices
                    )
                )
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &graph.events[index]
                )
            } else {
                var event = KBEvent(
                    id: UUID().uuidString,
                    title: title,
                    description: extracted.description,
                    year: extracted.year,
                    month: extracted.month,
                    locationId: locationId,
                    participantIds: participantIds,
                    sourceSessionIds: [sessionId],
                    createdAt: now
                )
                event.privacyMetadata = conversationPrivacyMetadata(
                    sessionId: sessionId,
                    sourceTurnIndices: extracted.sourceTurnIndices
                )
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &event
                )
                graph.events.append(event)
                addedCount += 1
            }
        }

        for extracted in result.facts {
            let statement = extracted.statement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !statement.isEmpty else { continue }
            let relatedPersonIds = extracted.relatedPeople.compactMap {
                findMatchingPerson(name: $0, aliases: [], identity: identity)?.id
            }
            let relatedPlaceIds = extracted.relatedPlaces.compactMap {
                findMatchingPlace(name: $0, identity: identity)?.id
            }
            let relatedEventIds = extracted.relatedEvents.compactMap { title in
                graph.events.first {
                    entityIsVisible($0, for: identity) && $0.title == title
                }?.id
            }
            if let existing = findMatchingFact(statement: statement, identity: identity),
               let index = graph.facts.firstIndex(where: { $0.id == existing.id }) {
                graph.facts[index].confidence = mergedConfidence(
                    graph.facts[index].confidence,
                    extracted.confidence ?? "high"
                )
                graph.facts[index].relatedPersonIds = merged(
                    graph.facts[index].relatedPersonIds,
                    relatedPersonIds
                )
                graph.facts[index].relatedPlaceIds = merged(
                    graph.facts[index].relatedPlaceIds,
                    relatedPlaceIds
                )
                graph.facts[index].relatedEventIds = merged(
                    graph.facts[index].relatedEventIds,
                    relatedEventIds
                )
                graph.facts[index].sourceSessionIds = merged(
                    graph.facts[index].sourceSessionIds,
                    [sessionId]
                )
                graph.facts[index].privacyMetadata = mergedPrivacy(
                    graph.facts[index].privacyMetadata,
                    conversationPrivacyMetadata(
                        sessionId: sessionId,
                        sourceTurnIndices: extracted.sourceTurnIndices
                    )
                )
                applyIdentity(
                    identity,
                    evidenceStatus: KnowledgeGenerationPolicy.allowsFact(
                        privacyScope: "generationAllowed",
                        confidence: extracted.confidence ?? "high"
                    ) ? "observed" : "candidate",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &graph.facts[index]
                )
            } else {
                var fact = KBFact(
                    id: UUID().uuidString,
                    statement: statement,
                    confidence: extracted.confidence ?? "high",
                    relatedPersonIds: relatedPersonIds,
                    relatedPlaceIds: relatedPlaceIds,
                    relatedEventIds: relatedEventIds,
                    sourceSessionIds: [sessionId],
                    createdAt: now
                )
                fact.privacyMetadata = conversationPrivacyMetadata(
                    sessionId: sessionId,
                    sourceTurnIndices: extracted.sourceTurnIndices
                )
                applyIdentity(
                    identity,
                    evidenceStatus: KnowledgeGenerationPolicy.allowsFact(
                        privacyScope: "generationAllowed",
                        confidence: extracted.confidence ?? "high"
                    ) ? "observed" : "candidate",
                    sourceTurnIndices: extracted.sourceTurnIndices,
                    to: &fact
                )
                graph.facts.append(fact)
                addedCount += 1
            }
        }

        return addedCount
    }

    private func mergeProposal(
        _ proposal: KBKnowledgeMutationProposal,
        sessionId: Int,
        identity: KBPersonaIdentity
    ) -> Int {
        checkCapacity()
        let now = Date()
        var addedCount = 0
        var personMap: [String: String] = [:]
        var placeMap: [String: String] = [:]
        var eventMap: [String: String] = [:]
        var factMap: [String: String] = [:]

        for item in proposal.upserts.people {
            let exact = graph.people.first { $0.id == item.id && entityIsVisible($0, for: identity) }
            let natural = findMatchingPerson(name: item.name, aliases: item.aliases, identity: identity)
            personMap[item.id] = exact?.id ?? natural?.id ?? uniqueLocalID(
                preferred: item.id,
                occupied: Set(graph.people.map(\.id))
            )
        }
        for item in proposal.upserts.places {
            let exact = graph.places.first { $0.id == item.id && entityIsVisible($0, for: identity) }
            let natural = findMatchingPlace(name: item.name, identity: identity)
            placeMap[item.id] = exact?.id ?? natural?.id ?? uniqueLocalID(
                preferred: item.id,
                occupied: Set(graph.places.map(\.id))
            )
        }
        for item in proposal.upserts.events {
            let exact = graph.events.first { $0.id == item.id && entityIsVisible($0, for: identity) }
            let natural = findMatchingEvent(
                title: item.title,
                year: item.year,
                month: item.month,
                identity: identity
            )
            eventMap[item.id] = exact?.id ?? natural?.id ?? uniqueLocalID(
                preferred: item.id,
                occupied: Set(graph.events.map(\.id))
            )
        }
        for item in proposal.upserts.facts {
            let exact = graph.facts.first { $0.id == item.id && entityIsVisible($0, for: identity) }
            let natural = findMatchingFact(statement: item.statement, identity: identity)
            factMap[item.id] = exact?.id ?? natural?.id ?? uniqueLocalID(
                preferred: item.id,
                occupied: Set(graph.facts.map(\.id))
            )
        }

        let visiblePersonIDs = Set(graph.people.filter { entityIsVisible($0, for: identity) }.map(\.id))
        let visiblePlaceIDs = Set(graph.places.filter { entityIsVisible($0, for: identity) }.map(\.id))
        let visibleEventIDs = Set(graph.events.filter { entityIsVisible($0, for: identity) }.map(\.id))

        for item in proposal.upserts.people {
            guard let localID = personMap[item.id] else { continue }
            let relatedIDs = mappedReferences(
                item.relatedPersonIds,
                through: personMap,
                existing: visiblePersonIDs
            )
            if let index = graph.people.firstIndex(where: { $0.id == localID }) {
                graph.people[index].aliases = merged(graph.people[index].aliases, item.aliases)
                    .filter { $0 != graph.people[index].name }
                graph.people[index].traits = merged(graph.people[index].traits, item.traits)
                if graph.people[index].relation == nil { graph.people[index].relation = item.relation }
                if graph.people[index].briefBio == nil { graph.people[index].briefBio = item.briefBio }
                graph.people[index].relatedPersonIds = merged(
                    graph.people[index].relatedPersonIds,
                    relatedIDs
                )
                graph.people[index].sourceSessionIds = merged(
                    graph.people[index].sourceSessionIds,
                    item.sourceSessionIds + [sessionId]
                )
                graph.people[index].sourceTurnIndices = merged(
                    graph.people[index].sourceTurnIndices ?? [],
                    item.sourceTurnIndices
                )
                graph.people[index].privacyMetadata = mergedPrivacy(
                    graph.people[index].privacyMetadata,
                    item.privacyMetadata
                )
                graph.people[index].evidenceStatus = mergedEvidence(
                    graph.people[index].evidenceStatus,
                    item.evidenceStatus
                )
                graph.people[index].ownerUserId = identity.ownerUserId
                graph.people[index].personaScope = identity.personaScope
                graph.people[index].digitalHumanId = identity.digitalHumanId
                graph.people[index].updatedAt = max(graph.people[index].updatedAt, item.updatedAt ?? now)
            } else {
                var person = KBPerson(
                    id: localID,
                    name: item.name,
                    aliases: item.aliases,
                    relation: item.relation,
                    traits: item.traits,
                    briefBio: item.briefBio,
                    relatedPersonIds: relatedIDs,
                    sourceSessionIds: merged(item.sourceSessionIds, [sessionId]),
                    createdAt: item.createdAt ?? now,
                    updatedAt: item.updatedAt ?? now,
                    privacyMetadata: item.privacyMetadata
                )
                applyIdentity(
                    identity,
                    evidenceStatus: item.evidenceStatus,
                    sourceTurnIndices: item.sourceTurnIndices,
                    to: &person
                )
                graph.people.append(person)
                addedCount += 1
            }
        }

        for item in proposal.upserts.places {
            guard let localID = placeMap[item.id] else { continue }
            let relatedIDs = mappedReferences(
                item.relatedPersonIds,
                through: personMap,
                existing: visiblePersonIDs
            )
            if let index = graph.places.firstIndex(where: { $0.id == localID }) {
                if graph.places[index].category == nil { graph.places[index].category = item.category }
                if graph.places[index].latitude == nil { graph.places[index].latitude = item.latitude }
                if graph.places[index].longitude == nil { graph.places[index].longitude = item.longitude }
                if graph.places[index].description == nil { graph.places[index].description = item.description }
                graph.places[index].relatedPersonIds = merged(
                    graph.places[index].relatedPersonIds,
                    relatedIDs
                )
                graph.places[index].sourceSessionIds = merged(
                    graph.places[index].sourceSessionIds,
                    item.sourceSessionIds + [sessionId]
                )
                graph.places[index].sourceTurnIndices = merged(
                    graph.places[index].sourceTurnIndices ?? [],
                    item.sourceTurnIndices
                )
                graph.places[index].privacyMetadata = mergedPrivacy(
                    graph.places[index].privacyMetadata,
                    item.privacyMetadata
                )
                graph.places[index].evidenceStatus = mergedEvidence(
                    graph.places[index].evidenceStatus,
                    item.evidenceStatus
                )
                graph.places[index].ownerUserId = identity.ownerUserId
                graph.places[index].personaScope = identity.personaScope
                graph.places[index].digitalHumanId = identity.digitalHumanId
            } else {
                var place = KBPlace(
                    id: localID,
                    name: item.name,
                    category: item.category,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    description: item.description,
                    relatedPersonIds: relatedIDs,
                    sourceSessionIds: merged(item.sourceSessionIds, [sessionId]),
                    createdAt: item.createdAt ?? now,
                    privacyMetadata: item.privacyMetadata
                )
                applyIdentity(
                    identity,
                    evidenceStatus: item.evidenceStatus,
                    sourceTurnIndices: item.sourceTurnIndices,
                    to: &place
                )
                graph.places.append(place)
                addedCount += 1
            }
        }

        for item in proposal.upserts.events {
            guard let localID = eventMap[item.id] else { continue }
            let locationID = item.locationId.flatMap {
                mappedReference($0, through: placeMap, existing: visiblePlaceIDs)
            }
            let participantIDs = mappedReferences(
                item.participantIds,
                through: personMap,
                existing: visiblePersonIDs
            )
            if let index = graph.events.firstIndex(where: { $0.id == localID }) {
                if graph.events[index].description == nil { graph.events[index].description = item.description }
                if graph.events[index].year == nil { graph.events[index].year = item.year }
                if graph.events[index].month == nil { graph.events[index].month = item.month }
                if graph.events[index].locationId == nil { graph.events[index].locationId = locationID }
                graph.events[index].participantIds = merged(
                    graph.events[index].participantIds,
                    participantIDs
                )
                graph.events[index].mediaIds = merged(graph.events[index].mediaIds, item.mediaIds)
                if graph.events[index].memoirId == nil { graph.events[index].memoirId = item.memoirId }
                graph.events[index].sourceSessionIds = merged(
                    graph.events[index].sourceSessionIds,
                    item.sourceSessionIds + [sessionId]
                )
                graph.events[index].sourceTurnIndices = merged(
                    graph.events[index].sourceTurnIndices ?? [],
                    item.sourceTurnIndices
                )
                graph.events[index].privacyMetadata = mergedPrivacy(
                    graph.events[index].privacyMetadata,
                    item.privacyMetadata
                )
                graph.events[index].evidenceStatus = mergedEvidence(
                    graph.events[index].evidenceStatus,
                    item.evidenceStatus
                )
                graph.events[index].ownerUserId = identity.ownerUserId
                graph.events[index].personaScope = identity.personaScope
                graph.events[index].digitalHumanId = identity.digitalHumanId
            } else {
                var event = KBEvent(
                    id: localID,
                    title: item.title,
                    description: item.description,
                    year: item.year,
                    month: item.month,
                    locationId: locationID,
                    participantIds: participantIDs,
                    mediaIds: item.mediaIds,
                    memoirId: item.memoirId,
                    sourceSessionIds: merged(item.sourceSessionIds, [sessionId]),
                    createdAt: item.createdAt ?? now,
                    privacyMetadata: item.privacyMetadata
                )
                applyIdentity(
                    identity,
                    evidenceStatus: item.evidenceStatus,
                    sourceTurnIndices: item.sourceTurnIndices,
                    to: &event
                )
                graph.events.append(event)
                addedCount += 1
            }
        }

        for item in proposal.upserts.facts {
            guard let localID = factMap[item.id] else { continue }
            let relatedPersonIDs = mappedReferences(
                item.relatedPersonIds,
                through: personMap,
                existing: visiblePersonIDs
            )
            let relatedPlaceIDs = mappedReferences(
                item.relatedPlaceIds,
                through: placeMap,
                existing: visiblePlaceIDs
            )
            let relatedEventIDs = mappedReferences(
                item.relatedEventIds,
                through: eventMap,
                existing: visibleEventIDs
            )
            if let index = graph.facts.firstIndex(where: { $0.id == localID }) {
                graph.facts[index].confidence = mergedConfidence(
                    graph.facts[index].confidence,
                    item.confidence
                )
                graph.facts[index].relatedPersonIds = merged(
                    graph.facts[index].relatedPersonIds,
                    relatedPersonIDs
                )
                graph.facts[index].relatedPlaceIds = merged(
                    graph.facts[index].relatedPlaceIds,
                    relatedPlaceIDs
                )
                graph.facts[index].relatedEventIds = merged(
                    graph.facts[index].relatedEventIds,
                    relatedEventIDs
                )
                graph.facts[index].sourceSessionIds = merged(
                    graph.facts[index].sourceSessionIds,
                    item.sourceSessionIds + [sessionId]
                )
                graph.facts[index].sourceTurnIndices = merged(
                    graph.facts[index].sourceTurnIndices ?? [],
                    item.sourceTurnIndices
                )
                graph.facts[index].privacyMetadata = mergedPrivacy(
                    graph.facts[index].privacyMetadata,
                    item.privacyMetadata
                )
                graph.facts[index].evidenceStatus = mergedEvidence(
                    graph.facts[index].evidenceStatus,
                    item.evidenceStatus
                )
                graph.facts[index].ownerUserId = identity.ownerUserId
                graph.facts[index].personaScope = identity.personaScope
                graph.facts[index].digitalHumanId = identity.digitalHumanId
            } else {
                var fact = KBFact(
                    id: localID,
                    statement: item.statement,
                    confidence: item.confidence,
                    relatedPersonIds: relatedPersonIDs,
                    relatedPlaceIds: relatedPlaceIDs,
                    relatedEventIds: relatedEventIDs,
                    sourceSessionIds: merged(item.sourceSessionIds, [sessionId]),
                    createdAt: item.createdAt ?? now,
                    privacyMetadata: item.privacyMetadata
                )
                applyIdentity(
                    identity,
                    evidenceStatus: item.evidenceStatus,
                    sourceTurnIndices: item.sourceTurnIndices,
                    to: &fact
                )
                graph.facts.append(fact)
                addedCount += 1
            }
        }

        return addedCount
    }

    // MARK: - Private: Matching and Persona Metadata

    private func findMatchingPerson(
        name: String,
        aliases: [String],
        identity: KBPersonaIdentity
    ) -> KBPerson? {
        let allNames = Set(([name] + aliases).map(normalizedMatchText).filter { !$0.isEmpty })
        let visiblePeople = graph.people.filter { entityIsVisible($0, for: identity) }
        if let exact = visiblePeople.first(where: {
            allNames.contains(normalizedMatchText($0.name))
                || !$0.aliases.map(normalizedMatchText).filter(allNames.contains).isEmpty
        }) {
            return exact
        }
        guard normalizedMatchText(name).count >= 2 else { return nil }
        return visiblePeople.first { person in
            ([person.name] + person.aliases).contains { candidate in
                let normalizedCandidate = normalizedMatchText(candidate)
                let normalizedName = normalizedMatchText(name)
                return normalizedCandidate.contains(normalizedName)
                    || normalizedName.contains(normalizedCandidate)
            }
        }
    }

    private func findMatchingPlace(name: String, identity: KBPersonaIdentity) -> KBPlace? {
        let normalizedName = normalizedMatchText(name)
        return graph.places.filter { entityIsVisible($0, for: identity) }.first { place in
            let candidate = normalizedMatchText(place.name)
            return candidate == normalizedName
                || candidate.contains(normalizedName)
                || normalizedName.contains(candidate)
        }
    }

    private func findMatchingEvent(
        title: String,
        year: Int?,
        month: Int?,
        identity: KBPersonaIdentity
    ) -> KBEvent? {
        let normalizedTitle = normalizedMatchText(title)
        return graph.events.first {
            entityIsVisible($0, for: identity)
                && normalizedMatchText($0.title) == normalizedTitle
                && ($0.year == nil || year == nil || $0.year == year)
                && ($0.month == nil || month == nil || $0.month == month)
        }
    }

    private func findMatchingFact(
        statement: String,
        identity: KBPersonaIdentity
    ) -> KBFact? {
        let normalizedStatement = normalizedMatchText(statement)
        return graph.facts.first { fact in
            guard entityIsVisible(fact, for: identity) else { return false }
            let existing = normalizedMatchText(fact.statement)
            return existing == normalizedStatement
                || (existing.count >= 10 && normalizedStatement.count >= 10
                    && (existing.contains(normalizedStatement) || normalizedStatement.contains(existing)))
        }
    }

    private func entityIsVisible(_ person: KBPerson, for identity: KBPersonaIdentity) -> Bool {
        KBPersonaPolicy.allowsEntity(
            ownerUserId: person.ownerUserId,
            personaScope: person.personaScope,
            digitalHumanId: person.digitalHumanId,
            for: identity,
            legacyOwnerUserId: loadedUserId
        )
    }

    private func entityIsVisible(_ place: KBPlace, for identity: KBPersonaIdentity) -> Bool {
        KBPersonaPolicy.allowsEntity(
            ownerUserId: place.ownerUserId,
            personaScope: place.personaScope,
            digitalHumanId: place.digitalHumanId,
            for: identity,
            legacyOwnerUserId: loadedUserId
        )
    }

    private func entityIsVisible(_ event: KBEvent, for identity: KBPersonaIdentity) -> Bool {
        KBPersonaPolicy.allowsEntity(
            ownerUserId: event.ownerUserId,
            personaScope: event.personaScope,
            digitalHumanId: event.digitalHumanId,
            for: identity,
            legacyOwnerUserId: loadedUserId
        )
    }

    private func entityIsVisible(_ fact: KBFact, for identity: KBPersonaIdentity) -> Bool {
        KBPersonaPolicy.allowsEntity(
            ownerUserId: fact.ownerUserId,
            personaScope: fact.personaScope,
            digitalHumanId: fact.digitalHumanId,
            for: identity,
            legacyOwnerUserId: loadedUserId
        )
    }

    private func applyIdentity(
        _ identity: KBPersonaIdentity,
        evidenceStatus: String,
        sourceTurnIndices: [Int],
        to person: inout KBPerson
    ) {
        person.ownerUserId = identity.ownerUserId
        person.personaScope = identity.personaScope
        person.digitalHumanId = identity.digitalHumanId
        person.evidenceStatus = mergedEvidence(person.evidenceStatus, evidenceStatus)
        person.sourceTurnIndices = merged(person.sourceTurnIndices ?? [], sourceTurnIndices)
    }

    private func applyIdentity(
        _ identity: KBPersonaIdentity,
        evidenceStatus: String,
        sourceTurnIndices: [Int],
        to place: inout KBPlace
    ) {
        place.ownerUserId = identity.ownerUserId
        place.personaScope = identity.personaScope
        place.digitalHumanId = identity.digitalHumanId
        place.evidenceStatus = mergedEvidence(place.evidenceStatus, evidenceStatus)
        place.sourceTurnIndices = merged(place.sourceTurnIndices ?? [], sourceTurnIndices)
    }

    private func applyIdentity(
        _ identity: KBPersonaIdentity,
        evidenceStatus: String,
        sourceTurnIndices: [Int],
        to event: inout KBEvent
    ) {
        event.ownerUserId = identity.ownerUserId
        event.personaScope = identity.personaScope
        event.digitalHumanId = identity.digitalHumanId
        event.evidenceStatus = mergedEvidence(event.evidenceStatus, evidenceStatus)
        event.sourceTurnIndices = merged(event.sourceTurnIndices ?? [], sourceTurnIndices)
    }

    private func applyIdentity(
        _ identity: KBPersonaIdentity,
        evidenceStatus: String,
        sourceTurnIndices: [Int],
        to fact: inout KBFact
    ) {
        fact.ownerUserId = identity.ownerUserId
        fact.personaScope = identity.personaScope
        fact.digitalHumanId = identity.digitalHumanId
        fact.evidenceStatus = mergedEvidence(fact.evidenceStatus, evidenceStatus)
        fact.sourceTurnIndices = merged(fact.sourceTurnIndices ?? [], sourceTurnIndices)
    }

    private func merged<T: Hashable>(_ existing: [T], _ incoming: [T]) -> [T] {
        var seen = Set(existing)
        return existing + incoming.filter { seen.insert($0).inserted }
    }

    private func mergedPrivacy(
        _ existing: KBPrivacyMetadata?,
        _ incoming: KBPrivacyMetadata
    ) -> KBPrivacyMetadata {
        guard let existing else { return incoming }
        var refs = existing.sourceRefs
        for ref in incoming.sourceRefs where !refs.contains(where: {
            $0.kind == ref.kind && $0.id == ref.id && $0.title == ref.title
        }) {
            refs.append(ref)
        }
        let scope = existing.scope == "localOnly" ? existing.scope : incoming.scope
        return KBPrivacyMetadata(
            scope: scope,
            sourceRefs: refs,
            widgetVisibility: existing.widgetVisibility
        )
    }

    private func mergedEvidence(_ existing: String?, _ incoming: String) -> String {
        if let existing,
           ["rejected", "superseded"].contains(existing.lowercased()) {
            return existing
        }
        if ["rejected", "superseded"].contains(incoming.lowercased()) {
            return incoming
        }
        let rank = ["candidate": 0, "observed": 1, "confirmed": 2]
        guard let existing else { return incoming }
        return (rank[existing.lowercased()] ?? 0) >= (rank[incoming.lowercased()] ?? 0)
            ? existing
            : incoming
    }

    private func mergedConfidence(_ existing: String, _ incoming: String) -> String {
        let rank = ["low": 0, "medium": 1, "high": 2, "confirmed": 3]
        return (rank[existing.lowercased()] ?? 0) >= (rank[incoming.lowercased()] ?? 0)
            ? existing
            : incoming
    }

    private func mappedReferences(
        _ references: [String],
        through map: [String: String],
        existing: Set<String>
    ) -> [String] {
        references.compactMap { mappedReference($0, through: map, existing: existing) }
    }

    private func mappedReference(
        _ reference: String,
        through map: [String: String],
        existing: Set<String>
    ) -> String? {
        map[reference] ?? (existing.contains(reference) ? reference : nil)
    }

    private func uniqueLocalID(preferred: String, occupied: Set<String>) -> String {
        occupied.contains(preferred) ? UUID().uuidString : preferred
    }

    private func normalizedMatchText(_ value: String) -> String {
        value
            .precomposedStringWithCompatibilityMapping
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private func findMatchingPerson(name: String, aliases: [String]) -> KBPerson? {
        findMatchingPerson(
            name: name,
            aliases: aliases,
            identity: Self.resolveCurrentPersonaIdentity()
        )
    }

    private func findMatchingPlace(name: String) -> KBPlace? {
        findMatchingPlace(name: name, identity: Self.resolveCurrentPersonaIdentity())
    }

    // MARK: - Public API: Search

    private func semanticSearchSnapshot() -> (
        graph: KBLiteGraph,
        scope: KBLiteSemanticCacheScope?
    ) {
        graphLock.lock()
        defer { graphLock.unlock() }
        return (graph, semanticCacheScopeLocked())
    }

    /// 混合检索：语义搜索（iOS 17+）+ 关键词 fallback
    /// - Parameter query: 用户当前说的内容
    /// - Returns: 匹配的实体集合
    func search(query: String) -> KBSearchResult {
        guard !query.isEmpty else { return KBSearchResult() }
        let snapshot = semanticSearchSnapshot()
        return search(
            query: query,
            graphSnapshot: snapshot.graph,
            semanticScope: snapshot.scope
        )
    }

    private func search(
        query: String,
        graphSnapshot: KBLiteGraph,
        semanticScope: KBLiteSemanticCacheScope?
    ) -> KBSearchResult {
        if let semanticScope, !isCurrentSemanticCacheScope(semanticScope) {
            return KBSearchResult()
        }

        // 尝试语义搜索（iOS 17+），失败或不可用则 fallback 关键词
        if KBLiteSemanticSearch.shared.isAvailable, let semanticScope {
            let semantic = KBLiteSemanticSearch.shared.semanticSearch(
                scope: semanticScope,
                query: query,
                people: graphSnapshot.people,
                places: graphSnapshot.places,
                events: graphSnapshot.events,
                facts: graphSnapshot.facts
            )
            if !semantic.isEmpty, isCurrentSemanticCacheScope(semanticScope) {
                return semantic
            }
        }

        // Fallback: 关键词匹配
        if let semanticScope, !isCurrentSemanticCacheScope(semanticScope) {
            return KBSearchResult()
        }
        return keywordSearch(query: query, graphSnapshot: graphSnapshot)
    }

    /// 关键词检索（原始实现，作为语义搜索的 fallback）
    private func keywordSearch(query: String, graphSnapshot: KBLiteGraph) -> KBSearchResult {
        var result = KBSearchResult()

        // 使用 NSLinguisticTagger 做中文分词
        let keywords = tokenizeChinese(query)

        print("[KBLite] 🔍 检索: \"\(query)\" → 关键词: \(keywords)")

        // 人物匹配
        result.people = graphSnapshot.people.filter { person in
            let searchTarget = person.searchableText
            return keywords.contains { kw in
                searchTarget.contains(kw)
            }
        }

        // 地点匹配
        result.places = graphSnapshot.places.filter { place in
            let searchTarget = place.searchableText
            return keywords.contains { kw in
                searchTarget.contains(kw)
            }
        }

        // 事件匹配
        result.events = graphSnapshot.events.filter { event in
            let searchTarget = event.searchableText + " " + event.formattedDate
            return keywords.contains { kw in
                searchTarget.contains(kw)
            }
        }

        // 事实匹配
        result.facts = graphSnapshot.facts.filter { fact in
            keywords.contains { kw in
                fact.statement.contains(kw)
            }
        }

        print("[KBLite] 🔍 检索结果: \(result.totalCount) 条 (人:\(result.people.count) 地:\(result.places.count) 事:\(result.events.count) 实:\(result.facts.count))")
        return result
    }

    /// 中文分词（使用系统 NSLinguisticTagger）
    private func tokenizeChinese(_ text: String) -> [String] {
        var tokens: [String] = []
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = text

        tagger.enumerateTags(
            in: NSRange(text.startIndex..., in: text),
            scheme: .tokenType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { _, range, _, _ in
            if let substring = Range(range, in: text) {
                let token = String(text[substring])
                // 过滤单字词和纯数字
                if token.count >= 2 && !token.allSatisfy({ $0.isNumber }) {
                    tokens.append(token)
                }
            }
        }

        // 分词失败时，切分 2-3 字片段作为 fallback
        if tokens.isEmpty {
            var i = text.startIndex
            while i < text.endIndex {
                let end = text.index(i, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
                let token = String(text[i..<end])
                tokens.append(token)
                i = end
            }
        }

        return tokens
    }

    // MARK: - Public API: Context Building

    /// 构建可注入 system_prompt 的知识库上下文
    /// - Parameters:
    ///   - query: 用户当前说的话（触发检索），nil 时返回最近摘要
    ///   - maxItems: 每类实体最多返回条数
    /// - Returns: 上下文字符串，空字符串表示无可用上下文
    func buildContextString(query: String?, maxItems: Int = 5) -> String {
        buildContextString(
            query: query,
            maxItems: maxItems,
            generationAllowedOnly: false,
            expectedIdentity: nil
        )
    }

    /// 构建允许发送给生成服务的上下文。缺少显式授权元数据的旧数据不会离开设备。
    func buildGenerationAllowedContextString(
        query: String?,
        maxItems: Int = 5,
        expectedIdentity: KBPersonaIdentity? = nil
    ) -> String {
        let identity = expectedIdentity ?? Self.resolveCurrentPersonaIdentity()
        guard identity.isComplete, loadedUserId == identity.ownerUserId else {
            print(
                "[KBLite] 跳过生成上下文：知识所有者不匹配 " +
                "loaded=\(loadedUserId) expected=\(identity.ownerUserId)"
            )
            return ""
        }
        return buildContextString(
            query: query,
            maxItems: maxItems,
            generationAllowedOnly: true,
            expectedIdentity: identity
        )
    }

    private func buildContextString(
        query: String?,
        maxItems: Int,
        generationAllowedOnly: Bool,
        expectedIdentity: KBPersonaIdentity?
    ) -> String {
        var parts: [String] = []
        let searchSnapshot = semanticSearchSnapshot()
        let graphSnapshot = searchSnapshot.graph
        if generationAllowedOnly {
            guard let contextScope = searchSnapshot.scope,
                  isCurrentSemanticCacheScope(contextScope) else {
                return ""
            }
        }
        let canGenerateEntity: (KBPrivacyMetadata?, String?) -> Bool = { metadata, evidenceStatus in
            guard generationAllowedOnly else { return true }
            guard KnowledgeGenerationPolicy.allowsEntity(
                privacyScope: metadata?.scope
            ), let expectedIdentity else {
                return false
            }
            return KBPersonaPolicy.allowsEvidenceStatus(
                evidenceStatus,
                for: expectedIdentity
            )
        }
        let canGenerateFact: (KBFact) -> Bool = { fact in
            guard generationAllowedOnly else { return true }
            guard KnowledgeGenerationPolicy.allowsFact(
                privacyScope: fact.privacyMetadata?.scope,
                confidence: fact.confidence
            ) else {
                return false
            }
            guard let expectedIdentity else { return false }
            return KBPersonaPolicy.allowsEvidenceStatus(
                fact.evidenceStatus,
                for: expectedIdentity
            )
        }

        // 有 query → 检索相关知识
        if let q = query, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            let rankingCandidates = generationAllowedOnly
                ? generationSearchCandidates(
                    from: graphSnapshot,
                    expectedIdentity: expectedIdentity,
                    canGenerateEntity: canGenerateEntity,
                    canGenerateFact: canGenerateFact
                )
                : graphSnapshot
            let result = search(
                query: q,
                graphSnapshot: rankingCandidates,
                semanticScope: searchSnapshot.scope
            )
            let people = result.people.filter {
                canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                    && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
            }
            let places = result.places.filter {
                canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                    && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
            }
            let events = result.events.filter {
                canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                    && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
            }
            let facts = result.facts.filter {
                canGenerateFact($0)
                    && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
            }

            if !people.isEmpty {
                let summaries: [String] = people.prefix(maxItems).map { p in
                    var line = "\(p.name)"
                    if let rel = p.relation { line += "（\(rel)）" }
                    if !p.traits.isEmpty { line += "，特征：\(p.traits.joined(separator: "、"))" }

                    // 附上关联事实
                    let relatedFacts = graphSnapshot.facts.filter {
                        $0.relatedPersonIds.contains(p.id)
                            && canGenerateFact($0)
                            && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
                    }
                    if !relatedFacts.isEmpty {
                        let factsText = relatedFacts.prefix(3).map { $0.statement }.joined(separator: "；")
                        line += "。已知：\(factsText)"
                    } else if let bio = p.briefBio {
                        line += "。简介：\(bio)"
                    }
                    return line
                }
                parts.append("【相关人物】\n" + summaries.joined(separator: "\n"))
            }

            if !places.isEmpty {
                let summaries: [String] = places.prefix(maxItems).map { p in
                    var line = p.name
                    if let cat = p.category { line += "（\(cat)）" }
                    if let desc = p.description { line += "：\(desc)" }
                    return line
                }
                parts.append("【相关地点】\n" + summaries.joined(separator: "\n"))
            }

            if !events.isEmpty {
                let summaries: [String] = events.prefix(maxItems).map { e in
                    var line = e.title
                    let date = e.formattedDate
                    if !date.isEmpty { line += "（\(date)）" }
                    if let desc = e.description { line += "：\(desc)" }
                    return line
                }
                parts.append("【相关事件】\n" + summaries.joined(separator: "\n"))
            }

            if !facts.isEmpty {
                let factsText = facts.prefix(maxItems).map { "· \($0.statement)" }.joined(separator: "\n")
                parts.append("【相关事实】\n" + factsText)
            }
        }

        // 无 query 或检索结果为空 → 提供最近摘要
        if parts.isEmpty {
            let recentPeople = graphSnapshot.people
                .filter {
                    canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                        && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
                }
                .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            if !recentPeople.isEmpty {
                let names = recentPeople.prefix(5).map { $0.name }.joined(separator: "、")
                parts.append("【已知人物】您提到过：\(names)等")
            }

            let recentEvents = graphSnapshot.events
                .filter {
                    canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                        && (expectedIdentity == nil || entityIsVisible($0, for: expectedIdentity!))
                }
                .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            if !recentEvents.isEmpty {
                let titles = recentEvents.prefix(5).map { e in
                    let d = e.formattedDate
                    return d.isEmpty ? e.title : "\(d)\(e.title)"
                }.joined(separator: "、")
                parts.append("【已知事件】\(titles)")
            }
        }

        if let contextScope = searchSnapshot.scope,
           !isCurrentSemanticCacheScope(contextScope) {
            return ""
        }
        if parts.isEmpty { return "" }

        return "\n\n=== 用户知识库 ===\n" + parts.joined(separator: "\n\n") +
               "\n请自然地引用上述已知信息，让长辈感受到你记得他/她说过的事。不要逐条播报。"
    }

    private func generationSearchCandidates(
        from graph: KBLiteGraph,
        expectedIdentity: KBPersonaIdentity?,
        canGenerateEntity: (KBPrivacyMetadata?, String?) -> Bool,
        canGenerateFact: (KBFact) -> Bool
    ) -> KBLiteGraph {
        guard let expectedIdentity else { return KBLiteGraph() }
        var candidates = graph
        candidates.people = graph.people.filter {
            canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                && entityIsVisible($0, for: expectedIdentity)
        }
        candidates.places = graph.places.filter {
            canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                && entityIsVisible($0, for: expectedIdentity)
        }
        candidates.events = graph.events.filter {
            canGenerateEntity($0.privacyMetadata, $0.evidenceStatus)
                && entityIsVisible($0, for: expectedIdentity)
        }
        candidates.facts = graph.facts.filter {
            canGenerateFact($0) && entityIsVisible($0, for: expectedIdentity)
        }
        return candidates
    }

    // MARK: - Public API: Image Analysis

    /// 将从图片分析描述中提取的知识加入知识库
    /// - Parameters:
    ///   - result: 图片分析结果
    ///   - sessionId: 当前会话序号
    ///   - sourceAssetId: 对话照片的稳定资源 ID，不得使用本地绝对路径
    func ingestImageAnalysis(
        _ result: KBImageAnalysisResult,
        sessionId: Int,
        sourceAssetId: String
    ) {
        guard let identity = Self.resolveAuthorizedPersonaIdentity(
            for: DigitalHumanContextStore.shared.current
        ) else {
            print("[KBLite] 图片分析缺少授权 persona identity，跳过知识入库")
            return
        }
        guard let accountScope = captureAccountLeaseScope(
            expectedOwnerUserId: identity.ownerUserId,
            at: .request
        ) else { return }
        guard let photoSource = KBKnowledgeSourceIdentityPolicy.conversationPhotoReference(
            assetId: sourceAssetId
        ) else {
            print("[KBLite] 图片分析来源 ID 无效，跳过知识入库")
            return
        }
        let photoPrivacyMetadata = KBPrivacyMetadata.generationAllowed(
            sourceRefs: [photoSource]
        )
        var addedCount = 0
        let now = Date()
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit),
              identity.ownerUserId == loadedUserId else {
            graphLock.unlock()
            return
        }
        let rollbackGraph = graph

        // 场景 → 地点
        if !result.scene.isEmpty {
            let existing = findMatchingPlace(name: result.scene)
            if existing == nil {
                var place = KBPlace(
                    id: UUID().uuidString,
                    name: result.scene,
                    description: result.description,
                    sourceSessionIds: [sessionId],
                    createdAt: now
                )
                place.privacyMetadata = photoPrivacyMetadata
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: [],
                    to: &place
                )
                graph.places.append(place)
                addedCount += 1
            }
        }

        // 检测到的人物 → 尝试添加
        for personDesc in result.detectedPeople {
            // 尝试从描述中提取名字（如 "爷爷"、"奶奶"）
            let name = extractPersonNameFromDescription(personDesc)
            let existing = findMatchingPerson(name: name, aliases: [])
            if existing == nil {
                var person = KBPerson(
                    id: UUID().uuidString,
                    name: name,
                    aliases: [],
                    relation: nil,
                    traits: [],
                    sourceSessionIds: [sessionId],
                    createdAt: now,
                    updatedAt: now
                )
                person.privacyMetadata = photoPrivacyMetadata
                applyIdentity(
                    identity,
                    evidenceStatus: "observed",
                    sourceTurnIndices: [],
                    to: &person
                )
                graph.people.append(person)
                addedCount += 1
            }
        }

        if addedCount > 0 {
            graph.lastUpdated = now
        }
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graph = rollbackGraph
            graphLock.unlock()
            return
        }
        graphLock.unlock()

        if addedCount > 0,
           save(accountScope: accountScope, rollbackGraph: rollbackGraph) {
            print("[KBLite] 🖼️ 图片分析入库: 新增 \(addedCount) 实体")
        }
    }

    /// 从图片人物描述中提取可能的姓名
    private func extractPersonNameFromDescription(_ desc: String) -> String {
        // 尝试匹配常见称谓
        let knownRelations = ["爷爷", "奶奶", "外公", "外婆", "爸爸", "妈妈",
                             "老伴", "儿子", "女儿", "孙子", "孙女"]
        for rel in knownRelations {
            if desc.contains(rel) { return rel }
        }
        // 无法提取具体名字，返回简短描述
        return desc.count <= 6 ? desc : String(desc.prefix(6))
    }

    // MARK: - Boundary Protection

    /// 容量检查：超过上限时清理旧实体
    private func checkCapacity() {
        if graph.facts.count > maxFacts {
            let toRemove = graph.facts.count - maxFacts + 50
            let sorted = graph.facts.sorted { ($0.sourceSessionIds.first ?? 0) < ($1.sourceSessionIds.first ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.facts.removeAll { removed.contains($0.id) }
            warnCapacity("事实", removed: toRemove)
        }
        if graph.people.count > maxPeople {
            let toRemove = graph.people.count - maxPeople + 10
            let sorted = graph.people.sorted { ($0.sourceSessionIds.last ?? 0) < ($1.sourceSessionIds.last ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.facts.removeAll { fact in
                fact.relatedPersonIds.contains(where: { removed.contains($0) })
            }
            graph.people.removeAll { removed.contains($0.id) }
            warnCapacity("人物", removed: toRemove)
        }
        if graph.places.count > maxPlaces {
            let toRemove = graph.places.count - maxPlaces + 10
            let sorted = graph.places.sorted { ($0.sourceSessionIds.last ?? 0) < ($1.sourceSessionIds.last ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.places.removeAll { removed.contains($0.id) }
            warnCapacity("地点", removed: toRemove)
        }
        if graph.events.count > maxEvents {
            let toRemove = graph.events.count - maxEvents + 10
            let sorted = graph.events.sorted { ($0.sourceSessionIds.last ?? 0) < ($1.sourceSessionIds.last ?? 0) }
            let removed = sorted.prefix(toRemove).map { $0.id }
            graph.events.removeAll { removed.contains($0.id) }
            warnCapacity("事件", removed: toRemove)
        }
    }

    private func warnCapacity(_ type: String, removed: Int) {
        if !didWarnCapacity {
            didWarnCapacity = true
            print("[KBLite] ⚠️ 知识库容量告警：\(type)超出上限，已清理 \(removed) 条旧记录")
            print("[KBLite] ⚠️ 当前: 人\(graph.people.count)/\(maxPeople) 地\(graph.places.count)/\(maxPlaces) 事\(graph.events.count)/\(maxEvents) 实\(graph.facts.count)/\(maxFacts)")
        }
    }

    // MARK: - External Save Notification

    /// 外部模块（如 MultiUser）修改图谱后调用此方法持久化
    func notifyGraphUpdated() {
        guard let accountScope = captureAccountLeaseScope(at: .request) else { return }
        save(accountScope: accountScope)
    }

    // MARK: - Maintenance

    /// 重置知识库（调试用 / 用户主动清除）
    func reset() {
        guard let accountScope = captureAccountLeaseScope(at: .request) else { return }
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graphLock.unlock()
            return
        }
        let rollbackGraph = graph
        graph = KBLiteGraph()
        didWarnCapacity = false
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graph = rollbackGraph
            graphLock.unlock()
            return
        }
        graphLock.unlock()
        if save(accountScope: accountScope, rollbackGraph: rollbackGraph) {
            print("[KBLite] 🔄 知识库已重置")
        }
    }

    /// 导出知识库为 JSON 字符串（用于备份/分享）
    func exportJSON() -> String? {
        guard let accountScope = captureAccountLeaseScope(at: .request),
              validateAccountLeaseScope(accountScope, at: .runtime) else {
            return nil
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .runtime) else {
            graphLock.unlock()
            return nil
        }
        let graphSnapshot = graph
        graphLock.unlock()
        guard let data = try? encoder.encode(graphSnapshot),
              validateAccountLeaseScope(accountScope, at: .runtime) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func exportGraphDictionary() -> [String: Any]? {
        exportGraphSnapshot()?.dictionary
    }

    func exportGraphSnapshot() -> KBLiteGraphSnapshot? {
        guard let accountScope = captureAccountLeaseScope(at: .request) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .runtime) else {
            graphLock.unlock()
            return nil
        }
        let snapshot = graph
        let userId = loadedUserId
        graphLock.unlock()
        guard let data = try? encoder.encode(snapshot),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              validateAccountLeaseScope(accountScope, at: .runtime) else {
            return nil
        }
        return KBLiteGraphSnapshot(
            dictionary: object,
            mutationToken: Self.graphMutationToken(data),
            userId: userId
        )
    }

    /// 应用后端 change feed 的最新完整图谱。
    /// 本机无未同步变更时以后端为准（包括可同步实体的删除），但始终保留
    /// localOnly/旧版无授权元数据的本地实体；本机有变更时按 ID 保留本机版本，
    /// 同时吸收后端新增实体，随后由 coordinator 以新 revision 提交合并结果。
    @discardableResult
    func applySyncedGraph(
        _ dictionary: [String: Any],
        preservingLocalChanges: Bool
    ) -> Bool {
        applySyncedGraphCAS(
            dictionary,
            preservingLocalChanges: preservingLocalChanges,
            expectedMutationToken: nil,
            expectedUserId: nil
        ) == .applied
    }

    func applySyncedGraphCAS(
        _ dictionary: [String: Any],
        preservingLocalChanges: Bool,
        expectedMutationToken: UInt64?,
        expectedUserId: String?
    ) -> KBLiteSyncedGraphApplyResult {
        guard let accountScope = captureAccountLeaseScope(
            expectedOwnerUserId: expectedUserId,
            at: .request
        ) else {
            return .staleLocalMutation
        }
        guard JSONSerialization.isValidJSONObject(dictionary),
              let data = try? JSONSerialization.data(withJSONObject: dictionary) else {
            return .invalidGraph
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let imported = try? decoder.decode(KBLiteGraph.self, from: data) else {
            return .invalidGraph
        }
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graphLock.unlock()
            return .staleLocalMutation
        }
        if expectedMutationToken != nil {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let currentData = try? encoder.encode(graph),
                  KnowledgeGraphCASPolicy.canApply(
                      expectedMutationToken: expectedMutationToken,
                      currentMutationToken: Self.graphMutationToken(currentData),
                      expectedUserId: expectedUserId,
                      currentUserId: loadedUserId
                  ) else {
                graphLock.unlock()
                return .staleLocalMutation
            }
        } else if !KnowledgeGraphCASPolicy.canApply(
            expectedMutationToken: nil,
            currentMutationToken: 0,
            expectedUserId: expectedUserId,
            currentUserId: loadedUserId
        ) {
            graphLock.unlock()
            return .staleLocalMutation
        }
        let rollbackGraph = graph
        if preservingLocalChanges {
            let local = graph
            graph = KBLiteGraph(
                version: max(local.version, imported.version),
                lastUpdated: Date(),
                sessionCount: max(local.sessionCount, imported.sessionCount),
                lastBackendExtractionSessionId: local.lastBackendExtractionSessionId,
                lastBackendExtractionAt: local.lastBackendExtractionAt,
                people: preferLocalByID(remote: imported.people, local: local.people, id: { $0.id }),
                places: preferLocalByID(remote: imported.places, local: local.places, id: { $0.id }),
                events: preferLocalByID(remote: imported.events, local: local.events, id: { $0.id }),
                facts: preferLocalByID(remote: imported.facts, local: local.facts, id: { $0.id })
            )
        } else {
            let local = graph
            graph = KBLiteGraph(
                version: max(local.version, imported.version),
                lastUpdated: Date(),
                sessionCount: max(local.sessionCount, imported.sessionCount),
                lastBackendExtractionSessionId: local.lastBackendExtractionSessionId,
                lastBackendExtractionAt: local.lastBackendExtractionAt,
                people: preferLocalByID(
                    remote: imported.people,
                    local: local.people.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                ),
                places: preferLocalByID(
                    remote: imported.places,
                    local: local.places.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                ),
                events: preferLocalByID(
                    remote: imported.events,
                    local: local.events.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                ),
                facts: preferLocalByID(
                    remote: imported.facts,
                    local: local.facts.filter { !isRemotelySyncable($0.privacyMetadata) },
                    id: { $0.id }
                )
            )
        }
        graph.lastUpdated = Date()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graph = rollbackGraph
            graphLock.unlock()
            return .staleLocalMutation
        }
        graphLock.unlock()
        return save(accountScope: accountScope, rollbackGraph: rollbackGraph)
            ? .applied
            : .staleLocalMutation
    }

    private static func graphMutationToken(_ data: Data) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }

    private static func graphMutationToken(for graph: KBLiteGraph) -> UInt64? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(graph) else { return nil }
        return graphMutationToken(data)
    }

    private func preferLocalByID<T>(
        remote: [T],
        local: [T],
        id: (T) -> String
    ) -> [T] {
        var localByID: [String: T] = [:]
        local.forEach { localByID[id($0)] = $0 }
        let remoteIDs = Set(remote.map(id))
        let mergedRemote = remote.map { localByID[id($0)] ?? $0 }
        return mergedRemote + local.filter { !remoteIDs.contains(id($0)) }
    }

    private func isRemotelySyncable(_ metadata: KBPrivacyMetadata?) -> Bool {
        guard let scope = metadata?.scope else { return false }
        return scope == "generationAllowed" || scope == "familyCircle"
    }

    /// 从 JSON 字符串导入知识库（合并模式）
    @discardableResult
    func importJSON(_ jsonString: String) -> Bool {
        guard let accountScope = captureAccountLeaseScope(at: .request) else { return false }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = jsonString.data(using: .utf8),
              let imported = try? decoder.decode(KBLiteGraph.self, from: data) else {
            print("[KBLite] ❌ 导入失败：JSON 解析错误")
            return false
        }
        graphLock.lock()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graphLock.unlock()
            return false
        }
        let rollbackGraph = graph
        let addedCount = mergeGraph(imported)
        graph.lastUpdated = Date()
        guard validateAccountLeaseScopeLocked(accountScope, at: .commit) else {
            graph = rollbackGraph
            graphLock.unlock()
            return false
        }
        graphLock.unlock()
        guard save(accountScope: accountScope, rollbackGraph: rollbackGraph) else { return false }
        print("[KBLite] 📥 导入完成: 新增 \(addedCount) 实体")
        return true
    }

    private func mergeGraph(_ imported: KBLiteGraph) -> Int {
        var addedCount = 0
        for person in imported.people {
            if findMatchingPerson(name: person.name, aliases: person.aliases) == nil {
                graph.people.append(person)
                addedCount += 1
            }
        }
        for place in imported.places {
            if findMatchingPlace(name: place.name) == nil {
                graph.places.append(place)
                addedCount += 1
            }
        }
        for event in imported.events {
            if graph.events.first(where: { $0.title == event.title }) == nil {
                graph.events.append(event)
                addedCount += 1
            }
        }
        for fact in imported.facts {
            if !graph.facts.contains(where: { $0.statement == fact.statement }) {
                graph.facts.append(fact)
                addedCount += 1
            }
        }
        return addedCount
    }

    /// 生成包含知识库上下文的增强开场白提示
    func buildGreetingHint() -> String {
        if isEmpty { return "" }
        var hints: [String] = []
        let recentPeople = graph.people
            .filter { !$0.traits.isEmpty || $0.briefBio != nil }
            .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            .prefix(3)
        if !recentPeople.isEmpty {
            let peopleHints = recentPeople.map { p in
                var h = p.name
                if !p.traits.isEmpty { h += "（\(p.traits.prefix(2).joined(separator: "、"))）" }
                return h
            }
            hints.append("记得：\(peopleHints.joined(separator: "、"))")
        }
        let recentEvents = graph.events
            .filter { $0.year != nil }
            .sorted { ($0.sourceSessionIds.last ?? 0) > ($1.sourceSessionIds.last ?? 0) }
            .prefix(2)
        if !recentEvents.isEmpty {
            let eventHints = recentEvents.map { e in "\(e.formattedDate)\(e.title)" }
            hints.append("事件：\(eventHints.joined(separator: "、"))")
        }
        return hints.isEmpty ? "" : hints.joined(separator: "。")
    }
}
