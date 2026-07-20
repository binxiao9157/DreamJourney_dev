import XCTest
#if canImport(DreamJourney)
@testable import DreamJourney
#elseif canImport(DreamJourneyCore)
@testable import DreamJourneyCore
#endif

final class AudioOwnerLeaseModelTests: XCTestCase {
    func testDigitalHumanPlaybackPreemptsEchoCaptureAndStaleReleaseCannotClearIt() {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
        let identifiers = SequenceUUIDGenerator(values: [
            UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        ])
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        var model = AudioOwnerLeaseModel()

        let capture = acquire(
            &model,
            owner: .echoCapture,
            priority: .echoCapture,
            scope: scope,
            leaseId: identifiers.next(),
            issuedAt: clock.now
        )
        clock.advance(by: 1)
        let playback = acquire(
            &model,
            owner: .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope,
            leaseId: identifiers.next(),
            issuedAt: clock.now
        )

        XCTAssertEqual(model.activeLease?.leaseId, playback.leaseId)
        XCTAssertEqual(model.release(capture), .ignoredStaleLease(active: playback))
        XCTAssertEqual(model.release(playback), .released(playback))
        XCTAssertNil(model.activeLease)
    }

    func testOlderRuntimeGenerationCannotPreemptCurrentAudioOwner() {
        var model = AudioOwnerLeaseModel()
        let current = acquire(
            &model,
            owner: .archiveRecorder,
            priority: .recorder,
            scope: AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9),
            leaseId: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let result = model.acquire(
            owner: .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 8),
            leaseId: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )

        XCTAssertEqual(result, .deniedStaleGeneration(active: current))
        XCTAssertEqual(model.activeLease, current)
    }

    func testSystemInterruptionOnlyResumesCurrentLease() {
        var model = AudioOwnerLeaseModel()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        let capture = acquire(
            &model,
            owner: .echoCapture,
            priority: .echoCapture,
            scope: scope,
            leaseId: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let playback = acquire(
            &model,
            owner: .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope,
            leaseId: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )

        guard case let .interrupted(interrupted) = model.interruptActiveLease() else {
            return XCTFail("active playback lease should enter interrupted state")
        }
        XCTAssertEqual(interrupted.leaseId, playback.leaseId)
        XCTAssertEqual(interrupted.state, .interrupted)
        XCTAssertEqual(model.resume(capture), .ignoredStaleLease(active: interrupted))

        XCTAssertEqual(model.resume(playback), .resumed(playback))
        XCTAssertEqual(model.activeLease, playback)
    }

    func testOwnerDefaultPurposeAndRouteAreStable() {
        var model = AudioOwnerLeaseModel()
        let profilePreview = acquire(
            &model,
            owner: .profileVoicePreview,
            priority: .playback,
            scope: AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9),
            leaseId: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(profilePreview.purpose, .profileVoicePreview)
        XCTAssertEqual(profilePreview.route, .spokenAudioPreview)
        XCTAssertEqual(profilePreview.state, .active)
    }

    func testEchoLocalPlaybackDefaultPurposeAndRouteAreStable() {
        var model = AudioOwnerLeaseModel()
        let localPlayback = acquire(
            &model,
            owner: .echoLocalPlayback,
            priority: .playback,
            scope: AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9),
            leaseId: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(localPlayback.purpose, .echoLocalTTSPlayback)
        XCTAssertEqual(localPlayback.route, .playAndRecordVoiceChat)
    }

    private func acquire(
        _ model: inout AudioOwnerLeaseModel,
        owner: AudioOwnerLeaseOwner,
        priority: AudioOwnerLeasePriority,
        scope: AudioOwnerLeaseScope,
        leaseId: UUID,
        issuedAt: Date
    ) -> AudioOwnerLease {
        let result = model.acquire(
            owner: owner,
            priority: priority,
            scope: scope,
            leaseId: leaseId,
            issuedAt: issuedAt
        )
        switch result {
        case let .acquired(lease):
            return lease
        case let .preempted(_, current):
            return current
        case .deniedByActiveOwner, .deniedStaleGeneration:
            XCTFail("expected initial audio owner acquisition")
            fatalError("test cannot continue without an audio lease")
        }
    }
}

