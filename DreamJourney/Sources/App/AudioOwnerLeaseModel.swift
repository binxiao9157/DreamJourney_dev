import Foundation

// Pure arbitration model. Runtime AVAudioSession enforcement remains in WI-S1-03-07.
enum AudioOwnerLeaseOwner: String, CaseIterable, Sendable {
    case echoCapture
    case echoLocalPlayback
    case tencentDigitalHumanPlayback
    case archiveRecorder
    case archivePlayback
    case profileVoicePreview
    case memoirPlayback
}

enum AudioOwnerLeasePurpose: String, Equatable, Sendable {
    case echoCapture
    case echoLocalTTSPlayback
    case tencentAudioDrive
    case archiveRecording
    case archivePlayback
    case profileVoicePreview
    case memoirPlayback
}

enum AudioOwnerLeaseRoute: String, Equatable, Sendable {
    case playAndRecordVoiceChat
    case recordAndSpeaker
    case playback
    case spokenAudioPreview
}

enum AudioOwnerLeaseState: String, Equatable, Sendable {
    case active
    case interrupted
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
    let purpose: AudioOwnerLeasePurpose
    let route: AudioOwnerLeaseRoute
    let scope: AudioOwnerLeaseScope
    let priority: AudioOwnerLeasePriority
    let state: AudioOwnerLeaseState
    let issuedAt: Date

    func updating(state: AudioOwnerLeaseState) -> AudioOwnerLease {
        AudioOwnerLease(
            leaseId: leaseId,
            owner: owner,
            purpose: purpose,
            route: route,
            scope: scope,
            priority: priority,
            state: state,
            issuedAt: issuedAt
        )
    }
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

enum AudioOwnerLeaseInterruptionResult: Equatable, Sendable {
    case interrupted(AudioOwnerLease)
    case alreadyInterrupted(AudioOwnerLease)
    case ignoredNoActiveLease
}

enum AudioOwnerLeaseResumeResult: Equatable, Sendable {
    case resumed(AudioOwnerLease)
    case ignoredStaleLease(active: AudioOwnerLease?)
    case ignoredNotInterrupted(active: AudioOwnerLease)
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
        purpose: AudioOwnerLeasePurpose? = nil,
        route: AudioOwnerLeaseRoute? = nil,
        leaseId: UUID = UUID(),
        issuedAt: Date = Date()
    ) -> AudioOwnerLeaseAcquireResult {
        let requested = AudioOwnerLease(
            leaseId: leaseId,
            owner: owner,
            purpose: purpose ?? owner.defaultPurpose,
            route: route ?? owner.defaultRoute,
            scope: scope,
            priority: priority,
            state: .active,
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

    mutating func interruptActiveLease() -> AudioOwnerLeaseInterruptionResult {
        guard let activeLease else {
            return .ignoredNoActiveLease
        }
        guard activeLease.state == .active else {
            return .alreadyInterrupted(activeLease)
        }
        let interrupted = activeLease.updating(state: .interrupted)
        self.activeLease = interrupted
        return .interrupted(interrupted)
    }

    mutating func resume(_ lease: AudioOwnerLease) -> AudioOwnerLeaseResumeResult {
        guard let activeLease, activeLease.leaseId == lease.leaseId else {
            return .ignoredStaleLease(active: activeLease)
        }
        guard activeLease.state == .interrupted else {
            return .ignoredNotInterrupted(active: activeLease)
        }
        let resumed = activeLease.updating(state: .active)
        self.activeLease = resumed
        return .resumed(resumed)
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

private extension AudioOwnerLeaseOwner {
    var defaultPurpose: AudioOwnerLeasePurpose {
        switch self {
        case .echoCapture:
            return .echoCapture
        case .echoLocalPlayback:
            return .echoLocalTTSPlayback
        case .tencentDigitalHumanPlayback:
            return .tencentAudioDrive
        case .archiveRecorder:
            return .archiveRecording
        case .archivePlayback:
            return .archivePlayback
        case .profileVoicePreview:
            return .profileVoicePreview
        case .memoirPlayback:
            return .memoirPlayback
        }
    }

    var defaultRoute: AudioOwnerLeaseRoute {
        switch self {
        case .echoCapture, .echoLocalPlayback, .tencentDigitalHumanPlayback:
            return .playAndRecordVoiceChat
        case .archiveRecorder:
            return .recordAndSpeaker
        case .profileVoicePreview:
            return .spokenAudioPreview
        case .archivePlayback, .memoirPlayback:
            return .playback
        }
    }
}
