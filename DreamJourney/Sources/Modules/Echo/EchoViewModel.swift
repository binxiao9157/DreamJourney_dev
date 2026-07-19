import Foundation

struct EchoDelayedReplyCallsiteContext: Codable, Equatable {
    let accountLease: AccountLease
    let resourceOwnerId: String
    let operationId: String
    let roleContextKey: String

    init?(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String,
        roleContextKey: String
    ) {
        let normalizedOwnerId = resourceOwnerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedOperationId = operationId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRoleContextKey = roleContextKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedOwnerId.isEmpty,
              normalizedOwnerId == accountLease.subjectId,
              !normalizedOperationId.isEmpty,
              !normalizedRoleContextKey.isEmpty,
              EchoDelayedReplyOperationScope(
                  accountLease: accountLease,
                  resourceOwnerId: normalizedOwnerId,
                  operationId: normalizedOperationId
              ) != nil else {
            return nil
        }
        self.accountLease = accountLease
        self.resourceOwnerId = normalizedOwnerId
        self.operationId = normalizedOperationId
        self.roleContextKey = normalizedRoleContextKey
    }

    var operationScope: EchoDelayedReplyOperationScope? {
        EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )
    }
}

final class EchoDelayedReplyCallsiteScopeStore {
    private let storageNamespace = "dj.echo.delayedReply.callsite-scope.v1"
    private let defaults: UserDefaults
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.defaults = defaults
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    @discardableResult
    func save(_ context: EchoDelayedReplyCallsiteContext) -> Bool {
        guard accountLeaseRuntime.validate(context.accountLease, at: .request).allowed,
              let data = try? JSONEncoder().encode(context) else {
            return false
        }
        let storageKey = key(
            accountLease: context.accountLease,
            resourceOwnerId: context.resourceOwnerId
        )

        lock.lock()
        defer { lock.unlock() }
        guard accountLeaseRuntime.validate(context.accountLease, at: .commit).allowed else {
            return false
        }
        let previousData = defaults.data(forKey: storageKey)
        defaults.set(data, forKey: storageKey)
        guard accountLeaseRuntime.validate(context.accountLease, at: .commit).allowed else {
            restore(previousData: previousData, replacing: data, forKey: storageKey)
            return false
        }
        return true
    }

