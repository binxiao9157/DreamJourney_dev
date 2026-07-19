import Foundation

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
