import Foundation

enum EchoRuntimeLeaseStatus: String, Equatable {
    case requestingSession
    case active
    case fallback
}

enum EchoRuntimeCallbackScope: Equatable {
    case session
    case interaction
}

enum EchoRuntimeCallbackRejection: Equatable {
    case noActiveLease
    case accountMismatch
    case contextMismatch
    case runtimeGenerationMismatch
    case lifecycleGenerationMismatch
    case interactionGenerationMismatch
    case requestMismatch
    case sessionMismatch
    case sessionNotRequesting
    case sessionExpired
}

enum EchoRuntimeCallbackValidation: Equatable {
    case accepted
    case rejected(EchoRuntimeCallbackRejection)
}

struct EchoRuntimeLease: Equatable {
    let accountLease: AccountLease
    let contextKey: String
    let conversationID: String?
    let requestID: String?
    let sessionID: String?
    let providerAssetID: String?
    let expiresAt: Date?
    let runtimeGeneration: UInt64
    let lifecycleGeneration: UInt64
    let interactionGeneration: UInt64
    let status: EchoRuntimeLeaseStatus
}

struct EchoRuntimeCallbackToken: Equatable {
    let accountLease: AccountLease
    let contextKey: String
    let runtimeGeneration: UInt64
    let lifecycleGeneration: UInt64
    let interactionGeneration: UInt64
    let requestID: String?
    let sessionID: String?
    let scope: EchoRuntimeCallbackScope
}

/// Owns the local validity boundary for a single Echo digital-human runtime.
/// Provider session authority remains on the backend; this coordinator only
/// rejects late callbacks before they can mutate the active UIKit screen.
final class EchoRuntimeSessionCoordinator {
    private(set) var activeLease: EchoRuntimeLease?
    private(set) var runtimeGeneration: UInt64 = 0

    @discardableResult
    func beginSessionRequest(
        accountLease: AccountLease,
        lifecycleToken: DigitalHumanLifecycleToken,
        contextKey: String,
        requestID: String
    ) -> EchoRuntimeCallbackToken {
        runtimeGeneration &+= 1
        let lease = EchoRuntimeLease(
            accountLease: accountLease,
            contextKey: contextKey,
            conversationID: nil,
            requestID: requestID,
            sessionID: nil,
            providerAssetID: nil,
            expiresAt: nil,
            runtimeGeneration: runtimeGeneration,
            lifecycleGeneration: lifecycleToken.generation,
            interactionGeneration: lifecycleToken.interactionGeneration,
            status: .requestingSession
        )
        activeLease = lease
        return callbackToken(for: lease, scope: .session)
    }

    func currentSessionCallbackToken() -> EchoRuntimeCallbackToken? {
        guard let activeLease,
              activeLease.status == .active,
              activeLease.sessionID != nil,
              activeLease.expiresAt.map({ $0 > Date() }) ?? true else {
            return nil
        }
        return callbackToken(for: activeLease, scope: .session)
    }

    @discardableResult
    func activateSession(
        _ callback: EchoRuntimeCallbackToken,
        sessionID: String,
        providerAssetID: String?,
        expiresAt: Date?
    ) -> EchoRuntimeCallbackValidation {
        let validation = validate(callback)
        guard validation == .accepted else {
            return validation
        }
        guard let activeLease,
              activeLease.status == .requestingSession else {
            return .rejected(.sessionNotRequesting)
        }
        self.activeLease = EchoRuntimeLease(
            accountLease: activeLease.accountLease,
            contextKey: activeLease.contextKey,
            conversationID: activeLease.conversationID,
            requestID: nil,
            sessionID: sessionID,
            providerAssetID: providerAssetID,
            expiresAt: expiresAt,
            runtimeGeneration: activeLease.runtimeGeneration,
            lifecycleGeneration: activeLease.lifecycleGeneration,
            interactionGeneration: activeLease.interactionGeneration,
            status: .active
        )
        return .accepted
    }

    @discardableResult
    func markFallback(_ callback: EchoRuntimeCallbackToken) -> EchoRuntimeCallbackValidation {
        let validation = validate(callback)
        guard validation == .accepted,
              let activeLease else {
            return validation
        }
        self.activeLease = EchoRuntimeLease(
            accountLease: activeLease.accountLease,
            contextKey: activeLease.contextKey,
            conversationID: activeLease.conversationID,
            requestID: activeLease.requestID,
            sessionID: activeLease.sessionID,
            providerAssetID: activeLease.providerAssetID,
            expiresAt: activeLease.expiresAt,
            runtimeGeneration: activeLease.runtimeGeneration,
            lifecycleGeneration: activeLease.lifecycleGeneration,
            interactionGeneration: activeLease.interactionGeneration,
            status: .fallback
        )
        return .accepted
    }