    func load(
        accountLease: AccountLease,
        resourceOwnerId: String,
        roleContextKey: String
    ) -> EchoDelayedReplyCallsiteContext? {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return nil
        }
        let storageKey = key(accountLease: accountLease, resourceOwnerId: resourceOwnerId)
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: storageKey),
              let context = try? JSONDecoder().decode(
                  EchoDelayedReplyCallsiteContext.self,
                  from: data
              ),
              context.accountLease == accountLease,
              context.resourceOwnerId == resourceOwnerId,
              context.roleContextKey == roleContextKey,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
            return nil
        }
        return context
    }

    @discardableResult
    func clear(_ context: EchoDelayedReplyCallsiteContext) -> Bool {
        guard accountLeaseRuntime.validate(context.accountLease, at: .commit).allowed else {
            return false
        }
        let storageKey = key(
            accountLease: context.accountLease,
            resourceOwnerId: context.resourceOwnerId
        )
        lock.lock()
        defer { lock.unlock() }
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(
                  EchoDelayedReplyCallsiteContext.self,
                  from: data
              ),
              stored == context,
              accountLeaseRuntime.validate(context.accountLease, at: .commit).allowed else {
            return false
        }
        defaults.removeObject(forKey: storageKey)
        guard accountLeaseRuntime.validate(context.accountLease, at: .commit).allowed else {
            if defaults.data(forKey: storageKey) == nil {
                defaults.set(data, forKey: storageKey)
            }
            return false
        }
        return true
    }

    private func key(accountLease: AccountLease, resourceOwnerId: String) -> String {
        let identity = EchoDelayedReplyOperationScope.identityDigest(
            values: [
                "subject", accountLease.subjectId,
                "vault", accountLease.vaultId,
                "generation", String(accountLease.generation),
                "generation-id", accountLease.generationId.uuidString,
                "authority-epoch", accountLease.authorityEpoch,
                "resource-owner", resourceOwnerId,
            ]
        )
        return "\(storageNamespace).\(identity)"
    }

    private func restore(previousData: Data?, replacing data: Data, forKey storageKey: String) {
        guard defaults.data(forKey: storageKey) == data else { return }
        if let previousData {
            defaults.set(previousData, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }
}

enum EchoInteractionState {
    case idle
    case starting
    case listening
    case thinking
    case waitingReply(minutes: Int)
    case neutralSafety(EchoSafetyDecision)
    case speaking
    case replied
    case error(String)
}

/// Pure, provider-independent turn lifecycle used by Echo application code.
/// It intentionally does not carry transcript, context, audio or digital-human state.
enum EchoTurnPhase: String, Equatable {
    case idle
    case starting
    case listening
    case thinking
    case waitingReply
    case speaking
    case replied
    case failed
}

enum EchoTurnIntent: Equatable {
    case prepareVoiceInteraction
    case voiceCaptureStarted
    case userTurnAccepted
    case delayedReplyScheduled
    case delayedReplyRestored
    case replyStarted
    case replyDelivered
    case restoredDelayedReplyDelivered
    case reset
    case failure
    case retry
}

struct EchoTurnTransition: Equatable {
    let intent: EchoTurnIntent
    let previousPhase: EchoTurnPhase
    let currentPhase: EchoTurnPhase
    let accepted: Bool
}

struct EchoTurnIntentReducer {
    private(set) var phase: EchoTurnPhase = .idle

    func accepts(_ intent: EchoTurnIntent) -> Bool {
        nextPhase(for: intent) != nil
    }

    @discardableResult
    mutating func reduce(_ intent: EchoTurnIntent) -> EchoTurnTransition {
        let previousPhase = phase
        guard let nextPhase = nextPhase(for: intent) else {
            return EchoTurnTransition(
                intent: intent,
                previousPhase: previousPhase,
                currentPhase: previousPhase,
                accepted: false
            )
        }

        phase = nextPhase
        return EchoTurnTransition(
            intent: intent,
            previousPhase: previousPhase,
            currentPhase: nextPhase,
            accepted: true
        )
    }

    private func nextPhase(for intent: EchoTurnIntent) -> EchoTurnPhase? {
        switch intent {
        case .prepareVoiceInteraction:
            switch phase {
            case .idle, .replied, .failed:
                return .starting
            case .starting, .listening, .thinking, .waitingReply, .speaking:
                return nil
            }
        case .voiceCaptureStarted:
            switch phase {
            case .idle, .starting, .replied:
                return .listening
            case .listening, .thinking, .waitingReply, .speaking, .failed:
                return nil
            }
        case .userTurnAccepted:
            switch phase {
            case .starting, .listening:
                return .thinking
            case .idle, .thinking, .waitingReply, .speaking, .replied, .failed:
                return nil
            }
        case .delayedReplyScheduled:
            switch phase {
            case .listening, .thinking:
                return .waitingReply
            case .idle, .starting, .waitingReply, .speaking, .replied, .failed:
                return nil
            }
        case .delayedReplyRestored:
            switch phase {
            case .idle, .replied, .failed:
                return .waitingReply
            case .starting, .listening, .thinking, .waitingReply, .speaking:
                return nil
            }
        case .replyStarted:
            switch phase {
            case .starting, .listening, .thinking:
                return .speaking
            case .idle, .waitingReply, .speaking, .replied, .failed:
                return nil
            }
        case .replyDelivered:
            switch phase {
            case .waitingReply, .speaking:
                return .replied
            case .idle, .starting, .listening, .thinking, .replied, .failed:
                return nil
            }
        case .restoredDelayedReplyDelivered:
            switch phase {
            case .idle, .waitingReply:
                return .replied
            case .starting, .listening, .thinking, .speaking, .replied, .failed:
                return nil
            }
        case .reset:
            return .idle
        case .failure:
            return .failed
        case .retry:
            return phase == .failed ? .idle : nil
        }
    }
}

struct EchoReplyPacingPolicy {
    static let waitAfterUserTurnCount = 10
    static let replyDelayMinuteRange = 5...10
    private static let earlyWaitSignalKeywords = [
        "睡不着",
        "焦虑",
        "很难过",
        "害怕",
        "孤单",
        "撑不住",
        "快崩溃",
        "一直哭",
    ]

    static func shouldWaitForReply(afterUserTurnCount userTurnCount: Int, userText: String) -> Bool {
        triggerForWait(afterUserTurnCount: userTurnCount, userText: userText) != nil
    }

    static func triggerForWait(afterUserTurnCount userTurnCount: Int, userText: String) -> EchoDelayedReplyTrigger? {
        guard EchoSafetyPolicy.evaluate(text: userText).allowsDelayedReply else {
            return nil
        }
        if shouldTriggerEarlyWait(for: userText) {
            return .contentSignal
        }
        if userTurnCount >= waitAfterUserTurnCount {
            return .tenRoundBaseline
        }
        return nil
    }

    static func shouldTriggerEarlyWait(for userText: String) -> Bool {
        let normalizedText = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return false }
        return earlyWaitSignalKeywords.contains { normalizedText.contains($0) }
    }

    static func replyDelayMinutes(forCompletedSessionCount sessionCount: Int) -> Int {
        let offset = max(0, sessionCount) % 6
        return replyDelayMinuteRange.lowerBound + offset
    }
}

