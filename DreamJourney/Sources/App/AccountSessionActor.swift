import Foundation

enum AccountSessionState: String, Codable, Equatable, Sendable {
    case signedOut
    case activating
    case active
    case switching
    case suspended
    case deleting
}

enum AccountSessionRootRoute: String, Codable, Equatable, Sendable {
    case authentication
    case validation
    case privateUI
}

enum AccountSessionCredentialTrust: String, Codable, Equatable, Sendable {
    case requiresOnlineValidation
    case prevalidatedTestOnly
}

enum AccountSessionActivationPhase: Int, Codable, Equatable, Sendable {
    case prepared
    case sessionSaved
    case storesMounted
    case profileCached
    case committed
}

struct AccountSessionCredentialSnapshot: Equatable, Sendable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let tokenFamilyId: String
    let sessionVersion: Int
    let isPrivateAccessEligible: Bool
    let trust: AccountSessionCredentialTrust

    var normalizedSubjectId: String {
        subjectId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isUsable: Bool {
        isPrivateAccessEligible
            && !normalizedSubjectId.isEmpty
            && !vaultId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !sessionId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !tokenFamilyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && sessionVersion > 0
    }
}

struct AccountSession: Codable, Equatable, Sendable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let tokenFamilyId: String
    let sessionVersion: Int
    let generation: UInt64
    let generationId: UUID
    let state: AccountSessionState
    let activatedAt: Date?
}

struct AccountSessionRefreshLease: Equatable, Sendable {
    let subjectId: String
    let vaultId: String
    let sessionId: String
    let tokenFamilyId: String
    let sessionVersion: Int
    let generation: UInt64
    let generationId: UUID
}

struct AccountSessionTransitionReceipt: Codable, Equatable, Sendable {
    let generation: UInt64
    let generationId: UUID
    let state: AccountSessionState
    let rootRoute: AccountSessionRootRoute
    let reason: String
    let accepted: Bool
    let activationPhase: AccountSessionActivationPhase?
    let session: AccountSession?
}

struct AccountSessionActivationJournalEntry: Codable, Equatable {
    let schemaVersion: Int
    let generation: UInt64
    let generationId: UUID
    let state: AccountSessionState
    let rootRoute: AccountSessionRootRoute
    let reason: String
    let accepted: Bool
    let activationPhase: AccountSessionActivationPhase?
    let updatedAt: Date
}

final class AccountSessionActivationJournalStore: @unchecked Sendable {
    static let shared = AccountSessionActivationJournalStore()

    private let storageKey = "dj.accountSession.activationJournal.v1"
    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(_ receipt: AccountSessionTransitionReceipt, at date: Date = Date()) {
        let entry = AccountSessionActivationJournalEntry(
            schemaVersion: 1,
            generation: receipt.generation,
            generationId: receipt.generationId,
            state: receipt.state,
            rootRoute: receipt.rootRoute,
            reason: receipt.reason,
            accepted: receipt.accepted,
            activationPhase: receipt.activationPhase,
            updatedAt: date
        )
        guard let data = try? JSONEncoder().encode(entry) else { return }
        lock.lock()
        defaults.set(data, forKey: storageKey)
        lock.unlock()
    }

    func load() -> AccountSessionActivationJournalEntry? {
        lock.lock()
        let data = defaults.data(forKey: storageKey)
        lock.unlock()
        guard let data else { return nil }
        return try? JSONDecoder().decode(AccountSessionActivationJournalEntry.self, from: data)
    }
}

