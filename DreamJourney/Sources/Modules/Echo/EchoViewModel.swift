import Foundation

enum EchoInteractionState {
    case idle
    case listening
    case waitingReply(minutes: Int)
    case speaking
    case error(String)
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

    var onStateChange: ((EchoInteractionState) -> Void)?
    var onTranscriptAppend: ((String, Bool) -> Void)?
    var onArchiveContextStatusChange: ((EchoArchiveContextStatus) -> Void)?

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

    func beginVoiceInteraction() {
        context = contextStore.current
        refreshArchiveContextStatus()
        updateState(.listening)
    }

    func finishUserVoice(text: String) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            updateState(.error("刚才没有听清，可以再说一次"))
            return
        }

        refreshArchiveContextStatus()
        memoryManager.recordUserTurn(text: normalizedText)
        onTranscriptAppend?(normalizedText, true)

        let wait = Self.replyDelayMinutes(for: memoryManager.currentMemory.sessionCount)
        updateState(.waitingReply(minutes: wait))
    }

    func receiveAIReply(_ text: String) {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else { return }

        memoryManager.recordAITurn(text: normalizedText)
        onTranscriptAppend?(normalizedText, false)
        updateState(.speaking)
    }

    func resetToIdle() {
        updateState(.idle)
    }

    func fail(_ message: String) {
        updateState(.error(message))
    }

    static func replyDelayMinutes(for sessionCount: Int) -> Int {
        let options = [5, 10, 30]
        return options[max(0, sessionCount) % options.count]
    }

    private static func currentArchiveContextStatus() -> EchoArchiveContextStatus {
        let snapshot = MemoryArchiveRepository.shared.contextSnapshot()
        return EchoArchiveContextStatus(
            totalItemCount: snapshot.totalItemCount,
            availableItemCount: snapshot.availableItemCount
        )
    }

    func refreshArchiveContextStatus() {
        context = contextStore.current
        let providedStatus = archiveContextStatusProvider()
        archiveContextStatus = EchoArchiveContextStatus(
            totalItemCount: providedStatus.totalItemCount,
            availableItemCount: providedStatus.availableItemCount,
            mode: context.mode
        )
        onArchiveContextStatusChange?(archiveContextStatus)
    }

    private func updateState(_ newState: EchoInteractionState) {
        state = newState
        onStateChange?(newState)
    }
}
