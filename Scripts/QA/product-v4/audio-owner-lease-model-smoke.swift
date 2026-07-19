import Foundation

@main
enum AudioOwnerLeaseModelSmoke {
    static func main() {
        verifyCurrentLeaseOwnsInterruptionRecovery()
        verifyOwnerDefaultsDescribeTheIntendedRoute()
        verifyObserveOnlyTransitionRejectsStaleRelease()
        verifyObserveOnlySystemEventsRequireCurrentLease()
        verifyFallbackOrBackgroundReleaseClearsTencentLease()
        print("Audio owner lease model smoke passed")
    }

    private static func verifyCurrentLeaseOwnsInterruptionRecovery() {
        var model = AudioOwnerLeaseModel()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        let capture = acquire(
            &model,
            owner: .echoCapture,
            priority: .echoCapture,
            scope: scope,
            leaseID: "00000000-0000-0000-0000-000000000021"
        )
        let playback = acquire(
            &model,
            owner: .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope,
            leaseID: "00000000-0000-0000-0000-000000000022"
        )

        guard case let .interrupted(interrupted) = model.interruptActiveLease() else {
            fail("active digital-human playback should enter interrupted state")
        }
        require(interrupted.leaseId == playback.leaseId, "interruption must retain the active lease identity")
        require(interrupted.state == .interrupted, "interruption must update active lease state")
        require(
            model.resume(capture) == .ignoredStaleLease(active: interrupted),
            "a preempted microphone lease must not resume after playback interruption"
        )
        require(
            model.resume(playback) == .resumed(playback),
            "only the interrupted active lease may resume"
        )
    }

    private static func verifyOwnerDefaultsDescribeTheIntendedRoute() {
        var model = AudioOwnerLeaseModel()
        let preview = acquire(
            &model,
            owner: .profileVoicePreview,
            priority: .playback,
            scope: AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9),
            leaseID: "00000000-0000-0000-0000-000000000023"
        )

        require(preview.purpose == .profileVoicePreview, "profile preview purpose must be explicit")
        require(preview.route == .spokenAudioPreview, "profile preview route must remain explicit")
        require(preview.state == .active, "a new lease must start active")
    }

    private static func verifyObserveOnlyTransitionRejectsStaleRelease() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        guard case let .acquired(localPlayback) = coordinator.observeOwner(
            .echoLocalPlayback,
            priority: .playback,
            scope: scope
        ) else {
            fail("local Echo playback should acquire its observation lease")
        }
        guard case let .preempted(_, digitalHuman) = coordinator.observeOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        ) else {
            fail("Tencent playback should preempt local Echo playback")
        }
        require(
            coordinator.releaseObservedLease(localPlayback) == .ignoredStaleRelease(active: digitalHuman),
            "old local playback release must not clear the newer Tencent owner"
        )
        require(
            coordinator.diagnosticsSnapshot().activeLease == digitalHuman,
            "newer Tencent owner must remain active after stale release"
        )
    }

    private static func verifyObserveOnlySystemEventsRequireCurrentLease() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let scope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        guard case let .acquired(capture) = coordinator.observeOwner(
            .echoCapture,
            priority: .echoCapture,
            scope: scope
        ) else {
            fail("Echo capture should acquire its observation lease")
        }
        guard case let .preempted(_, digitalHuman) = coordinator.observeOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: scope
        ) else {
            fail("Tencent playback should preempt Echo capture")
        }
        require(
            coordinator.observeInterruption(for: capture) == .ignoredStaleEvent(active: digitalHuman),
            "a stale interruption must not interrupt the newer Tencent lease"
        )
        guard case let .interrupted(interruptedDigitalHuman) = coordinator.observeInterruption(for: digitalHuman) else {
            fail("the current Tencent lease should enter interrupted state")
        }
        require(
            coordinator.observeRouteChange(for: capture) == .ignoredStaleEvent(active: interruptedDigitalHuman),
            "a stale route change must not mutate the newer Tencent lease"
        )
        require(
            coordinator.observeResume(for: interruptedDigitalHuman) == .resumed(digitalHuman),
            "only the current interrupted Tencent lease may resume"
        )
    }

    private static func verifyFallbackOrBackgroundReleaseClearsTencentLease() {
        let coordinator = AudioOwnerLeaseCoordinator()
        let previousScope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 9)
        let nextScope = AudioOwnerLeaseScope(accountGeneration: 4, runtimeGeneration: 10)
        guard case let .acquired(digitalHuman) = coordinator.observeOwner(
            .tencentDigitalHumanPlayback,
            priority: .tencentDigitalHumanPlayback,
            scope: previousScope
        ) else {
            fail("Tencent playback should acquire before runtime teardown")
        }
        require(
            coordinator.releaseObservedLease(digitalHuman) == .released(digitalHuman),
            "fallback or background teardown must retire the current Tencent lease"
        )
        guard case let .acquired(capture) = coordinator.observeOwner(
            .echoCapture,
            priority: .echoCapture,
            scope: nextScope
        ) else {
            fail("the next Echo capture must not be blocked by a released Tencent lease")
        }
        require(capture.scope == nextScope, "new capture must use the current runtime scope")
    }

    private static func acquire(
        _ model: inout AudioOwnerLeaseModel,
        owner: AudioOwnerLeaseOwner,
        priority: AudioOwnerLeasePriority,
        scope: AudioOwnerLeaseScope,
        leaseID: String
    ) -> AudioOwnerLease {
        let result = model.acquire(
            owner: owner,
            priority: priority,
            scope: scope,
            leaseId: UUID(uuidString: leaseID)!,
            issuedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        switch result {
        case let .acquired(lease), let .preempted(_, lease):
            return lease
        case .deniedByActiveOwner, .deniedStaleGeneration:
            fail("expected audio owner acquisition to succeed")
        }
    }

    private static func require(_ condition: Bool, _ message: String) {
        guard condition else {
            fail(message)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("Audio owner lease model smoke failed: \(message)\n", stderr)
        Foundation.exit(1)
    }
}
