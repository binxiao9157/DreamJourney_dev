import Foundation

private struct Lease: Equatable {
    let subjectId: String
    let vaultId: String
    let generation: UInt64
    let generationId: UUID
    let authorityEpoch: String
}

private struct DelayedReplyCallsiteContext: Equatable {
    let lease: Lease
    let resourceOwnerId: String
    let operationId: String
    let roleContextKey: String
}

private struct ActiveEchoScope {
    var lease: Lease
    var roleContextKey: String
    var pending: DelayedReplyCallsiteContext?

    mutating func begin(operationId: String) -> DelayedReplyCallsiteContext {
        let context = DelayedReplyCallsiteContext(
            lease: lease,
            resourceOwnerId: lease.subjectId,
            operationId: operationId,
            roleContextKey: roleContextKey
        )
        pending = context
        return context
    }

    func accepts(_ candidate: DelayedReplyCallsiteContext) -> Bool {
        candidate == pending
            && candidate.lease == lease
            && candidate.resourceOwnerId == lease.subjectId
            && candidate.roleContextKey == roleContextKey
    }
}

@main
private enum EchoDelayedReplyCallsiteModelSmoke {
    static func main() {
        let leaseA = makeLease(subject: "account-a", generation: 1, generationID: 0xA1)
        let leaseANext = makeLease(subject: "account-a", generation: 2, generationID: 0xA2)
        let leaseB = makeLease(subject: "account-b", generation: 1, generationID: 0xB1)
        var scope = ActiveEchoScope(lease: leaseA, roleContextKey: "account-a|self", pending: nil)

        let original = scope.begin(operationId: "reply-a")
        require(scope.accepts(original), "originating operation must be accepted")

        var switchedRole = scope
        switchedRole.roleContextKey = "family-b|family"
        require(!switchedRole.accepts(original), "role switch must reject the old callback")

        var nextGeneration = scope
        nextGeneration.lease = leaseANext
        require(!nextGeneration.accepts(original), "generation rotation must reject the old callback")

        var switchedAccount = scope
        switchedAccount.lease = leaseB
        require(!switchedAccount.accepts(original), "account switch must reject the old callback")

        let replacement = scope.begin(operationId: "reply-b")
        require(!scope.accepts(original), "replacement operation must retire the old callback")
        require(scope.accepts(replacement), "replacement operation must remain usable")

        let forgedOwner = DelayedReplyCallsiteContext(
            lease: replacement.lease,
            resourceOwnerId: "account-b",
            operationId: replacement.operationId,
            roleContextKey: replacement.roleContextKey
        )
        require(!scope.accepts(forgedOwner), "resource owner mismatch must fail closed")

        print("Echo delayed reply callsite model smoke passed")
    }

    private static func makeLease(subject: String, generation: UInt64, generationID: UInt8) -> Lease {
        let suffix = String(format: "%02X", generationID)
        return Lease(
            subjectId: subject,
            vaultId: "vault-\(subject)",
            generation: generation,
            generationId: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(suffix)")!,
            authorityEpoch: "epoch-1"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError(message)
        }
    }
}
