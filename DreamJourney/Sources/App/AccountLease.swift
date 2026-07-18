import Foundation

enum AccountLeaseCheckpoint: String, CaseIterable, Codable, Sendable {
    case request
    case commit
    case ui
    case timer
    case runtime
}

enum AccountLeaseValidationReason: String, Codable, Sendable {
    case allowed
    case noActiveSession
    case subjectMismatch
    case vaultMismatch
    case generationMismatch
    case generationIdentityMismatch
    case authorityEpochMismatch
}

struct AccountLease: Codable, Equatable, Sendable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
}

/// Immutable runtime input passed from the app root into feature construction.
/// It intentionally contains identity and policy authority only; feature-specific
/// writers remain behind their existing repositories until their own migration slice.
struct AppFeatureRuntimeContext: Equatable, Sendable {
    let accountLease: AccountLease
    let lifecycleGeneration: UInt64
    let releasePolicyAuthorityEpoch: String

    init?(
        accountLease: AccountLease,
        lifecycleGeneration: UInt64,
        releasePolicyAuthorityEpoch: String
    ) {
        let normalizedAuthorityEpoch = releasePolicyAuthorityEpoch
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard lifecycleGeneration == accountLease.generation,
              !normalizedAuthorityEpoch.isEmpty,
              normalizedAuthorityEpoch == accountLease.authorityEpoch else {
            return nil
        }
        self.accountLease = accountLease
        self.lifecycleGeneration = lifecycleGeneration
        self.releasePolicyAuthorityEpoch = normalizedAuthorityEpoch
    }
}

/// Process-level lifecycle signals forwarded by SceneDelegate. The payload is
/// intentionally separate from account teardown events: it never carries a
/// subject, vault, session identifier, or provider state.
enum AppLifecycleEvent: String, CaseIterable, Codable, Sendable {
    case sceneConnected
    case didBecomeActive
    case willResignActive
    case willEnterForeground
    case didEnterBackground
    case didDisconnect

    var triggersPrivateForegroundRefresh: Bool {
        self == .willEnterForeground
    }
}

enum AppLifecycleRuntimeDisposition: String, Codable, Equatable, Sendable {
    case activeRuntime
    case noActiveRuntime
}

/// Value-minimized receipt for App/Scene lifecycle forwarding. It makes the
/// active generation observable without persisting an account or policy value.
struct AppLifecycleEventReceipt: Equatable, Sendable {
    let schemaVersion: Int
    let event: AppLifecycleEvent
    let sequence: UInt64
    let runtimeDisposition: AppLifecycleRuntimeDisposition
    let lifecycleGeneration: UInt64?
    let hasReleasePolicyAuthority: Bool

    init(
        event: AppLifecycleEvent,
        sequence: UInt64,
        runtimeContext: AppFeatureRuntimeContext?
    ) {
        self.schemaVersion = 1
        self.event = event
        self.sequence = sequence
        if let runtimeContext {
            self.runtimeDisposition = .activeRuntime
            self.lifecycleGeneration = runtimeContext.lifecycleGeneration
            self.hasReleasePolicyAuthority = !runtimeContext.releasePolicyAuthorityEpoch.isEmpty
        } else {
            self.runtimeDisposition = .noActiveRuntime
            self.lifecycleGeneration = nil
            self.hasReleasePolicyAuthority = false
        }
    }

    var canRunPrivateForegroundRefresh: Bool {
        event.triggersPrivateForegroundRefresh
            && runtimeDisposition == .activeRuntime
            && lifecycleGeneration != nil
            && hasReleasePolicyAuthority
    }
}

struct AccountLeaseValidationDecision: Equatable, Sendable {
    let checkpoint: AccountLeaseCheckpoint
    let allowed: Bool
    let reason: AccountLeaseValidationReason
    let sessionRotated: Bool
}

