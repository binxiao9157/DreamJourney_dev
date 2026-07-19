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

    func testStoredDueReplyCanDeliverAfterAppRelaunchWithoutAcceptingStaleReply() {
        var reducer = EchoTurnIntentReducer()

        XCTAssertFalse(reducer.reduce(.replyDelivered).accepted)

        let restoredDelivery = reducer.reduce(.restoredDelayedReplyDelivered)

        XCTAssertTrue(restoredDelivery.accepted)
        XCTAssertEqual(restoredDelivery.previousPhase, .idle)
        XCTAssertEqual(restoredDelivery.currentPhase, .replied)
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
