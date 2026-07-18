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
        updateState(.starting)
    }

    func beginVoiceInteraction() {
        context = contextStore.current
        memoryManager.refreshForCurrentContext()
        refreshArchiveContextStatus()
        updateState(.listening)
    }

    func finishUserVoice(text: String) {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            updateState(.error("账号状态已变化，请重新进入回响"))
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
            updateState(.error("刚才没有听清，可以再说一次"))
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
                updateState(.error("等待回信保存失败，请稍后重试"))
                return
            }
            guard delayedReplyCallsiteScopeStore.save(callsiteContext) else {
                _ = delayedReplyStore.clear(
                    resourceOwnerId: callsiteContext.resourceOwnerId,
                    operationId: callsiteContext.operationId,
                    accountLease: callsiteContext.accountLease
                )
                updateState(.error("等待回信保存失败，请稍后重试"))
                return
            }
            pendingDelayedReply = delayedReply
            pendingDelayedReplyContext = callsiteContext
            updateState(.waitingReply(minutes: wait))
            return
        }

        updateState(.thinking)
    }

    func receiveAIReply(_ text: String) {
        guard !isNeutralSafetyMode else { return }
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        memoryManager.refreshForCurrentContext()
        memoryManager.recordAITurn(text: normalizedText)
        onTranscriptAppend?(normalizedText, false)
        updateState(.speaking)
    }

    func markReplyDelivered(accountLease: AccountLease) {
        guard !isNeutralSafetyMode else { return }
        guard accountLeaseRuntime.validate(accountLease, at: .commit).allowed else { return }
        if let callsiteContext = pendingDelayedReplyContext {
            guard callsiteContext.accountLease == accountLease,
                  retirePendingDelayedReply(callsiteContext) else {
                return
            }
        }
        pendingDelayedReply = nil
        pendingDelayedReplyContext = nil
        updateState(.replied)
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
        updateState(.idle)
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
        updateState(.idle)
    }

    func fail(_ message: String) {
        guard !isNeutralSafetyMode else { return }
        updateState(.error(message))
    }

    func retryAfterError() {
        guard case .error = state else { return }
        updateState(.idle)
    }

    func markStoredDelayedReplyArrived(
        _ delayedReply: EchoDelayedReply,
        callsiteContext: EchoDelayedReplyCallsiteContext
    ) {
        guard matchesPendingDelayedReplyContext(callsiteContext),
              delayedReply.id == callsiteContext.operationId,
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
        updateState(.replied)
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

        pendingDelayedReply = delayedReply
        pendingDelayedReplyContext = callsiteContext
        if delayedReply.deliverAt <= now {
            markStoredDelayedReplyArrived(
                delayedReply,
                callsiteContext: callsiteContext
            )
            return true
        }

        let remainingMinutes = max(1, Int(ceil(delayedReply.deliverAt.timeIntervalSince(now) / 60)))
        updateState(.waitingReply(minutes: remainingMinutes))
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