actor AccountSessionActor {
    static let shared = AccountSessionActor()

    private var generation: UInt64
    private var generationId: UUID
    private var currentSession: AccountSession?
    private var currentActivationPhase: AccountSessionActivationPhase?
    private let journal: AccountSessionActivationJournalStore

    init(journal: AccountSessionActivationJournalStore = .shared) {
        self.journal = journal
        let priorEntry = journal.load()
        generation = priorEntry?.generation ?? 0
        generationId = priorEntry?.generationId ?? UUID()
        currentActivationPhase = nil
    }

    func bootstrap(
        cachedProfileSubjectId: String?,
        credential: AccountSessionCredentialSnapshot?
    ) -> AccountSessionTransitionReceipt {
        let cachedSubjectId = normalized(cachedProfileSubjectId)
        guard let credential else {
            return transition(
                state: .signedOut,
                rootRoute: .authentication,
                reason: cachedSubjectId == nil ? "coldStartNoCachedIdentity" : "coldStartCredentialMissing",
                credential: nil
            )
        }
        guard credential.isUsable else {
            return transition(
                state: .signedOut,
                rootRoute: .authentication,
                reason: "coldStartCredentialIneligible",
                credential: nil
            )
        }
        if credential.trust == .prevalidatedTestOnly {
            guard credential.normalizedSubjectId == cachedSubjectId else {
                return transition(
                    state: .signedOut,
                    rootRoute: .authentication,
                    reason: "coldStartTestCredentialSubjectMismatch",
                    credential: nil
                )
            }
            return transition(
                state: .active,
                rootRoute: .privateUI,
                reason: "coldStartPrevalidatedTestCredential",
                credential: credential,
                activationPhase: .committed,
                activatedAt: Date()
            )
        }
        return transition(
            state: .activating,
            rootRoute: .validation,
            reason: coldStartValidationReason(
                cachedSubjectId: cachedSubjectId,
                credentialSubjectId: credential.normalizedSubjectId
            ),
            credential: credential,
            activationPhase: .prepared
        )
    }

    func recordActivationPhase(
        _ phase: AccountSessionActivationPhase,
        expectedGeneration: UInt64
    ) -> AccountSessionTransitionReceipt {
        guard let currentSession,
              currentSession.generation == expectedGeneration,
              currentSession.state == .activating,
              let currentActivationPhase,
              phase.rawValue == currentActivationPhase.rawValue + 1 else {
            return rejected(reason: "activationPhaseRejectedAsStaleOrOutOfOrder")
        }
        self.currentActivationPhase = phase
        let receipt = AccountSessionTransitionReceipt(
            generation: generation,
            generationId: generationId,
            state: currentSession.state,
            rootRoute: .validation,
            reason: "activationPhase.\(phase)",
            accepted: true,
            activationPhase: phase,
            session: currentSession
        )
        journal.record(receipt)
        return receipt
    }

    func activateValidatedCredential(
        _ credential: AccountSessionCredentialSnapshot,
        expectedGeneration: UInt64
    ) -> AccountSessionTransitionReceipt {
        guard let currentSession,
              currentSession.generation == expectedGeneration,
              currentSession.state == .activating,
              currentActivationPhase == .profileCached,
              credential.isUsable,
              currentSession.subjectId == credential.normalizedSubjectId,
              currentSession.vaultId == credential.vaultId else {
            return rejected(reason: "validatedCredentialRejectedAsStale")
        }
        return transition(
            state: .active,
            rootRoute: .privateUI,
            reason: "onlineSessionValidated",
            credential: credential,
            activationPhase: .committed,
            rotateGeneration: false,
            activatedAt: Date()
        )
    }

    func activateVerifiedLogin(
        _ credential: AccountSessionCredentialSnapshot
    ) -> AccountSessionTransitionReceipt {
        guard credential.isUsable,
              credential.trust == .requiresOnlineValidation else {
            return transition(
                state: .signedOut,
                rootRoute: .authentication,
                reason: "verifiedLoginCredentialRejected",
                credential: nil
            )
        }
        return transition(
            state: .active,
            rootRoute: .privateUI,
            reason: "verifiedLoginActivated",
            credential: credential,
            activationPhase: .committed,
            activatedAt: Date()
        )
    }

    func captureRefreshLease(
        for credential: AccountSessionCredentialSnapshot
    ) -> AccountSessionRefreshLease? {
        guard credential.isUsable,
              let currentSession,
              currentSession.state == .active || currentSession.state == .activating,
              currentSession.subjectId == credential.normalizedSubjectId,
              currentSession.vaultId == credential.vaultId,
              currentSession.sessionId == credential.sessionId,
              currentSession.tokenFamilyId == credential.tokenFamilyId,
              currentSession.sessionVersion == credential.sessionVersion else {
            return nil
        }
        return AccountSessionRefreshLease(
            subjectId: currentSession.subjectId,
            vaultId: currentSession.vaultId,
            sessionId: currentSession.sessionId,
            tokenFamilyId: currentSession.tokenFamilyId,
            sessionVersion: currentSession.sessionVersion,
            generation: currentSession.generation,
            generationId: currentSession.generationId
        )
    }

    func isCurrentRefreshLease(_ lease: AccountSessionRefreshLease) -> Bool {
        refreshLeaseIsCurrent(lease)
    }

    func commitRefreshedCredential(
        _ credential: AccountSessionCredentialSnapshot,
        lease: AccountSessionRefreshLease,
        writer: @Sendable () throws -> Bool
    ) -> Bool {
        guard refreshLeaseIsCurrent(lease),
              credential.isUsable,
              credential.normalizedSubjectId == lease.subjectId,
              credential.vaultId == lease.vaultId,
              credential.sessionId != lease.sessionId,
              credential.tokenFamilyId == lease.tokenFamilyId,
              credential.sessionVersion == lease.sessionVersion + 1 else {
            return false
        }
        do {
            guard try writer() else { return false }
        } catch {
            return false
        }
        guard let currentSession else { return false }
        let refreshedSession = AccountSession(
            subjectId: currentSession.subjectId,
            vaultId: currentSession.vaultId,
            sessionId: credential.sessionId,
            tokenFamilyId: credential.tokenFamilyId,
            sessionVersion: credential.sessionVersion,
            generation: currentSession.generation,
            generationId: currentSession.generationId,
            state: currentSession.state,
            activatedAt: currentSession.activatedAt
        )
        self.currentSession = refreshedSession
        let receipt = AccountSessionTransitionReceipt(
            generation: generation,
            generationId: generationId,
            state: refreshedSession.state,
            rootRoute: rootRoute(for: refreshedSession.state),
            reason: "refreshSessionCASCommitted",
            accepted: true,
            activationPhase: currentActivationPhase,
            session: refreshedSession
        )
        journal.record(receipt)
        return true
    }

    func invalidateRefreshLease(
        _ lease: AccountSessionRefreshLease,
        reason: String,
        clear: @Sendable () -> Bool
    ) -> Bool {
        guard refreshLeaseIsCurrent(lease), clear() else { return false }
        _ = transition(
            state: .suspended,
            rootRoute: .authentication,
            reason: reason,
            session: currentSession,
            activationPhase: nil
        )
        return true
    }

    func beginSwitch(expectedGeneration: UInt64) -> AccountSessionTransitionReceipt {
        guard let currentSession,
              currentSession.generation == expectedGeneration,
              currentSession.state == .active else {
            return rejected(reason: "accountSwitchRejectedAsStale")
        }
        return transition(
            state: .switching,
            rootRoute: .validation,
            reason: "accountSwitchStarted",
            session: currentSession,
            activationPhase: nil
        )
    }

    func suspend(expectedGeneration: UInt64?, reason: String) -> AccountSessionTransitionReceipt {
        if let expectedGeneration,
           currentSession?.generation != expectedGeneration {
            return rejected(reason: "accountSuspensionRejectedAsStale")
        }
        return transition(
            state: .suspended,
            rootRoute: .authentication,
            reason: reason,
            session: currentSession,
            activationPhase: nil
        )
    }

    func beginDeleting(expectedGeneration: UInt64) -> AccountSessionTransitionReceipt {
        guard let currentSession,
              currentSession.generation == expectedGeneration,
              currentSession.state == .active else {
            return rejected(reason: "accountDeletionRejectedAsStale")
        }
        return transition(
            state: .deleting,
            rootRoute: .authentication,
            reason: "accountDeletionStarted",
            session: currentSession,
            activationPhase: nil
        )
    }

    func signOut(
        expectedGeneration: UInt64?,
        reason: String
    ) -> AccountSessionTransitionReceipt {
        if let expectedGeneration,
           currentSession?.generation != expectedGeneration {
            return rejected(reason: "accountSignOutRejectedAsStale")
        }
        return transition(
            state: .signedOut,
            rootRoute: .authentication,
            reason: reason,
            credential: nil,
            activationPhase: nil
        )
    }

    func snapshot() -> AccountSessionTransitionReceipt {
        let state = currentSession?.state ?? .signedOut
        return AccountSessionTransitionReceipt(
            generation: generation,
            generationId: generationId,
            state: state,
            rootRoute: rootRoute(for: state),
            reason: "snapshot",
            accepted: true,
            activationPhase: currentActivationPhase,
            session: currentSession
        )
    }

    private func transition(
        state: AccountSessionState,
        rootRoute: AccountSessionRootRoute,
        reason: String,
        credential: AccountSessionCredentialSnapshot?,
        activationPhase: AccountSessionActivationPhase? = nil,
        rotateGeneration: Bool = true,
        activatedAt: Date? = nil
    ) -> AccountSessionTransitionReceipt {
        if rotateGeneration {
            generation &+= 1
            generationId = UUID()
        }
        let session = credential.map {
            AccountSession(
                subjectId: $0.normalizedSubjectId,
                vaultId: $0.vaultId,
                sessionId: $0.sessionId,
                tokenFamilyId: $0.tokenFamilyId,
                sessionVersion: $0.sessionVersion,
                generation: generation,
                generationId: generationId,
                state: state,
                activatedAt: activatedAt
            )
        }
        currentSession = session
        currentActivationPhase = activationPhase
        let receipt = AccountSessionTransitionReceipt(
            generation: generation,
            generationId: generationId,
            state: state,
            rootRoute: rootRoute,
            reason: reason,
            accepted: true,
            activationPhase: activationPhase,
            session: session
        )
        journal.record(receipt)
        return receipt
    }

    private func transition(
        state: AccountSessionState,
        rootRoute: AccountSessionRootRoute,
        reason: String,
        session: AccountSession?,
        activationPhase: AccountSessionActivationPhase?
    ) -> AccountSessionTransitionReceipt {
        generation &+= 1
        generationId = UUID()
        let nextSession = session.map {
            AccountSession(
                subjectId: $0.subjectId,
                vaultId: $0.vaultId,
                sessionId: $0.sessionId,
                tokenFamilyId: $0.tokenFamilyId,
                sessionVersion: $0.sessionVersion,
                generation: generation,
                generationId: generationId,
                state: state,
                activatedAt: state == .active ? ($0.activatedAt ?? Date()) : $0.activatedAt
            )
        }
        currentSession = nextSession
        currentActivationPhase = activationPhase
        let receipt = AccountSessionTransitionReceipt(
            generation: generation,
            generationId: generationId,
            state: state,
            rootRoute: rootRoute,
            reason: reason,
            accepted: true,
            activationPhase: activationPhase,
            session: nextSession
        )
        journal.record(receipt)
        return receipt
    }

    private func rejected(reason: String) -> AccountSessionTransitionReceipt {
        let state = currentSession?.state ?? .signedOut
        let receipt = AccountSessionTransitionReceipt(
            generation: generation,
            generationId: generationId,
            state: state,
            rootRoute: rootRoute(for: state),
            reason: reason,
            accepted: false,
            activationPhase: currentActivationPhase,
            session: currentSession
        )
        journal.record(receipt)
        return receipt
    }

    private func rootRoute(for state: AccountSessionState) -> AccountSessionRootRoute {
        switch state {
        case .active:
            return .privateUI
        case .activating, .switching:
            return .validation
        case .signedOut, .suspended, .deleting:
            return .authentication
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func refreshLeaseIsCurrent(_ lease: AccountSessionRefreshLease) -> Bool {
        guard let currentSession,
              currentSession.state == .active || currentSession.state == .activating else {
            return false
        }
        return currentSession.subjectId == lease.subjectId
            && currentSession.vaultId == lease.vaultId
            && currentSession.sessionId == lease.sessionId
            && currentSession.tokenFamilyId == lease.tokenFamilyId
            && currentSession.sessionVersion == lease.sessionVersion
            && currentSession.generation == lease.generation
            && currentSession.generationId == lease.generationId
    }

    private func coldStartValidationReason(
        cachedSubjectId: String?,
        credentialSubjectId: String
    ) -> String {
        guard let cachedSubjectId else {
            return "coldStartProfileRecoveryRequired"
        }
        if cachedSubjectId != credentialSubjectId {
            return "coldStartProfileMismatchQuarantined"
        }
        return "coldStartOnlineValidationRequired"
    }
}
