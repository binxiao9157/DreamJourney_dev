import Foundation

#if os(iOS) || targetEnvironment(macCatalyst)
import AVFoundation
#endif

enum AudioOwnerLeaseObservationResult: Equatable, Sendable {
    case unchanged(AudioOwnerLease)
    case acquired(AudioOwnerLease)
    case preempted(previous: AudioOwnerLease, current: AudioOwnerLease)
    case deniedByActiveOwner(active: AudioOwnerLease)
    case deniedStaleGeneration(active: AudioOwnerLease)
    case released(AudioOwnerLease)
    case ignoredStaleRelease(active: AudioOwnerLease?)
    case interrupted(AudioOwnerLease)
    case alreadyInterrupted(AudioOwnerLease)
    case resumed(AudioOwnerLease)
    case routeChanged(AudioOwnerLease)
    case ignoredStaleEvent(active: AudioOwnerLease?)
    case ignoredNotInterrupted(active: AudioOwnerLease)

    var diagnosticCode: String {
        switch self {
        case .unchanged:
            return "unchanged"
        case .acquired:
            return "acquired"
        case .preempted:
            return "preempted"
        case .deniedByActiveOwner:
            return "deniedByActiveOwner"
        case .deniedStaleGeneration:
            return "deniedStaleGeneration"
        case .released:
            return "released"
        case .ignoredStaleRelease:
            return "ignoredStaleRelease"
        case .interrupted:
            return "interrupted"
        case .alreadyInterrupted:
            return "alreadyInterrupted"
        case .resumed:
            return "resumed"
        case .routeChanged:
            return "routeChanged"
        case .ignoredStaleEvent:
            return "ignoredStaleEvent"
        case .ignoredNotInterrupted:
            return "ignoredNotInterrupted"
        }
    }
}

struct AudioOwnerLeaseDiagnosticsSnapshot: Equatable, Sendable {
    let activeLease: AudioOwnerLease?
    let observedTransitionCount: Int
    let resultCounts: [String: Int]
}

/// Process-wide observation boundary for audio ownership. This coordinator deliberately
/// does not configure AVAudioSession yet; callers retain their current runtime behavior
/// while we collect stable lease evidence before enforcement is introduced.
final class AudioOwnerLeaseCoordinator: @unchecked Sendable {
    static let shared = AudioOwnerLeaseCoordinator()

    private let lock = NSLock()
    private var model = AudioOwnerLeaseModel()
    private var observedTransitionCount = 0
    private var resultCounts: [String: Int] = [:]

    @discardableResult
    func observeOwner(
        _ owner: AudioOwnerLeaseOwner,
        priority: AudioOwnerLeasePriority,
        scope: AudioOwnerLeaseScope
    ) -> AudioOwnerLeaseObservationResult {
        lock.lock()
        defer { lock.unlock() }

        if let activeLease = model.activeLease,
           activeLease.owner == owner,
           activeLease.priority == priority,
           activeLease.scope == scope,
           activeLease.state == .active {
            let result = AudioOwnerLeaseObservationResult.unchanged(activeLease)
            record(result)
            return result
        }

        let result: AudioOwnerLeaseObservationResult
        switch model.acquire(owner: owner, priority: priority, scope: scope) {
        case let .acquired(lease):
            result = .acquired(lease)
        case let .preempted(previous, current):
            result = .preempted(previous: previous, current: current)
        case let .deniedByActiveOwner(active):
            result = .deniedByActiveOwner(active: active)
        case let .deniedStaleGeneration(active):
            result = .deniedStaleGeneration(active: active)
        }
        record(result)
        return result
    }

    @discardableResult
    func releaseObservedLease(_ lease: AudioOwnerLease) -> AudioOwnerLeaseObservationResult {
        lock.lock()
        defer { lock.unlock() }

        let result: AudioOwnerLeaseObservationResult
        switch model.release(lease) {
        case let .released(released):
            result = .released(released)
        case let .ignoredStaleLease(active):
            result = .ignoredStaleRelease(active: active)
        }
        record(result)
        return result
    }

