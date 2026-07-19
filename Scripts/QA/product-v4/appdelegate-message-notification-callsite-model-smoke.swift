import Foundation
import UserNotifications

private final class CallsiteNotificationCenter: EchoDelayedReplyNotificationRequestCenter, @unchecked Sendable {
    private(set) var requests: [String: UNNotificationRequest] = [:]

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    ) {
        requests[request.identifier] = request
        completionHandler?(nil)
    }

    func getPendingNotificationRequests(
        completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void
    ) {
        completionHandler(Array(requests.values))
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        identifiers.forEach { requests.removeValue(forKey: $0) }
    }
}

private final class CallsiteLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    var activeLease: AccountLease?

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        guard let activeLease,
              subjectId == nil || subjectId == activeLease.subjectId else {
            return nil
        }
        return activeLease
    }

    func validate(
        _ lease: AccountLease,
        at checkpoint: AccountLeaseCheckpoint
    ) -> AccountLeaseValidationDecision {
        let allowed = lease == activeLease
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: allowed,
            reason: allowed ? .allowed : .generationIdentityMismatch,
            sessionRotated: !allowed
        )
    }
}

@main
private enum AppDelegateMessageNotificationCallsiteModelSmoke {
    static func main() {
        let runtime = CallsiteLeaseRuntime()
        let center = CallsiteNotificationCenter()
        let scheduler = EchoDelayedReplyNotificationScheduler(
            requestCenter: center,
            accountLeaseRuntime: runtime
        )
        let leaseA = makeLease(
            subject: "account-a-private",
            generation: 7,
            generationId: "10000000-0000-0000-0000-000000000007"
        )
        let leaseB = makeLease(
            subject: "account-b-private",
            generation: 7,
            generationId: "20000000-0000-0000-0000-000000000007"
        )
        let reply = EchoDelayedReply(
            id: "delayed-reply-private-id",
            scheduledAt: Date(timeIntervalSince1970: 1_784_000_000),
            deliverAt: Date().addingTimeInterval(60),
            minutes: 1,
            userTurnCount: 10,
            trigger: .tenRoundBaseline
        )
        let resourceOwnerA = "resource-owner-a-private"
        let resourceOwnerB = "resource-owner-b-private"
        let firstOperation = "notification-operation-private"

        runtime.activeLease = leaseA
        schedule(
            reply,
            lease: leaseA,
            resourceOwnerId: resourceOwnerA,
            operationId: firstOperation,
            scheduler: scheduler
        )
        let identifierA = expectedIdentifier(
            lease: leaseA,
            resourceOwnerId: resourceOwnerA,
            delayedReplyId: reply.id,
            operationId: firstOperation
        )
        guard let requestA = center.requests[identifierA] else {
            fatalError("AppDelegate lookup could not resolve account A scoped request")
        }
        verifyCallsiteMetadata(
            requestA,
            lease: leaseA,
            resourceOwnerId: resourceOwnerA,
            delayedReply: reply,
            operationId: firstOperation
        )

        runtime.activeLease = leaseB
        schedule(
            reply,
            lease: leaseB,
            resourceOwnerId: resourceOwnerB,
            operationId: firstOperation,
            scheduler: scheduler
        )
        let identifierB = expectedIdentifier(
            lease: leaseB,
            resourceOwnerId: resourceOwnerB,
            delayedReplyId: reply.id,
            operationId: firstOperation
        )
        require(identifierA != identifierB, "same reply id must not collide across accounts")
        require(center.requests[identifierB] != nil, "account B scoped request is missing")
        require(center.requests[identifierA] != nil, "scheduling account B must preserve account A request")

        runtime.activeLease = leaseA
        let secondOperation = "reply-second-operation"
        schedule(
            reply,
            lease: leaseA,
            resourceOwnerId: resourceOwnerA,
            operationId: secondOperation,
            scheduler: scheduler
        )
        let secondIdentifier = expectedIdentifier(
            lease: leaseA,
            resourceOwnerId: resourceOwnerA,
            delayedReplyId: reply.id,
            operationId: secondOperation
        )
        require(secondIdentifier != identifierA, "operation identity must rotate the scoped identifier")
        guard let secondRequest = center.requests[secondIdentifier] else {
            fatalError("second operation request is missing")
        }
        verifyCallsiteMetadata(
            secondRequest,
            lease: leaseA,
            resourceOwnerId: resourceOwnerA,
            delayedReply: reply,
            operationId: secondOperation
        )

        print("AppDelegate message/notification callsite model smoke passed")
    }

    private static func schedule(
        _ reply: EchoDelayedReply,
        lease: AccountLease,
        resourceOwnerId: String,
        operationId: String,
        scheduler: EchoDelayedReplyNotificationScheduler
    ) {
        scheduler.schedule(
            reply,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId,
            accountLease: lease
        )
    }

