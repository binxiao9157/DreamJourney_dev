import Foundation

// MARK: - Dialog Engine Shared Models

enum DialogEndReason {
    case manual
    case keyword(String)
    case silenceTimeout
    case serverEnded
    case crisis(SafetyAssessment)
}

protocol DialogEngineDelegate: AnyObject {
    func onDialogStarted()
    func onASRResult(text: String, isFinal: Bool)
    func onTTSStarted(text: String)
    func onTTSFinished()
    func onChatStreaming(text: String)
    func onError(error: Error)
    func onSafetyTriggered(assessment: SafetyAssessment)
    func onDialogEnded(reason: DialogEndReason)
}

extension DialogEngineDelegate {
    func onSafetyTriggered(assessment: SafetyAssessment) {}
}
