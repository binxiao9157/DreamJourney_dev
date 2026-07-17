import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

func credential(
    subjectId: String,
    eligible: Bool = true,
    trust: AccountSessionCredentialTrust = .requiresOnlineValidation
) -> AccountSessionCredentialSnapshot {
    AccountSessionCredentialSnapshot(
        subjectId: subjectId,
        vaultId: "vault-\(subjectId)",
        sessionId: "session-\(subjectId)",
        tokenFamilyId: "family-\(subjectId)",
        sessionVersion: 1,
        isPrivateAccessEligible: eligible,
        trust: trust
    )
}

@main
struct AccountSessionActorModelSmoke {
    static func main() async {
        let suiteName = "DreamJourney.AccountSessionActorModelSmoke.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create isolated UserDefaults suite")
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let journal = AccountSessionActivationJournalStore(defaults: defaults)
        let actor = AccountSessionActor(journal: journal)

        let noState = await actor.bootstrap(cachedProfileSubjectId: nil, credential: nil)
        require(noState.state == .signedOut, "empty cold start must stay signed out")
        require(noState.rootRoute == .authentication, "empty cold start must show authentication")

        let profileOnly = await actor.bootstrap(cachedProfileSubjectId: "account-a", credential: nil)
        require(profileOnly.state == .signedOut, "cached profile alone must not authorize private UI")

        let credentialOnly = await actor.bootstrap(
            cachedProfileSubjectId: nil,
            credential: credential(subjectId: "account-a")
        )
        require(credentialOnly.state == .activating, "valid credential must permit online profile recovery")
        require(credentialOnly.rootRoute == .validation, "profile recovery must stay behind the validation gate")

        let mismatch = await actor.bootstrap(
            cachedProfileSubjectId: "account-a",
            credential: credential(subjectId: "account-b")
        )
        require(mismatch.state == .activating, "valid session must remain recoverable after profile mismatch")
        require(mismatch.reason == "coldStartProfileMismatchQuarantined", "mismatched profile must be quarantined")
        require(mismatch.rootRoute != .privateUI, "mismatched cached profile must never enter private UI")

        let ineligible = await actor.bootstrap(
            cachedProfileSubjectId: "account-a",
            credential: credential(subjectId: "account-a", eligible: false)
        )
        require(ineligible.state == .signedOut, "ineligible credential must fail closed")

        let activating = await actor.bootstrap(
            cachedProfileSubjectId: "account-a",
            credential: credential(subjectId: "account-a")
        )
        require(activating.state == .activating, "matching credential must require online validation")
        require(activating.rootRoute == .validation, "matching cold start must remain behind validation gate")
        require(activating.session?.activatedAt == nil, "cold-start credential must not be marked active early")

        let sessionSaved = await actor.recordActivationPhase(
            .sessionSaved,
            expectedGeneration: activating.generation
        )
        require(sessionSaved.accepted, "activation journal must record session persistence")
        let skippedPhase = await actor.recordActivationPhase(
            .profileCached,
            expectedGeneration: activating.generation
        )
        require(!skippedPhase.accepted, "activation journal must reject skipped phases")
        let storesMounted = await actor.recordActivationPhase(
            .storesMounted,
            expectedGeneration: activating.generation
        )
        require(storesMounted.accepted, "activation journal must record private store mount")
        let profileCached = await actor.recordActivationPhase(
            .profileCached,
            expectedGeneration: activating.generation
        )
        require(profileCached.accepted, "activation journal must record profile cache rebuild")

        let active = await actor.activateValidatedCredential(
            credential(subjectId: "account-a"),
            expectedGeneration: activating.generation
        )
        require(active.accepted, "matching online validation must activate")
        require(active.state == .active && active.rootRoute == .privateUI, "validated account must enter private UI")
        require(active.generation == activating.generation, "one activation must retain one lifecycle generation")
        require(active.generationId == activating.generationId, "one activation must retain one generation identity")
        require(active.activationPhase == .committed, "active route requires a committed activation journal")
        require(active.session?.activatedAt != nil, "active account must carry activation time")

        let switching = await actor.beginSwitch(expectedGeneration: active.generation)
        require(switching.state == .switching, "active account must enter switching state")
        require(switching.rootRoute == .validation, "account switching must hide private UI")

        let signedOut = await actor.signOut(
            expectedGeneration: switching.generation,
            reason: "modelLogout"
        )
        require(signedOut.state == .signedOut, "logout must clear active account")
        let staleActivation = await actor.activateValidatedCredential(
            credential(subjectId: "account-a"),
            expectedGeneration: activating.generation
        )
        require(!staleActivation.accepted, "stale validation callback must be rejected")
        require(staleActivation.state == .signedOut, "stale callback must not resurrect the account")

        let verifiedLogin = await actor.activateVerifiedLogin(credential(subjectId: "account-b"))
        require(verifiedLogin.state == .active, "fresh verified login must activate directly")
        let staleSignOut = await actor.signOut(
            expectedGeneration: active.generation,
            reason: "lateLogoutFromAccountA"
        )
        require(!staleSignOut.accepted, "late logout must not clear a newer account generation")
        require(staleSignOut.session?.subjectId == "account-b", "late logout must preserve the newer account")
        let deleting = await actor.beginDeleting(expectedGeneration: verifiedLogin.generation)
        require(deleting.state == .deleting, "active account must enter deleting state")
        require(deleting.rootRoute == .authentication, "deleting account must unmount private UI")

        let synthetic = await actor.bootstrap(
            cachedProfileSubjectId: "uiqa-account",
            credential: credential(
                subjectId: "uiqa-account",
                trust: .prevalidatedTestOnly
            )
        )
        require(synthetic.state == .active, "explicit UIQA credential must preserve simulator harness")
        require(synthetic.reason == "coldStartPrevalidatedTestCredential", "UIQA bypass must be auditable")

        guard let entry = journal.load() else {
            fatalError("activation journal must retain the latest transition receipt")
        }
        require(entry.generation == synthetic.generation, "journal generation must match actor generation")
        require(entry.generationId == synthetic.generationId, "journal generation id must match actor receipt")
        require(entry.state == .active, "journal must record the latest state")
        require(entry.activationPhase == .committed, "journal must persist the committed activation phase")
        let journalData = defaults.data(forKey: "dj.accountSession.activationJournal.v1") ?? Data()
        let journalText = String(data: journalData, encoding: .utf8) ?? ""
        for forbidden in ["uiqa-account", "session-uiqa-account", "family-uiqa-account"] {
            require(!journalText.contains(forbidden), "activation journal must not persist identity or credential values")
        }

        let restartedActor = AccountSessionActor(journal: journal)
        let resumed = await restartedActor.bootstrap(
            cachedProfileSubjectId: "account-c",
            credential: credential(subjectId: "account-c")
        )
        require(resumed.generation > synthetic.generation, "process restart must not reuse generation sequence")
        require(resumed.generationId != synthetic.generationId, "process restart must rotate generation id")
        require(resumed.rootRoute == .validation, "interrupted activation must replay through validation")

        defaults.set(Data("corrupt-journal".utf8), forKey: "dj.accountSession.activationJournal.v1")
        let corruptJournalActor = AccountSessionActor(journal: journal)
        let recoveredFromCorruption = await corruptJournalActor.bootstrap(
            cachedProfileSubjectId: "account-d",
            credential: credential(subjectId: "account-d")
        )
        require(recoveredFromCorruption.rootRoute == .validation, "corrupt journal must recover fail closed")
        require(recoveredFromCorruption.state != .active, "corrupt journal must not restore private UI")

        print("Product V4 AccountSessionActor model smoke passed")
    }
}
