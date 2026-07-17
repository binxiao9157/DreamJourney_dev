import Foundation

private final class RefreshWriterProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var writes = 0
    private var clears = 0

    var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }

    var clearCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return clears
    }

    func write() -> Bool {
        lock.lock()
        writes += 1
        lock.unlock()
        return true
    }

    func clear() -> Bool {
        lock.lock()
        clears += 1
        lock.unlock()
        return true
    }
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

private func refreshCredential(
    subjectId: String,
    sessionId: String,
    familyId: String,
    version: Int
) -> AccountSessionCredentialSnapshot {
    AccountSessionCredentialSnapshot(
        subjectId: subjectId,
        vaultId: "vault-\(subjectId)",
        sessionId: sessionId,
        tokenFamilyId: familyId,
        sessionVersion: version,
        isPrivateAccessEligible: true,
        trust: .requiresOnlineValidation
    )
}

private func activate(
    actor: AccountSessionActor,
    credential: AccountSessionCredentialSnapshot
) async -> AccountSessionTransitionReceipt {
    let prepared = await actor.bootstrap(
        cachedProfileSubjectId: credential.subjectId,
        credential: credential
    )
    for phase in [
        AccountSessionActivationPhase.sessionSaved,
        .storesMounted,
        .profileCached,
    ] {
        let receipt = await actor.recordActivationPhase(
            phase,
            expectedGeneration: prepared.generation
        )
        require(receipt.accepted, "activation phase must be accepted: \(phase)")
    }
    return await actor.activateValidatedCredential(
        credential,
        expectedGeneration: prepared.generation
    )
}

@main
private struct AccountSessionRefreshCASModelSmoke {
    static func main() async {
        let suiteName = "DreamJourney.AccountSessionRefreshCAS.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let actor = AccountSessionActor(
            journal: AccountSessionActivationJournalStore(defaults: defaults)
        )

        let a1 = refreshCredential(
            subjectId: "account-a",
            sessionId: "session-a1",
            familyId: "family-a",
            version: 1
        )
        let activeA = await activate(actor: actor, credential: a1)
        let leaseA = await actor.captureRefreshLease(for: a1)
        require(leaseA != nil, "active account must issue a refresh lease")

        let a2 = refreshCredential(
            subjectId: "account-a",
            sessionId: "session-a2",
            familyId: "family-a",
            version: 2
        )
        let successfulWriter = RefreshWriterProbe()
        let committed = await actor.commitRefreshedCredential(
            a2,
            lease: leaseA!,
            writer: { successfulWriter.write() }
        )
        require(committed, "same-family successor must commit")
        require(successfulWriter.writeCount == 1, "accepted refresh must write exactly once")
        let refreshedA = await actor.snapshot()
        require(refreshedA.generation == activeA.generation, "refresh must not rotate account generation")
        require(refreshedA.generationId == activeA.generationId, "refresh must retain generation identity")
        require(refreshedA.session?.sessionId == "session-a2", "actor must adopt the refreshed session id")
        require(refreshedA.session?.sessionVersion == 2, "actor must adopt the refreshed session version")

        let staleWriter = RefreshWriterProbe()
        let staleOldResponse = await actor.commitRefreshedCredential(
            a2,
            lease: leaseA!,
            writer: { staleWriter.write() }
        )
        require(!staleOldResponse, "old session lease must be stale after rotation")
        require(staleWriter.writeCount == 0, "stale refresh must not reach Keychain writer")

        let leaseA2 = await actor.captureRefreshLease(for: a2)
        require(leaseA2 != nil, "rotated session must issue a new refresh lease")
        let signedOut = await actor.signOut(
            expectedGeneration: refreshedA.generation,
            reason: "refreshCASLogout"
        )
        require(signedOut.state == .signedOut, "logout must invalidate the active generation")
        let postLogoutWriter = RefreshWriterProbe()
        let postLogoutCommit = await actor.commitRefreshedCredential(
            refreshCredential(
                subjectId: "account-a",
                sessionId: "session-a3",
                familyId: "family-a",
                version: 3
            ),
            lease: leaseA2!,
            writer: { postLogoutWriter.write() }
        )
        require(!postLogoutCommit, "refresh response after logout must be rejected")
        require(postLogoutWriter.writeCount == 0, "logout race must not write Keychain")

        let b1 = refreshCredential(
            subjectId: "account-b",
            sessionId: "session-b1",
            familyId: "family-b",
            version: 1
        )
        _ = await actor.activateVerifiedLogin(b1)
        let postSwitchWriter = RefreshWriterProbe()
        let postSwitchCommit = await actor.commitRefreshedCredential(
            a2,
            lease: leaseA2!,
            writer: { postSwitchWriter.write() }
        )
        require(!postSwitchCommit, "account-A refresh must not overwrite account B")
        require(postSwitchWriter.writeCount == 0, "account switch race must not write Keychain")

        let leaseB = await actor.captureRefreshLease(for: b1)
        require(leaseB != nil, "account B must issue a refresh lease")
        let wrongFamilyWriter = RefreshWriterProbe()
        let wrongFamilyCommit = await actor.commitRefreshedCredential(
            refreshCredential(
                subjectId: "account-b",
                sessionId: "session-b2",
                familyId: "family-other",
                version: 2
            ),
            lease: leaseB!,
            writer: { wrongFamilyWriter.write() }
        )
        require(!wrongFamilyCommit, "refresh must not change token family")
        require(wrongFamilyWriter.writeCount == 0, "wrong-family response must not write Keychain")

        let skippedVersionWriter = RefreshWriterProbe()
        let skippedVersionCommit = await actor.commitRefreshedCredential(
            refreshCredential(
                subjectId: "account-b",
                sessionId: "session-b3",
                familyId: "family-b",
                version: 3
            ),
            lease: leaseB!,
            writer: { skippedVersionWriter.write() }
        )
        require(!skippedVersionCommit, "refresh must advance session version by exactly one")
        require(skippedVersionWriter.writeCount == 0, "skipped version must not write Keychain")

        let terminalClear = RefreshWriterProbe()
        let invalidated = await actor.invalidateRefreshLease(
            leaseB!,
            reason: "refresh_token_reuse_detected",
            clear: { terminalClear.clear() }
        )
        require(invalidated, "terminal refresh error must invalidate the matching generation")
        require(terminalClear.clearCount == 1, "terminal error must clear exactly one matching session")
        let suspended = await actor.snapshot()
        require(suspended.state == .suspended, "terminal refresh error must suspend private access")
        require(suspended.generation > leaseB!.generation, "terminal invalidation must rotate generation")

        print("Product V4 AccountSession refresh CAS model smoke passed")
    }
}
