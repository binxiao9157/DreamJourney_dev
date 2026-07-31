import XCTest
import UIKit
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

final class AudioSessionCoordinatorTests: XCTestCase {
    func testTencentPlaybackPreemptsCaptureAndStaleReleaseCannotDeactivateIt() {
        let driver = RecordingAudioSessionDriver()
        let coordinator = AudioSessionCoordinator(driver: driver)
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)

        guard case let .acquired(capture) = coordinator.acquire(
            .echoCapture,
            priority: .echoCapture,
            scope: scope
        ) else {
            return XCTFail("Echo capture should activate first")
        }
        guard case let .preempted(previous, playback) = coordinator.acquire(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        ) else {
            return XCTFail("Tencent playback should preempt capture")
        }

        XCTAssertEqual(previous.leaseId, capture.leaseId)
        XCTAssertEqual(
            coordinator.release(capture),
            .ignoredStaleRelease(active: playback)
        )
        XCTAssertTrue(driver.deactivatedLeases.isEmpty)
        XCTAssertTrue(coordinator.isCurrentActiveLease(playback))

        XCTAssertEqual(coordinator.release(playback), .released(playback))
        XCTAssertEqual(driver.deactivatedLeases, [playback])
    }

    func testFailedTencentPreemptionRestoresCaptureAndDoesNotCommitNewOwner() {
        let driver = RecordingAudioSessionDriver()
        driver.failingActivationOwners = [.tencentDigitalHumanPlayback]
        let coordinator = AudioSessionCoordinator(driver: driver)
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)

        guard case let .acquired(capture) = coordinator.acquire(
            .echoCapture,
            priority: .echoCapture,
            scope: scope
        ) else {
            return XCTFail("Echo capture should activate")
        }

        let result = coordinator.acquire(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        )
        guard case let .activationFailed(requested, active, recoveryAttempted) = result else {
            return XCTFail("failed playback activation must be surfaced")
        }

        XCTAssertEqual(requested.owner, .tencentDigitalHumanPlayback)
        XCTAssertEqual(active, capture)
        XCTAssertTrue(recoveryAttempted)
        XCTAssertTrue(coordinator.isCurrentActiveLease(capture))
        XCTAssertEqual(
            driver.activatedLeases.map(\.owner),
            [.echoCapture, .tencentDigitalHumanPlayback, .echoCapture]
        )
    }

    func testOnlyCurrentInterruptedLeaseCanResumeAndResumeReactivatesDriver() {
        let driver = RecordingAudioSessionDriver()
        let coordinator = AudioSessionCoordinator(driver: driver)
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)

        guard case let .acquired(capture) = coordinator.acquire(
            .echoCapture,
            priority: .echoCapture,
            scope: scope
        ), case let .preempted(_, playback) = coordinator.acquire(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        ), case let .interrupted(interrupted) = coordinator.interrupt(playback) else {
            return XCTFail("current Tencent playback should enter interruption state")
        }

        XCTAssertEqual(
            coordinator.resume(capture),
            .ignoredStaleEvent(active: interrupted)
        )
        XCTAssertEqual(coordinator.resume(interrupted), .resumed(playback))
        XCTAssertTrue(coordinator.isCurrentActiveLease(playback))
        XCTAssertEqual(
            driver.activatedLeases.map(\.owner),
            [.echoCapture, .tencentDigitalHumanPlayback, .tencentDigitalHumanPlayback]
        )
    }

    func testFailedDeactivationRetainsCurrentLease() {
        let driver = RecordingAudioSessionDriver()
        driver.shouldFailDeactivation = true
        let coordinator = AudioSessionCoordinator(driver: driver)
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)

        guard case let .acquired(capture) = coordinator.acquire(
            .echoCapture,
            priority: .echoCapture,
            scope: scope
        ) else {
            return XCTFail("Echo capture should activate")
        }

        XCTAssertEqual(
            coordinator.release(capture),
            .deactivationFailed(active: capture)
        )
        XCTAssertTrue(coordinator.isCurrentActiveLease(capture))
    }
}

final class TencentDigitalHumanCloudRuntimeTests: XCTestCase {
    func testTerminalEventsOnlyCompleteTheMatchingActiveRequest() throws {
        let bridge = TencentTerminalEventTestBridge()
        let runtime = TencentDigitalHumanCloudRuntime(
            contract: try makeMockContract(),
            bridge: bridge,
            contentView: UIView()
        )
        var observedStates: [DigitalHumanSessionState] = []
        runtime.onStateChange = { observedStates.append($0) }

        try runtime.configure(DigitalHumanProfile(
            provider: "tencent",
            personaId: "qa-persona",
            displayName: "QA Tencent",
            lifecycleMode: .sunlight,
            driveMode: "streamText",
            alphaEnabled: true,
            smartActionEnabled: false,
            assetKey: "qa-asset"
        ))
        try runtime.open()
        bridge.emit(.webSocketOpen)

        let firstRequest = "request-first"
        try runtime.sendTextChunk("第一轮", requestID: firstRequest, sequence: 0, isFinal: true)
        bridge.emit(.audioStart(requestID: firstRequest))
        bridge.emit(.textOver(requestID: firstRequest))

        XCTAssertEqual(runtime.state, .speaking(requestID: firstRequest))
        XCTAssertFalse(observedStates.contains(.completed(requestID: firstRequest)))

        bridge.emit(.audioOver(requestID: nil))
        bridge.emit(.audioOver(requestID: "request-stale"))
        XCTAssertEqual(runtime.state, .speaking(requestID: firstRequest))
        XCTAssertFalse(observedStates.contains(.completed(requestID: firstRequest)))

        let secondRequest = "request-second"
        try runtime.sendTextChunk("第二轮", requestID: secondRequest, sequence: 0, isFinal: true)
        bridge.emit(.audioOver(requestID: firstRequest))
        XCTAssertEqual(runtime.state, .buffering)
        XCTAssertFalse(observedStates.contains(.completed(requestID: firstRequest)))

        bridge.emit(.audioStart(requestID: secondRequest))
        bridge.emit(.audioOver(requestID: secondRequest))

        XCTAssertEqual(runtime.state, .ready)
        XCTAssertEqual(
            observedStates.filter { $0 == .completed(requestID: secondRequest) }.count,
            1
        )
        XCTAssertFalse(observedStates.contains(.completed(requestID: firstRequest)))

        let interruptedRequest = "request-interrupted"
        try runtime.sendTextChunk("第三轮", requestID: interruptedRequest, sequence: 0, isFinal: true)
        runtime.interrupt()
        bridge.emit(.audioOver(requestID: interruptedRequest))

        XCTAssertEqual(runtime.state, .interrupting)
        XCTAssertFalse(observedStates.contains(.completed(requestID: interruptedRequest)))
    }

