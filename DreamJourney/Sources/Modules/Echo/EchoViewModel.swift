import Foundation

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

    private(set) var context: DigitalHumanContext
    private(set) var archiveContextStatus: EchoArchiveContextStatus = .empty
    private(set) var state: EchoInteractionState = .idle
    private(set) var pendingDelayedReply: EchoDelayedReply?
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
        archiveContextStatusProvider: @escaping () -> EchoArchiveContextStatus = EchoViewModel.currentArchiveContextStatus
    ) {
        self.contextStore = contextStore
        self.memoryManager = memoryManager
        self.archiveContextStatusProvider = archiveContextStatusProvider
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
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            updateState(.error("刚才没有听清，可以再说一次"))
            return
        }

        let safetyDecision = EchoSafetyPolicy.evaluate(text: normalizedText)
        guard !safetyDecision.isCrisis else {
            enterNeutralSafetyMode(safetyDecision, userText: normalizedText)
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
            pendingDelayedReply = delayedReply
            _ = EchoDelayedReplyStore.shared.save(delayedReply)
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

    func markReplyDelivered() {
        guard !isNeutralSafetyMode else { return }
        pendingDelayedReply = nil
        EchoDelayedReplyStore.shared.clear()
        updateState(.replied)
    }

    func resetToIdle() {
        currentSessionUserTurnCount = 0
        pendingDelayedReply = nil
        EchoDelayedReplyStore.shared.clear()
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

    func markStoredDelayedReplyArrived(_ delayedReply: EchoDelayedReply) {
        pendingDelayedReply = nil
        EchoReplyMessageStore.shared.saveArrivedReply(
            id: delayedReply.id,
            deliverAt: delayedReply.deliverAt,
            trigger: delayedReply.trigger.rawValue
        )
        EchoDelayedReplyStore.shared.clear()
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
    func restoreStoredDelayedReplyIfAvailable(now: Date = Date()) -> Bool {
        guard let delayedReply = EchoDelayedReplyStore.shared.load() else {
            return false
        }

        if delayedReply.deliverAt <= now {
            markStoredDelayedReplyArrived(delayedReply)
            return true
        }

        pendingDelayedReply = delayedReply
        let remainingMinutes = max(1, Int(ceil(delayedReply.deliverAt.timeIntervalSince(now) / 60)))
        updateState(.waitingReply(minutes: remainingMinutes))
        return true
    }

    private func updateState(_ newState: EchoInteractionState) {
        state = newState
        onStateChange?(newState)
    }

    private func enterNeutralSafetyMode(_ decision: EchoSafetyDecision, userText: String) {
        pendingDelayedReply = nil
        EchoDelayedReplyNotificationScheduler.shared.cancelPendingDelayedReply()
        EchoDelayedReplyStore.shared.clear()
        onTranscriptAppend?(userText, true)
        if let responseText = decision.responseText {
            onTranscriptAppend?(responseText, false)
        }
        updateState(.neutralSafety(decision))
    }
}
