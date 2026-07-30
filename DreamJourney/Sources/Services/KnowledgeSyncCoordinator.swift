import Foundation

/// 串行协调本地 KBLite 与后端 revision/change-feed，避免 UI 层各自触发网络同步。
final class KnowledgeSyncCoordinator {
    static let shared = KnowledgeSyncCoordinator()

    private let queue = DispatchQueue(label: "com.dreamjourney.knowledge-sync", qos: .utility)
    private let baseStore = KnowledgeRemoteBaseStore()
    private let pendingStore = KnowledgePendingMutationStore()
    private let governanceOutboxStore = KnowledgeGovernanceOutboxStore()
    private let accountLeaseRuntime = AccountLeaseRuntime.shared
    /// QA-only Owner Truth Projection shadow. It owns a separate cache and is
    /// deliberately never passed to the legacy KBLite merge/apply paths below.
    private let ownerTruthKBLiteCompatibilityRuntime = OwnerTruthKBLiteCompatibilityProjectionRuntime()
    private var governanceCompletions: [String: (Result<KBKnowledgeGovernanceResponse, Error>) -> Void] = [:]
    private var activeUserId: String?
    private var activeAccountLease: AccountLease?
    private var syncGeneration = UUID()
    private var isSyncing = false
    private var needsResync = false
    private var debounceWorkItem: DispatchWorkItem?
    private var activePullSessionID: UUID?
    private var snapshotFallbackAttemptedPullSessionID: UUID?
    private var activeSyncAuthorization: KnowledgeSyncAuthorizationScope?
    private var activePersonaIdentity: KBPersonaIdentity?
    private var activeAuthorizationEpoch: UUID?
    private var authorizationEpochState = KnowledgeAuthorizationEpochState()
    private var authorizationOwnerUserId: String?
    private var authorizationPersonaIdentity: KBPersonaIdentity?
    private let authorizationEpochLock = NSLock()
    private let queueIdentityKey = DispatchSpecificKey<UInt8>()
    private let queueIdentityValue: UInt8 = 1

    private init() {
        queue.setSpecific(key: queueIdentityKey, value: queueIdentityValue)
    }

    func userDidChange(to userId: String?) {
        // 必须在 KBLite 切换图谱前同步失效旧 generation，避免已排队的旧用户回调
        // 通过检查后写入新用户文件。
        let authorizationEpoch = rotateAuthorizationEpoch(
            ownerUserId: userId,
            personaIdentity: nil
        )
        performSynchronouslyOnQueue {
            let staleCompletions = Array(self.governanceCompletions.values)
            self.governanceCompletions.removeAll()
            self.ownerTruthKBLiteCompatibilityRuntime.unmount()
            self.activeUserId = userId
            self.activeAccountLease = nil
            self.activeSyncAuthorization = nil
            self.activePersonaIdentity = nil
            self.syncGeneration = UUID()
            self.activeAuthorizationEpoch = authorizationEpoch
            self.isSyncing = false
            self.needsResync = false
            self.activePullSessionID = nil
            self.snapshotFallbackAttemptedPullSessionID = nil
            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = nil
            if !staleCompletions.isEmpty {
                DispatchQueue.main.async {
                    staleCompletions.forEach {
                        $0(.failure(KnowledgeGovernanceCoordinatorError.userChanged))
                    }
                }
            }
        }
        guard userId != nil else { return }
        DispatchQueue.main.async {
            self.synchronizeCurrentUser(reason: "userChanged")
        }
    }

    /// Cancels the old owner's sync runtime without binding or mounting a replacement owner.
    /// Durable pending mutations and governance outbox items remain owner-locked except on deletion.
    @discardableResult
    func teardownForAccountLifecycle(
        context: AccountLifecycleContext
    ) -> AccountLifecycleModuleResult {
        let authorizationEpoch = rotateAuthorizationEpoch(
            ownerUserId: nil,
            personaIdentity: nil
        )
        var result = AccountLifecycleModuleResult.completed(
            .failed,
            remainingLocalData: true,
            detailCode: "knowledgeSyncTeardownNotExecuted"
        )

        performSynchronouslyOnQueue {
            let oldOwner = context.oldAccountLease?.subjectId
            if let activeUserId = self.activeUserId,
               let oldOwner,
               activeUserId != oldOwner {
                result = .completed(
                    .failed,
                    remainingLocalData: true,
                    detailCode: "knowledgeSyncTeardownScopeMismatch"
                )
                return
            }
            if let activeAccountLease = self.activeAccountLease,
               let oldAccountLease = context.oldAccountLease,
               !Self.isSameAccountLeaseGeneration(activeAccountLease, oldAccountLease) {
                result = .completed(
                    .failed,
                    remainingLocalData: true,
                    detailCode: "knowledgeSyncTeardownScopeMismatch"
                )
                return
            }

            self.governanceCompletions.removeAll()
            self.ownerTruthKBLiteCompatibilityRuntime.unmount()
            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = nil
            self.activeUserId = nil
            self.activeAccountLease = nil
            self.activeSyncAuthorization = nil
            self.activePersonaIdentity = nil
            self.syncGeneration = UUID()
            self.activeAuthorizationEpoch = authorizationEpoch
            self.isSyncing = false
            self.needsResync = false
            self.activePullSessionID = nil
            self.snapshotFallbackAttemptedPullSessionID = nil

            switch context.event {
            case .accountDeletion:
                guard let oldOwner, !oldOwner.isEmpty else {
                    result = .completed(
                        .failed,
                        remainingLocalData: true,
                        detailCode: "knowledgeSyncDeletionLeaseUnavailable"
                    )
                    return
                }
                do {
                    try self.baseStore.remove(for: oldOwner)
                    try self.pendingStore.remove(for: oldOwner)
                    try self.governanceOutboxStore.removeAll(for: oldOwner)
                    result = .completed(
                        .purged,
                        remainingLocalData: false,
                        detailCode: "knowledgeSyncDeletionPurged"
                    )
                } catch {
                    result = .completed(
                        .failed,
                        remainingLocalData: true,
                        detailCode: "knowledgeSyncDeletionPurgeFailed"
                    )
                }

            case .coldStartRecovery:
                result = .completed(
                    .unmounted,
                    remainingLocalData: true,
                    detailCode: "knowledgeSyncColdStartUnmounted"
                )

            case .switchAccount:
                result = .completed(
                    .retainedLocked,
                    remainingLocalData: true,
                    detailCode: "knowledgeSyncSwitchRetainedLocked"
                )

            case .logout:
                result = .completed(
                    .retainedLocked,
                    remainingLocalData: true,
                    detailCode: "knowledgeSyncLogoutRetainedLocked"
                )

            case .privateSuspension:
                result = .completed(
                    .retainedLocked,
                    remainingLocalData: true,
                    detailCode: "knowledgeSyncSuspensionRetainedLocked"
                )
            }
        }
        return result
    }