    private func makeMockContract() throws -> DigitalHumanSessionContract {
        try XCTUnwrap(DigitalHumanSessionContract(json: [
            "sessionId": "qa-session",
            "userId": "qa-owner",
            "provider": "tencent",
            "providerMode": "mockContract",
            "personaId": "qa-persona",
            "scene": "echo",
            "deviceId": "qa-device",
            "lifecycleMode": DigitalHumanMode.sunlight.rawValue,
            "driveMode": "streamText",
            "assetKey": "qa-asset",
            "contractVersion": 1,
        ]))
    }
}

private final class RecordingAudioSessionDriver: AudioSessionDriving {
    enum DriverError: Error {
        case activationRejected
        case deactivationRejected
    }

    var activatedLeases: [AudioOwnerLease] = []
    var deactivatedLeases: [AudioOwnerLease] = []
    var failingActivationOwners: Set<AudioOwnerLeaseOwner> = []
    var shouldFailDeactivation = false

    func activate(for lease: AudioOwnerLease) throws {
        activatedLeases.append(lease)
        if failingActivationOwners.contains(lease.owner) {
            throw DriverError.activationRejected
        }
    }

    func deactivate(after lease: AudioOwnerLease) throws {
        deactivatedLeases.append(lease)
        if shouldFailDeactivation {
            throw DriverError.deactivationRejected
        }
    }
}

private final class TencentTerminalEventTestBridge: TencentDigitalHumanSDKBridge {
    let contentView = UIView()
    var eventHandler: ((TencentDigitalHumanSDKBridgeEvent) -> Void)?

    func configure(
        _ configuration: TencentDigitalHumanSDKConfiguration,
        profile: DigitalHumanProfile
    ) throws {
        _ = configuration
        _ = profile
    }