final class AudioOwnerLeaseCoordinatorTests: XCTestCase {
    func testObserveOnlyTransitionRejectsStaleRelease() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)

        guard case let .acquired(localPlayback) = coordinator.observeOwner(
            .echoLocalPlayback,
            priority: .playback,
            scope: scope
        ) else {
            return XCTFail("local Echo playback should acquire its observation lease")
        }
        guard case let .preempted(previous, digitalHuman) = coordinator.observeOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        ) else {
            return XCTFail("Tencent playback should preempt local Echo playback")
        }
        XCTAssertEqual(previous.leaseId, localPlayback.leaseId)

        XCTAssertEqual(
            coordinator.releaseObservedLease(localPlayback),
            .ignoredStaleRelease(active: digitalHuman)
        )
        XCTAssertEqual(coordinator.diagnosticsSnapshot().activeLease, digitalHuman)
    }

    func testRepeatedObserveOnlyOwnerDoesNotCreateAnotherLease() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        guard case let .acquired(first) = coordinator.observeOwner(
            .echoLocalPlayback,
            priority: .playback,
            scope: scope
        ) else {
            return XCTFail("first local Echo owner should acquire")
        }

        XCTAssertEqual(
            coordinator.observeOwner(
                .echoLocalPlayback,
                priority: .playback,
                scope: scope
            ),
            .unchanged(first)
        )
        XCTAssertEqual(coordinator.diagnosticsSnapshot().observedTransitionCount, 2)
    }

    func testObserveOnlySystemEventsRequireTheCurrentLeaseToken() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        guard case let .acquired(capture) = coordinator.observeOwner(
            .echoCapture,
            priority: .echoCapture,
            scope: scope
        ) else {
            return XCTFail("Echo capture should acquire its observation lease")
        }
        guard case let .preempted(_, digitalHuman) = coordinator.observeOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        ) else {
            return XCTFail("Tencent playback should preempt Echo capture")
        }

        XCTAssertEqual(
            coordinator.observeInterruption(for: capture),
            .ignoredStaleEvent(active: digitalHuman)
        )
        guard case let .interrupted(interruptedDigitalHuman) = coordinator.observeInterruption(for: digitalHuman) else {
            return XCTFail("the current digital-human lease should enter interrupted state")
        }
        XCTAssertEqual(
            coordinator.observeRouteChange(for: capture),
            .ignoredStaleEvent(active: interruptedDigitalHuman)
        )
        XCTAssertEqual(
            coordinator.observeResume(for: capture),
            .ignoredStaleEvent(active: interruptedDigitalHuman)
        )
        XCTAssertEqual(
            coordinator.observeResume(for: interruptedDigitalHuman),
            .resumed(digitalHuman)
        )
    }

    func testFallbackOrBackgroundReleaseClearsTencentLeaseBeforeNewCapture() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let previousScope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        let nextScope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 10)

        guard case let .acquired(digitalHuman) = coordinator.observeOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: previousScope
        ) else {
            return XCTFail("Tencent playback should acquire its observation lease")
        }
        XCTAssertEqual(
            coordinator.releaseObservedLease(digitalHuman),
            .released(digitalHuman)
        )

        guard case let .acquired(capture) = coordinator.observeOwner(
            .echoCapture,
            priority: .echoCapture,
            scope: nextScope
        ) else {
            return XCTFail("a new Echo capture must start after fallback or background release")
        }
        XCTAssertEqual(capture.scope, nextScope)
        XCTAssertEqual(coordinator.diagnosticsSnapshot().activeLease, capture)
    }
}

final class EchoTurnIntentReducerTests: XCTestCase {
    func testOrdinaryTurnTransitionsFromVoiceStartToReplyDelivered() {
        var reducer = EchoTurnIntentReducer()

        XCTAssertEqual(reducer.reduce(.prepareVoiceInteraction).currentPhase, .starting)
        XCTAssertEqual(reducer.reduce(.voiceCaptureStarted).currentPhase, .listening)
        XCTAssertEqual(reducer.reduce(.userTurnAccepted).currentPhase, .thinking)
        XCTAssertEqual(reducer.reduce(.replyStarted).currentPhase, .speaking)

        let delivery = reducer.reduce(.replyDelivered)

        XCTAssertTrue(delivery.accepted)
        XCTAssertEqual(delivery.previousPhase, .speaking)
        XCTAssertEqual(delivery.currentPhase, .replied)
    }

    func testStaleReplyCannotResurrectAnIdleTurn() {
        var reducer = EchoTurnIntentReducer()

        XCTAssertTrue(reducer.reduce(.reset).accepted)
        let staleReply = reducer.reduce(.replyStarted)

        XCTAssertFalse(staleReply.accepted)
        XCTAssertEqual(staleReply.previousPhase, .idle)
        XCTAssertEqual(staleReply.currentPhase, .idle)
        XCTAssertEqual(reducer.phase, .idle)
    }

    func testDelayedReplyCanBeScheduledAndDeliveredWithoutOpeningAnotherTurn() {
        var reducer = EchoTurnIntentReducer()
        _ = reducer.reduce(.prepareVoiceInteraction)
        _ = reducer.reduce(.voiceCaptureStarted)

        XCTAssertEqual(reducer.reduce(.delayedReplyScheduled).currentPhase, .waitingReply)
        XCTAssertFalse(reducer.reduce(.voiceCaptureStarted).accepted)
        XCTAssertEqual(reducer.reduce(.replyDelivered).currentPhase, .replied)
    }

    func testStoredDueReplyAwaitsServerResultAfterAppRelaunchWithoutAcceptingStaleReply() {
        var reducer = EchoTurnIntentReducer()

        XCTAssertFalse(reducer.reduce(.replyDelivered).accepted)

        let restoredDelivery = reducer.reduce(.delayedReplyDue)

        XCTAssertTrue(restoredDelivery.accepted)
        XCTAssertEqual(restoredDelivery.previousPhase, .idle)
        XCTAssertEqual(restoredDelivery.currentPhase, .awaitingReplyDelivery)
        XCTAssertTrue(reducer.reduce(.replyDelivered).accepted)
        XCTAssertEqual(reducer.phase, .replied)
    }