    func personaContextDidChange(to identity: KBPersonaIdentity?) {
        guard let authorizationEpoch = rotateAuthorizationEpochForPersonaChange(identity) else {
            return
        }
        performSynchronouslyOnQueue {
            let authorizedIdentity: KBPersonaIdentity?
            if let identity,
               identity.ownerUserId == self.activeUserId,
               self.activeSyncAuthorization?.allows(identity: identity) == true {
                authorizedIdentity = identity
            } else {
                authorizedIdentity = nil
            }
            self.bindAuthorizationMetadata(
                ownerUserId: self.activeUserId,
                personaIdentity: authorizedIdentity
            )

            let staleCompletions = Array(self.governanceCompletions.values)
            self.governanceCompletions.removeAll()
            self.activePersonaIdentity = authorizedIdentity
            self.syncGeneration = UUID()
            self.activeAuthorizationEpoch = authorizationEpoch
            self.isSyncing = false
            self.needsResync = false
            self.activePullSessionID = nil
            self.snapshotFallbackAttemptedPullSessionID = nil
            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = nil
            if !staleCompletions.isEmpty {
                DispatchQueue.main.async {
                    staleCompletions.forEach {
                        $0(.failure(KnowledgeGovernanceCoordinatorError.invalidSessionOrIdentity))
                    }
                }
            }
        }
    }

    func familyAuthorizationRefreshStarted(ownerUserId: String) {
        let normalizedOwner = ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwner.isEmpty else { return }
        guard let authorizationEpoch = rotateAuthorizationEpochForFamilyRefresh(
            ownerUserId: normalizedOwner
        ) else { return }
        performSynchronouslyOnQueue {
            guard self.activeUserId == normalizedOwner else { return }
            let staleCompletions = Array(self.governanceCompletions.values)
            self.governanceCompletions.removeAll()
            self.activeSyncAuthorization = nil
            self.syncGeneration = UUID()
            self.activeAuthorizationEpoch = authorizationEpoch
            self.isSyncing = false
            self.needsResync = false
            self.activePullSessionID = nil
            self.snapshotFallbackAttemptedPullSessionID = nil
            self.debounceWorkItem?.cancel()
            self.debounceWorkItem = nil
            if !staleCompletions.isEmpty {
                DispatchQueue.main.async {
                    staleCompletions.forEach {
                        $0(.failure(KnowledgeGovernanceCoordinatorError.invalidSessionOrIdentity))
                    }
                }
            }
        }
    }

    func familyAuthorizationDidRefresh(ownerUserId: String, authorizationChanged: Bool) {
        updateFamilyAuthorization(
            ownerUserId: ownerUserId,
            resetRemoteBase: authorizationChanged,
            reason: "familyAuthorizationRefreshed"
        )
    }

    func familyAuthorizationRefreshFailed(ownerUserId: String) {
        updateFamilyAuthorization(
            ownerUserId: ownerUserId,
            resetRemoteBase: true,
            reason: "familyAuthorizationFailed"
        )
    }