struct EchoArchiveContextStatus: Equatable {
    let totalItemCount: Int
    let availableItemCount: Int
    let mode: DigitalHumanMode

    init(
        totalItemCount: Int,
        availableItemCount: Int,
        mode: DigitalHumanMode = .sunlight
    ) {
        self.totalItemCount = totalItemCount
        self.availableItemCount = availableItemCount
        self.mode = mode
    }

    static let empty = EchoArchiveContextStatus(totalItemCount: 0, availableItemCount: 0)

    var hasAvailableContext: Bool {
        availableItemCount > 0
    }

    var shouldShowArchiveContextIndicator: Bool {
        hasAvailableContext && mode != .silent
    }

    var indicatorText: String? {
        guard shouldShowArchiveContextIndicator else { return nil }
        switch mode {
        case .star:
            return availableItemCount > 1
                ? "\(availableItemCount) 条关怀线索正在参与回响"
                : "关怀线索正在参与回响"
        case .sunlight:
            return availableItemCount > 1
                ? "\(availableItemCount) 条档案线索正在参与回响"
                : "档案线索正在参与回响"
        case .silent:
            return nil
        }
    }
}

protocol EchoContextBuildTransport {
    var isContextBuildConfigured: Bool { get }

    func buildEchoContextPacket(
        userId: String,
        query: String,
        personaScope: String,
        digitalHumanId: String,
        lifecycleMode: DigitalHumanMode,
        viewerFamilyMemberID: String?,
        completion: @escaping (Result<EchoContextPacket, Error>) -> Void
    )
}

extension DreamJourneyBackendClient: EchoContextBuildTransport {}

/// Provider-independent ownership for one backend context-build request.
/// The controller still owns rendering and DialogEngine submission; this lease
/// only prevents an older asynchronous response from mutating a newer Echo turn.
struct EchoContextBuildLease: Equatable {
    let generation: UInt64
    let turnID: String
    let expectedIdentity: EchoKnowledgeContextIdentity
}

struct EchoContextBuildIdentityMismatch: Equatable {
    let expectedIdentity: EchoKnowledgeContextIdentity
    let responseUserId: String
    let responsePersonaScope: String?
    let responseDigitalHumanId: String?
}

enum EchoContextBuildDelivery {
    case success(EchoContextPacket)
    case identityMismatch(EchoContextBuildIdentityMismatch)
    case failure(Error)
}

/// Incremental application coordinator for Echo business requests.
/// Runtime digital-human/audio lifecycles intentionally remain outside this seam.
final class EchoApplicationCoordinator {
    private var nextContextBuildGeneration: UInt64 = 0
    private let contextBuildTransport: EchoContextBuildTransport
    private(set) var activeContextBuildLease: EchoContextBuildLease?

    init(contextBuildTransport: EchoContextBuildTransport = DreamJourneyBackendClient.shared) {
        self.contextBuildTransport = contextBuildTransport
    }

    @discardableResult
    func beginContextBuild(
        turnID: String,
        expectedIdentity: EchoKnowledgeContextIdentity
    ) -> EchoContextBuildLease {
        nextContextBuildGeneration &+= 1
        let lease = EchoContextBuildLease(
            generation: nextContextBuildGeneration,
            turnID: turnID,
            expectedIdentity: expectedIdentity
        )
        activeContextBuildLease = lease
        return lease
    }