    func beginInteraction(
        conversationID: String,
        requestID: String
    ) -> EchoRuntimeCallbackToken? {
        guard let activeLease,
              activeLease.status == .active,
              activeLease.sessionID != nil,
              activeLease.expiresAt.map({ $0 > Date() }) ?? true else {
            return nil
        }
        let interactionGeneration = activeLease.interactionGeneration &+ 1
        let interactionLease = EchoRuntimeLease(
            accountLease: activeLease.accountLease,
            contextKey: activeLease.contextKey,
            conversationID: conversationID,
            requestID: requestID,
            sessionID: activeLease.sessionID,
            providerAssetID: activeLease.providerAssetID,
            expiresAt: activeLease.expiresAt,
            runtimeGeneration: activeLease.runtimeGeneration,
            lifecycleGeneration: activeLease.lifecycleGeneration,
            interactionGeneration: interactionGeneration,
            status: .active
        )
        self.activeLease = interactionLease
        return callbackToken(for: interactionLease, scope: .interaction)
    }

    func finishInteraction() {
        guard let activeLease,
              activeLease.status == .active,
              activeLease.conversationID != nil || activeLease.requestID != nil else {
            return
        }
        self.activeLease = EchoRuntimeLease(
            accountLease: activeLease.accountLease,
            contextKey: activeLease.contextKey,
            conversationID: nil,
            requestID: nil,
            sessionID: activeLease.sessionID,
            providerAssetID: activeLease.providerAssetID,
            expiresAt: activeLease.expiresAt,
            runtimeGeneration: activeLease.runtimeGeneration,
            lifecycleGeneration: activeLease.lifecycleGeneration,
            interactionGeneration: activeLease.interactionGeneration &+ 1,
            status: .active
        )
    }

    /// A successful backend heartbeat extends the session lease.  Keep the
    /// coordinator's callback boundary in sync so an otherwise-valid runtime
    /// is not rejected at the original expiry time.
    @discardableResult
    func renewSession(
        _ callback: EchoRuntimeCallbackToken,
        expiresAt: Date?
    ) -> EchoRuntimeCallbackValidation {
        let validation = validate(callback)
        guard validation == .accepted,
              let activeLease,
              activeLease.status == .active else {
            return validation
        }
        guard expiresAt.map({ $0 > Date() }) == true else {
            return .rejected(.sessionExpired)
        }

        self.activeLease = EchoRuntimeLease(
            accountLease: activeLease.accountLease,
            contextKey: activeLease.contextKey,
            conversationID: activeLease.conversationID,
            requestID: activeLease.requestID,
            sessionID: activeLease.sessionID,
            providerAssetID: activeLease.providerAssetID,
            expiresAt: expiresAt,
            runtimeGeneration: activeLease.runtimeGeneration,
            lifecycleGeneration: activeLease.lifecycleGeneration,
            interactionGeneration: activeLease.interactionGeneration,
            status: activeLease.status
        )
        return .accepted
    }

    func invalidatePendingSessionRequest() {
        guard activeLease?.status == .requestingSession else {
            return
        }
        runtimeGeneration &+= 1
        activeLease = nil
    }

    func releaseRuntime() {
        runtimeGeneration &+= 1
        activeLease = nil
    }

    func validate(_ callback: EchoRuntimeCallbackToken) -> EchoRuntimeCallbackValidation {
        guard let activeLease else {
            return .rejected(.noActiveLease)
        }
        guard activeLease.accountLease == callback.accountLease else {
            return .rejected(.accountMismatch)
        }
        guard activeLease.contextKey == callback.contextKey else {
            return .rejected(.contextMismatch)
        }
        guard activeLease.runtimeGeneration == callback.runtimeGeneration else {
            return .rejected(.runtimeGenerationMismatch)
        }
        guard activeLease.lifecycleGeneration == callback.lifecycleGeneration else {
            return .rejected(.lifecycleGenerationMismatch)
        }
        if let expiresAt = activeLease.expiresAt,
           expiresAt <= Date() {
            return .rejected(.sessionExpired)
        }
        if let callbackSessionID = callback.sessionID,
           activeLease.sessionID != callbackSessionID {
            return .rejected(.sessionMismatch)
        }
        if callback.scope == .interaction {
            guard activeLease.interactionGeneration == callback.interactionGeneration else {
                return .rejected(.interactionGenerationMismatch)
            }
            guard activeLease.requestID == callback.requestID else {
                return .rejected(.requestMismatch)
            }
        }
        return .accepted
    }

    private func callbackToken(
        for lease: EchoRuntimeLease,
        scope: EchoRuntimeCallbackScope
    ) -> EchoRuntimeCallbackToken {
        EchoRuntimeCallbackToken(
            accountLease: lease.accountLease,
            contextKey: lease.contextKey,
            runtimeGeneration: lease.runtimeGeneration,
            lifecycleGeneration: lease.lifecycleGeneration,
            interactionGeneration: lease.interactionGeneration,
            requestID: lease.requestID,
            sessionID: lease.sessionID,
            scope: scope
        )
    }
}

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
        isPausingForProviderSpeech = false
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

    func completeProviderRequest(matching requestID: String) -> ProviderCompletion? {
        guard activeRequestID == requestID else {
            return nil
        }
        let completion = ProviderCompletion(
            turnID: currentTurnID ?? "unknown",
            requestID: requestID,
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