    private func updateFamilyAuthorization(
        ownerUserId: String,
        resetRemoteBase: Bool,
        reason: String
    ) {
        let normalizedOwner = ownerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwner.isEmpty else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateFamilyAuthorization(
                    ownerUserId: normalizedOwner,
                    resetRemoteBase: resetRemoteBase,
                    reason: reason
                )
            }
            return
        }
        guard let authorization = makeAccountSyncAuthorization(userId: normalizedOwner) else { return }
        guard let accountLease = captureAccountLease(for: normalizedOwner) else { return }
        let currentPersonaIdentity = KBLiteManager.captureCurrentPersonaAuthorizationSnapshot()?.identity
        bindAuthorizationMetadata(
            ownerUserId: normalizedOwner,
            personaIdentity: currentPersonaIdentity
        )
        let authorizationEpoch = currentAuthorizationEpoch()
        queue.async {
            guard self.activeUserId == normalizedOwner,
                  let context = self.bindAccountLease(accountLease, userId: normalizedOwner),
                  self.isCurrent(context, at: .commit) else {
                return
            }
            self.activeSyncAuthorization = authorization
            self.activeAuthorizationEpoch = authorizationEpoch
            self.activePersonaIdentity = currentPersonaIdentity.flatMap {
                authorization.allows(identity: $0) ? $0 : nil
            }
            if resetRemoteBase {
                guard self.isCurrent(context, at: .commit) else { return }
                try? self.baseStore.remove(for: normalizedOwner)
                guard self.isCurrent(context, at: .commit) else { return }
                try? self.pendingStore.remove(for: normalizedOwner)
            }
            self.enqueueSync(reason: reason, context: context)
        }
    }

    func synchronizeCurrentUser(reason: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.synchronizeCurrentUser(reason: reason)
            }
            return
        }
        guard DreamJourneyBackendClient.shared.isKnowledgeSyncConfigured,
              let userId = UserManager.shared.currentUser?.id,
              BackendAuthSessionStore.shared.currentSession?.userId == userId,
              let authorization = makeAccountSyncAuthorization(userId: userId),
              let accountLease = captureAccountLease(for: userId) else {
            print("[KnowledgeSync] skip reason=missingBackendOrUserSession trigger=\(reason)")
            return
        }
        let currentPersonaIdentity = KBLiteManager.captureCurrentPersonaAuthorizationSnapshot()?.identity
        bindAuthorizationMetadata(ownerUserId: userId, personaIdentity: currentPersonaIdentity)
        let authorizationEpoch = currentAuthorizationEpoch()
        queue.async {
            if self.activeUserId != userId {
                self.activeUserId = userId
                self.activeAccountLease = nil
                self.syncGeneration = UUID()
                self.activeAuthorizationEpoch = authorizationEpoch
                self.isSyncing = false
                self.needsResync = false
                self.activePullSessionID = nil
                self.snapshotFallbackAttemptedPullSessionID = nil
                self.debounceWorkItem?.cancel()
                self.debounceWorkItem = nil
            }
            guard let context = self.bindAccountLease(accountLease, userId: userId) else { return }
            self.activeSyncAuthorization = authorization
            if self.activeAuthorizationEpoch == nil {
                self.activeAuthorizationEpoch = authorizationEpoch
            }
            self.activePersonaIdentity = currentPersonaIdentity.flatMap {
                authorization.allows(identity: $0) ? $0 : nil
            }
            self.ownerTruthKBLiteCompatibilityRuntime.mount(accountLease: context.accountLease)
            self.enqueueSync(reason: reason, context: context)
        }
    }

    /// 将用户知识治理动作先持久化，再与普通图谱同步共用同一串行网络所有权。
    @discardableResult
    func performGovernance(
        action: KBKnowledgeGovernanceAction,
        expectedIdentity: KBPersonaIdentity? = nil,
        operationId: String = "ios-governance-\(UUID().uuidString.lowercased())",
        completion: @escaping (Result<KBKnowledgeGovernanceResponse, Error>) -> Void
    ) -> String {
        let normalizedOperationId = operationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let authorizationSnapshot = KBLiteManager.captureCurrentPersonaAuthorizationSnapshot()
        let identity = expectedIdentity ?? authorizationSnapshot?.identity
        guard DreamJourneyBackendClient.shared.isKnowledgeSyncConfigured,
              let authorizationSnapshot,
              let identity,
              authorizationSnapshot.identity == identity,
              let accountAuthorization = makeAccountSyncAuthorization(userId: identity.ownerUserId),
              accountAuthorization.allows(identity: identity),
              let userId = UserManager.shared.currentUser?.id,
              BackendAuthSessionStore.shared.currentSession?.userId == userId,
              KBLiteManager.shared.loadedUserId == userId,
              identity.ownerUserId == userId,
              let accountLease = captureAccountLease(for: userId) else {
            DispatchQueue.main.async {
                completion(.failure(KnowledgeGovernanceCoordinatorError.invalidSessionOrIdentity))
            }
            return normalizedOperationId
        }

        queue.async {
            do {
                guard self.activeUserId == userId,
                      self.activePersonaIdentity == nil || self.activePersonaIdentity == identity,
                      let context = self.bindAccountLease(accountLease, userId: userId),
                      self.isCurrent(context, at: .commit) else {
                    throw KnowledgeGovernanceCoordinatorError.invalidSessionOrIdentity
                }
                self.activeSyncAuthorization = accountAuthorization
                self.activePersonaIdentity = identity
                let item = KnowledgeGovernanceOutboxItem(
                    operationId: normalizedOperationId,
                    userId: userId,
                    expectedOwnerUserId: identity.ownerUserId,
                    expectedPersonaScope: identity.personaScope,
                    expectedDigitalHumanId: identity.digitalHumanId,
                    action: action,
                    createdAt: Date()
                )
                // Durability is the commit point: never issue the request before this succeeds.
                guard self.isCurrent(context, at: .commit) else { return }
                try self.governanceOutboxStore.enqueue(item, for: userId)
                guard self.isCurrent(context, at: .commit) else { return }
                guard self.governanceCompletions[normalizedOperationId] == nil else {
                    throw KnowledgeSyncModelError.operationPayloadConflict
                }
                self.governanceCompletions[normalizedOperationId] = completion

                if self.isSyncing {
                    self.needsResync = true
                    return
                }
                self.debounceWorkItem?.cancel()
                self.debounceWorkItem = nil
                if self.loadBase(context: context) == nil {
                    self.startSync(context: context, reason: "governanceBootstrap")
                } else {
                    _ = self.startNextGovernance(context: context)
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
                        return
                    }
                    completion(.failure(error))
                }
            }
        }
        return normalizedOperationId
    }

    func pendingGovernanceCount(completion: @escaping (Int) -> Void) {
        queue.async {
            guard let userId = self.activeUserId,
                  let accountLease = self.activeAccountLease else {
                DispatchQueue.main.async { completion(0) }
                return
            }
            let context = KnowledgeSyncLeaseContext(
                userId: userId,
                generation: self.syncGeneration,
                accountLease: accountLease
            )
            guard self.isCurrent(context, at: .request) else { return }
            let count = self.loadGovernanceOutbox(context: context).count
            DispatchQueue.main.async {
                guard self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
                completion(count)
            }
        }
    }

    private func enqueueSync(reason: String, context: KnowledgeSyncLeaseContext) {
        guard isCurrent(context, at: .request) else { return }
        if isSyncing {
            needsResync = true
            return
        }
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isCurrent(context, at: .timer) else { return }
            self.startSync(context: context, reason: reason)
        }
        debounceWorkItem = workItem
        queue.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func startSync(context: KnowledgeSyncLeaseContext, reason: String) {
        guard isCurrent(context, at: .request), !isSyncing else { return }
        let userId = context.userId
        isSyncing = true
        let revision = loadBase(context: context)?.revision ?? 0
        print("[KnowledgeSync] start user=\(userId) revision=\(revision) reason=\(reason)")
        beginKnowledgePull(
            context: context,
            startRevision: revision,
            retryLocalMutationOnConflict: true,
            allowLegacyEndpointFallback: true
        )
    }

    @discardableResult
    private func startNextGovernance(context: KnowledgeSyncLeaseContext) -> Bool {
        guard isCurrent(context, at: .request), !isSyncing,
              let base = loadBase(context: context) else {
            return false
        }
        let userId = context.userId
        guard let authorization = currentSyncAuthorization(userId: userId),
              let currentIdentity = activePersonaIdentity,
              authorization.allows(identity: currentIdentity),
              let item = loadGovernanceOutbox(context: context).first(where: {
                  !$0.isQuarantined && $0.expectedIdentity == currentIdentity
              }) else {
            return false
        }

        guard isCurrent(context, at: .request) else { return false }
        isSyncing = true
        print(
            "[KnowledgeSync] governanceStart user=\(userId) operation=\(item.operationId) "
                + "action=\(item.action.kind.rawValue) revision=\(base.revision)"
        )
        DreamJourneyBackendClient.shared.governKnowledge(
            userId: userId,
            operationId: item.operationId,
            baseRevision: base.revision,
            action: item.action
        ) { [weak self] result in
            self?.queue.async {
                guard let self,
                      self.isCurrent(context, at: .commit) else {
                    return
                }
                switch result {
                case .success(let response):
                    self.handleGovernanceSuccess(
                        response,
                        item: item,
                        previousBase: base,
                        context: context
                    )
                case .failure(let error):
                    if Self.isOperationPayloadConflict(error) {
                        self.handleGovernancePayloadConflict(
                            error,
                            item: item,
                            context: context
                        )
                    } else if Self.isRevisionConflict(error) {
                        // Keep the durable item and operation ID; refresh the base before retrying.
                        self.isSyncing = false
                        self.enqueueSync(reason: "governanceRevisionConflict", context: context)
                    } else {
                        self.completeGovernance(
                            item.operationId,
                            result: .failure(error),
                            context: context
                        )
                        self.finishGovernance(
                            context: context,
                            error: error,
                            continueDraining: false
                        )
                    }
                }
            }
        }
        return true
    }

    private func handleGovernancePayloadConflict(
        _ error: Error,
        item: KnowledgeGovernanceOutboxItem,
        context: KnowledgeSyncLeaseContext
    ) {
        guard isCurrent(context, at: .commit) else { return }
        let userId = context.userId
        do {
            if item.recoveryCount == 0 {
                let nextOperationId = "ios-governance-\(UUID().uuidString.lowercased())"
                let replacement = item.rotatingOperation(to: nextOperationId)
                guard isCurrent(context, at: .commit) else { return }
                try governanceOutboxStore.replace(
                    operationId: item.operationId,
                    with: replacement,
                    for: userId
                )
                guard isCurrent(context, at: .commit) else { return }
                if let completion = governanceCompletions.removeValue(forKey: item.operationId) {
                    governanceCompletions[nextOperationId] = completion
                }
                print(
                    "[KnowledgeSync] governanceOperationRotated user=\(userId) "
                        + "recoveryCount=\(replacement.recoveryCount)"
                )
                isSyncing = false
                enqueueSync(reason: "governanceOperationPayloadConflict", context: context)
                return
            }

            let quarantined = item.quarantined(reason: "knowledgeOperationPayloadConflict")
            guard isCurrent(context, at: .commit) else { return }
            try governanceOutboxStore.replace(
                operationId: item.operationId,
                with: quarantined,
                for: userId
            )
            guard isCurrent(context, at: .commit) else { return }
            print(
                "[KnowledgeSync] governanceOperationQuarantined user=\(userId) "
                    + "recoveryCount=\(quarantined.recoveryCount)"
            )
            completeGovernance(item.operationId, result: .failure(error), context: context)
            finishGovernance(
                context: context,
                error: error,
                continueDraining: true
            )
        } catch {
            completeGovernance(item.operationId, result: .failure(error), context: context)
            finishGovernance(
                context: context,
                error: error,
                continueDraining: false
            )
        }
    }

    private func handleGovernanceSuccess(
        _ response: KBKnowledgeGovernanceResponse,
        item: KnowledgeGovernanceOutboxItem,
        previousBase: KnowledgeRemoteBaseSnapshot,
        context: KnowledgeSyncLeaseContext
    ) {
        guard isCurrent(context, at: .commit) else { return }
        let userId = context.userId
        guard let authorization = currentSyncAuthorization(userId: userId),
              activePersonaIdentity == item.expectedIdentity,
              authorization.allows(identity: item.expectedIdentity) else {
            completeGovernance(
                item.operationId,
                result: .failure(KnowledgeGovernanceCoordinatorError.invalidSessionOrIdentity),
                context: context
            )
            isSyncing = false
            return
        }

        let remote = KnowledgeRemoteBaseSnapshot(revision: response.revision, graph: response.graph)
        guard applyAuthoritativeRemote(remote, previousBase: previousBase, context: context) else {
            let error = KnowledgeGovernanceCoordinatorError.authoritativeApplyFailed
            completeGovernance(item.operationId, result: .failure(error), context: context)
            finishGovernance(
                context: context,
                error: error,
                continueDraining: false
            )
            return
        }
        do {
            // Remove only after the authoritative graph and revision are durable locally.
            guard isCurrent(context, at: .commit) else { return }
            try governanceOutboxStore.remove(operationId: item.operationId, for: userId)
            guard isCurrent(context, at: .commit) else { return }
            completeGovernance(item.operationId, result: .success(response), context: context)
            finishGovernance(
                context: context,
                error: nil,
                continueDraining: true
            )
        } catch {
            completeGovernance(item.operationId, result: .failure(error), context: context)
            finishGovernance(
                context: context,
                error: error,
                continueDraining: false
            )
        }
    }

    private func finishGovernance(
        context: KnowledgeSyncLeaseContext,
        error: Error?,
        continueDraining: Bool
    ) {
        guard isCurrent(context, at: .commit) else { return }
        let userId = context.userId
        isSyncing = false
        if let error {
            print("[KnowledgeSync] governanceFailed user=\(userId) error=\(error.localizedDescription)")
        } else {
            print("[KnowledgeSync] governanceCompleted user=\(userId)")
        }
        if continueDraining, startNextGovernance(context: context) {
            return
        }
        if needsResync {
            needsResync = false
            enqueueSync(reason: "governanceCoalescedUpdate", context: context)
        }
    }

    private func completeGovernance(
        _ operationId: String,
        result: Result<KBKnowledgeGovernanceResponse, Error>,
        context: KnowledgeSyncLeaseContext
    ) {
        guard isCurrent(context, at: .commit) else { return }
        guard let completion = governanceCompletions.removeValue(forKey: operationId) else { return }
        DispatchQueue.main.async {
            guard self.isCurrent(context, at: .ui) else { return }
            completion(result)
        }
    }

    private func beginKnowledgePull(
        context: KnowledgeSyncLeaseContext,
        startRevision: Int,
        retryLocalMutationOnConflict: Bool,
        allowLegacyEndpointFallback: Bool
    ) {
        guard isCurrent(context, at: .request) else { return }
        let pullSessionID = UUID()
        activePullSessionID = pullSessionID
        snapshotFallbackAttemptedPullSessionID = nil
        pullNextKnowledgePage(
            context: context,
            pullSessionID: pullSessionID,
            reducer: KnowledgeChangeFeedReducer(startRevision: startRevision),
            retryLocalMutationOnConflict: retryLocalMutationOnConflict,
            allowLegacyEndpointFallback: allowLegacyEndpointFallback
        )
    }

    private func pullNextKnowledgePage(
        context: KnowledgeSyncLeaseContext,
        pullSessionID: UUID,
        reducer: KnowledgeChangeFeedReducer,
        retryLocalMutationOnConflict: Bool,
        allowLegacyEndpointFallback: Bool
    ) {
        guard isCurrent(context, at: .request),
              activePullSessionID == pullSessionID else {
            return
        }
        let userId = context.userId
        DreamJourneyBackendClient.shared.fetchKnowledgeChanges(
            userId: userId,
            sinceRevision: reducer.nextSinceRevision,
            targetRevision: reducer.targetRevision
        ) { [weak self] result in
            self?.queue.async {
                guard let self,
                      self.isCurrent(context, at: .commit),
                      self.isCurrentPull(
                          context: context,
                          pullSessionID: pullSessionID,
                          at: .commit
                      ) else {
                    return
                }
                switch result {
                case .success(let page):
                    do {
                        var nextReducer = reducer
                        let reduction = try nextReducer.consume(page)
                        if !reduction.isTerminal {
                            self.pullNextKnowledgePage(
                                context: context,
                                pullSessionID: pullSessionID,
                                reducer: nextReducer,
                                retryLocalMutationOnConflict: retryLocalMutationOnConflict,
                                allowLegacyEndpointFallback: allowLegacyEndpointFallback
                            )
                            return
                        }

                        self.activePullSessionID = nil
                        guard self.commitKnowledgePull(
                            reduction,
                            context: context
                        ) else {
                            self.finishSync(
                                context: context,
                                error: KnowledgeSyncError.invalidChangeFeed
                            )
                            return
                        }
                        self.pushLocalGraph(
                            context: context,
                            retryOnConflict: retryLocalMutationOnConflict
                        )
                    } catch {
                        self.activePullSessionID = nil
                        self.finishSync(context: context, error: error)
                    }
                case .failure(let error):
                    if Self.shouldRecoverCompactedChangeFeed(error) {
                        self.recoverCompactedKnowledgeFeed(
                            context: context,
                            pullSessionID: pullSessionID,
                            retryLocalMutationOnConflict: retryLocalMutationOnConflict
                        )
                    } else if allowLegacyEndpointFallback,
                       reducer.pageCount == 0,
                       Self.isUnsupportedEndpoint(error) {
                        self.activePullSessionID = nil
                        self.pushLegacySnapshot(context: context)
                    } else {
                        self.activePullSessionID = nil
                        self.finishSync(context: context, error: error)
                    }
                }
            }
        }
    }

    private func recoverCompactedKnowledgeFeed(
        context: KnowledgeSyncLeaseContext,
        pullSessionID: UUID,
        retryLocalMutationOnConflict: Bool
    ) {
        guard isCurrent(context, at: .request),
              isCurrentPull(
                  context: context,
                  pullSessionID: pullSessionID,
                  at: .request
              ) else {
            return
        }
        guard snapshotFallbackAttemptedPullSessionID != pullSessionID else {
            activePullSessionID = nil
            finishSync(
                context: context,
                error: KnowledgeSyncError.invalidChangeFeed
            )
            return
        }
        snapshotFallbackAttemptedPullSessionID = pullSessionID
        let previousBase = loadBase(context: context)
        guard isCurrent(context, at: .request) else { return }
        let userId = context.userId
        DreamJourneyBackendClient.shared.fetchKnowledgeSnapshot(userId: userId) { [weak self] result in
            self?.queue.async {
                guard let self,
                      self.isCurrent(context, at: .commit),
                      self.isCurrentPull(
                          context: context,
                          pullSessionID: pullSessionID,
                          at: .commit
                      ),
                      self.snapshotFallbackAttemptedPullSessionID == pullSessionID else {
                    return
                }
                switch result {
                case .success(let response):
                    let minimumRevision = previousBase?.revision ?? 0
                    guard response.revision >= minimumRevision,
                          self.applyAuthoritativeRemote(
                              KnowledgeRemoteBaseSnapshot(
                                  revision: response.revision,
                                  graph: response.graph
                              ),
                              previousBase: previousBase,
                              context: context
                          ) else {
                        self.activePullSessionID = nil
                        self.finishSync(
                            context: context,
                            error: KnowledgeSyncError.invalidSnapshotResponse
                        )
                        return
                    }
                    self.activePullSessionID = nil
                    self.pushLocalGraph(
                        context: context,
                        retryOnConflict: retryLocalMutationOnConflict
                    )
                case .failure(let error):
                    self.activePullSessionID = nil
                    self.finishSync(context: context, error: error)
                }
            }
        }
    }

    private func commitKnowledgePull(
        _ reduction: KnowledgeChangeFeedReduction,
        context: KnowledgeSyncLeaseContext
    ) -> Bool {
        guard isCurrent(context, at: .commit) else { return false }
        let userId = context.userId
        let existingBase = loadBase(context: context)
        if let remote = reduction.authoritativeSnapshot {
            return remote.revision == reduction.targetRevision
                && applyAuthoritativeRemote(
                    remote,
                    previousBase: existingBase,
                    context: context
                )
        }
        if let existingBase {
            return existingBase.revision == reduction.targetRevision
        }
        guard reduction.targetRevision == 0,
              let localSnapshot = KBLiteManager.shared.exportGraphSnapshot(),
              localSnapshot.userId == userId else {
            return false
        }
        return applyAuthoritativeRemote(
            KnowledgeRemoteBaseSnapshot(
                revision: 0,
                graph: Self.emptyRemoteGraph(localMetadata: localSnapshot.dictionary)
            ),
            previousBase: nil,
            context: context
        )
    }

    private func applyAuthoritativeRemote(
        _ remote: KnowledgeRemoteBaseSnapshot,
        previousBase: KnowledgeRemoteBaseSnapshot?,
        context: KnowledgeSyncLeaseContext
    ) -> Bool {
        let userId = context.userId
        for attempt in 1...3 {
            guard isCurrent(context, at: .commit),
                  KBLiteManager.shared.loadedUserId == userId,
                  let localSnapshot = KBLiteManager.shared.exportGraphSnapshot(),
                  localSnapshot.userId == userId,
                  let authorization = currentSyncAuthorization(userId: userId) else {
                return false
            }
            do {
                let result: KnowledgeSyncMergeResult
                if let previousBase {
                    result = try KnowledgeSyncGraphEngine.merge(
                        base: previousBase.graph,
                        local: localSnapshot.dictionary,
                        remote: remote.graph,
                        authorization: authorization
                    )
                } else {
                    result = try KnowledgeSyncGraphEngine.bootstrap(
                        local: localSnapshot.dictionary,
                        remote: remote.graph,
                        authorization: authorization
                    )
                }
                guard isCurrent(context, at: .commit) else { return false }
                switch KBLiteManager.shared.applySyncedGraphCAS(
                    result.graph,
                    preservingLocalChanges: false,
                    expectedMutationToken: localSnapshot.mutationToken,
                    expectedUserId: userId
                ) {
                case .applied:
                    guard isCurrent(context, at: .commit) else { return false }
                    let authorizedRemoteGraph = try KnowledgeSyncGraphEngine.syncPayloadGraph(
                        from: remote.graph,
                        authorization: authorization
                    )
                    guard isCurrent(context, at: .commit) else { return false }
                    try baseStore.save(
                        KnowledgeRemoteBaseSnapshot(
                            revision: remote.revision,
                            graph: authorizedRemoteGraph
                        ),
                        for: userId
                    )
                    guard isCurrent(context, at: .commit) else { return false }
                    try? pendingStore.remove(for: userId)
                    guard isCurrent(context, at: .commit) else { return false }
                    if !result.conflicts.isEmpty {
                        // Do not log entity content. This summary is QA-only type/ID evidence.
                        print("[KnowledgeSync] threeWayConflicts \(result.qaConflictSummary)")
                    }
                    return true
                case .staleLocalMutation:
                    print("[KnowledgeSync] localGraphChangedDuringCommit user=\(userId) attempt=\(attempt)")
                    continue
                case .invalidGraph:
                    return false
                }
            } catch {
                print("[KnowledgeSync] authoritativeMergeFailed user=\(userId) error=\(error.localizedDescription)")
                return false
            }
        }
        print("[KnowledgeSync] authoritativeCommitCASExhausted user=\(userId)")
        return false
    }

    private func pushLocalGraph(context: KnowledgeSyncLeaseContext, retryOnConflict: Bool) {
        guard isCurrent(context, at: .request) else { return }
        let userId = context.userId
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary(),
              let base = loadBase(context: context),
              let authorization = currentSyncAuthorization(userId: userId) else {
            finishSync(context: context, error: KnowledgeSyncError.missingRemoteBase)
            return
        }

        let pending: KnowledgePendingMutation
        do {
            let syncableGraph = try KnowledgeSyncGraphEngine.syncPayloadGraph(
                from: localGraph,
                authorization: authorization
            )
            guard let fingerprint = KnowledgeSyncGraphEngine.fingerprint(of: syncableGraph) else {
                throw KnowledgeSyncError.invalidLocalGraph
            }
            if let stored = loadPending(context: context),
               stored.baseRevision == base.revision,
               stored.localFingerprint == fingerprint,
               Self.mutationComponents(from: stored.payload) != nil {
                pending = stored
            } else {
                let deletedAt = Self.isoTimestamp(Date())
                let delta = try KnowledgeSyncGraphEngine.makeDelta(
                    base: base.graph,
                    local: localGraph,
                    deletedAt: deletedAt,
                    authorization: authorization
                )
                if delta.isEmpty {
                    guard isCurrent(context, at: .commit) else { return }
                    try? pendingStore.remove(for: userId)
                    finishSync(context: context, error: nil)
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
                guard isCurrent(context, at: .commit) else { return }
                try pendingStore.save(created, for: userId)
                guard isCurrent(context, at: .commit) else { return }
                pending = created
            }
        } catch {
            guard isCurrent(context, at: .commit) else { return }
            finishSync(context: context, error: error)
            return
        }

        guard let components = Self.mutationComponents(from: pending.payload) else {
            finishSync(context: context, error: KnowledgeSyncError.invalidPendingMutation)
            return
        }
        guard isCurrent(context, at: .request) else { return }
        DreamJourneyBackendClient.shared.mutateKnowledgeV2(
            userId: userId,
            upserts: components.upserts,
            tombstones: components.tombstones,
            operationId: pending.operationId,
            baseRevision: pending.baseRevision
        ) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(context, at: .commit) else { return }
                switch result {
                case .success(let object):
                    guard let snapshot = KnowledgeMutationV2Contract.authoritativeSnapshot(from: object),
                          self.applyAuthoritativeRemote(
                              snapshot,
                              previousBase: base,
                              context: context
                          ) else {
                        self.finishSync(
                            context: context,
                            error: KnowledgeSyncError.invalidMutationResponse
                        )
                        return
                    }
                    self.finishSync(context: context, error: nil)
                case .failure(let error):
                    if Self.isOperationPayloadConflict(error) {
                        self.recoverPendingOperationConflict(
                            context: context,
                            error: error
                        )
                    } else if retryOnConflict, Self.isRevisionConflict(error) {
                        self.refreshAfterConflict(context: context)
                    } else if Self.shouldFallbackV2(error) {
                        self.pushLegacyMutation(
                            context: context,
                            retryOnConflict: retryOnConflict
                        )
                    } else {
                        self.finishSync(context: context, error: error)
                    }
                }
            }
        }
    }

    private func recoverPendingOperationConflict(
        context: KnowledgeSyncLeaseContext,
        error: Error
    ) {
        guard isCurrent(context, at: .commit) else { return }
        let userId = context.userId
        do {
            try pendingStore.remove(for: userId)
            print("[KnowledgeSync] pendingOperationDiscarded user=\(userId) reason=payloadConflict")
            refreshAfterConflict(context: context)
        } catch {
            finishSync(context: context, error: error)
        }
    }

    private func refreshAfterConflict(context: KnowledgeSyncLeaseContext) {
        beginKnowledgePull(
            context: context,
            startRevision: 0,
            retryLocalMutationOnConflict: false,
            allowLegacyEndpointFallback: false
        )
    }

    private func pushLegacyMutation(
        context: KnowledgeSyncLeaseContext,
        retryOnConflict: Bool
    ) {
        guard isCurrent(context, at: .request) else { return }
        let userId = context.userId
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary(),
              let authorization = currentSyncAuthorization(userId: userId) else {
            finishSync(context: context, error: KnowledgeSyncError.invalidLocalGraph)
            return
        }
        let graph: [String: Any]
        do {
            graph = try KnowledgeSyncGraphEngine.syncPayloadGraph(
                from: localGraph,
                authorization: authorization
            )
        } catch {
            finishSync(context: context, error: error)
            return
        }
        let baseRevision = loadBase(context: context)?.revision ?? 0
        let operationId = loadPending(context: context)?.operationId
            ?? "ios-v1-\(UUID().uuidString.lowercased())"
        guard isCurrent(context, at: .request) else { return }
        DreamJourneyBackendClient.shared.mutateKnowledge(
            userId: userId,
            graph: graph,
            operationId: operationId,
            baseRevision: baseRevision
        ) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(context, at: .commit) else { return }
                switch result {
                case .success(let object):
                    let revision = Self.intValue(object["revision"])
                    guard self.saveLegacyBase(graph: graph, revision: revision, context: context) else {
                        self.finishSync(context: context, error: KnowledgeSyncError.basePersistenceFailed)
                        return
                    }
                    self.finishSync(context: context, error: nil)
                case .failure(let error):
                    if Self.isOperationPayloadConflict(error) {
                        self.recoverPendingOperationConflict(
                            context: context,
                            error: error
                        )
                    } else if retryOnConflict, Self.isRevisionConflict(error) {
                        self.refreshAfterConflict(context: context)
                    } else if Self.isUnsupportedEndpoint(error) {
                        self.pushLegacySnapshot(context: context)
                    } else {
                        self.finishSync(context: context, error: error)
                    }
                }
            }
        }
    }

    private func pushLegacySnapshot(context: KnowledgeSyncLeaseContext) {
        guard isCurrent(context, at: .request) else { return }
        let userId = context.userId
        guard KBLiteManager.shared.loadedUserId == userId,
              let localGraph = KBLiteManager.shared.exportGraphDictionary(),
              let authorization = currentSyncAuthorization(userId: userId) else {
            finishSync(context: context, error: KnowledgeSyncError.invalidLocalGraph)
            return
        }
        let graph: [String: Any]
        do {
            graph = try KnowledgeSyncGraphEngine.syncPayloadGraph(
                from: localGraph,
                authorization: authorization
            )
        } catch {
            finishSync(context: context, error: error)
            return
        }
        guard isCurrent(context, at: .request) else { return }
        DreamJourneyBackendClient.shared.syncKnowledge(userId: userId, graph: graph) { [weak self] result in
            self?.queue.async {
                guard let self, self.isCurrent(context, at: .commit) else { return }
                switch result {
                case .success(let object):
                    let revision = Self.intValue(object["revision"])
                    guard self.saveLegacyBase(graph: graph, revision: revision, context: context) else {
                        self.finishSync(context: context, error: KnowledgeSyncError.basePersistenceFailed)
                        return
                    }
                    self.finishSync(context: context, error: nil)
                case .failure(let error):
                    self.finishSync(context: context, error: error)
                }
            }
        }
    }

    private func saveLegacyBase(
        graph: [String: Any],
        revision: Int,
        context: KnowledgeSyncLeaseContext
    ) -> Bool {
        guard isCurrent(context, at: .commit) else { return false }
        let userId = context.userId
        do {
            try baseStore.save(
                KnowledgeRemoteBaseSnapshot(revision: max(0, revision), graph: graph),
                for: userId
            )
            guard isCurrent(context, at: .commit) else { return false }
            try? pendingStore.remove(for: userId)
            return isCurrent(context, at: .commit)
        } catch {
            print("[KnowledgeSync] legacyBaseSaveFailed user=\(userId) error=\(error.localizedDescription)")
            return false
        }
    }

    private func finishSync(context: KnowledgeSyncLeaseContext, error: Error?) {
        guard isCurrent(context, at: .commit) else { return }
        let userId = context.userId
        activePullSessionID = nil
        snapshotFallbackAttemptedPullSessionID = nil
        isSyncing = false
        if let error {
            print("[KnowledgeSync] failed user=\(userId) error=\(error.localizedDescription)")
        } else {
            print("[KnowledgeSync] completed user=\(userId) revision=\(loadBase(context: context)?.revision ?? 0)")
            if startNextGovernance(context: context) {
                return
            }
        }
        if needsResync {
            needsResync = false
            enqueueSync(reason: "coalescedUpdate", context: context)
        }
    }

    private func currentSyncAuthorization(userId: String) -> KnowledgeSyncAuthorizationScope? {
        guard activeSyncAuthorization?.ownerUserId == userId,
              activeSyncAuthorization?.isComplete == true else {
            return nil
        }
        return activeSyncAuthorization
    }

    private func makeAccountSyncAuthorization(userId: String) -> KnowledgeSyncAuthorizationScope? {
        guard Thread.isMainThread, UserManager.shared.currentUser?.id == userId else { return nil }
        let personalIdentity = KBPersonaIdentity(
            ownerUserId: userId,
            personaScope: "personal",
            digitalHumanId: userId
        )
        let familyIdentities = FamilyRepository.shared.acceptedMembersForKnowledgeSync(ownerUserId: userId).map { member in
            let digitalHumanId = member.digitalHumanId
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return KBPersonaIdentity(
                ownerUserId: userId,
                personaScope: "family",
                digitalHumanId: digitalHumanId.isEmpty ? member.id : digitalHumanId
            )
        }
        let authorization = KnowledgeSyncAuthorizationScope(
            identity: personalIdentity,
            additionalIdentities: familyIdentities
        )
        return authorization.isComplete ? authorization : nil
    }

    private func captureAccountLease(for userId: String) -> AccountLease? {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: userId),
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        return accountLease
    }

    private func bindAccountLease(
        _ accountLease: AccountLease,
        userId: String
    ) -> KnowledgeSyncLeaseContext? {
        guard activeUserId == userId,
              accountLease.subjectId == userId,
              accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        if let activeAccountLease,
           !Self.isSameAccountLeaseGeneration(activeAccountLease, accountLease) {
            ownerTruthKBLiteCompatibilityRuntime.unmount()
            governanceCompletions.removeAll()
            syncGeneration = UUID()
            isSyncing = false
            needsResync = false
            activePullSessionID = nil
            snapshotFallbackAttemptedPullSessionID = nil
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
        }
        activeAccountLease = accountLease
        return KnowledgeSyncLeaseContext(
            userId: userId,
            generation: syncGeneration,
            accountLease: accountLease
        )
    }

    private func isCurrent(
        _ context: KnowledgeSyncLeaseContext,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        guard isCurrent(userId: context.userId, generation: context.generation),
              context.accountLease.subjectId == context.userId,
              activeAccountLease.map({
                  Self.isSameAccountLeaseGeneration($0, context.accountLease)
              }) == true,
              accountLeaseRuntime.validate(context.accountLease, at: checkpoint).allowed else {
            return false
        }
        return true
    }

    private func isCurrent(userId: String, generation: UUID) -> Bool {
        guard activeUserId == userId, syncGeneration == generation else { return false }
        authorizationEpochLock.lock()
        defer { authorizationEpochLock.unlock() }
        return authorizationEpochState.accepts(boundEpoch: activeAuthorizationEpoch)
    }

    private static func isSameAccountLeaseGeneration(
        _ lhs: AccountLease,
        _ rhs: AccountLease
    ) -> Bool {
        lhs.subjectId == rhs.subjectId
            && lhs.vaultId == rhs.vaultId
            && lhs.generation == rhs.generation
            && lhs.generationId == rhs.generationId
            && lhs.authorityEpoch == rhs.authorityEpoch
    }

    private func rotateAuthorizationEpoch(
        ownerUserId: String?,
        personaIdentity: KBPersonaIdentity?
    ) -> UUID {
        authorizationEpochLock.lock()
        defer { authorizationEpochLock.unlock() }
        authorizationOwnerUserId = ownerUserId
        authorizationPersonaIdentity = personaIdentity
        return authorizationEpochState.rotate()
    }

    private func rotateAuthorizationEpochForPersonaChange(
        _ identity: KBPersonaIdentity?
    ) -> UUID? {
        authorizationEpochLock.lock()
        defer { authorizationEpochLock.unlock() }
        guard authorizationPersonaIdentity != identity else { return nil }
        authorizationPersonaIdentity = identity
        return authorizationEpochState.rotate()
    }

    private func rotateAuthorizationEpochForFamilyRefresh(ownerUserId: String) -> UUID? {
        authorizationEpochLock.lock()
        defer { authorizationEpochLock.unlock() }
        guard authorizationOwnerUserId == ownerUserId else { return nil }
        return authorizationEpochState.rotate()
    }

    private func bindAuthorizationMetadata(
        ownerUserId: String?,
        personaIdentity: KBPersonaIdentity?
    ) {
        authorizationEpochLock.lock()
        authorizationOwnerUserId = ownerUserId
        authorizationPersonaIdentity = personaIdentity
        authorizationEpochLock.unlock()
    }

    private func currentAuthorizationEpoch() -> UUID {
        authorizationEpochLock.lock()
        defer { authorizationEpochLock.unlock() }
        return authorizationEpochState.currentEpoch
    }

    private func performSynchronouslyOnQueue(_ block: () -> Void) {
        if DispatchQueue.getSpecific(key: queueIdentityKey) == queueIdentityValue {
            block()
        } else {
            queue.sync(execute: block)
        }
    }

    private func isCurrentPull(
        context: KnowledgeSyncLeaseContext,
        pullSessionID: UUID,
        at checkpoint: AccountLeaseCheckpoint
    ) -> Bool {
        isCurrent(context, at: checkpoint)
            && activePullSessionID == pullSessionID
            && isSyncing
    }

    private func loadBase(context: KnowledgeSyncLeaseContext) -> KnowledgeRemoteBaseSnapshot? {
        guard isCurrent(context, at: .request) else { return nil }
        let userId = context.userId
        do {
            return try baseStore.load(for: userId)
        } catch {
            print("[KnowledgeSync] invalidBaseRemoved user=\(userId) error=\(error.localizedDescription)")
            guard isCurrent(context, at: .commit) else { return nil }
            try? baseStore.remove(for: userId)
            guard isCurrent(context, at: .commit) else { return nil }
            try? pendingStore.remove(for: userId)
            return nil
        }
    }

    private func loadPending(context: KnowledgeSyncLeaseContext) -> KnowledgePendingMutation? {
        guard isCurrent(context, at: .request) else { return nil }
        let userId = context.userId
        do {
            return try pendingStore.load(for: userId)
        } catch {
            print("[KnowledgeSync] invalidPendingRemoved user=\(userId) error=\(error.localizedDescription)")
            guard isCurrent(context, at: .commit) else { return nil }
            try? pendingStore.remove(for: userId)
            return nil
        }
    }

    private func loadGovernanceOutbox(
        context: KnowledgeSyncLeaseContext
    ) -> [KnowledgeGovernanceOutboxItem] {
        guard isCurrent(context, at: .request) else { return [] }
        let userId = context.userId
        do {
            return try governanceOutboxStore.load(for: userId)
        } catch {
            print("[KnowledgeSync] invalidGovernanceOutboxRemoved user=\(userId) error=\(error.localizedDescription)")
            guard isCurrent(context, at: .commit) else { return [] }
            try? governanceOutboxStore.removeAll(for: userId)
            return []
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
              case .backendError(let statusCode, let context) = clientError else {
            return false
        }
        return KnowledgeMutationV2FallbackPolicy.shouldFallback(
            statusCode: statusCode,
            detail: context.detail
        )
    }

    private static func isUnsupportedEndpoint(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, _) = clientError else {
            return false
        }
        return statusCode == 404 || statusCode == 405
    }

    private static func shouldRecoverCompactedChangeFeed(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, let context) = clientError else {
            return false
        }
        return KnowledgeChangeFeedRecoveryPolicy.shouldFetchSnapshot(
            statusCode: statusCode,
            detailCode: context.code
        )
    }

    private static func isRevisionConflict(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, let context) = clientError else {
            return false
        }
        return statusCode == 409 && context.code == "knowledgeRevisionConflict"
    }

    private static func isOperationPayloadConflict(_ error: Error) -> Bool {
        guard let clientError = error as? DreamJourneyBackendClient.ClientError,
              case .backendError(let statusCode, let context) = clientError else {
            return false
        }
        return statusCode == 409 && context.code == "knowledgeOperationPayloadConflict"
    }
}

private struct KnowledgeSyncLeaseContext: Sendable {
    let userId: String
    let generation: UUID
    let accountLease: AccountLease
}

private enum KnowledgeSyncError: LocalizedError {
    case invalidChangeFeed
    case invalidSnapshotResponse
    case invalidLocalGraph
    case missingRemoteBase
    case invalidPendingMutation
    case invalidMutationResponse
    case basePersistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalidChangeFeed:
            return "知识增量响应无法安全应用"
        case .invalidSnapshotResponse:
            return "知识快照响应无法安全应用"
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

private enum KnowledgeGovernanceCoordinatorError: LocalizedError {
    case invalidSessionOrIdentity
    case authoritativeApplyFailed
    case userChanged

    var errorDescription: String? {
        switch self {
        case .invalidSessionOrIdentity:
            return "当前账号或数字人身份无法安全提交知识治理动作"
        case .authoritativeApplyFailed:
            return "知识治理结果无法安全应用到本地图谱"
        case .userChanged:
            return "账号已切换，旧知识治理请求已取消"
        }
    }
}
