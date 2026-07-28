import Foundation

@main
enum EchoRuntimeSessionCoordinatorModelSmoke {
    static func main() {
        verifyLateRoleSwitchCannotActivateStaleSession()
        verifyStopPreservesSessionButInvalidatesInteraction()
        verifyReleaseRejectsOutstandingSessionCallback()
        verifyBackgroundOrFallbackReleaseRejectsSessionAndInteractionCallbacks()
        verifySessionCallbackRejectsDifferentProviderSession()
        verifyNewInteractionRejectsPriorRequestCallbacks()
        verifyProviderCompletionRequiresMatchingRequestID()
        verifyExpiredSessionRejectsNewWork()
        verifyHeartbeatRenewalExtendsSessionCallbackBoundary()
        print("Echo runtime session coordinator model smoke passed")
    }

    private static func verifyLateRoleSwitchCannotActivateStaleSession() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 7)
        let first = coordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "request-self"
        )
        let replacement = coordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: token(
                generation: 12,
                interactionGeneration: 4,
                contextKey: "viewer|owner-2|family"
            ),
            contextKey: "viewer|owner-2|family",
            requestID: "request-family"
        )

        require(
            coordinator.activateSession(
                first,
                sessionID: "stale-session",
                providerAssetID: nil,
                expiresAt: nil
            ) == .rejected(.contextMismatch),
            "late role-switch response must not activate the prior session"
        )
        require(
            coordinator.activateSession(
                replacement,
                sessionID: "family-session",
                providerAssetID: "family-asset",
                expiresAt: nil
            ) == .accepted,
            "current role response should activate"
        )
    }

    private static func verifyStopPreservesSessionButInvalidatesInteraction() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "request-self"
        )
        require(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "self-asset",
                expiresAt: nil
            ) == .accepted,
            "active session setup should succeed"
        )
        guard let session = coordinator.currentSessionCallbackToken(),
              let interaction = coordinator.beginInteraction(
                conversationID: "conversation-1",
                requestID: "reply-1"
              ) else {
            fail("active session should issue session and interaction callback tokens")
        }

        coordinator.finishInteraction()

        require(
            coordinator.validate(session) == .accepted,
            "stopping a turn must keep the provider session valid"
        )
        require(
            coordinator.validate(interaction) == .rejected(.interactionGenerationMismatch),
            "stopping a turn must reject late provider interaction callbacks"
        )
    }

    private static func verifyReleaseRejectsOutstandingSessionCallback() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "request-self"
        )
        require(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: nil,
                expiresAt: nil
            ) == .accepted,
            "active session setup should succeed"
        )
        guard let session = coordinator.currentSessionCallbackToken() else {
            fail("active session should issue a callback token")
        }

        coordinator.releaseRuntime()

        require(
            coordinator.validate(session) == .rejected(.noActiveLease),
            "page exit or runtime release must reject late provider callbacks"
        )
    }

    private static func verifyBackgroundOrFallbackReleaseRejectsSessionAndInteractionCallbacks() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "request-self"
        )
        require(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "self-asset",
                expiresAt: nil
            ) == .accepted,
            "active session setup should succeed"
        )
        guard let session = coordinator.currentSessionCallbackToken(),
              let interaction = coordinator.beginInteraction(
                conversationID: "conversation-1",
                requestID: "reply-1"
              ) else {
            fail("active session should issue session and interaction callback tokens")
        }

        coordinator.releaseRuntime()

        require(
            coordinator.validate(session) == .rejected(.noActiveLease),
            "background or fallback runtime release must reject old session callbacks"
        )
        require(
            coordinator.validate(interaction) == .rejected(.noActiveLease),
            "background or fallback runtime release must reject old interaction callbacks"
        )
    }

    private static func verifySessionCallbackRejectsDifferentProviderSession() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 7)
        let request = coordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "request-self"
        )
        require(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "self-asset",
                expiresAt: nil
            ) == .accepted,
            "active session setup should succeed"
        )
        let staleSession = EchoRuntimeCallbackToken(
            accountLease: accountLease,
            contextKey: "viewer|owner-1|self",
            runtimeGeneration: coordinator.runtimeGeneration,
            lifecycleGeneration: 11,
            interactionGeneration: 3,
            requestID: nil,
            sessionID: "previous-session",
            scope: .session
        )

        require(
            coordinator.validate(staleSession) == .rejected(.sessionMismatch),
            "heartbeat or provider state from a replaced session must be rejected"
        )
    }

    private static func verifyNewInteractionRejectsPriorRequestCallbacks() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let sessionRequest = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request"
        )
        require(
            coordinator.activateSession(
                sessionRequest,
                sessionID: "active-session",
                providerAssetID: "self-asset",
                expiresAt: nil
            ) == .accepted,
            "active session setup should succeed"
        )
        guard let first = coordinator.beginInteraction(
            conversationID: "conversation-1",
            requestID: "reply-request-1"
        ), let replacement = coordinator.beginInteraction(
            conversationID: "conversation-1",
            requestID: "reply-request-2"
        ) else {
            fail("active session should issue interaction callback tokens")
        }

        require(
            coordinator.validate(first) == .rejected(.interactionGenerationMismatch),
            "a replacement request must reject older synthesis or PCM callbacks"
        )
        require(
            coordinator.validate(replacement) == .accepted,
            "the newest provider request should remain valid"
        )
    }

    private static func verifyProviderCompletionRequiresMatchingRequestID() {
        let coordinator = DigitalHumanConversationCoordinator()
        coordinator.beginProviderRequest(
            requestID: "current-request",
            replyText: "当前回响",
            turnID: "turn-current",
            keepsPendingReply: true
        )

        require(
            coordinator.completeProviderRequest(matching: "stale-request") == nil,
            "a late provider completion must not clear the current request"
        )
        require(
            coordinator.activeRequestID == "current-request",
            "stale completion must leave the current provider request intact"
        )
        guard let completion = coordinator.completeProviderRequest(matching: "current-request") else {
            fail("current provider completion should be accepted")
        }
        require(completion.requestID == "current-request", "completion must retain the matched request ID")
        require(!coordinator.hasProviderSpeechInFlight, "accepted completion must clear the provider request")
    }

    private static func verifyExpiredSessionRejectsNewWork() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "expired-session-request"
        )
        require(
            coordinator.activateSession(
                request,
                sessionID: "expired-session",
                providerAssetID: "self-asset",
                expiresAt: Date().addingTimeInterval(-1)
            ) == .accepted,
            "an expired provider response still has to be representable for rejection"
        )
        require(
            coordinator.validate(request) == .rejected(.sessionExpired),
            "expired lease callbacks must fail closed"
        )
        require(
            coordinator.currentSessionCallbackToken() == nil,
            "expired lease must not issue a new session callback"
        )
        require(
            coordinator.beginInteraction(conversationID: "conversation", requestID: "reply") == nil,
            "expired lease must not begin a provider interaction"
        )
    }

    private static func verifyHeartbeatRenewalExtendsSessionCallbackBoundary() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: token(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "renew-session-request"
        )
        let initialExpiry = Date().addingTimeInterval(10)
        require(
            coordinator.activateSession(
                request,
                sessionID: "renew-session",
                providerAssetID: "self-asset",
                expiresAt: initialExpiry
            ) == .accepted,
            "active session setup should succeed"
        )
        guard let callback = coordinator.currentSessionCallbackToken() else {
            fail("active session should issue a callback before renewal")
        }
        let renewedExpiry = Date().addingTimeInterval(120)
        require(
            coordinator.renewSession(callback, expiresAt: renewedExpiry) == .accepted,
            "valid heartbeat renewal should update the session expiry"
        )
        require(
            coordinator.activeLease?.expiresAt == renewedExpiry,
            "renewed expiry must become the active callback boundary"
        )
        require(
            coordinator.validate(callback) == .accepted,
            "session callback remains valid after a successful renewal"
        )
    }

    private static func token(
        generation: UInt64,
        interactionGeneration: UInt64,
        contextKey: String
    ) -> DigitalHumanLifecycleToken {
        DigitalHumanLifecycleToken(
            generation: generation,
            interactionGeneration: interactionGeneration,
            contextKey: contextKey
        )
    }

    private static func makeAccountLease(subjectId: String, generation: UInt64) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: "vault-\(subjectId)",
            sessionId: "session-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "epoch-v1"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Echo runtime session coordinator model smoke failed: \(message)\n", stderr)
        exit(1)
    }
}
