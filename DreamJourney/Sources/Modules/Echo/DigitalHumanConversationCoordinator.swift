import Foundation

final class DigitalHumanConversationCoordinator {
    private(set) var activeRequestID: String?
    private(set) var pendingReplyText: String?
    private(set) var currentTurnID: String?
    private(set) var lastReplyTextSent: String?
    private(set) var isPausingForProviderSpeech = false
    private(set) var shouldResumeAfterProviderSpeech = false

    var hasProviderSpeechInFlight: Bool {
        activeRequestID != nil || pendingReplyText != nil
    }

    func reset(cancelPrewarm: () -> Void, cancelTextOverTimeout: () -> Void) {
        cancelPrewarm()
        cancelTextOverTimeout()
        activeRequestID = nil
        pendingReplyText = nil
        currentTurnID = nil
        lastReplyTextSent = nil
        isPausingForProviderSpeech = false
        shouldResumeAfterProviderSpeech = false
    }

    func markPausingForProviderSpeech() {
        isPausingForProviderSpeech = true
        shouldResumeAfterProviderSpeech = true
    }

    func consumePausingForProviderSpeech() -> Bool {
        guard isPausingForProviderSpeech else {
            return false
        }
        isPausingForProviderSpeech = false
        return true
    }

    func consumeResumeAfterProviderSpeech() -> Bool {
        guard shouldResumeAfterProviderSpeech else {
            return false
        }
        shouldResumeAfterProviderSpeech = false
        return true
    }

    func clearResumeState() {
        isPausingForProviderSpeech = false
        shouldResumeAfterProviderSpeech = false
    }

    func clearProviderRequest() {
        activeRequestID = nil
        pendingReplyText = nil
    }

    func clearProviderRequestAndResumeState() {
        clearProviderRequest()
        clearResumeState()
    }

    func clearForRouteFailure() {
        clearProviderRequestAndResumeState()
        lastReplyTextSent = nil
    }

    func ensureTurnID(makeID: () -> String) -> String {
        if let currentTurnID {
            return currentTurnID
        }
        let turnID = makeID()
        currentTurnID = turnID
        return turnID
    }

    @discardableResult
    func startUserTurn(makeID: () -> String) -> String {
        let turnID = makeID()
        currentTurnID = turnID
        return turnID
    }

    func isDuplicateReply(_ replyText: String) -> Bool {
        lastReplyTextSent == replyText
    }

    func beginProviderRequest(
        requestID: String,
        replyText: String,
        turnID: String,
        keepsPendingReply: Bool
    ) {
        activeRequestID = requestID
        currentTurnID = turnID
        lastReplyTextSent = replyText
        pendingReplyText = keepsPendingReply ? replyText : nil
    }

    func completeProviderRequest() -> ProviderCompletion? {
        guard hasProviderSpeechInFlight else {
            return nil
        }
        let completion = ProviderCompletion(
            turnID: currentTurnID ?? "unknown",
            requestID: activeRequestID ?? "unknown",
            replyText: pendingReplyText
        )
        clearProviderRequest()
        return completion
    }

    func shouldInterruptOnUserStop(routeEchoAudioThroughDigitalHuman: Bool) -> Bool {
        hasProviderSpeechInFlight ||
            (routeEchoAudioThroughDigitalHuman && shouldResumeAfterProviderSpeech)
    }
}

extension DigitalHumanConversationCoordinator {
    struct ProviderCompletion {
        let turnID: String
        let requestID: String
        let replyText: String?
    }
}