    func testFailureOnlyRetriesFromFailureState() {
        var reducer = EchoTurnIntentReducer()

        XCTAssertFalse(reducer.reduce(.retry).accepted)
        XCTAssertEqual(reducer.reduce(.failure).currentPhase, .failed)
        XCTAssertEqual(reducer.reduce(.retry).currentPhase, .idle)
    }
}

final class EchoApplicationCoordinatorTests: XCTestCase {
    func testContextBuildLeaseSupersedesEarlierRequest() {
        let coordinator = EchoApplicationCoordinator()
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )

        let first = coordinator.beginContextBuild(
            turnID: "turn-1",
            expectedIdentity: identity
        )
        let second = coordinator.beginContextBuild(
            turnID: "turn-2",
            expectedIdentity: identity
        )

        XCTAssertFalse(coordinator.isCurrent(first))
        XCTAssertTrue(coordinator.isCurrent(second))
        XCTAssertEqual(second.generation, first.generation + 1)
        XCTAssertEqual(second.turnID, "turn-2")
        XCTAssertEqual(second.expectedIdentity, identity)
    }

    func testInvalidatingContextBuildRejectsLateCallback() {
        let coordinator = EchoApplicationCoordinator()
        let lease = coordinator.beginContextBuild(
            turnID: "turn-1",
            expectedIdentity: EchoKnowledgeContextIdentity(
                userId: "owner-1",
                personaScope: "self",
                digitalHumanId: "digital-human-1"
            )
        )

        XCTAssertEqual(coordinator.invalidateContextBuild(), lease)
        XCTAssertFalse(coordinator.isCurrent(lease))
        XCTAssertNil(coordinator.activeContextBuildLease)
    }

    func testSameTurnNewGenerationRejectsOldCallback() {
        let coordinator = EchoApplicationCoordinator()
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "family",
            digitalHumanId: "digital-human-2"
        )

        let first = coordinator.beginContextBuild(
            turnID: "same-turn",
            expectedIdentity: identity
        )
        let replacement = coordinator.beginContextBuild(
            turnID: "same-turn",
            expectedIdentity: identity
        )

        XCTAssertNotEqual(first.generation, replacement.generation)
        XCTAssertFalse(coordinator.isCurrent(first))
        XCTAssertTrue(coordinator.isCurrent(replacement))
    }

    func testCoordinatorDropsSupersededTransportCallbackBeforeDelivery() {
        let transport = DeferredEchoContextBuildTransport()
        let coordinator = EchoApplicationCoordinator(contextBuildTransport: transport)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let expectation = expectation(description: "only current context callback delivered")
        expectation.assertForOverFulfill = true
        var deliveredLeases: [EchoContextBuildLease] = []

        let first = coordinator.requestContextBuild(
            turnID: "turn-1",
            query: "first query",
            expectedIdentity: identity,
            lifecycleMode: .sunlight,
            viewerFamilyMemberID: nil
        ) { lease, _ in
            deliveredLeases.append(lease)
        }
        let second = coordinator.requestContextBuild(
            turnID: "turn-2",
            query: "second query",
            expectedIdentity: identity,
            lifecycleMode: .sunlight,
            viewerFamilyMemberID: nil
        ) { lease, _ in
            deliveredLeases.append(lease)
            expectation.fulfill()
        }

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        transport.complete(at: 0, result: .failure(DeferredEchoContextBuildTransport.TestError.failed))
        transport.complete(at: 1, result: .failure(DeferredEchoContextBuildTransport.TestError.failed))

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(deliveredLeases, [second].compactMap { $0 })
    }

    func testCoordinatorDoesNotStartWhenContextTransportIsUnavailable() {
        let transport = DeferredEchoContextBuildTransport()
        transport.isContextBuildConfigured = false
        let coordinator = EchoApplicationCoordinator(contextBuildTransport: transport)
        let result = coordinator.requestContextBuild(
            turnID: "turn-1",
            query: "query",
            expectedIdentity: EchoKnowledgeContextIdentity(
                userId: "owner-1",
                personaScope: "self",
                digitalHumanId: "digital-human-1"
            ),
            lifecycleMode: .sunlight,
            viewerFamilyMemberID: nil
        ) { _, _ in
            XCTFail("unavailable context transport must not invoke completion")
        }

        XCTAssertNil(result)
        XCTAssertTrue(transport.completions.isEmpty)
        XCTAssertNil(coordinator.activeContextBuildLease)
    }

    func testCoordinatorClassifiesIdentityMismatchedPacketBeforeControllerDelivery() {
        let transport = DeferredEchoContextBuildTransport()
        let coordinator = EchoApplicationCoordinator(contextBuildTransport: transport)
        let expectedIdentity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let expectation = expectation(description: "identity mismatch delivered")

        let lease = coordinator.requestContextBuild(
            turnID: "turn-1",
            query: "query",
            expectedIdentity: expectedIdentity,
            lifecycleMode: .sunlight,
            viewerFamilyMemberID: nil
        ) { _, delivery in
            guard case .identityMismatch(let mismatch) = delivery else {
                XCTFail("mismatched packet must not be delivered as success")
                return
            }
            XCTAssertEqual(mismatch.expectedIdentity, expectedIdentity)
            XCTAssertEqual(mismatch.responseUserId, "owner-2")
            XCTAssertEqual(mismatch.responsePersonaScope, "self")
            XCTAssertEqual(mismatch.responseDigitalHumanId, "digital-human-1")
            expectation.fulfill()
        }

        XCTAssertNotNil(lease)
        transport.complete(
            at: 0,
            result: .success(
                makeEchoContextPacket(
                    userId: "owner-2",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1"
                )
            )
        )

        wait(for: [expectation], timeout: 1)
    }
}

