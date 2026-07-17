import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

private func session(
    subjectId: String,
    vaultId: String,
    sessionId: String,
    generation: UInt64,
    generationId: UUID,
    state: AccountSessionState = .active
) -> AccountSession {
    AccountSession(
        subjectId: subjectId,
        vaultId: vaultId,
        sessionId: sessionId,
        tokenFamilyId: "family-\(subjectId)",
        sessionVersion: sessionId.hasSuffix("2") ? 2 : 1,
        generation: generation,
        generationId: generationId,
        state: state,
        activatedAt: Date(timeIntervalSince1970: 1)
    )
}

@main
private struct AccountLeaseRuntimeModelSmoke {
    static func main() {
        let generationA = UUID()
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-a")
        runtime.publish(
            session: session(
                subjectId: "account-a",
                vaultId: "vault-a",
                sessionId: "session-a1",
                generation: 7,
                generationId: generationA
            )
        )

        guard let leaseA = runtime.capture(forSubjectId: "account-a") else {
            fatalError("active account must issue an AccountLease")
        }
        require(leaseA.subjectId == "account-a", "lease subject must be canonical")
        require(leaseA.vaultId == "vault-a", "lease vault must be canonical")
        require(leaseA.sessionId == "session-a1", "lease must retain captured session lineage")
        require(leaseA.generation == 7, "lease must retain account generation")
        require(leaseA.generationId == generationA, "lease must retain generation identity")
        require(leaseA.authorityEpoch == "epoch-a", "lease must retain authority epoch")

        for checkpoint in AccountLeaseCheckpoint.allCases {
            require(
                runtime.validate(leaseA, at: checkpoint).allowed,
                "current lease must pass \(checkpoint.rawValue) checkpoint"
            )
        }
        require(
            runtime.capture(forSubjectId: "account-b") == nil,
            "capture must reject a different account"
        )

        runtime.publish(
            session: session(
                subjectId: "account-a",
                vaultId: "vault-a",
                sessionId: "session-a2",
                generation: 7,
                generationId: generationA
            )
        )
        let refreshDecision = runtime.validate(leaseA, at: .commit)
        require(refreshDecision.allowed, "same-generation token refresh must preserve business lease")
        require(refreshDecision.sessionRotated, "session rotation must remain observable")

        runtime.updateAuthorityEpoch("epoch-b")
        let epochDecision = runtime.validate(leaseA, at: .runtime)
        require(!epochDecision.allowed, "authority epoch change must reject old lease")
        require(epochDecision.reason == .authorityEpochMismatch, "epoch rejection reason must be stable")

        guard let leaseAfterEpoch = runtime.capture(forSubjectId: "account-a") else {
            fatalError("current account must recapture after authority epoch change")
        }
        require(leaseAfterEpoch.authorityEpoch == "epoch-b", "recaptured lease must use new epoch")

        runtime.publish(
            session: session(
                subjectId: "account-b",
                vaultId: "vault-b",
                sessionId: "session-b1",
                generation: 8,
                generationId: UUID()
            )
        )
        let switchDecision = runtime.validate(leaseAfterEpoch, at: .ui)
        require(!switchDecision.allowed, "account switch must reject old UI callback")
        require(switchDecision.reason == .subjectMismatch, "switch rejection reason must be stable")

        runtime.publish(session: nil)
        let logoutDecision = runtime.validate(leaseAfterEpoch, at: .timer)
        require(!logoutDecision.allowed, "logout must reject old timer")
        require(logoutDecision.reason == .noActiveSession, "logout rejection reason must be stable")

        let diagnostics = runtime.diagnosticsSnapshot()
        require(diagnostics.acceptedCount >= 6, "diagnostics must count accepted checkpoints")
        require(diagnostics.rejectedCount >= 3, "diagnostics must count rejected checkpoints")
        require(
            diagnostics.rejectedByCheckpoint[AccountLeaseCheckpoint.runtime.rawValue] == 1,
            "runtime rejection must be counted without account values"
        )

        print("Product V4 AccountLease runtime model smoke passed")
    }
}
