import Foundation

struct DigitalHumanLifecycleToken: Equatable {
    let generation: UInt64
    let interactionGeneration: UInt64
    let contextKey: String
}

struct DigitalHumanBackgroundReleaseLease: Equatable {
    let generation: UInt64
    let contextKey: String
}

final class DigitalHumanLifecycleCoordinator {
    private(set) var generation: UInt64 = 0
    private(set) var interactionGeneration: UInt64 = 0
    private(set) var contextKey = ""
    private(set) var lastInvalidationReason = "initial"
    private(set) var backgroundReleaseGeneration: UInt64 = 0
    private(set) var backgroundReleaseContextKey: String?

    func token(for contextKey: String) -> DigitalHumanLifecycleToken {
        if self.contextKey != contextKey {
            return invalidate(contextKey: contextKey, reason: "contextChanged")
        }
        return currentToken
    }

    @discardableResult
    func invalidate(contextKey: String, reason: String) -> DigitalHumanLifecycleToken {
        generation &+= 1
        interactionGeneration &+= 1
        cancelBackgroundReleaseLease()
        self.contextKey = contextKey
        lastInvalidationReason = reason
        return currentToken
    }

    @discardableResult
    func invalidateInteraction(contextKey: String, reason: String) -> DigitalHumanLifecycleToken {
        guard self.contextKey == contextKey else {
            return invalidate(contextKey: contextKey, reason: reason)
        }
        interactionGeneration &+= 1
        lastInvalidationReason = reason
        return currentToken
    }

    func isCurrent(_ token: DigitalHumanLifecycleToken, contextKey: String) -> Bool {
        token == currentToken && self.contextKey == contextKey
    }

    func isCurrentSession(_ token: DigitalHumanLifecycleToken, contextKey: String) -> Bool {
        token.generation == generation
            && token.contextKey == self.contextKey
            && self.contextKey == contextKey
    }

    func beginBackgroundReleaseLease(contextKey: String) -> DigitalHumanBackgroundReleaseLease {
        backgroundReleaseGeneration &+= 1
        backgroundReleaseContextKey = contextKey
        return DigitalHumanBackgroundReleaseLease(
            generation: backgroundReleaseGeneration,
            contextKey: contextKey
        )
    }

    func cancelBackgroundReleaseLease() {
        backgroundReleaseGeneration &+= 1
        backgroundReleaseContextKey = nil
    }

    func isCurrentBackgroundReleaseLease(
        _ lease: DigitalHumanBackgroundReleaseLease,
        contextKey: String
    ) -> Bool {
        lease.generation == backgroundReleaseGeneration
            && lease.contextKey == backgroundReleaseContextKey
            && lease.contextKey == contextKey
    }

    private var currentToken: DigitalHumanLifecycleToken {
        DigitalHumanLifecycleToken(
            generation: generation,
            interactionGeneration: interactionGeneration,
            contextKey: contextKey
        )
    }
}

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
