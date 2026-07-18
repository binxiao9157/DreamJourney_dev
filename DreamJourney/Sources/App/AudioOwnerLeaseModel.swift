import Foundation

// Pure arbitration model. Runtime AVAudioSession integration remains in WI-S1-03-07.
enum AudioOwnerLeaseOwner: String, CaseIterable, Sendable {
    case echoCapture
    case tencentDigitalHumanPlayback
    case archiveRecorder
    case archivePlayback
    case profileVoicePreview
    case memoirPlayback
}

enum AudioOwnerLeasePriority: Int, Comparable, Sendable {
    case echoCapture = 100
    case playback = 200
    case recorder = 300
    case tencentDigitalHumanPlayback = 400

    static func < (lhs: AudioOwnerLeasePriority, rhs: AudioOwnerLeasePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct AudioOwnerLeaseScope: Equatable, Sendable {
    let accountGeneration: UInt64
    let runtimeGeneration: UInt64
}

struct AudioOwnerLease: Equatable, Sendable {
    let leaseId: UUID
    let owner: AudioOwnerLeaseOwner
    let scope: AudioOwnerLeaseScope
    let priority: AudioOwnerLeasePriority
    let issuedAt: Date
}

enum AudioOwnerLeaseAcquireResult: Equatable, Sendable {
    case acquired(AudioOwnerLease)
    case preempted(previous: AudioOwnerLease, current: AudioOwnerLease)
    case deniedByActiveOwner(active: AudioOwnerLease)
    case deniedStaleGeneration(active: AudioOwnerLease)
}

enum AudioOwnerLeaseReleaseResult: Equatable, Sendable {
    case released(AudioOwnerLease)
    case ignoredStaleLease(active: AudioOwnerLease?)
}

struct AudioOwnerLeaseModel: Sendable {
    private(set) var activeLease: AudioOwnerLease?

    init(activeLease: AudioOwnerLease? = nil) {
        self.activeLease = activeLease
    }

    mutating func acquire(
        owner: AudioOwnerLeaseOwner,
        priority: AudioOwnerLeasePriority,
        scope: AudioOwnerLeaseScope,
        leaseId: UUID = UUID(),
        issuedAt: Date = Date()
    ) -> AudioOwnerLeaseAcquireResult {
        let requested = AudioOwnerLease(
            leaseId: leaseId,
            owner: owner,
            scope: scope,
            priority: priority,
            issuedAt: issuedAt
        )

        guard let activeLease else {
            self.activeLease = requested
            return .acquired(requested)
        }

        switch compare(requested.scope, to: activeLease.scope) {
        case .orderedAscending:
            return .deniedStaleGeneration(active: activeLease)
        case .orderedDescending:
            self.activeLease = requested
            return .preempted(previous: activeLease, current: requested)
        case .orderedSame:
            guard requested.priority >= activeLease.priority else {
                return .deniedByActiveOwner(active: activeLease)
            }
            self.activeLease = requested
            return .preempted(previous: activeLease, current: requested)
        }
    }

    mutating func release(_ lease: AudioOwnerLease) -> AudioOwnerLeaseReleaseResult {
        guard let activeLease, activeLease.leaseId == lease.leaseId else {
            return .ignoredStaleLease(active: activeLease)
        }
        self.activeLease = nil
        return .released(activeLease)
    }

    private func compare(
        _ lhs: AudioOwnerLeaseScope,
        to rhs: AudioOwnerLeaseScope
    ) -> ComparisonResult {
        if lhs.accountGeneration != rhs.accountGeneration {
            return lhs.accountGeneration < rhs.accountGeneration ? .orderedAscending : .orderedDescending
        }
        if lhs.runtimeGeneration != rhs.runtimeGeneration {
            return lhs.runtimeGeneration < rhs.runtimeGeneration ? .orderedAscending : .orderedDescending
        }
        return .orderedSame
    }
}
