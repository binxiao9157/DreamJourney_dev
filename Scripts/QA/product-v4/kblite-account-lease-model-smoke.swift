import Foundation

private func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

private struct KBLiteEffectModel {
    let runtime: AccountLeaseRuntimePort
    let lease: AccountLease
    private(set) var commitCount = 0
    private(set) var uiCount = 0
    private(set) var runtimeCount = 0

    mutating func commit() {
        guard runtime.validate(lease, at: .commit).allowed else { return }
        commitCount += 1
    }

    mutating func applyUI() {
        guard runtime.validate(lease, at: .ui).allowed else { return }
        uiCount += 1
    }

    mutating func applyRuntimeEffect() {
        guard runtime.validate(lease, at: .runtime).allowed else { return }
        runtimeCount += 1
    }
}

private func session(
    subjectId: String,
    generation: UInt64,
    generationId: UUID
) -> AccountSession {
    AccountSession(
        subjectId: subjectId,
        vaultId: "vault-\(subjectId)",
        sessionId: "session-\(generation)",
        tokenFamilyId: "family-\(subjectId)",
        sessionVersion: 1,
        generation: generation,
        generationId: generationId,
        state: .active,
        activatedAt: Date(timeIntervalSince1970: 1)
    )
}

@main
private struct KBLiteAccountLeaseModelSmoke {
    static func main() {
        let runtime = AccountLeaseRuntime(authorityEpoch: "epoch-a")
        let firstGeneration = UUID()
        runtime.publish(session: session(subjectId: "account-a", generation: 1, generationId: firstGeneration))
        guard let lease = runtime.capture(forSubjectId: "account-a") else {
            fatalError("active KBLite owner must issue a lease")
        }

        var current = KBLiteEffectModel(runtime: runtime, lease: lease)
        current.commit()
        current.applyRuntimeEffect()
        current.applyUI()
        require(current.commitCount == 1, "current lease must permit persistence")
        require(current.runtimeCount == 1, "current lease must permit runtime effects")
        require(current.uiCount == 1, "current lease must permit UI effects")

        runtime.publish(session: session(subjectId: "account-b", generation: 2, generationId: UUID()))
        runtime.publish(session: session(subjectId: "account-a", generation: 3, generationId: UUID()))

        var stale = KBLiteEffectModel(runtime: runtime, lease: lease)
        stale.commit()
        stale.applyRuntimeEffect()
        stale.applyUI()
        require(stale.commitCount == 0, "A-B-A must not revive an old KBLite file commit")
        require(stale.runtimeCount == 0, "A-B-A must not revive old Widget or cache work")
        require(stale.uiCount == 0, "A-B-A must not deliver an old KBLite notification")

        print("KBLite AccountLease model smoke passed")
    }
}