final class EchoRuntimeSessionCoordinatorTests: XCTestCase {
    func testLateRoleSwitchSessionCallbackIsRejectedBeforeActivation() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 7)
        let first = coordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request-self"
        )
        let replacement = coordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 12,
                interactionGeneration: 4,
                contextKey: "viewer|owner-2|family"
            ),
            contextKey: "viewer|owner-2|family",
            requestID: "session-request-family"
        )

        XCTAssertEqual(
            coordinator.validate(first),
            .rejected(.contextMismatch)
        )
        XCTAssertEqual(
            coordinator.activateSession(
                first,
                sessionID: "stale-session",
                providerAssetID: "asset-stale",
                expiresAt: nil
            ),
            .rejected(.contextMismatch)
        )
        XCTAssertEqual(
            coordinator.activateSession(
                replacement,
                sessionID: "family-session",
                providerAssetID: "asset-family",
                expiresAt: Date(timeIntervalSince1970: 1_700_000_100)
            ),
            .accepted
        )
        XCTAssertEqual(coordinator.activeLease?.contextKey, "viewer|owner-2|family")
        XCTAssertEqual(coordinator.activeLease?.sessionID, "family-session")
        XCTAssertEqual(coordinator.activeLease?.status, .active)
    }

    func testStopInvalidatesInteractionButPreservesActiveSession() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "asset-self",
                expiresAt: nil
            ),
            .accepted
        )
        let sessionCallback = try! XCTUnwrap(coordinator.currentSessionCallbackToken())
        let interactionCallback = try! XCTUnwrap(
            coordinator.beginInteraction(
                conversationID: "conversation-1",
                requestID: "reply-request-1"
            )
        )

        XCTAssertEqual(coordinator.validate(sessionCallback), .accepted)
        XCTAssertEqual(coordinator.validate(interactionCallback), .accepted)

        coordinator.finishInteraction()

        XCTAssertEqual(coordinator.validate(sessionCallback), .accepted)
        XCTAssertEqual(
            coordinator.validate(interactionCallback),
            .rejected(.interactionGenerationMismatch)
        )
        XCTAssertEqual(coordinator.activeLease?.status, .active)
        XCTAssertEqual(coordinator.activeLease?.sessionID, "active-session")
    }

    func testReleaseRejectsAllOutstandingSessionCallbacks() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "asset-self",
                expiresAt: nil
            ),
            .accepted
        )
        let callback = try! XCTUnwrap(coordinator.currentSessionCallbackToken())

        coordinator.releaseRuntime()

        XCTAssertNil(coordinator.activeLease)
        XCTAssertEqual(coordinator.validate(callback), .rejected(.noActiveLease))
    }

    func testBackgroundOrFallbackReleaseRejectsSessionAndInteractionCallbacks() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "asset-self",
                expiresAt: nil
            ),
            .accepted
        )
        let session = try! XCTUnwrap(coordinator.currentSessionCallbackToken())
        let interaction = try! XCTUnwrap(
            coordinator.beginInteraction(
                conversationID: "conversation-1",
                requestID: "reply-request-1"
            )
        )

        coordinator.releaseRuntime()

        XCTAssertEqual(coordinator.validate(session), .rejected(.noActiveLease))
        XCTAssertEqual(coordinator.validate(interaction), .rejected(.noActiveLease))
    }

    func testSessionCallbackRejectsDifferentProviderSession() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 7)
        let request = coordinator.beginSessionRequest(
            accountLease: accountLease,
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                request,
                sessionID: "active-session",
                providerAssetID: "asset-self",
                expiresAt: nil
            ),
            .accepted
        )

        let staleSessionCallback = EchoRuntimeCallbackToken(
            accountLease: accountLease,
            contextKey: "viewer|owner-1|self",
            runtimeGeneration: coordinator.runtimeGeneration,
            lifecycleGeneration: 11,
            interactionGeneration: 3,
            requestID: nil,
            sessionID: "previous-session",
            scope: .session
        )

        XCTAssertEqual(
            coordinator.validate(staleSessionCallback),
            .rejected(.sessionMismatch)
        )
    }

    func testNewInteractionRejectsPriorRequestCallbacks() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let sessionRequest = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                sessionRequest,
                sessionID: "active-session",
                providerAssetID: "asset-self",
                expiresAt: nil
            ),
            .accepted
        )
        let first = try! XCTUnwrap(
            coordinator.beginInteraction(
                conversationID: "conversation-1",
                requestID: "reply-request-1"
            )
        )
        let replacement = try! XCTUnwrap(
            coordinator.beginInteraction(
                conversationID: "conversation-1",
                requestID: "reply-request-2"
            )
        )

        XCTAssertEqual(
            coordinator.validate(first),
            .rejected(.interactionGenerationMismatch)
        )
        XCTAssertEqual(coordinator.validate(replacement), .accepted)
    }

    func testExpiredSessionRejectsNewWork() {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "expired-session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                request,
                sessionID: "expired-session",
                providerAssetID: "asset-self",
                expiresAt: Date().addingTimeInterval(-1)
            ),
            .accepted
        )

        XCTAssertEqual(coordinator.validate(request), .rejected(.sessionExpired))
        XCTAssertNil(coordinator.currentSessionCallbackToken())
        XCTAssertNil(
            coordinator.beginInteraction(
                conversationID: "conversation",
                requestID: "reply"
            )
        )
    }

    func testHeartbeatRenewalExtendsSessionCallbackBoundary() throws {
        let coordinator = EchoRuntimeSessionCoordinator()
        let request = coordinator.beginSessionRequest(
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 7),
            lifecycleToken: DigitalHumanLifecycleToken(
                generation: 11,
                interactionGeneration: 3,
                contextKey: "viewer|owner-1|self"
            ),
            contextKey: "viewer|owner-1|self",
            requestID: "renew-session-request"
        )
        XCTAssertEqual(
            coordinator.activateSession(
                request,
                sessionID: "renew-session",
                providerAssetID: "asset-self",
                expiresAt: Date().addingTimeInterval(10)
            ),
            .accepted
        )
        let callback = try XCTUnwrap(coordinator.currentSessionCallbackToken())
        let renewedExpiry = Date().addingTimeInterval(120)

        XCTAssertEqual(coordinator.renewSession(callback, expiresAt: renewedExpiry), .accepted)
        XCTAssertEqual(coordinator.activeLease?.expiresAt, renewedExpiry)
        XCTAssertEqual(coordinator.validate(callback), .accepted)
    }

    private func makeAccountLease(subjectId: String, generation: UInt64) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: "vault-\(subjectId)",
            sessionId: "session-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "epoch-v1"
        )
    }
}

