import Foundation

@main
enum EchoRuntimeSessionCoordinatorModelSmoke {
    static func main() {
        verifyLateRoleSwitchCannotActivateStaleSession()
        verifyStopPreservesSessionButInvalidatesInteraction()
        verifyReleaseRejectsOutstandingSessionCallback()
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
