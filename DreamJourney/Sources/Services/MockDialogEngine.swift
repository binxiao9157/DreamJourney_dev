import Foundation

final class MockDialogEngine: DialogEngineProtocol {
    weak var delegate: DialogEngineDelegate?
    private(set) var isEngineReady = false
    private(set) var isDialogActive = false

    func setup() {
        isEngineReady = true
    }

    func startDialog() {
        guard isEngineReady else {
            delegate?.onError(error: MockDialogEngineError.engineNotReady)
            return
        }
        guard !isDialogActive else { return }
        isDialogActive = true
        delegate?.onDialogStarted()
    }

    func stopDialog(reason: DialogEndReason) {
        guard isDialogActive else { return }
        isDialogActive = false
        delegate?.onDialogEnded(reason: reason)
    }

    func destroyEngine() {
        if isDialogActive {
            stopDialog(reason: .manual)
        }
        isEngineReady = false
    }

    func simulateUserTurn(_ text: String) {
        guard isDialogActive else {
            delegate?.onError(error: MockDialogEngineError.dialogNotActive)
            return
        }

        let assessment = SafetyMonitor.shared.evaluate(text)
        if assessment.shouldBlockRoleplay {
            delegate?.onSafetyTriggered(assessment: assessment)
            stopDialog(reason: .crisis(assessment))
            return
        }

        delegate?.onASRResult(text: text, isFinal: true)
        let reply = deterministicReply(for: text)
        delegate?.onChatStreaming(text: reply)
        delegate?.onTTSStarted(text: reply)
        delegate?.onTTSFinished()
    }

    private func deterministicReply(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "我在这里，我们可以慢慢聊。"
        }
        return "我听见你提到：\(trimmed)。我们可以继续把这段记忆整理清楚。"
    }
}

enum MockDialogEngineError: LocalizedError {
    case engineNotReady
    case dialogNotActive

    var errorDescription: String? {
        switch self {
        case .engineNotReady:
            return "Mock dialog engine is not ready."
        case .dialogNotActive:
            return "Mock dialog is not active."
        }
    }
}