struct AccountLeaseDiagnosticsSnapshot: Equatable, Sendable {
    let acceptedCount: Int
    let rejectedCount: Int
    let acceptedByCheckpoint: [String: Int]
    let rejectedByCheckpoint: [String: Int]
    let rejectedByReason: [String: Int]
}

protocol AccountLeaseRuntimePort: Sendable {
    func capture(forSubjectId subjectId: String?) -> AccountLease?
    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision
}

final class AccountLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    static let shared = AccountLeaseRuntime()

    private let lock = NSLock()
    private var activeSession: AccountSession?
    private var authorityEpoch: String
    private var acceptedByCheckpoint: [String: Int] = [:]
    private var rejectedByCheckpoint: [String: Int] = [:]
    private var rejectedByReason: [String: Int] = [:]

    init(authorityEpoch: String = "unresolved") {
        self.authorityEpoch = Self.normalizedAuthorityEpoch(authorityEpoch)
    }

    func publish(session: AccountSession?) {
        lock.lock()
        activeSession = session?.state == .active ? session : nil
        lock.unlock()
    }

    func updateAuthorityEpoch(_ authorityEpoch: String) {
        lock.lock()
        self.authorityEpoch = Self.normalizedAuthorityEpoch(authorityEpoch)
        lock.unlock()
    }

    func capture(forSubjectId subjectId: String? = nil) -> AccountLease? {
        let expectedSubject = Self.normalized(subjectId)
        lock.lock()
        defer { lock.unlock() }
        guard let activeSession,
              expectedSubject == nil || expectedSubject == activeSession.subjectId else {
            return nil
        }
        return AccountLease(
            subjectId: activeSession.subjectId,
            vaultId: activeSession.vaultId,
            sessionId: activeSession.sessionId,
            generation: activeSession.generation,
            generationId: activeSession.generationId,
            authorityEpoch: authorityEpoch
        )
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        lock.lock()
        let decision = decisionLocked(for: lease, checkpoint: checkpoint)
        let checkpointKey = checkpoint.rawValue
        if decision.allowed {
            acceptedByCheckpoint[checkpointKey, default: 0] += 1
        } else {
            rejectedByCheckpoint[checkpointKey, default: 0] += 1
            rejectedByReason[decision.reason.rawValue, default: 0] += 1
        }
        lock.unlock()
        return decision
    }

    func diagnosticsSnapshot() -> AccountLeaseDiagnosticsSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return AccountLeaseDiagnosticsSnapshot(
            acceptedCount: acceptedByCheckpoint.values.reduce(0, +),
            rejectedCount: rejectedByCheckpoint.values.reduce(0, +),
            acceptedByCheckpoint: acceptedByCheckpoint,
            rejectedByCheckpoint: rejectedByCheckpoint,
            rejectedByReason: rejectedByReason
        )
    }

    private func decisionLocked(
        for lease: AccountLease,
        checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        guard let activeSession else {
            return denied(.noActiveSession, at: checkpoint)
        }
        guard activeSession.subjectId == lease.subjectId else {
            return denied(.subjectMismatch, at: checkpoint)
        }
        guard activeSession.vaultId == lease.vaultId else {
            return denied(.vaultMismatch, at: checkpoint)
        }
        guard activeSession.generation == lease.generation else {
            return denied(.generationMismatch, at: checkpoint)
        }
        guard activeSession.generationId == lease.generationId else {
            return denied(.generationIdentityMismatch, at: checkpoint)
        }
        guard authorityEpoch == lease.authorityEpoch else {
            return denied(.authorityEpochMismatch, at: checkpoint)
        }
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: true,
            reason: .allowed,
            sessionRotated: activeSession.sessionId != lease.sessionId
        )
    }

    private func denied(
        _ reason: AccountLeaseValidationReason,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: false,
            reason: reason,
            sessionRotated: false
        )
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedAuthorityEpoch(_ value: String) -> String {
        normalized(value) ?? "unresolved"
    }
}