    @discardableResult
    func observeInterruption(for lease: AudioOwnerLease) -> AudioOwnerLeaseObservationResult {
        lock.lock()
        defer { lock.unlock() }

        let result: AudioOwnerLeaseObservationResult
        switch model.interrupt(lease) {
        case let .interrupted(interrupted):
            result = .interrupted(interrupted)
        case let .alreadyInterrupted(interrupted):
            result = .alreadyInterrupted(interrupted)
        case .ignoredNoActiveLease:
            result = .ignoredStaleEvent(active: nil)
        case let .ignoredStaleLease(active):
            result = .ignoredStaleEvent(active: active)
        }
        record(result)
        return result
    }

    @discardableResult
    func observeResume(for lease: AudioOwnerLease) -> AudioOwnerLeaseObservationResult {
        lock.lock()
        defer { lock.unlock() }

        let result: AudioOwnerLeaseObservationResult
        switch model.resume(lease) {
        case let .resumed(resumed):
            result = .resumed(resumed)
        case let .ignoredStaleLease(active):
            result = .ignoredStaleEvent(active: active)
        case let .ignoredNotInterrupted(active):
            result = .ignoredNotInterrupted(active: active)
        }
        record(result)
        return result
    }

    @discardableResult
    func observeRouteChange(for lease: AudioOwnerLease) -> AudioOwnerLeaseObservationResult {
        lock.lock()
        defer { lock.unlock() }

        let result: AudioOwnerLeaseObservationResult
        if let activeLease = model.activeLease, activeLease.leaseId == lease.leaseId {
            result = .routeChanged(activeLease)
        } else {
            result = .ignoredStaleEvent(active: model.activeLease)
        }
        record(result)
        return result
    }

    func diagnosticsSnapshot() -> AudioOwnerLeaseDiagnosticsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return AudioOwnerLeaseDiagnosticsSnapshot(
            activeLease: model.activeLease,
            observedTransitionCount: observedTransitionCount,
            resultCounts: resultCounts
        )
    }

    private func record(_ result: AudioOwnerLeaseObservationResult) {
        observedTransitionCount += 1
        resultCounts[result.diagnosticCode, default: 0] += 1
    }
}

/// Runtime boundary used by Echo once an owner lease has been selected. Keeping the
/// driver injectable makes the ordering contract testable without mutating the real
/// system audio session in unit or command-line smoke tests.
protocol AudioSessionDriving: AnyObject {
    func activate(for lease: AudioOwnerLease) throws
    func deactivate(after lease: AudioOwnerLease) throws
}

enum AudioSessionCoordinatorResult: Equatable, Sendable {
    case unchanged(AudioOwnerLease)
    case acquired(AudioOwnerLease)
    case preempted(previous: AudioOwnerLease, current: AudioOwnerLease)
    case deniedByActiveOwner(active: AudioOwnerLease)
    case deniedStaleGeneration(active: AudioOwnerLease)
    case released(AudioOwnerLease)
    case ignoredStaleRelease(active: AudioOwnerLease?)
    case interrupted(AudioOwnerLease)
    case alreadyInterrupted(AudioOwnerLease)
    case resumed(AudioOwnerLease)
    case routeChanged(AudioOwnerLease)
    case ignoredStaleEvent(active: AudioOwnerLease?)
    case ignoredNotInterrupted(active: AudioOwnerLease)
    case activationFailed(
        requested: AudioOwnerLease,
        active: AudioOwnerLease?,
        recoveryAttempted: Bool
    )
    case deactivationFailed(active: AudioOwnerLease)

