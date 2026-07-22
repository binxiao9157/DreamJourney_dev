import Foundation

struct AccountLifecycleTransitionResult: Sendable {
    let actorReceipt: AccountSessionTransitionReceipt
    let lifecycleReceipt: AccountLifecycleOperationReceipt

    var canFinalize: Bool {
        actorReceipt.accepted && lifecycleReceipt.isTerminal
    }

    var cleanupCompleted: Bool {
        lifecycleReceipt.event == .accountDeletion
            && actorReceipt.accepted
            && actorReceipt.state == .signedOut
            && lifecycleReceipt.isTerminal
            && lifecycleReceipt.moduleReceipts.count == 13
            && lifecycleReceipt.remainingLocalDataCount == 0
            && !lifecycleReceipt.hasFailures
    }

    var cleanupPendingAfterSignOut: Bool {
        lifecycleReceipt.event == .accountDeletion
            && actorReceipt.accepted
            && actorReceipt.state == .signedOut
            && !cleanupCompleted
    }
}

private final class AccountLifecycleBooleanBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    func set(_ value: Bool) {
        lock.lock()
        storedValue = value
        lock.unlock()
    }

    func value() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }
}

actor AccountLifecycleTransitionController {
    static let shared = AccountLifecycleTransitionController()

    private let accountSessionActor: AccountSessionActor
    private let coordinator: AccountLifecycleCoordinator
    private var registryInstalled = false

    init(
        accountSessionActor: AccountSessionActor = .shared,
        coordinator: AccountLifecycleCoordinator = .shared
    ) {
        self.accountSessionActor = accountSessionActor
        self.coordinator = coordinator
    }

    func perform(
        event: AccountLifecycleEvent,
        operationId: UUID = UUID(),
        oldAccountLease: AccountLease?,
        oldGeneration: UInt64,
        reason: String
    ) async -> AccountLifecycleTransitionResult {
        let actorReceipt: AccountSessionTransitionReceipt
        switch event {
        case .switchAccount:
            actorReceipt = await accountSessionActor.beginSwitch(
                expectedGeneration: oldGeneration
            )
        case .logout:
            actorReceipt = await accountSessionActor.signOut(
                expectedGeneration: oldGeneration,
                reason: reason
            )
        case .privateSuspension:
            actorReceipt = await accountSessionActor.suspend(
                expectedGeneration: oldGeneration,
                reason: reason
            )
        case .accountDeletion:
            return await performAccountDeletionAfterBackendSoftDelete(
                operationId: operationId,
                oldAccountLease: oldAccountLease,
                oldGeneration: oldGeneration
            )
        case .coldStartRecovery:
            actorReceipt = await accountSessionActor.snapshot()
        }

        return await performAfterExistingFence(
            event: event,
            operationId: operationId,
            oldAccountLease: oldAccountLease,
            oldGeneration: oldGeneration,
            actorReceipt: actorReceipt
        )
    }

    func performAccountDeletionAfterBackendSoftDelete(
        operationId: UUID = UUID(),
        oldAccountLease: AccountLease?,
        oldGeneration: UInt64
    ) async -> AccountLifecycleTransitionResult {
        let deletingReceipt = await accountSessionActor.beginDeleting(
            expectedGeneration: oldGeneration
        )
        guard deletingReceipt.accepted else {
            return AccountLifecycleTransitionResult(
                actorReceipt: deletingReceipt,
                lifecycleReceipt: rejectedAccountDeletionReceipt(
                    operationId: operationId,
                    oldGeneration: oldGeneration,
                    detailCode: "accountDeletionFenceRejected"
                )
            )
        }

        let transitionResult = await performAfterExistingFence(
            event: .accountDeletion,
            operationId: operationId,
            oldAccountLease: oldAccountLease,
            oldGeneration: oldGeneration,
            actorReceipt: deletingReceipt
        )
        let receipt = transitionResult.lifecycleReceipt
        guard receipt.isTerminal, receipt.moduleReceipts.count == 13 else {
            return transitionResult
        }
        let signedOutReceipt = await accountSessionActor.signOut(
            expectedGeneration: deletingReceipt.generation,
            reason: "accountDeletionLocalTeardownFinished"
        )
        return AccountLifecycleTransitionResult(
            actorReceipt: signedOutReceipt,
            lifecycleReceipt: transitionResult.lifecycleReceipt
        )
    }

    func performAfterExistingFence(
        event: AccountLifecycleEvent,
        operationId: UUID = UUID(),
        oldAccountLease: AccountLease?,
        oldGeneration: UInt64,
        actorReceipt: AccountSessionTransitionReceipt
    ) async -> AccountLifecycleTransitionResult {
        await installRegistryIfNeeded()

        if actorReceipt.accepted {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .djAccountLifecycleWillTeardown,
                    object: nil,
                    userInfo: [
                        "event": event.rawValue,
                        "oldGeneration": oldGeneration,
                    ]
                )
            }
        }

        let lifecycleReceipt = await coordinator.perform(
            event: event,
            operationId: operationId,
            oldAccountLease: oldAccountLease,
            oldGeneration: oldGeneration
        )
        return AccountLifecycleTransitionResult(
            actorReceipt: actorReceipt,
            lifecycleReceipt: lifecycleReceipt
        )
    }

    private func installRegistryIfNeeded() async {
        guard !registryInstalled else { return }
        await coordinator.replaceRegistrations(
            AccountLifecycleRuntimeRegistry.registrations()
        )
        registryInstalled = true
    }

    private func rejectedAccountDeletionReceipt(
        operationId: UUID,
        oldGeneration: UInt64,
        detailCode: String
    ) -> AccountLifecycleOperationReceipt {
        let now = Date()
        let moduleReceipt = AccountLifecycleModuleReceipt(
            schemaVersion: 1,
            operationId: operationId,
            moduleId: "account.lifecycle.deletionFence",
            event: .accountDeletion,
            phase: .fence,
            requestedOutcome: .purged,
            outcome: .failed,
            remainingLocalData: true,
            detailCode: detailCode,
            completedAt: now
        )
        return AccountLifecycleOperationReceipt(
            schemaVersion: 1,
            operationId: operationId,
            event: .accountDeletion,
            oldGeneration: oldGeneration,
            startedAt: now,
            completedAt: now,
            moduleReceipts: [moduleReceipt],
            isTerminal: true
        )
    }
}