final class VoiceDigitalHumanClientPortModelTests: XCTestCase {
    func testOperationScopeCarriesAccountPersonaRoleAndRuntimeGeneration() throws {
        let lease = makeAccountLease(subjectId: "viewer-1", generation: 8)
        let scope = try XCTUnwrap(
            VoiceDigitalHumanOperationScope(
                accountLease: lease,
                personaOwnerId: " family-owner-1 ",
                roleKey: " familyMember ",
                runtimeGeneration: 21
            )
        )

        XCTAssertEqual(scope.ownerUserId, "viewer-1")
        XCTAssertEqual(scope.personaOwnerId, "family-owner-1")
        XCTAssertEqual(scope.roleKey, "familyMember")
        XCTAssertEqual(scope.runtimeGeneration, 21)
        XCTAssertEqual(scope.accountLease, lease)
    }

    func testOperationScopeRejectsMissingPersonaOrRole() {
        let lease = makeAccountLease(subjectId: "viewer-1", generation: 8)

        XCTAssertNil(
            VoiceDigitalHumanOperationScope(
                accountLease: lease,
                personaOwnerId: " ",
                roleKey: "memoir",
                runtimeGeneration: 21
            )
        )
        XCTAssertNil(
            VoiceDigitalHumanOperationScope(
                accountLease: lease,
                personaOwnerId: "owner-1",
                roleKey: "\n",
                runtimeGeneration: 21
            )
        )
    }

    func testVoiceCloneRequestPreservesScopedProfileAndNormalizesOptionalOutputMode() throws {
        let scope = try XCTUnwrap(
            VoiceDigitalHumanOperationScope(
                accountLease: makeAccountLease(subjectId: "viewer-1", generation: 8),
                personaOwnerId: "owner-1",
                roleKey: "memoir",
                runtimeGeneration: 21
            )
        )
        let request = try XCTUnwrap(
            VoiceCloneSynthesisRequest(
                scope: scope,
                voiceProfileId: " voice-family-1 ",
                text: " 一段回忆 ",
                audioFormat: " mp3 ",
                sampleRate: 24_000,
                speechRate: 10,
                loudnessRate: 8,
                outputMode: "  "
            )
        )

        XCTAssertEqual(request.ownerUserId, "viewer-1")
        XCTAssertEqual(request.voiceProfileId, "voice-family-1")
        XCTAssertEqual(request.text, "一段回忆")
        XCTAssertEqual(request.audioFormat, "mp3")
        XCTAssertEqual(request.outputMode, nil)
        XCTAssertEqual(request.scope.runtimeGeneration, 21)
    }