    private static func verifyCallsiteMetadata(
        _ request: UNNotificationRequest,
        lease: AccountLease,
        resourceOwnerId: String,
        delayedReply: EchoDelayedReply,
        operationId: String
    ) {
        let userInfo = request.content.userInfo
        let expectedKeys: Set<String> = [
            NotificationRuntimeRoutePayload.Key.schemaVersion,
            NotificationRuntimeRoutePayload.Key.action,
            "type",
            "trigger",
            "accountSubjectIdentity",
            "accountLeaseGeneration",
            "accountLeaseGenerationIdentity",
            "accountLeaseVaultIdentity",
            "accountLeaseAuthorityEpochIdentity",
            "resourceOwnerIdentity",
            "operationIdentity",
        ]
        let actualKeys = Set(userInfo.keys.compactMap { $0 as? String })
        require(
            actualKeys == expectedKeys && actualKeys.count == userInfo.count,
            "callsite metadata must contain only the notification allowlist"
        )
        require(
            (userInfo[NotificationRuntimeRoutePayload.Key.schemaVersion] as? NSNumber)?.intValue
                == NotificationRuntimeRoutePayload.schemaVersion,
            "notification route schema mismatch"
        )
        require(
            userInfo[NotificationRuntimeRoutePayload.Key.action] as? String
                == NotificationRuntimeRouteAction.open.rawValue,
            "notification route action mismatch"
        )
        require(userInfo["type"] as? String == "echoDelayedReply", "notification type mismatch")
        require(
            userInfo["trigger"] as? String == delayedReply.trigger.rawValue,
            "notification trigger mismatch"
        )
        require(
            userInfo["accountSubjectIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(values: ["subject", lease.subjectId]),
            "subject identity digest mismatch"
        )
        require(
            (userInfo["accountLeaseGeneration"] as? NSNumber)?.uint64Value == lease.generation,
            "generation metadata mismatch"
        )
        require(
            userInfo["accountLeaseGenerationIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["generation-id", lease.generationId.uuidString]
                ),
            "generation identity digest mismatch"
        )
        require(
            userInfo["accountLeaseVaultIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(values: ["vault", lease.vaultId]),
            "vault identity digest mismatch"
        )
        require(
            userInfo["accountLeaseAuthorityEpochIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["authority-epoch", lease.authorityEpoch]
                ),
            "authority epoch identity digest mismatch"
        )
        require(
            userInfo["resourceOwnerIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["resource-owner", resourceOwnerId]
                ),
            "resource owner identity digest mismatch"
        )
        require(
            userInfo["operationIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(values: ["operation", operationId]),
            "operation identity digest mismatch"
        )
        let rawMetadataKeys: Set<String> = [
            "subjectId",
            "vaultId",
            "sessionId",
            "authorityEpoch",
            "generationId",
            "accountLeaseGenerationId",
            "resourceOwnerId",
            "delayedReplyId",
            "operationId",
        ]
        require(
            rawMetadataKeys.isDisjoint(with: actualKeys),
            "raw notification metadata key must be absent"
        )
        let rawValues = rawNotificationMetadataValues(
            lease: lease,
            resourceOwnerId: resourceOwnerId,
            delayedReplyId: delayedReply.id,
            operationId: operationId
        )
        for (key, value) in userInfo {
            for rawValue in rawValues {
                require(
                    !String(describing: key).contains(rawValue)
                        && !String(describing: value).contains(rawValue),
                    "raw identity or operation must not appear in notification metadata"
                )
            }
        }
    }

    private static func expectedIdentifier(
        lease: AccountLease,
        resourceOwnerId: String,
        delayedReplyId: String,
        operationId: String
    ) -> String {
        guard let identifier = EchoDelayedReplyNotificationScheduler.notificationIdentifier(
            resourceOwnerId: resourceOwnerId,
            operationId: operationId,
            accountLease: lease
        ) else {
            fatalError("scoped notification identifier was not derived")
        }
        require(
            identifier != EchoDelayedReplyNotificationScheduler.notificationIdentifier,
            "callsite must not use the legacy global identifier"
        )
        for rawValue in rawNotificationMetadataValues(
            lease: lease,
            resourceOwnerId: resourceOwnerId,
            delayedReplyId: delayedReplyId,
            operationId: operationId
        ) {
            require(
                !identifier.contains(rawValue),
                "identifier must not expose raw identity or operation metadata"
            )
        }
        return identifier
    }

    private static func rawNotificationMetadataValues(
        lease: AccountLease,
        resourceOwnerId: String,
        delayedReplyId: String,
        operationId: String
    ) -> [String] {
        [
            lease.subjectId,
            lease.vaultId,
            lease.sessionId,
            lease.authorityEpoch,
            lease.generationId.uuidString,
            resourceOwnerId,
            delayedReplyId,
            operationId,
        ].filter { !$0.isEmpty }
    }

    private static func makeLease(
        subject: String,
        generation: UInt64,
        generationId: String
    ) -> AccountLease {
        AccountLease(
            subjectId: subject,
            vaultId: "vault-\(subject)",
            sessionId: "session-\(subject)",
            generation: generation,
            generationId: UUID(uuidString: generationId)!,
            authorityEpoch: "authority-epoch-uiqa"
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