    @discardableResult
    func invalidateContextBuild() -> EchoContextBuildLease? {
        let invalidatedLease = activeContextBuildLease
        activeContextBuildLease = nil
        return invalidatedLease
    }

    func isCurrent(_ lease: EchoContextBuildLease) -> Bool {
        activeContextBuildLease == lease
    }

    @discardableResult
    func requestContextBuild(
        turnID: String,
        query: String,
        expectedIdentity: EchoKnowledgeContextIdentity,
        lifecycleMode: DigitalHumanMode,
        viewerFamilyMemberID: String?,
        completion: @escaping (EchoContextBuildLease, EchoContextBuildDelivery) -> Void
    ) -> EchoContextBuildLease? {
        guard contextBuildTransport.isContextBuildConfigured else {
            return nil
        }
        let lease = beginContextBuild(
            turnID: turnID,
            expectedIdentity: expectedIdentity
        )
        contextBuildTransport.buildEchoContextPacket(
            userId: expectedIdentity.userId,
            query: query,
            personaScope: expectedIdentity.personaScope,
            digitalHumanId: expectedIdentity.digitalHumanId,
            lifecycleMode: lifecycleMode,
            viewerFamilyMemberID: viewerFamilyMemberID
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.isCurrent(lease) else {
                    return
                }
                switch result {
                case .success(let packet):
                    guard EchoKnowledgeContextPolicy.responseIdentityMatches(
                        expected: lease.expectedIdentity,
                        responseUserId: packet.userId,
                        responsePersonaScope: packet.personaScope,
                        responseDigitalHumanId: packet.digitalHumanId
                    ) else {
                        completion(
                            lease,
                            .identityMismatch(
                                EchoContextBuildIdentityMismatch(
                                    expectedIdentity: lease.expectedIdentity,
                                    responseUserId: packet.userId,
                                    responsePersonaScope: packet.personaScope,
                                    responseDigitalHumanId: packet.digitalHumanId
                                )
                            )
                        )
                        return
                    }
                    completion(lease, .success(packet))
                case .failure(let error):
                    completion(lease, .failure(error))
                }
            }
        }
        return lease
    }
}

final class EchoViewModel {
    private let contextStore: DigitalHumanContextStore
    private let memoryManager: ConversationMemoryManager
    private let archiveContextStatusProvider: () -> EchoArchiveContextStatus
    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let delayedReplyStore: EchoDelayedReplyStore
    private let delayedReplyCallsiteScopeStore: EchoDelayedReplyCallsiteScopeStore
    private let delayedReplyNotificationScheduler: EchoDelayedReplyNotificationScheduler
    private let echoReplyMessageStore: EchoReplyMessageStore

    private(set) var context: DigitalHumanContext
    private(set) var archiveContextStatus: EchoArchiveContextStatus = .empty
    private(set) var state: EchoInteractionState = .idle
    private(set) var pendingDelayedReply: EchoDelayedReply?
    private(set) var pendingDelayedReplyContext: EchoDelayedReplyCallsiteContext?
    private var currentSessionUserTurnCount = 0
    private var turnIntentReducer = EchoTurnIntentReducer()

    var onStateChange: ((EchoInteractionState) -> Void)?
    var onTranscriptAppend: ((String, Bool) -> Void)?
    var onArchiveContextStatusChange: ((EchoArchiveContextStatus) -> Void)?
    var isWaitingForDelayedReply: Bool {
        if case .waitingReply = state {
            return true
        }
        return false
    }
    var neutralSafetyDecision: EchoSafetyDecision? {
        guard case .neutralSafety(let decision) = state else { return nil }
        return decision
    }
    var isNeutralSafetyMode: Bool {
        neutralSafetyDecision != nil
    }