    func openByAsset(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success("qa-session"))
    }

    func openByProject(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.success("qa-session"))
    }

    func sendText(_ text: String, requestID: String, sequence: Int, isFinal: Bool) throws {
        _ = text
        _ = requestID
        _ = sequence
        _ = isFinal
    }

    func sendPCM(_ data: Data, requestID: String, sequence: Int, isFinal: Bool) throws {
        _ = data
        _ = requestID
        _ = sequence
        _ = isFinal
    }

    func setRemoteAudioMuted(_ muted: Bool) {
        _ = muted
    }

    func interrupt() {}

    func close() {}

    func emit(_ event: TencentDigitalHumanSDKBridgeEvent) {
        eventHandler?(event)
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

final class EchoViewModelTurnAdmissionTests: XCTestCase {
    func testDuplicateFinalUserVoiceIsRejectedBeforeTranscriptSideEffects() throws {
        let suiteName = "EchoViewModelTurnAdmissionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

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
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-1"))
        let viewModel = EchoViewModel(
            archiveContextStatusProvider: { .empty },
            accountLeaseRuntime: runtime,
            delayedReplyStore: EchoDelayedReplyStore(
                defaults: defaults,
                accountLeaseRuntime: runtime
            ),
            delayedReplyCallsiteScopeStore: EchoDelayedReplyCallsiteScopeStore(
                defaults: defaults,
                accountLeaseRuntime: runtime
            )
        )
        var appendedUserTurns: [String] = []
        viewModel.onTranscriptAppend = { text, isUser in
            if isUser {
                appendedUserTurns.append(text)
            }
        }

        viewModel.prepareVoiceInteraction()
        viewModel.beginVoiceInteraction()

        XCTAssertTrue(viewModel.finishUserVoice(
            text: "我想讲讲小时候散步的事",
            accountLease: lease,
            resourceOwnerId: lease.subjectId,
            roleContextKey: "owner-1|self"
        ))
        XCTAssertFalse(viewModel.finishUserVoice(
            text: "我想讲讲小时候散步的事",
            accountLease: lease,
            resourceOwnerId: lease.subjectId,
            roleContextKey: "owner-1|self"
        ))
        XCTAssertEqual(appendedUserTurns, ["我想讲讲小时候散步的事"])
        guard case .thinking = viewModel.state else {
            return XCTFail("the accepted first turn must remain the sole thinking turn")
        }
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
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: transport,
            accountLeaseValidator: allowedAccountLeaseValidation
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 1)
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
            accountLease: accountLease,
            lifecycleMode: .sunlight,
            viewerFamilyMemberID: nil
        ) { lease, _ in
            deliveredLeases.append(lease)
        }
        let second = coordinator.requestContextBuild(
            turnID: "turn-2",
            query: "second query",
            expectedIdentity: identity,
            accountLease: accountLease,
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

    func testCoordinatorDeliversCurrentContextCallbackOnlyOnce() {
        let transport = DeferredEchoContextBuildTransport()
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: transport,
            accountLeaseValidator: allowedAccountLeaseValidation
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 1)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let firstDelivery = expectation(description: "current context callback is delivered once")
        let duplicateDelivery = expectation(description: "duplicate context callback is dropped")
        duplicateDelivery.isInverted = true
        var completionCount = 0

        let lease = coordinator.requestContextBuild(
            turnID: "turn-1",
            query: "one provider completion must produce one context delivery",
            expectedIdentity: identity,
            accountLease: accountLease,
            lifecycleMode: .sunlight,
            viewerFamilyMemberID: nil
        ) { _, delivery in
            completionCount += 1
            guard case .success = delivery else {
                return XCTFail("first current delivery must retain the context packet")
            }
            if completionCount == 1 {
                firstDelivery.fulfill()
            } else {
                duplicateDelivery.fulfill()
            }
        }

        XCTAssertNotNil(lease)
        transport.complete(
            at: 0,
            result: .success(
                makeEchoContextPacket(
                    userId: "owner-1",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1"
                )
            )
        )

        wait(for: [firstDelivery], timeout: 1)
        XCTAssertEqual(coordinator.activeContextBuildLease, lease)

        transport.complete(at: 0, result: .failure(DeferredEchoContextBuildTransport.TestError.failed))
        wait(for: [duplicateDelivery], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
    }

    func testCoordinatorDoesNotStartWhenContextTransportIsUnavailable() {
        let transport = DeferredEchoContextBuildTransport()
        transport.isContextBuildConfigured = false
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: transport,
            accountLeaseValidator: allowedAccountLeaseValidation
        )
        let result = coordinator.requestContextBuild(
            turnID: "turn-1",
            query: "query",
            expectedIdentity: EchoKnowledgeContextIdentity(
                userId: "owner-1",
                personaScope: "self",
                digitalHumanId: "digital-human-1"
            ),
            accountLease: makeAccountLease(subjectId: "owner-1", generation: 1),
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
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: transport,
            accountLeaseValidator: allowedAccountLeaseValidation
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 1)
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
            accountLease: accountLease,
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

    func testContextBuildStillDeliversLegacyPacketWhenRequestCorrelationIsMissing() {
        let transport = DeferredEchoContextBuildTransport()
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: transport,
            accountLeaseValidator: allowedAccountLeaseValidation
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 1)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let expectation = expectation(description: "legacy public packet is still delivered")

        XCTAssertNotNil(
            coordinator.requestContextBuild(
                turnID: "turn-legacy-packet",
                query: "ordinary public Echo cannot depend on QA correlation",
                expectedIdentity: identity,
                accountLease: accountLease,
                lifecycleMode: .sunlight,
                viewerFamilyMemberID: nil
            ) { _, delivery in
                guard case .success(let packet) = delivery else {
                    return XCTFail("legacy packet must retain public delivery compatibility")
                }
                XCTAssertNil(packet.requestCorrelation)
                expectation.fulfill()
            }
        )
        transport.complete(
            at: 0,
            result: .success(
                makeEchoContextPacket(
                    userId: "owner-1",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1"
                )
            )
        )

        wait(for: [expectation], timeout: 1)
    }

    func testCoordinatorRejectsLateContextPacketAfterAuthorityEpochChanges() {
        let transport = DeferredEchoContextBuildTransport()
        var currentAuthorityEpoch = "epoch-v1"
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: transport,
            accountLeaseValidator: { lease, checkpoint in
                AccountLeaseValidationDecision(
                    checkpoint: checkpoint,
                    allowed: lease.authorityEpoch == currentAuthorityEpoch,
                    reason: lease.authorityEpoch == currentAuthorityEpoch
                        ? .allowed
                        : .authorityEpochMismatch,
                    sessionRotated: false
                )
            }
        )
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 1)
        let expectation = expectation(description: "authority invalidation is delivered")

        XCTAssertNotNil(
            coordinator.requestContextBuild(
                turnID: "turn-authority-epoch",
                query: "late response must not survive an epoch change",
                expectedIdentity: identity,
                accountLease: accountLease,
                lifecycleMode: .sunlight,
                viewerFamilyMemberID: nil
            ) { _, delivery in
                guard case .authorityInvalidated(let invalidation) = delivery else {
                    return XCTFail("stale account authority must not deliver a context packet")
                }
                XCTAssertEqual(invalidation.checkpoint, .runtime)
                XCTAssertEqual(invalidation.reason, .authorityEpochMismatch)
                expectation.fulfill()
            }
        )

        currentAuthorityEpoch = "epoch-v2"
        transport.complete(
            at: 0,
            result: .success(
                makeEchoContextPacket(
                    userId: "owner-1",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1"
                )
            )
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertNil(coordinator.activeContextBuildLease)
    }

    func testOwnerTruthShadowStartsOnlyForCurrentSelfOwner() {
        let contextTransport = DeferredEchoContextBuildTransport()
        let shadowTransport = DeferredOwnerTruthContextShadowTransport()
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: contextTransport,
            ownerTruthContextShadowTransport: shadowTransport
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 4)
        let selfIdentity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let familyIdentity = EchoKnowledgeContextIdentity(
            userId: "family-1",
            personaScope: "family",
            digitalHumanId: "digital-human-2"
        )

        let accepted = coordinator.requestOwnerTruthContextShadow(
            turnID: "turn-self",
            query: "只观察确认态上下文",
            accountLease: accountLease,
            expectedIdentity: selfIdentity
        ) { _, _ in
            XCTFail("completion is not expected before the transport resolves")
        }
        XCTAssertNotNil(accepted)
        XCTAssertEqual(shadowTransport.requests.count, 1)
        XCTAssertEqual(shadowTransport.requests.first?.vaultID, "vault-owner-1")
        XCTAssertEqual(shadowTransport.requests.first?.ownerSubjectID, "owner-1")

        XCTAssertNil(
            coordinator.requestOwnerTruthContextShadow(
                turnID: "turn-family",
                query: "不得发起家人 Shadow 请求",
                accountLease: accountLease,
                expectedIdentity: familyIdentity
            ) { _, _ in
                XCTFail("family shadow must not invoke completion")
            }
        )
        XCTAssertEqual(shadowTransport.requests.count, 1)

        shadowTransport.isOwnerTruthContextCitationQAConfigured = false
        XCTAssertNil(
            coordinator.requestOwnerTruthContextShadow(
                turnID: "turn-disabled",
                query: "默认关闭",
                accountLease: accountLease,
                expectedIdentity: selfIdentity
            ) { _, _ in
                XCTFail("disabled shadow must not invoke completion")
            }
        )
        XCTAssertEqual(shadowTransport.requests.count, 1)
    }

    func testOwnerTruthShadowDropsSupersededAndInvalidatedCallbacks() {
        let contextTransport = DeferredEchoContextBuildTransport()
        let shadowTransport = DeferredOwnerTruthContextShadowTransport()
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: contextTransport,
            ownerTruthContextShadowTransport: shadowTransport
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 5)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let expectation = expectation(description: "only current shadow callback is delivered")
        expectation.assertForOverFulfill = true
        var deliveredLeases: [EchoOwnerTruthContextShadowLease] = []

        let first = coordinator.requestOwnerTruthContextShadow(
            turnID: "turn-1",
            query: "first query",
            accountLease: accountLease,
            expectedIdentity: identity
        ) { lease, _ in
            deliveredLeases.append(lease)
        }
        let second = coordinator.requestOwnerTruthContextShadow(
            turnID: "turn-2",
            query: "second query",
            accountLease: accountLease,
            expectedIdentity: identity
        ) { lease, delivery in
            deliveredLeases.append(lease)
            guard case .success = delivery else {
                return XCTFail("current shadow result must remain typed success")
            }
            expectation.fulfill()
        }

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        shadowTransport.complete(
            at: 0,
            result: .success(makeOwnerTruthContextShadowSummary(query: "first query"))
        )
        shadowTransport.complete(
            at: 1,
            result: .success(makeOwnerTruthContextShadowSummary(query: "second query"))
        )

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(deliveredLeases, [second].compactMap { $0 })

        XCTAssertNotNil(coordinator.invalidateOwnerTruthContextShadow())
        shadowTransport.complete(at: 1, result: .failure(DeferredOwnerTruthContextShadowTransport.TestError.failed))
        XCTAssertEqual(deliveredLeases, [second].compactMap { $0 })
    }

    func testContextBuildInvalidationAlsoDropsOwnerTruthShadowCallback() {
        let contextTransport = DeferredEchoContextBuildTransport()
        let shadowTransport = DeferredOwnerTruthContextShadowTransport()
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: contextTransport,
            ownerTruthContextShadowTransport: shadowTransport
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 6)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let notDelivered = expectation(description: "invalidated shadow callback must not deliver")
        notDelivered.isInverted = true

        XCTAssertNotNil(
            coordinator.requestOwnerTruthContextShadow(
                turnID: "turn-1",
                query: "context cancellation must fence shadow",
                accountLease: accountLease,
                expectedIdentity: identity
            ) { _, _ in
                notDelivered.fulfill()
            }
        )

        XCTAssertNil(coordinator.invalidateContextBuild())
        shadowTransport.complete(
            at: 0,
            result: .success(
                makeOwnerTruthContextShadowSummary(query: "context cancellation must fence shadow")
            )
        )
        wait(for: [notDelivered], timeout: 0.1)
        XCTAssertNil(coordinator.activeOwnerTruthContextShadowLease)
    }

    func testOwnerTruthShadowRejectsSummaryForDifferentQuery() {
        let contextTransport = DeferredEchoContextBuildTransport()
        let shadowTransport = DeferredOwnerTruthContextShadowTransport()
        let coordinator = EchoApplicationCoordinator(
            contextBuildTransport: contextTransport,
            ownerTruthContextShadowTransport: shadowTransport
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 7)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let expectation = expectation(description: "query mismatch is delivered as failure")

        XCTAssertNotNil(
            coordinator.requestOwnerTruthContextShadow(
                turnID: "turn-query-mismatch",
                query: "this turn must stay isolated",
                accountLease: accountLease,
                expectedIdentity: identity
            ) { _, delivery in
                guard case .failure(let error) = delivery else {
                    return XCTFail("mismatched shadow query must not be delivered as success")
                }
                XCTAssertEqual(error as? EchoOwnerTruthContextShadowCorrelationError, .queryMismatch)
                expectation.fulfill()
            }
        )

        shadowTransport.complete(
            at: 0,
            result: .success(makeOwnerTruthContextShadowSummary(query: "another turn"))
        )
        wait(for: [expectation], timeout: 1)
    }

    func testOwnerTruthContextShadowCompareStartsOnlyForCurrentSelfOwnerAndBothQAGates() {
        let compareTransport = DeferredOwnerTruthContextShadowCompareTransport()
        let coordinator = EchoApplicationCoordinator(
            ownerTruthContextShadowCompareTransport: compareTransport,
            accountLeaseValidator: allowedAccountLeaseValidation,
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { true }
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 12)
        let selfIdentity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let familyIdentity = EchoKnowledgeContextIdentity(
            userId: "family-1",
            personaScope: "family",
            digitalHumanId: "digital-human-2"
        )

        XCTAssertNotNil(
            coordinator.requestOwnerTruthContextShadowCompare(
                turnID: "turn-self",
                query: "只比较当前本人的上下文",
                accountLease: accountLease,
                expectedIdentity: selfIdentity
            ) { _, _ in
                XCTFail("comparison completion is not expected before the transport resolves")
            }
        )
        XCTAssertEqual(compareTransport.requests.count, 1)
        XCTAssertEqual(compareTransport.requests.first?.vaultID, "vault-owner-1")
        XCTAssertEqual(compareTransport.requests.first?.ownerSubjectID, "owner-1")
        XCTAssertEqual(compareTransport.requests.first?.intent, "echo_chat")

        XCTAssertNil(
            coordinator.requestOwnerTruthContextShadowCompare(
                turnID: "turn-family",
                query: "家人上下文不得加入本轮 QA 对照",
                accountLease: accountLease,
                expectedIdentity: familyIdentity
            ) { _, _ in
                XCTFail("family comparison must not invoke completion")
            }
        )
        XCTAssertEqual(compareTransport.requests.count, 1)

        let gateDisabledTransport = DeferredOwnerTruthContextShadowCompareTransport()
        let gateDisabledCoordinator = EchoApplicationCoordinator(
            ownerTruthContextShadowCompareTransport: gateDisabledTransport,
            accountLeaseValidator: allowedAccountLeaseValidation,
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { false }
        )
        XCTAssertNil(
            gateDisabledCoordinator.requestOwnerTruthContextShadowCompare(
                turnID: "turn-disabled",
                query: "迁移 QA 关闭时不得发起对照",
                accountLease: accountLease,
                expectedIdentity: selfIdentity
            ) { _, _ in
                XCTFail("disabled comparison must not invoke completion")
            }
        )
        XCTAssertTrue(gateDisabledTransport.requests.isEmpty)
    }

    func testOwnerTruthContextShadowCompareDropsSupersededCallbacks() throws {
        let compareTransport = DeferredOwnerTruthContextShadowCompareTransport()
        let coordinator = EchoApplicationCoordinator(
            ownerTruthContextShadowCompareTransport: compareTransport,
            accountLeaseValidator: allowedAccountLeaseValidation,
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { true }
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 13)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let currentDelivered = expectation(description: "only the current compare callback is delivered")
        let duplicateNotDelivered = expectation(description: "completed compare lease rejects a duplicate callback")
        duplicateNotDelivered.isInverted = true
        var deliveredLeases: [EchoOwnerTruthContextShadowCompareLease] = []
        var completionCount = 0

        let first = coordinator.requestOwnerTruthContextShadowCompare(
            turnID: "turn-1",
            query: "first compare query",
            accountLease: accountLease,
            expectedIdentity: identity
        ) { lease, _ in
            deliveredLeases.append(lease)
        }
        let second = coordinator.requestOwnerTruthContextShadowCompare(
            turnID: "turn-2",
            query: "second compare query",
            accountLease: accountLease,
            expectedIdentity: identity
        ) { lease, delivery in
            completionCount += 1
            deliveredLeases.append(lease)
            guard case .success(let comparison) = delivery else {
                return XCTFail("current comparison must remain a typed success")
            }
            XCTAssertEqual(comparison.disposition, .observed)
            if completionCount == 1 {
                currentDelivered.fulfill()
            } else {
                duplicateNotDelivered.fulfill()
            }
        }

        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        compareTransport.complete(
            at: 0,
            result: .success(try makeOwnerTruthContextShadowCompare(query: "first compare query"))
        )
        compareTransport.complete(
            at: 1,
            result: .success(try makeOwnerTruthContextShadowCompare(query: "second compare query"))
        )

        wait(for: [currentDelivered], timeout: 1)
        XCTAssertEqual(deliveredLeases, [second].compactMap { $0 })
        XCTAssertNil(coordinator.activeOwnerTruthContextShadowCompareLease)

        compareTransport.complete(
            at: 1,
            result: .success(try makeOwnerTruthContextShadowCompare(query: "second compare query"))
        )
        wait(for: [duplicateNotDelivered], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
    }

    func testContextBuildInvalidationDropsOwnerTruthContextShadowCompareCallback() throws {
        let compareTransport = DeferredOwnerTruthContextShadowCompareTransport()
        let coordinator = EchoApplicationCoordinator(
            ownerTruthContextShadowCompareTransport: compareTransport,
            accountLeaseValidator: allowedAccountLeaseValidation,
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { true }
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 14)
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let notDelivered = expectation(description: "invalidated compare callback is not delivered")
        notDelivered.isInverted = true

        XCTAssertNotNil(
            coordinator.requestOwnerTruthContextShadowCompare(
                turnID: "turn-invalidated",
                query: "context cancellation must fence same request comparison",
                accountLease: accountLease,
                expectedIdentity: identity
            ) { _, _ in
                notDelivered.fulfill()
            }
        )
        XCTAssertNil(coordinator.invalidateContextBuild())
        compareTransport.complete(
            at: 0,
            result: .success(
                try makeOwnerTruthContextShadowCompare(
                    query: "context cancellation must fence same request comparison"
                )
            )
        )
        wait(for: [notDelivered], timeout: 0.1)
        XCTAssertNil(coordinator.activeOwnerTruthContextShadowCompareLease)
    }

    func testOwnerTruthContextParityRequiresBothQAGates() {
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 8)
        let citationDisabled = EchoApplicationCoordinator(
            ownerTruthContextCitationQAEnabled: { false },
            ownerTruthMigrationParityQAEnabled: { true }
        )
        let parityDisabled = EchoApplicationCoordinator(
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { false }
        )

        XCTAssertNil(
            citationDisabled.beginOwnerTruthContextParity(
                turnID: "turn-gate",
                query: "QA gate must be explicit",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )
        XCTAssertNil(
            parityDisabled.beginOwnerTruthContextParity(
                turnID: "turn-gate",
                query: "QA gate must be explicit",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )
    }

    func testOwnerTruthContextParityPairsRealContractShapesWithoutPromotion() throws {
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 9)
        let coordinator = EchoApplicationCoordinator(
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { true }
        )
        let contextLease = coordinator.beginContextBuild(
            turnID: "turn-parity",
            expectedIdentity: identity
        )
        let parityLease = try XCTUnwrap(
            coordinator.beginOwnerTruthContextParity(
                turnID: "turn-parity",
                query: "同一回合只做上下文对照",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )
        let packet = makeEchoContextPacket(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1",
            requestQuery: "同一回合只做上下文对照"
        )

        XCTAssertNil(
            coordinator.recordOwnerTruthContextParityLegacy(
                packet,
                contextBuildLease: contextLease,
                parityLease: parityLease
            )
        )

        let evidence = coordinator.recordOwnerTruthContextParityShadow(
            makeOwnerTruthContextShadowSummary(query: "同一回合只做上下文对照"),
            parityLease: parityLease
        )

        XCTAssertEqual(evidence?.schemaVersion, "echo-owner-truth-context-parity-readout-v1")
        XCTAssertEqual(evidence?.comparisonState, "observedNonPromoting")
        XCTAssertEqual(evidence?.promotionDecision, "notEvaluated")
        XCTAssertTrue(evidence?.mismatchCodes.contains("M04") == true)
        XCTAssertGreaterThan(evidence?.blockerCount ?? 0, 0)
        XCTAssertNil(coordinator.activeOwnerTruthContextParityLease)
        XCTAssertFalse(evidence?.panelLines().joined(separator: " ").contains("同一回合只做上下文对照") == true)
    }

    func testOwnerTruthContextParityRejectsMissingOrMismatchedLegacyRequestCorrelation() throws {
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 11)
        let coordinator = EchoApplicationCoordinator(
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { true }
        )

        let missingContextLease = coordinator.beginContextBuild(
            turnID: "turn-missing-correlation",
            expectedIdentity: identity
        )
        let missingParityLease = try XCTUnwrap(
            coordinator.beginOwnerTruthContextParity(
                turnID: "turn-missing-correlation",
                query: "同一请求必须有服务端关联指纹",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )
        XCTAssertNil(
            coordinator.recordOwnerTruthContextParityLegacy(
                makeEchoContextPacket(
                    userId: "owner-1",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1"
                ),
                contextBuildLease: missingContextLease,
                parityLease: missingParityLease
            )
        )
        XCTAssertNil(coordinator.activeOwnerTruthContextParityLease)

        let mismatchContextLease = coordinator.beginContextBuild(
            turnID: "turn-mismatched-correlation",
            expectedIdentity: identity
        )
        let mismatchParityLease = try XCTUnwrap(
            coordinator.beginOwnerTruthContextParity(
                turnID: "turn-mismatched-correlation",
                query: "这个响应只能归属当前回合",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )
        XCTAssertNil(
            coordinator.recordOwnerTruthContextParityLegacy(
                makeEchoContextPacket(
                    userId: "owner-1",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1",
                    requestQuery: "另一条查询"
                ),
                contextBuildLease: mismatchContextLease,
                parityLease: mismatchParityLease
            )
        )
        XCTAssertNil(coordinator.activeOwnerTruthContextParityLease)
    }

    func testOwnerTruthContextParityRejectsQueryMismatchAndContextInvalidation() throws {
        let identity = EchoKnowledgeContextIdentity(
            userId: "owner-1",
            personaScope: "self",
            digitalHumanId: "digital-human-1"
        )
        let accountLease = makeAccountLease(subjectId: "owner-1", generation: 10)
        let coordinator = EchoApplicationCoordinator(
            ownerTruthContextCitationQAEnabled: { true },
            ownerTruthMigrationParityQAEnabled: { true }
        )
        let contextLease = coordinator.beginContextBuild(
            turnID: "turn-mismatch",
            expectedIdentity: identity
        )
        let parityLease = try XCTUnwrap(
            coordinator.beginOwnerTruthContextParity(
                turnID: "turn-mismatch",
                query: "must stay isolated",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )

        XCTAssertNil(
            coordinator.recordOwnerTruthContextParityShadow(
                makeOwnerTruthContextShadowSummary(query: "another turn"),
                parityLease: parityLease
            )
        )
        XCTAssertNil(coordinator.activeOwnerTruthContextParityLease)

        let replacementLease = try XCTUnwrap(
            coordinator.beginOwnerTruthContextParity(
                turnID: "turn-mismatch",
                query: "must stay isolated",
                accountLease: accountLease,
                expectedIdentity: identity
            )
        )
        XCTAssertEqual(coordinator.invalidateContextBuild(), contextLease)
        XCTAssertNil(
            coordinator.recordOwnerTruthContextParityLegacy(
                makeEchoContextPacket(
                    userId: "owner-1",
                    personaScope: "self",
                    digitalHumanId: "digital-human-1"
                ),
                contextBuildLease: contextLease,
                parityLease: replacementLease
            )
        )
        XCTAssertNil(coordinator.activeOwnerTruthContextParityLease)
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

    private func makeOwnerTruthContextShadowSummary(
        query: String = ""
    ) -> OwnerTruthContextCitationTraceSummary {
        let queryFingerprint = OwnerTruthContextCitationTraceSummary.queryFingerprint(for: query)
        return OwnerTruthContextCitationTraceSummary(
            contextVersion: "echo-context-v4-shadow",
            policyVersion: "owner-truth-context-policy-v1",
            selectionMode: .projectionCitationOrder,
            queryHash: queryFingerprint.hash,
            queryLength: queryFingerprint.length,
            contextHash: String(repeating: "a", count: 64),
            authorityState: .ready,
            authorityEpoch: 7,
            projectionCheckpoint: String(repeating: "b", count: 64),
            selectedContextRefs: ["memory-version:fixture"],
            selectedContextRefsBySource: ["owner-truth-memory-projection": ["memory-version:fixture"]],
            filteredContextReasons: [],
            selectedContextCount: 1,
            filteredContextCount: 0,
            rankingTraceCount: 1,
            citationCount: 1,
            answerCitationCount: 0,
            selectedContextSourceCounts: ["owner-truth-memory-projection": 1],
            fallbacks: []
        )
    }

    private func makeOwnerTruthContextShadowCompare(
        query: String
    ) throws -> OwnerTruthContextShadowCompare {
        let fingerprint = OwnerTruthContextCitationTraceSummary.queryFingerprint(for: query)
        guard let queryHash = fingerprint.hash else {
            XCTFail("comparison test query must produce a hash")
            throw DeferredOwnerTruthContextShadowCompareTransport.TestError.failed
        }
        return try OwnerTruthContextShadowCompare(
            backendJSONObject: [
                "schemaVersion": "owner-truth-context-shadow-compare-response-v1",
                "contextComparison": [
                    "schemaVersion": "owner-truth-context-shadow-compare-v1",
                    "policyVersion": "owner-truth-context-shadow-compare-policy-v1",
                    "shadowOnly": true,
                    "legacyContextUnchanged": true,
                    "legacyContextRead": true,
                    "requestCorrelation": [
                        "schemaVersion": "echo-context-request-correlation-v1",
                        "intent": "echo_chat",
                        "queryHash": queryHash,
                        "queryLength": fingerprint.length,
                    ],
                    "requestCorrelationMatches": true,
                    "disposition": "observed",
                    "legacy": [
                        "schemaVersion": 1,
                        "contextVersion": "echo-context-v1",
                        "selectedContextCount": 2,
                        "filteredContextCount": 1,
                        "fallbackCount": 0,
                    ],
                    "v4": [
                        "schemaVersion": "owner-truth-context-shadow-build-v1",
                        "contextVersion": "echo-context-v4-shadow",
                        "policyVersion": "owner-truth-context-shadow-build-policy-v1",
                        "state": "ready",
                        "selectedContextCount": 2,
                        "filteredContextCount": 1,
                        "fallbackCount": 0,
                        "allSelectedItemsHaveTypedCitation": true,
                        "authorityEpochPresent": true,
                        "projectionCheckpointPresent": true,
                    ],
                ],
            ],
            expectedIntent: "echo_chat",
            expectedQuery: query
        )
    }

    private func allowedAccountLeaseValidation(
        _ accountLease: AccountLease,
        _ checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: true,
            reason: .allowed,
            sessionRotated: false
        )
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

final class DigitalHumanConversationCoordinatorTests: XCTestCase {
    func testProviderCompletionRequiresMatchingRequestID() {
        let coordinator = DigitalHumanConversationCoordinator()
        coordinator.beginProviderRequest(
            requestID: "current-request",
            replyText: "当前回响",
            turnID: "turn-current",
            keepsPendingReply: true
        )

        XCTAssertNil(coordinator.completeProviderRequest(matching: "stale-request"))
        XCTAssertEqual(coordinator.activeRequestID, "current-request")
        XCTAssertTrue(coordinator.hasProviderSpeechInFlight)

        let completion = coordinator.completeProviderRequest(matching: "current-request")
        XCTAssertEqual(completion?.requestID, "current-request")
        XCTAssertEqual(completion?.turnID, "turn-current")
        XCTAssertEqual(completion?.replyText, "当前回响")
        XCTAssertNil(coordinator.activeRequestID)
        XCTAssertFalse(coordinator.hasProviderSpeechInFlight)
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

    func testAuthorityEnvelopeObservesOnlyMatchingBlockedAuthority() throws {
        let lease = makeAccountLease(subjectId: "viewer-1", generation: 8)
        let authority = try XCTUnwrap(
            VoiceDigitalHumanAuthorityEnvelope(
                json: [
                    "schemaVersion": 1,
                    "subjectId": "viewer-1",
                    "vaultId": "vault-viewer-1",
                    "authorityEpoch": 3,
                    "purpose": "voiceTraining",
                    "resourceKind": "voiceProfile",
                    "status": "blocked",
                    "receiptIdHash": String(repeating: "a", count: 64)
                ]
            )
        )

        let decision = VoiceDigitalHumanAuthorityAdapter.decide(
            authority: authority,
            accountLease: lease
        )

        XCTAssertEqual(decision.state, .observedDefaultDeny)
        XCTAssertEqual(decision.authority, authority)
        XCTAssertFalse(decision.providerEffectAllowed)
        XCTAssertFalse(decision.runtimePromotionAllowed)
    }

    func testAuthorityAdapterRejectsMissingMismatchedAndNonBlockedAuthority() throws {
        let lease = makeAccountLease(subjectId: "viewer-1", generation: 8)
        let basePayload: [String: Any] = [
            "schemaVersion": 1,
            "subjectId": "viewer-1",
            "vaultId": "vault-viewer-1",
            "authorityEpoch": "3",
            "purpose": "voiceTraining",
            "resourceKind": "voiceProfile",
            "status": "blocked",
            "receiptIdHash": String(repeating: "b", count: 64)
        ]

        XCTAssertEqual(
            VoiceDigitalHumanAuthorityAdapter.decide(authority: nil, accountLease: lease).state,
            .unavailable
        )

        var subjectMismatchPayload = basePayload
        subjectMismatchPayload["subjectId"] = "viewer-2"
        let subjectMismatch = try XCTUnwrap(
            VoiceDigitalHumanAuthorityEnvelope(json: subjectMismatchPayload)
        )
        XCTAssertEqual(
            VoiceDigitalHumanAuthorityAdapter.decide(
                authority: subjectMismatch,
                accountLease: lease
            ).state,
            .subjectMismatch
        )

        var vaultMismatchPayload = basePayload
        vaultMismatchPayload["vaultId"] = "vault-viewer-2"
        let vaultMismatch = try XCTUnwrap(
            VoiceDigitalHumanAuthorityEnvelope(json: vaultMismatchPayload)
        )
        XCTAssertEqual(
            VoiceDigitalHumanAuthorityAdapter.decide(
                authority: vaultMismatch,
                accountLease: lease
            ).state,
            .vaultMismatch
        )

        var pendingPayload = basePayload
        pendingPayload["status"] = "pending"
        let pending = try XCTUnwrap(VoiceDigitalHumanAuthorityEnvelope(json: pendingPayload))
        XCTAssertEqual(
            VoiceDigitalHumanAuthorityAdapter.decide(authority: pending, accountLease: lease).state,
            .defaultDenied
        )
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

private final class DeferredOwnerTruthContextShadowTransport: EchoOwnerTruthContextShadowTransport {
    enum TestError: Error {
        case failed
    }

    struct Request: Equatable {
        let vaultID: String
        let ownerSubjectID: String
        let query: String
    }

    var isOwnerTruthContextCitationQAConfigured = true
    private(set) var requests: [Request] = []
    private var completions: [(Result<OwnerTruthContextCitationTraceSummary, Error>) -> Void] = []

    func observeOwnerTruthContextShadow(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        query: String,
        completion: @escaping (Result<OwnerTruthContextCitationTraceSummary, Error>) -> Void
    ) {
        requests.append(
            Request(
                vaultID: vaultID.rawValue,
                ownerSubjectID: expectedOwnerSubjectID,
                query: query
            )
        )
        completions.append(completion)
    }

    func complete(at index: Int, result: Result<OwnerTruthContextCitationTraceSummary, Error>) {
        completions[index](result)
    }
}

private final class DeferredOwnerTruthContextShadowCompareTransport: EchoOwnerTruthContextShadowCompareTransport {
    enum TestError: Error {
        case failed
    }

    struct Request: Equatable {
        let vaultID: String
        let ownerSubjectID: String
        let intent: String
        let query: String
    }

    var isOwnerTruthContextCitationQAConfigured = true
    private(set) var requests: [Request] = []
    private var completions: [(Result<OwnerTruthContextShadowCompare, Error>) -> Void] = []

    func compareOwnerTruthContextShadow(
        vaultID: OwnerTruthVaultID,
        expectedOwnerSubjectID: String,
        intent: String,
        query: String,
        completion: @escaping (Result<OwnerTruthContextShadowCompare, Error>) -> Void
    ) {
        requests.append(
            Request(
                vaultID: vaultID.rawValue,
                ownerSubjectID: expectedOwnerSubjectID,
                intent: intent,
                query: query
            )
        )
        completions.append(completion)
    }

    func complete(at index: Int, result: Result<OwnerTruthContextShadowCompare, Error>) {
        completions[index](result)
    }
}

private func makeEchoContextPacket(
    userId: String,
    personaScope: String,
    digitalHumanId: String,
    requestQuery: String? = nil
) -> EchoContextPacket {
    var json: [String: Any] = [
        "traceId": "trace-id",
        "intent": "echo_chat",
        "userId": userId,
        "personaScope": personaScope,
        "digitalHumanId": digitalHumanId,
    ]
    if let requestQuery {
        let fingerprint = OwnerTruthContextCitationTraceSummary.queryFingerprint(for: requestQuery)
        json["requestCorrelation"] = [
            "schemaVersion": EchoContextPacketRequestCorrelation.schemaVersion,
            "intent": "echo_chat",
            "queryHash": fingerprint.hash as Any,
            "queryLength": fingerprint.length,
        ]
    }
    guard let packet = EchoContextPacket(json: json) else {
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

final class EchoDelayedReplyInboxAnswerReferenceTests: XCTestCase {
    func testAnswerPointerSurvivesStoreRecreationAndInboxRemainsRedacted() {
        let suiteName = "EchoDelayedReplyInboxAnswerReferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

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
        let lease = try! XCTUnwrap(runtime.capture(forSubjectId: "owner-1"))
        let firstStore = EchoReplyMessageStore(defaults: defaults, accountLeaseRuntime: runtime)

        XCTAssertTrue(firstStore.saveArrivedReply(
            id: "reply-1",
            sourceAnswerID: "answer-1",
            deliverAt: Date(timeIntervalSince1970: 1_700_000_060),
            trigger: EchoDelayedReplyTrigger.tenRoundBaseline.rawValue,
            accountLease: lease,
            resourceOwnerId: lease.subjectId,
            operationId: "reply-1"
        ))

        let restoredStore = EchoReplyMessageStore(defaults: defaults, accountLeaseRuntime: runtime)
        let source = try! XCTUnwrap(restoredStore.inboxSources(
            accountLease: lease,
            resourceOwnerId: lease.subjectId
        ).first)
        let message = try! XCTUnwrap(InAppMessage.fromEchoReply(source))
        XCTAssertTrue(message.metadataOnly)
        XCTAssertTrue(message.contentRedacted)
        XCTAssertFalse(message.summary.contains("Answer"))

        XCTAssertEqual(
            restoredStore.inboxAnswerReference(
                for: message,
                accountLease: lease,
                resourceOwnerId: lease.subjectId
            ),
            EchoReplyInboxAnswerReference(
                resourceOwnerId: "owner-1",
                delayedReplyID: "reply-1",
                sourceAnswerID: "answer-1"
            )
        )
    }
}

final class EchoDelayedReplyInboxAnswerReaderTests: XCTestCase {
    func testReaderReturnsOnlyAnswerMatchingPersistedInboxPointer() throws {
        let runtime = makeRuntime()
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-1"))
        let client = EchoDelayedReplyAnswerReadClientStub()
        client.result = .success(try completedAnswerContract(answerID: "answer-1"))
        let reader = EchoDelayedReplyInboxAnswerReader(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )
        let expectation = expectation(description: "matching private Answer")

        reader.read(
            EchoReplyInboxAnswerReference(
                resourceOwnerId: "owner-1",
                delayedReplyID: "reply-1",
                sourceAnswerID: "answer-1"
            ),
            accountLease: lease
        ) { result in
            guard case .success(let contract) = result else {
                return XCTFail("matching inbox pointer should read private Answer")
            }
            XCTAssertEqual(contract.answer.answerID, "answer-1")
            XCTAssertEqual(contract.answer.body, "服务器已经持久化的回信正文")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testReaderRejectsAnswerThatDoesNotMatchPersistedInboxPointer() throws {
        let runtime = makeRuntime()
        let lease = try XCTUnwrap(runtime.capture(forSubjectId: "owner-1"))
        let client = EchoDelayedReplyAnswerReadClientStub()
        client.result = .success(try completedAnswerContract(answerID: "answer-1"))
        let reader = EchoDelayedReplyInboxAnswerReader(
            client: client,
            accountLeaseRuntime: runtime,
            isEnabled: { true }
        )
        let expectation = expectation(description: "mismatched private Answer")

        reader.read(
            EchoReplyInboxAnswerReference(
                resourceOwnerId: "owner-1",
                delayedReplyID: "reply-1",
                sourceAnswerID: "other-answer"
            ),
            accountLease: lease
        ) { result in
            guard case .failure(let error as EchoDelayedReplyInboxAnswerReadError) = result else {
                return XCTFail("mismatched Answer must fail closed")
            }
            XCTAssertEqual(error, .inboxPointerMismatch)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    private func makeRuntime() -> AccountLeaseRuntime {
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
        return runtime
    }

    private func completedAnswerContract(answerID: String) throws -> EchoDelayedReplyAnswerReadContract {
        try EchoDelayedReplyAnswerReadContract(
            backendJSONObject: [
                "status": "completed",
                "userId": "owner-1",
                "delayedReplyId": "reply-1",
                "answer": [
                    "answerId": answerID,
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
                    "sourceAnswerId": answerID,
                ],
            ],
            expectedUserID: "owner-1",
            expectedDelayedReplyID: "reply-1"
        )
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
        XCTAssertEqual(inbox.first?.echoReplySourceAnswerID, "answer-1")
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