enum AccountLifecycleRuntimeRegistry {
    static func registrations() -> [AccountLifecycleModuleRegistration] {
        [
            registration(
                descriptor: descriptor(
                    id: "LM-01-auth-session",
                    phase: .fence,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownAuthSession(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-02-profile-and-release-cache",
                    phase: .fence,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownProfileAndReleaseCache(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-03-message-notification-effects",
                    phase: .cancelEffects,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownMessageNotificationEffects(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-04-voice-profile-remote-rights",
                    phase: .cancelEffects,
                    coldStart: .cancelled,
                    switchAccount: .cancelled,
                    logout: .cancelled,
                    suspension: .cancelled,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    remoteVoiceRightsDisposition(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-05-digital-human-remote-lease",
                    phase: .cancelEffects,
                    coldStart: .cancelled,
                    switchAccount: .cancelled,
                    logout: .cancelled,
                    suspension: .cancelled,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    remoteDigitalHumanLeaseDisposition(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-06-voice-runtime-and-cache",
                    phase: .unmountRuntime,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownVoiceRuntimeAndCache(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-07-digital-human-dialog-runtime",
                    phase: .unmountRuntime,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownDigitalHumanRuntime(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-08-owner-explicit-draft-stores",
                    phase: .retainOrPurgeDraft,
                    coldStart: .unmounted,
                    switchAccount: .retainedLocked,
                    logout: .retainedLocked,
                    suspension: .retainedLocked,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    explicitDraftDisposition(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-09-knowledge-draft-and-outbox-store",
                    phase: .retainOrPurgeDraft,
                    coldStart: .unmounted,
                    switchAccount: .retainedLocked,
                    logout: .retainedLocked,
                    suspension: .retainedLocked,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownKnowledgeStores(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-10-rebuildable-private-projections",
                    phase: .clearProjection,
                    coldStart: .unmounted,
                    switchAccount: .retainedLocked,
                    logout: .retainedLocked,
                    suspension: .retainedLocked,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownConversationAndFamily(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-11-widget-and-temporary-exports",
                    phase: .clearProjection,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownWidgetAndExports(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-12-qa-evidence-and-log-policy",
                    phase: .finalize,
                    coldStart: .cleared,
                    switchAccount: .cleared,
                    logout: .cleared,
                    suspension: .cleared,
                    deletion: .purged
                ),
                handler: { context, outcome in
                    teardownQAEvidence(context: context, requestedOutcome: outcome)
                }
            ),
            registration(
                descriptor: descriptor(
                    id: "LM-13-account-lifecycle-receipts",
                    phase: .finalize,
                    coldStart: .skipped,
                    switchAccount: .skipped,
                    logout: .skipped,
                    suspension: .skipped,
                    deletion: .skipped
                ),
                handler: { context, outcome in
                    retainLifecycleReceipts(context: context, requestedOutcome: outcome)
                }
            ),
        ]
    }

    private static func registration(
        descriptor: AccountLifecycleModuleDescriptor,
        handler: @escaping AccountLifecycleModuleRegistration.Handler
    ) -> AccountLifecycleModuleRegistration {
        AccountLifecycleModuleRegistration(descriptor: descriptor, handler: handler)
    }

    private static func descriptor(
        id: String,
        phase: AccountLifecyclePhase,
        coldStart: AccountLifecycleModuleOutcome,
        switchAccount: AccountLifecycleModuleOutcome,
        logout: AccountLifecycleModuleOutcome,
        suspension: AccountLifecycleModuleOutcome,
        deletion: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleDescriptor {
        AccountLifecycleModuleDescriptor(
            moduleId: id,
            phase: phase,
            coldStartPolicy: coldStart,
            switchPolicy: switchAccount,
            logoutPolicy: logout,
            suspensionPolicy: suspension,
            deletionPolicy: deletion
        )
    }

    private static func teardownAuthSession(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        if let current = BackendAuthSessionStore.shared.currentSession,
           let oldAccountLease = context.oldAccountLease,
           (current.userId != oldAccountLease.subjectId
                || current.sessionId != oldAccountLease.sessionId) {
            return .completed(
                requestedOutcome,
                remainingLocalData: false,
                detailCode: "oldAuthSessionAlreadyReplaced"
            )
        }
        BackendAuthSessionStore.shared.clear()
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "oldAuthSessionCleared"
        )
    }

    private static func teardownProfileAndReleaseCache(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard UserManager.shared.teardownProfileForAccountLifecycle(context: context) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "profileLifecycleScopeUnavailable"
            )
        }
        if let oldAccountLease = context.oldAccountLease {
            let appBuild = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleVersion"
            ) as? String ?? "0"
            ReleasePolicyStore.shared.remove(
                scope: ReleasePolicyCacheScope(
                    accountUserId: oldAccountLease.subjectId,
                    appBuild: appBuild
                )
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "profileAndReleaseCacheCleared"
        )
    }

    private static func teardownMessageNotificationEffects(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        let oldAccountLease = context.oldAccountLease
        let localResults = [
            EchoDelayedReplyStore.shared.teardownForAccountLifecycle(
                oldAccountLease: oldAccountLease
            ),
            InAppMessageLifecycleProjectionStore.shared.teardownForAccountLifecycle(
                oldAccountLease: oldAccountLease
            ),
            NotificationRuntimeRouteInbox.shared.teardownForAccountLifecycle(
                oldAccountLease: oldAccountLease
            ),
            PushDeviceTokenStore.shared.teardownForAccountLifecycle(
                oldAccountLease: oldAccountLease
            ),
        ]

        let echoNotificationSemaphore = DispatchSemaphore(value: 0)
        let echoNotificationResult = AccountLifecycleBooleanBox()
        EchoDelayedReplyNotificationScheduler.shared.teardownForAccountLifecycle(
            oldAccountLease: oldAccountLease
        ) { success in
            echoNotificationResult.set(success)
            echoNotificationSemaphore.signal()
        }
        let echoNotificationsCompleted = echoNotificationSemaphore.wait(timeout: .now() + 1) == .success
        let echoNotificationsCleared = echoNotificationResult.value()

        let timeLetterNotificationSemaphore = DispatchSemaphore(value: 0)
        let timeLetterNotificationResult = AccountLifecycleBooleanBox()
        TimeLetterReminderScheduler.shared.teardownForAccountLifecycle(
            oldAccountLease: oldAccountLease
        ) { success in
            timeLetterNotificationResult.set(success)
            timeLetterNotificationSemaphore.signal()
        }
        let timeLetterNotificationsCompleted = timeLetterNotificationSemaphore.wait(timeout: .now() + 1) == .success
        let timeLetterNotificationsCleared = timeLetterNotificationResult.value()

        guard localResults.allSatisfy({ $0 }),
              echoNotificationsCompleted,
              echoNotificationsCleared,
              timeLetterNotificationsCompleted,
              timeLetterNotificationsCleared else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: echoNotificationsCompleted && timeLetterNotificationsCompleted
                    ? "messageNotificationTeardownFailed"
                    : "messageNotificationTeardownTimedOut"
            )
        }
        if context.event == .accountDeletion {
            return .completed(
                .failed,
                remainingLocalData: false,
                detailCode: "messageRemoteDeletionReceiptPending"
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "messageNotificationLocalEffectsCleared"
        )
    }

    private static func remoteVoiceRightsDisposition(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard context.event != .accountDeletion else {
            return .completed(
                .failed,
                remainingLocalData: false,
                detailCode: "voiceRightsDeletionReceiptPending"
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "voiceRightsOwnerFenced"
        )
    }

    private static func remoteDigitalHumanLeaseDisposition(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard context.event != .accountDeletion else {
            return .completed(
                .failed,
                remainingLocalData: false,
                detailCode: "digitalHumanDeletionReceiptPending"
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "digitalHumanRuntimeReleaseRequested"
        )
    }

    private static func teardownVoiceRuntimeAndCache(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        aggregate(
            [
                VoiceCloneService.shared.handleAccountLifecycle(
                    context,
                    requestedOutcome: requestedOutcome
                ),
                MemoirTTSService.shared.handleAccountLifecycle(
                    context,
                    requestedOutcome: requestedOutcome
                ),
            ],
            requestedOutcome: requestedOutcome,
            successDetailCode: "voiceRuntimeAndCacheTeardownCompleted"
        )
    }

    private static func teardownDigitalHumanRuntime(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        DigitalHumanContextStore.shared.handleAccountLifecycle(
            context,
            requestedOutcome: requestedOutcome
        )
    }

    private static func explicitDraftDisposition(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard context.event == .accountDeletion else {
            return .completed(
                requestedOutcome,
                remainingLocalData: true,
                detailCode: "explicitDraftsRetainedOwnerLocked"
            )
        }
        guard let oldAccountLease = context.oldAccountLease,
              oldAccountLease.generation == context.oldGeneration else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "explicitDraftDeletionScopeUnavailable"
            )
        }
        let purgeResults = [
            MemoryArchiveRepository.shared.purgeLocalArchiveDataForAccountDeletion(
                accountLease: oldAccountLease
            ),
            AccountPrivateMediaStore.shared.purgeAccountDataForAccountDeletion(
                accountLease: oldAccountLease
            ),
            MemoirRepository.shared.purgeLocalDataForAccountDeletion(
                accountLease: oldAccountLease
            ),
            MemoryRepository.shared.purgeLocalDataForAccountDeletion(
                accountLease: oldAccountLease
            ),
            MemoryMapPresentationStore.shared.purgeLocalDataForAccountDeletion(
                accountLease: oldAccountLease
            ),
        ]
        guard purgeResults.allSatisfy({ $0 }) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "explicitDraftDeletionFailed"
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "explicitDraftsPurged"
        )
    }

    private static func teardownKnowledgeStores(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        aggregate(
            [
                KnowledgeSyncCoordinator.shared.teardownForAccountLifecycle(
                    context: context
                ),
                KBLiteManager.shared.teardownForAccountLifecycle(context: context),
            ],
            requestedOutcome: requestedOutcome,
            successDetailCode: "knowledgeRuntimeUnmounted"
        )
    }

    private static func teardownConversationAndFamily(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        aggregate(
            [
                ConversationMemoryManager.shared.teardownForAccountLifecycle(
                    context: context
                ),
                FamilyRepository.shared.teardownForAccountLifecycle(context: context),
            ],
            requestedOutcome: requestedOutcome,
            successDetailCode: "conversationAndFamilyUnmounted"
        )
    }

    private static func teardownWidgetAndExports(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        guard KnowledgeWidgetSnapshotStore.shared.teardownForAccountLifecycle(
            oldAccountLease: context.oldAccountLease
        ) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "widgetProjectionTeardownFailed"
            )
        }
        guard AccountDataExportTemporaryStore.teardownForAccountLifecycle(
            oldAccountLease: context.oldAccountLease
        ) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "accountDataExportTeardownFailed"
            )
        }
        guard AccountDataRightsReceiptStore.teardownForAccountLifecycle(
            oldAccountLease: context.oldAccountLease
        ) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "accountDataRightsReceiptTeardownFailed"
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "widgetExportsAndDataRightsReceiptsCleared"
        )
    }

    private static func teardownQAEvidence(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        EchoTraceAccountLifecycle.invalidateAndClear(
            ownerUserId: context.oldAccountLease?.subjectId
        )
        return .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "qaEvidenceClearedWithBoundedReceipts"
        )
    }

    private static func retainLifecycleReceipts(
        context: AccountLifecycleContext,
        requestedOutcome: AccountLifecycleModuleOutcome
    ) -> AccountLifecycleModuleResult {
        .completed(
            requestedOutcome,
            remainingLocalData: false,
            detailCode: "boundedValueMinimizedReceiptsRetained"
        )
    }

    private static func aggregate(
        _ results: [AccountLifecycleModuleResult],
        requestedOutcome: AccountLifecycleModuleOutcome,
        successDetailCode: String
    ) -> AccountLifecycleModuleResult {
        guard !results.isEmpty,
              results.allSatisfy({ $0.outcome == requestedOutcome }) else {
            return .completed(
                .failed,
                remainingLocalData: true,
                detailCode: "accountLifecycleAggregateFailed"
            )
        }
        return .completed(
            requestedOutcome,
            remainingLocalData: results.contains(where: \.remainingLocalData),
            detailCode: successDetailCode
        )
    }
}