    init(
        contextStore: DigitalHumanContextStore = .shared,
        memoryManager: ConversationMemoryManager = .shared,
        archiveContextStatusProvider: @escaping () -> EchoArchiveContextStatus = EchoViewModel.currentArchiveContextStatus,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared,
        delayedReplyStore: EchoDelayedReplyStore = .shared,
        delayedReplyCallsiteScopeStore: EchoDelayedReplyCallsiteScopeStore? = nil,
        delayedReplyNotificationScheduler: EchoDelayedReplyNotificationScheduler = .shared,
        echoReplyMessageStore: EchoReplyMessageStore = .shared
    ) {
        self.contextStore = contextStore
        self.memoryManager = memoryManager
        self.archiveContextStatusProvider = archiveContextStatusProvider
        self.accountLeaseRuntime = accountLeaseRuntime
        self.delayedReplyStore = delayedReplyStore
        self.delayedReplyCallsiteScopeStore = delayedReplyCallsiteScopeStore
            ?? EchoDelayedReplyCallsiteScopeStore(accountLeaseRuntime: accountLeaseRuntime)
        self.delayedReplyNotificationScheduler = delayedReplyNotificationScheduler
        self.echoReplyMessageStore = echoReplyMessageStore
        self.context = contextStore.current
    }

    func prepareVoiceInteraction() {
        context = contextStore.current
        memoryManager.refreshForCurrentContext()
        refreshArchiveContextStatus()
        _ = applyTurnIntent(.prepareVoiceInteraction, state: .starting)
    }

    func beginVoiceInteraction() {
        context = contextStore.current
        memoryManager.refreshForCurrentContext()
        refreshArchiveContextStatus()
        _ = applyTurnIntent(.voiceCaptureStarted, state: .listening)
    }