    func testDigitalHumanSessionRequestUsesScopedOwnerAndPersona() throws {
        let scope = try XCTUnwrap(
            VoiceDigitalHumanOperationScope(
                accountLease: makeAccountLease(subjectId: "viewer-1", generation: 8),
                personaOwnerId: "family-owner-1",
                roleKey: "familyMember",
                runtimeGeneration: 21
            )
        )
        let request = try XCTUnwrap(
            DigitalHumanSessionRequest(
                scope: scope,
                scene: " echo ",
                deviceId: " device-1 ",
                lifecycleMode: .sunlight
            )
        )

        XCTAssertEqual(request.ownerUserId, "viewer-1")
        XCTAssertEqual(request.personaId, "family-owner-1")
        XCTAssertEqual(request.scene, "echo")
        XCTAssertEqual(request.deviceId, "device-1")
        XCTAssertEqual(request.lifecycleMode, .sunlight)
    }

    private func makeAccountLease(subjectId: String, generation: UInt64) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: "vault-\(subjectId)",
            sessionId: "session-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "epoch-v1"
        )
    }
}

final class DialogEngineScopedTTSVoiceSelectionStoreTests: XCTestCase {
    func testNewerRoleGenerationKeepsSelectedVoiceProfile() {
        var store = DialogEngineScopedTTSVoiceSelectionStore()
        let bindingID = UUID()
        let lease = makeAccountLease(subjectId: "viewer-1", generation: 7)

        XCTAssertTrue(
            store.update(
                bindingID: bindingID,
                accountLease: lease,
                contextKey: "viewer-1|family-1|sunlight",
                lifecycleGeneration: 12,
                voiceProfileId: " S_family_1 "
            )
        )
        XCTAssertFalse(
            store.update(
                bindingID: bindingID,
                accountLease: lease,
                contextKey: "viewer-1|self|sunlight",
                lifecycleGeneration: 11,
                voiceProfileId: "S_personal_old"
            )
        )
        XCTAssertEqual(
            store.resolvedVoiceProfileId(bindingID: bindingID, accountLease: lease),
            "S_family_1"
        )
    }

    func testSelectionRejectsDifferentAccountGenerationAndClearsByBinding() {
        var store = DialogEngineScopedTTSVoiceSelectionStore()
        let bindingID = UUID()
        let lease = makeAccountLease(subjectId: "viewer-1", generation: 7)
        let otherLease = makeAccountLease(subjectId: "viewer-1", generation: 8)

        XCTAssertTrue(
            store.update(
                bindingID: bindingID,
                accountLease: lease,
                contextKey: "viewer-1|self|sunlight",
                lifecycleGeneration: 1,
                voiceProfileId: "S_personal_1"
            )
        )
        XCTAssertFalse(
            store.update(
                bindingID: bindingID,
                accountLease: otherLease,
                contextKey: "viewer-1|self|sunlight",
                lifecycleGeneration: 2,
                voiceProfileId: "S_personal_2"
            )
        )
        XCTAssertNil(store.resolvedVoiceProfileId(bindingID: bindingID, accountLease: otherLease))
        XCTAssertTrue(store.clear(bindingID: bindingID))
        XCTAssertNil(store.resolvedVoiceProfileId(bindingID: bindingID, accountLease: lease))
    }

    private func makeAccountLease(subjectId: String, generation: UInt64) -> AccountLease {
        AccountLease(
            subjectId: subjectId,
            vaultId: "vault-\(subjectId)",
            sessionId: "session-\(generation)",
            generation: generation,
            generationId: UUID(),
            authorityEpoch: "epoch-v1"
        )
    }
}

private final class DeferredEchoContextBuildTransport: EchoContextBuildTransport {
    enum TestError: Error {
        case failed
    }

    var isContextBuildConfigured = true
    private(set) var completions: [(Result<EchoContextPacket, Error>) -> Void] = []

    func buildEchoContextPacket(
        userId: String,
        query: String,
        personaScope: String,
        digitalHumanId: String,
        lifecycleMode: DigitalHumanMode,
        viewerFamilyMemberID: String?,
        completion: @escaping (Result<EchoContextPacket, Error>) -> Void
    ) {
        completions.append(completion)
    }

    func complete(at index: Int, result: Result<EchoContextPacket, Error>) {
        completions[index](result)
    }
}

private func makeEchoContextPacket(
    userId: String,
    personaScope: String,
    digitalHumanId: String
) -> EchoContextPacket {
    guard let packet = EchoContextPacket(json: [
        "traceId": "trace-id",
        "intent": "echo",
        "userId": userId,
        "personaScope": personaScope,
        "digitalHumanId": digitalHumanId,
    ]) else {
        fatalError("test context packet must decode")
    }
    return packet
}

final class EchoDelayedReplyAnswerReadContractTests: XCTestCase {
    func testCompletedAnswerRequiresOwnerScopedPrivateAnswerAndRedactedInboxReceipt() throws {
        let contract = try EchoDelayedReplyAnswerReadContract(
            backendJSONObject: completedAnswerPayload(),
            expectedUserID: "owner-1",
            expectedDelayedReplyID: "reply-1"
        )

        XCTAssertEqual(contract.userID, "owner-1")
        XCTAssertEqual(contract.delayedReplyID, "reply-1")
        XCTAssertEqual(contract.answer.answerID, "answer-1")
        XCTAssertEqual(contract.answer.body, "服务器已经持久化的回信正文")
        XCTAssertEqual(
            contract.answer.completedAt,
            ISO8601DateFormatter().date(from: "2026-07-20T08:00:00Z")
        )
        XCTAssertEqual(contract.answer.contextReceipt.contextVersion, "echo-context-v4")
        XCTAssertTrue(contract.receipt.mailboxProjectionBodyRedacted)
        XCTAssertEqual(contract.receipt.sourceAnswerID, contract.answer.answerID)
    }