    var diagnosticCode: String {
        switch self {
        case .unchanged:
            return "unchanged"
        case .acquired:
            return "acquired"
        case .preempted:
            return "preempted"
        case .deniedByActiveOwner:
            return "deniedByActiveOwner"
        case .deniedStaleGeneration:
            return "deniedStaleGeneration"
        case .released:
            return "released"
        case .ignoredStaleRelease:
            return "ignoredStaleRelease"
        case .interrupted:
            return "interrupted"
        case .alreadyInterrupted:
            return "alreadyInterrupted"
        case .resumed:
            return "resumed"
        case .routeChanged:
            return "routeChanged"
        case .ignoredStaleEvent:
            return "ignoredStaleEvent"
        case .ignoredNotInterrupted:
            return "ignoredNotInterrupted"
        case .activationFailed:
            return "activationFailed"
        case .deactivationFailed:
            return "deactivationFailed"
        }
    }
}

struct AudioSessionCoordinatorDiagnosticsSnapshot: Equatable, Sendable {
    let activeLease: AudioOwnerLease?
    let transitionCount: Int
    let resultCounts: [String: Int]
}

/// Actual Echo audio-session arbitrator. It commits the model only after the driver
/// accepts a transition, so stale callbacks and a failed preemption cannot erase a
/// newer physical owner.
final class AudioSessionCoordinator: @unchecked Sendable {
    static let shared = AudioSessionCoordinator(driver: SystemAudioSessionDriver())

    private let lock = NSLock()
    private let driver: AudioSessionDriving
    private var model = AudioOwnerLeaseModel()
    private var transitionCount = 0
    private var resultCounts: [String: Int] = [:]

    init(driver: AudioSessionDriving) {
        self.driver = driver
    }

    @discardableResult
    func acquire(
        _ owner: AudioOwnerLeaseOwner,
        priority: AudioOwnerLeasePriority,
        scope: AudioOwnerLeaseScope
    ) -> AudioSessionCoordinatorResult {
        lock.lock()
        defer { lock.unlock() }

        if let activeLease = model.activeLease,
           activeLease.owner == owner,
           activeLease.priority == priority,
           activeLease.scope == scope,
           activeLease.state == .active {
            let result = AudioSessionCoordinatorResult.unchanged(activeLease)
            record(result)
            return result
        }

        let priorModel = model
        var candidateModel = model
        let candidateResult = candidateModel.acquire(
            owner: owner,
            priority: priority,
            scope: scope
        )

        let requestedLease: AudioOwnerLease
        let successResult: AudioSessionCoordinatorResult
        let previousLease: AudioOwnerLease?
        switch candidateResult {
        case let .acquired(lease):
            requestedLease = lease
            successResult = .acquired(lease)
            previousLease = nil
        case let .preempted(previous, current):
            requestedLease = current
            successResult = .preempted(previous: previous, current: current)
            previousLease = previous
        case let .deniedByActiveOwner(active):
            let result = AudioSessionCoordinatorResult.deniedByActiveOwner(active: active)
            record(result)
            return result
        case let .deniedStaleGeneration(active):
            let result = AudioSessionCoordinatorResult.deniedStaleGeneration(active: active)
            record(result)
            return result
        }

        do {
            try driver.activate(for: requestedLease)
            model = candidateModel
            record(successResult)
            return successResult
        } catch {
            var recoveryAttempted = false
            if let previousLease {
                recoveryAttempted = true
                try? driver.activate(for: previousLease)
            }
            model = priorModel
            let result = AudioSessionCoordinatorResult.activationFailed(
                requested: requestedLease,
                active: priorModel.activeLease,
                recoveryAttempted: recoveryAttempted
            )
            record(result)
            return result
        }
    }

    @discardableResult
    func release(_ lease: AudioOwnerLease) -> AudioSessionCoordinatorResult {
        lock.lock()
        defer { lock.unlock() }

        guard let activeLease = model.activeLease,
              activeLease.leaseId == lease.leaseId else {
            let result = AudioSessionCoordinatorResult.ignoredStaleRelease(active: model.activeLease)
            record(result)
            return result
        }

        do {
            try driver.deactivate(after: activeLease)
        } catch {
            let result = AudioSessionCoordinatorResult.deactivationFailed(active: activeLease)
            record(result)
            return result
        }

        switch model.release(activeLease) {
        case let .released(released):
            let result = AudioSessionCoordinatorResult.released(released)
            record(result)
            return result
        case let .ignoredStaleLease(active):
            let result = AudioSessionCoordinatorResult.ignoredStaleRelease(active: active)
            record(result)
            return result
        }
    }