    func finishUserVoice(text: String) {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            _ = applyTurnIntent(.failure, state: .error("账号状态已变化，请重新进入回响"))
            return
        }
        finishUserVoice(
            text: text,
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            roleContextKey: Self.roleContextKey(for: contextStore.current)
        )
    }

    func finishUserVoice(
        text: String,
        accountLease: AccountLease,
        resourceOwnerId: String,
        roleContextKey: String
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else {
            return
        }
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            _ = applyTurnIntent(.failure, state: .error("刚才没有听清，可以再说一次"))
            return
        }

        let safetyDecision = EchoSafetyPolicy.evaluate(text: normalizedText)
        guard !safetyDecision.isCrisis else {
            enterNeutralSafetyMode(
                safetyDecision,
                userText: normalizedText,
                accountLease: accountLease
            )
            return
        }

        guard turnIntentReducer.accepts(.userTurnAccepted)
                || turnIntentReducer.accepts(.delayedReplyScheduled) else {
            return
        }

        memoryManager.refreshForCurrentContext()
        refreshArchiveContextStatus()
        memoryManager.recordUserTurn(text: normalizedText)
        onTranscriptAppend?(normalizedText, true)
        currentSessionUserTurnCount += 1

        if EchoReplyPacingPolicy.shouldWaitForReply(
            afterUserTurnCount: currentSessionUserTurnCount,
            userText: normalizedText
        ), let waitTrigger = EchoReplyPacingPolicy.triggerForWait(
            afterUserTurnCount: currentSessionUserTurnCount,
            userText: normalizedText
        ) {
            let wait = EchoReplyPacingPolicy.replyDelayMinutes(
                forCompletedSessionCount: memoryManager.currentMemory.sessionCount
            )
            let now = Date()
            let delayedReply = EchoDelayedReply(
                id: UUID().uuidString,
                scheduledAt: now,
                deliverAt: now.addingTimeInterval(TimeInterval(wait * 60)),
                minutes: wait,
                userTurnCount: currentSessionUserTurnCount,
                trigger: waitTrigger
            )
            guard let callsiteContext = EchoDelayedReplyCallsiteContext(
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId,
                operationId: delayedReply.id,
                roleContextKey: roleContextKey
            ), delayedReplyStore.save(
                delayedReply,
                resourceOwnerId: callsiteContext.resourceOwnerId,
                operationId: callsiteContext.operationId,
                accountLease: callsiteContext.accountLease
            ) else {
                _ = applyTurnIntent(.failure, state: .error("等待回信保存失败，请稍后重试"))
                return
            }
            guard delayedReplyCallsiteScopeStore.save(callsiteContext) else {
                _ = delayedReplyStore.clear(
                    resourceOwnerId: callsiteContext.resourceOwnerId,
                    operationId: callsiteContext.operationId,
                    accountLease: callsiteContext.accountLease
                )
                _ = applyTurnIntent(.failure, state: .error("等待回信保存失败，请稍后重试"))
                return
            }
            pendingDelayedReply = delayedReply
            pendingDelayedReplyContext = callsiteContext
            _ = applyTurnIntent(.delayedReplyScheduled, state: .waitingReply(minutes: wait))
            return
        }

        _ = applyTurnIntent(.userTurnAccepted, state: .thinking)
    }

    func receiveAIReply(_ text: String) {
        guard !isNeutralSafetyMode else { return }
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty,
              applyTurnIntent(.replyStarted, state: .speaking) else { return }

        memoryManager.refreshForCurrentContext()
        memoryManager.recordAITurn(text: normalizedText)
        onTranscriptAppend?(normalizedText, false)
    }

    func markReplyDelivered(accountLease: AccountLease) {
        guard !isNeutralSafetyMode else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed,
              turnIntentReducer.accepts(.replyDelivered) else { return }
        if let callsiteContext = pendingDelayedReplyContext {
            guard callsiteContext.accountLease == accountLease,
                  retirePendingDelayedReply(callsiteContext) else {
                return
            }
        }
        pendingDelayedReply = nil
        pendingDelayedReplyContext = nil
        _ = applyTurnIntent(.replyDelivered, state: .replied)
    }

    func markReplyDelivered() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        markReplyDelivered(accountLease: accountLease)
    }

    func resetToIdle(accountLease: AccountLease) {
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else { return }
        if let callsiteContext = pendingDelayedReplyContext {
            guard callsiteContext.accountLease == accountLease,
                  retirePendingDelayedReply(callsiteContext) else {
                return
            }
        }
        currentSessionUserTurnCount = 0
        pendingDelayedReply = nil
        pendingDelayedReplyContext = nil
        _ = applyTurnIntent(.reset, state: .idle)
    }

    func resetToIdle() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        resetToIdle(accountLease: accountLease)
    }

    func resetTransientStateForAccountRebind() {
        context = contextStore.current
        currentSessionUserTurnCount = 0
        pendingDelayedReply = nil
        pendingDelayedReplyContext = nil
        _ = applyTurnIntent(.reset, state: .idle)
    }

    func fail(_ message: String) {
        guard !isNeutralSafetyMode else { return }
        _ = applyTurnIntent(.failure, state: .error(message))
    }

    func retryAfterError() {
        guard case .error = state else { return }
        _ = applyTurnIntent(.retry, state: .idle)
    }

    func markStoredDelayedReplyArrived(
        _ delayedReply: EchoDelayedReply,
        callsiteContext: EchoDelayedReplyCallsiteContext
    ) {
        guard matchesPendingDelayedReplyContext(callsiteContext),
              delayedReply.id == callsiteContext.operationId,
              turnIntentReducer.accepts(.restoredDelayedReplyDelivered),
              echoReplyMessageStore.saveArrivedReply(
            id: delayedReply.id,
            deliverAt: delayedReply.deliverAt,
            trigger: delayedReply.trigger.rawValue,
            accountLease: callsiteContext.accountLease,
            resourceOwnerId: callsiteContext.resourceOwnerId,
            operationId: callsiteContext.operationId
        ), retirePendingDelayedReply(callsiteContext) else {
            return
        }
        pendingDelayedReply = nil
        pendingDelayedReplyContext = nil
        _ = applyTurnIntent(.restoredDelayedReplyDelivered, state: .replied)
    }

    static func replyDelayMinutes(for sessionCount: Int) -> Int {
        EchoReplyPacingPolicy.replyDelayMinutes(forCompletedSessionCount: sessionCount)
    }

    private static func currentArchiveContextStatus() -> EchoArchiveContextStatus {
        let snapshot = MemoryArchiveRepository.shared.contextSnapshot()
        return EchoArchiveContextStatus(
            totalItemCount: snapshot.totalItemCount,
            availableItemCount: snapshot.availableItemCount
        )
    }

    func refreshArchiveContextStatus() {
        guard !isNeutralSafetyMode else { return }
        context = contextStore.current
        memoryManager.refreshForCurrentContext()
        let providedStatus = archiveContextStatusProvider()
        archiveContextStatus = EchoArchiveContextStatus(
            totalItemCount: providedStatus.totalItemCount,
            availableItemCount: providedStatus.availableItemCount,
            mode: context.mode
        )
        onArchiveContextStatusChange?(archiveContextStatus)
    }

    @discardableResult
    func restoreStoredDelayedReplyIfAvailable(
        accountLease: AccountLease,
        resourceOwnerId: String,
        roleContextKey: String,
        now: Date = Date()
    ) -> Bool {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              let callsiteContext = delayedReplyCallsiteScopeStore.load(
                  accountLease: accountLease,
                  resourceOwnerId: resourceOwnerId,
                  roleContextKey: roleContextKey
              ),
              let delayedReply = delayedReplyStore.load(
                  resourceOwnerId: callsiteContext.resourceOwnerId,
                  operationId: callsiteContext.operationId,
                  accountLease: callsiteContext.accountLease
              ),
              delayedReply.id == callsiteContext.operationId else {
            return false
        }

        if delayedReply.deliverAt <= now {
            pendingDelayedReply = delayedReply
            pendingDelayedReplyContext = callsiteContext
            markStoredDelayedReplyArrived(
                delayedReply,
                callsiteContext: callsiteContext
            )
            return true
        }

        let remainingMinutes = max(1, Int(ceil(delayedReply.deliverAt.timeIntervalSince(now) / 60)))
        guard turnIntentReducer.accepts(.delayedReplyRestored) else {
            return false
        }
        pendingDelayedReply = delayedReply
        pendingDelayedReplyContext = callsiteContext
        _ = applyTurnIntent(.delayedReplyRestored, state: .waitingReply(minutes: remainingMinutes))
        return true
    }

    func restoreStoredDelayedReplyIfAvailable(now: Date = Date()) -> Bool {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            return false
        }
        return restoreStoredDelayedReplyIfAvailable(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            roleContextKey: Self.roleContextKey(for: contextStore.current),
            now: now
        )
    }

    func matchesPendingDelayedReplyContext(
        _ callsiteContext: EchoDelayedReplyCallsiteContext
    ) -> Bool {
        pendingDelayedReplyContext == callsiteContext
            && pendingDelayedReply?.id == callsiteContext.operationId
            && accountLeaseRuntime.validate(callsiteContext.accountLease, at: .runtime).allowed
    }

    private func updateState(_ newState: EchoInteractionState) {
        state = newState
        onStateChange?(newState)
    }

    @discardableResult
    private func applyTurnIntent(
        _ intent: EchoTurnIntent,
        state: EchoInteractionState
    ) -> Bool {
        let transition = turnIntentReducer.reduce(intent)
        guard transition.accepted else { return false }
        updateState(state)
        return true
    }

    private func enterNeutralSafetyMode(
        _ decision: EchoSafetyDecision,
        userText: String,
        accountLease: AccountLease
    ) {
        if let callsiteContext = pendingDelayedReplyContext,
           callsiteContext.accountLease == accountLease {
            delayedReplyNotificationScheduler.cancelPendingDelayedReply(
                resourceOwnerId: callsiteContext.resourceOwnerId,
                operationId: callsiteContext.operationId,
                accountLease: callsiteContext.accountLease
            )
            _ = retirePendingDelayedReply(callsiteContext)
        }
        pendingDelayedReply = nil
        pendingDelayedReplyContext = nil
        onTranscriptAppend?(userText, true)
        if let responseText = decision.responseText {
            onTranscriptAppend?(responseText, false)
        }
        _ = turnIntentReducer.reduce(.reset)
        updateState(.neutralSafety(decision))
    }

    private func retirePendingDelayedReply(
        _ callsiteContext: EchoDelayedReplyCallsiteContext
    ) -> Bool {
        guard matchesPendingDelayedReplyContext(callsiteContext),
              delayedReplyStore.clear(
                  resourceOwnerId: callsiteContext.resourceOwnerId,
                  operationId: callsiteContext.operationId,
                  accountLease: callsiteContext.accountLease
              ) else {
            return false
        }
        _ = delayedReplyCallsiteScopeStore.clear(callsiteContext)
        return true
    }

    private static func roleContextKey(for context: DigitalHumanContext) -> String {
        [
            context.viewerUserId ?? "",
            context.ownerId.trimmingCharacters(in: .whitespacesAndNewlines),
            context.mode.rawValue,
            context.isSelfAssistant ? "self" : "family",
        ].joined(separator: "|")
    }
}