    func testAnswerReadRejectsAReceiptThatCouldExposeAnInboxBody() {
        var payload = completedAnswerPayload()
        var receipt = payload["receipt"] as! [String: Any]
        receipt["mailboxProjectionBodyRedacted"] = false
        payload["receipt"] = receipt

        XCTAssertThrowsError(
            try EchoDelayedReplyAnswerReadContract(
                backendJSONObject: payload,
                expectedUserID: "owner-1",
                expectedDelayedReplyID: "reply-1"
            )
        )
    }

    private func completedAnswerPayload() -> [String: Any] {
        [
            "status": "completed",
            "userId": "owner-1",
            "delayedReplyId": "reply-1",
            "answer": [
                "answerId": "answer-1",
                "body": "服务器已经持久化的回信正文",
                "completedAt": "2026-07-20T08:00:00Z",
                "conversationId": "conversation-1",
                "requestId": "request-1",
                "replyGeneration": 1,
                "contextReceipt": [
                    "contextHash": String(repeating: "a", count: 64),
                    "contextVersion": "echo-context-v4",
                    "citationReceiptHash": String(repeating: "b", count: 64),
                    "policyVersion": "echo-policy-v4",
                ],
            ],
            "receipt": [
                "deliveryState": "completed",
                "deliveryProtocolVersion": "echo-delayed-reply-v1",
                "mailboxProjectionBodyRedacted": true,
                "sourceAnswerId": "answer-1",
            ],
        ]
    }
}