    @discardableResult
    func interrupt(_ lease: AudioOwnerLease) -> AudioSessionCoordinatorResult {
        lock.lock()
        defer { lock.unlock() }

        let result: AudioSessionCoordinatorResult
        switch model.interrupt(lease) {
        case let .interrupted(interrupted):
            result = .interrupted(interrupted)
        case let .alreadyInterrupted(interrupted):
            result = .alreadyInterrupted(interrupted)
        case .ignoredNoActiveLease:
            result = .ignoredStaleEvent(active: nil)
        case let .ignoredStaleLease(active):
            result = .ignoredStaleEvent(active: active)
        }
        record(result)
        return result
    }

    @discardableResult
    func resume(_ lease: AudioOwnerLease) -> AudioSessionCoordinatorResult {
        lock.lock()
        defer { lock.unlock() }

        var candidateModel = model
        switch candidateModel.resume(lease) {
        case let .resumed(resumed):
            do {
                try driver.activate(for: resumed)
                model = candidateModel
                let result = AudioSessionCoordinatorResult.resumed(resumed)
                record(result)
                return result
            } catch {
                let result = AudioSessionCoordinatorResult.activationFailed(
                    requested: resumed,
                    active: model.activeLease,
                    recoveryAttempted: false
                )
                record(result)
                return result
            }
        case let .ignoredStaleLease(active):
            let result = AudioSessionCoordinatorResult.ignoredStaleEvent(active: active)
            record(result)
            return result
        case let .ignoredNotInterrupted(active):
            let result = AudioSessionCoordinatorResult.ignoredNotInterrupted(active: active)
            record(result)
            return result
        }
    }

    @discardableResult
    func routeDidChange(for lease: AudioOwnerLease) -> AudioSessionCoordinatorResult {
        lock.lock()
        defer { lock.unlock() }

        let result: AudioSessionCoordinatorResult
        if let activeLease = model.activeLease, activeLease.leaseId == lease.leaseId {
            result = .routeChanged(activeLease)
        } else {
            result = .ignoredStaleEvent(active: model.activeLease)
        }
        record(result)
        return result
    }

    func isCurrentActiveLease(_ lease: AudioOwnerLease) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let activeLease = model.activeLease else { return false }
        return activeLease.leaseId == lease.leaseId && activeLease.state == .active
    }

    func diagnosticsSnapshot() -> AudioSessionCoordinatorDiagnosticsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return AudioSessionCoordinatorDiagnosticsSnapshot(
            activeLease: model.activeLease,
            transitionCount: transitionCount,
            resultCounts: resultCounts
        )
    }

    private func record(_ result: AudioSessionCoordinatorResult) {
        transitionCount += 1
        resultCounts[result.diagnosticCode, default: 0] += 1
    }
}

#if os(iOS) || targetEnvironment(macCatalyst)
private final class SystemAudioSessionDriver: AudioSessionDriving {
    func activate(for lease: AudioOwnerLease) throws {
        let session = AVAudioSession.sharedInstance()
        switch lease.route {
        case .playAndRecordVoiceChat:
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
        case .recordAndSpeaker:
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        case .playback:
            try session.setCategory(.playback, mode: .default)
        case .spokenAudioPreview:
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        }
        try session.setActive(true)
    }

    func deactivate(after _: AudioOwnerLease) throws {
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#else
private final class SystemAudioSessionDriver: AudioSessionDriving {
    func activate(for _: AudioOwnerLease) throws {}
    func deactivate(after _: AudioOwnerLease) throws {}
}
#endif