final class EchoDelayedReplyAnswerReconciliationTests: XCTestCase {
    func testCompletedServerAnswerCreatesRedactedInboxPointerAndRetiresPendingReply() throws {
        let fixture = makeFixture()
        fixture.client.result = .success(try completedAnswerContract())
        var appendedText: String?
        fixture.viewModel.onTranscriptAppend = { text, isUser in
            if !isUser {
                appendedText = text
            }
        }

        let expectation = expectation(description: "server answer reconciled")
        fixture.viewModel.reconcilePendingDelayedReplyAnswerIfQAGated(
            accountLease: fixture.lease,
            roleContextKey: fixture.callsiteContext.roleContextKey
        ) { outcome in
            XCTAssertEqual(outcome, .delivered(answerID: "answer-1"))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertNil(fixture.delayedReplyStore.load(
            resourceOwnerId: fixture.lease.subjectId,
            operationId: fixture.delayedReply.id,
            accountLease: fixture.lease
        ))
        XCTAssertNil(fixture.viewModel.pendingDelayedReply)
        XCTAssertEqual(appendedText, "服务器已经持久化的回信正文")
        let inbox = fixture.messageStore.inboxSources(
            accountLease: fixture.lease,
            resourceOwnerId: fixture.lease.subjectId
        )
        XCTAssertEqual(inbox.count, 1)
        XCTAssertEqual(inbox.first?.echoReplyId, fixture.delayedReply.id)
        XCTAssertEqual(inbox.first?.echoReplySummary, "之前等待的回响已经准备好，可以继续对话。")
        guard case .replied = fixture.viewModel.state else {
            return XCTFail("completed server Answer must move Echo to replied")
        }
    }

    func testNotReadyServerAnswerLeavesPendingReplyAndInboxUntouched() throws {
        let fixture = makeFixture()
        fixture.client.result = .failure(DreamJourneyBackendClient.ClientError.backendError(
            statusCode: 409,
            context: .init(
                code: "echo_delayed_reply_answer_not_ready",
                detail: "Answer is not ready"
            )
        ))

        let expectation = expectation(description: "server answer remains pending")
        fixture.viewModel.reconcilePendingDelayedReplyAnswerIfQAGated(
            accountLease: fixture.lease,
            roleContextKey: fixture.callsiteContext.roleContextKey
        ) { outcome in
            XCTAssertEqual(outcome, .serverAnswerNotReady)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        XCTAssertNotNil(fixture.delayedReplyStore.load(
            resourceOwnerId: fixture.lease.subjectId,
            operationId: fixture.delayedReply.id,
            accountLease: fixture.lease
        ))
        XCTAssertEqual(
            fixture.messageStore.inboxSources(
                accountLease: fixture.lease,
                resourceOwnerId: fixture.lease.subjectId
            ).count,
            0
        )
        guard case .awaitingReplyDelivery = fixture.viewModel.state else {
            return XCTFail("not-ready server Answer must keep Echo awaiting delivery")
        }
    }

    private func makeFixture() -> DelayedReplyFixture {
        let suiteName = "EchoDelayedReplyAnswerReconciliationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-v1")
        runtime.publish(session: AccountSession(
            subjectId: "owner-1",
            vaultId: "vault-1",
            sessionId: "session-1",
            tokenFamilyId: "token-family-1",
            sessionVersion: 1,
            generation: 1,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            state: .active,
            activatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        let lease = runtime.capture(forSubjectId: "owner-1")!
        let delayedReplyStore = EchoDelayedReplyStore(
            defaults: defaults,
            accountLeaseRuntime: runtime
        )
        let callsiteScopeStore = EchoDelayedReplyCallsiteScopeStore(
            defaults: defaults,
            accountLeaseRuntime: runtime
        )
        let messageStore = EchoReplyMessageStore(
            defaults: defaults,
            accountLeaseRuntime: runtime
        )
        let client = EchoDelayedReplyAnswerReadClientStub()
        let delayedReply = EchoDelayedReply(
            id: "reply-1",
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_000),
            deliverAt: Date(timeIntervalSince1970: 1_700_000_060),
            minutes: 1,
            userTurnCount: 10,
            trigger: .tenRoundBaseline
        )
        let callsiteContext = EchoDelayedReplyCallsiteContext(
            accountLease: lease,
            resourceOwnerId: lease.subjectId,
            operationId: delayedReply.id,
            roleContextKey: "owner-1|owner-1|selfAssistant|self"
        )!
        XCTAssertTrue(delayedReplyStore.save(
            delayedReply,
            resourceOwnerId: lease.subjectId,
            operationId: delayedReply.id,
            accountLease: lease
        ))
        XCTAssertTrue(callsiteScopeStore.save(callsiteContext))
        let viewModel = EchoViewModel(
            accountLeaseRuntime: runtime,
            delayedReplyStore: delayedReplyStore,
            delayedReplyCallsiteScopeStore: callsiteScopeStore,
            delayedReplyAnswerReadClient: client,
            delayedReplyAnswerReconciliationEnabled: { true },
            echoReplyMessageStore: messageStore
        )
        XCTAssertTrue(viewModel.restoreStoredDelayedReplyIfAvailable(
            accountLease: lease,
            resourceOwnerId: lease.subjectId,
            roleContextKey: callsiteContext.roleContextKey,
            now: Date(timeIntervalSince1970: 1_700_000_120)
        ))
        return DelayedReplyFixture(
            suiteName: suiteName,
            defaults: defaults,
            lease: lease,
            delayedReply: delayedReply,
            callsiteContext: callsiteContext,
            delayedReplyStore: delayedReplyStore,
            messageStore: messageStore,
            client: client,
            viewModel: viewModel
        )
    }

    private func completedAnswerContract() throws -> EchoDelayedReplyAnswerReadContract {
        try EchoDelayedReplyAnswerReadContract(
            backendJSONObject: [
                "status": "completed",
                "userId": "owner-1",
                "delayedReplyId": "reply-1",
                "answer": [
                    "answerId": "answer-1",
                    "body": "服务器已经持久化的回信正文",
                    "completedAt": "2026-07-20T08:00:00Z",
                    "conversationId": "conversation-1",
                    "requestId": "request-1",
                    "replyGeneration": 1,
                    "contextReceipt": [
                        "contextHash": String(repeating: "a", count: 64),
                        "contextVersion": "echo-context-v4",
                        "citationReceiptHash": String(repeating: "b", count: 64),
                        "policyVersion": "echo-policy-v4",
                    ],
                ],
                "receipt": [
                    "deliveryState": "completed",
                    "deliveryProtocolVersion": "echo-delayed-reply-v1",
                    "mailboxProjectionBodyRedacted": true,
                    "sourceAnswerId": "answer-1",
                ],
            ],
            expectedUserID: "owner-1",
            expectedDelayedReplyID: "reply-1"
        )
    }
}

private final class DelayedReplyFixture {
    let suiteName: String
    let defaults: UserDefaults
    let lease: AccountLease
    let delayedReply: EchoDelayedReply
    let callsiteContext: EchoDelayedReplyCallsiteContext
    let delayedReplyStore: EchoDelayedReplyStore
    let messageStore: EchoReplyMessageStore
    let client: EchoDelayedReplyAnswerReadClientStub
    let viewModel: EchoViewModel

    init(
        suiteName: String,
        defaults: UserDefaults,
        lease: AccountLease,
        delayedReply: EchoDelayedReply,
        callsiteContext: EchoDelayedReplyCallsiteContext,
        delayedReplyStore: EchoDelayedReplyStore,
        messageStore: EchoReplyMessageStore,
        client: EchoDelayedReplyAnswerReadClientStub,
        viewModel: EchoViewModel
    ) {
        self.suiteName = suiteName
        self.defaults = defaults
        self.lease = lease
        self.delayedReply = delayedReply
        self.callsiteContext = callsiteContext
        self.delayedReplyStore = delayedReplyStore
        self.messageStore = messageStore
        self.client = client
        self.viewModel = viewModel
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private final class EchoDelayedReplyAnswerReadClientStub: EchoDelayedReplyAnswerReadClient {
    var result: Result<EchoDelayedReplyAnswerReadContract, Error>?

    func fetchEchoDelayedReplyAnswer(
        userID: String,
        delayedReplyID: String,
        completion: @escaping (Result<EchoDelayedReplyAnswerReadContract, Error>) -> Void
    ) {
        completion(result ?? .failure(EchoDelayedReplyAnswerReadContractError.invalidResponse(
            "missing test result"
        )))
    }
}
