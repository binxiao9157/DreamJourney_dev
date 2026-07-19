import Foundation
import UserNotifications

private final class MutableLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
    var activeLease: AccountLease?
    private(set) var captureCount = 0

    init(activeLease: AccountLease?) {
        self.activeLease = activeLease
    }

    func capture(forSubjectId subjectId: String?) -> AccountLease? {
        captureCount += 1
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
        let allowed = activeLease.map {
            $0.subjectId == lease.subjectId
                && $0.vaultId == lease.vaultId
                && $0.generation == lease.generation
                && $0.generationId == lease.generationId
                && $0.authorityEpoch == lease.authorityEpoch
        } ?? false
        return AccountLeaseValidationDecision(
            checkpoint: checkpoint,
            allowed: allowed,
            reason: allowed ? .allowed : .generationIdentityMismatch,
            sessionRotated: false
        )
    }
}

private final class MockNotificationRequestCenter: EchoDelayedReplyNotificationRequestCenter, @unchecked Sendable {
    private(set) var requests: [String: UNNotificationRequest] = [:]
    private var addCompletions: [String: @Sendable (Error?) -> Void] = [:]

    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    ) {
        requests[request.identifier] = request
        addCompletions[request.identifier] = completionHandler
    }

    func getPendingNotificationRequests(
        completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void
    ) {
        completionHandler(Array(requests.values))
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        for identifier in identifiers {
            requests.removeValue(forKey: identifier)
        }
    }

    func completeAdd(identifier: String, error: Error? = nil) {
        let completion = addCompletions.removeValue(forKey: identifier)
        completion?(error)
    }
}

@main
private enum EchoDelayedReplyOwnerScopeModelSmoke {
    static func main() throws {
        let suiteName = "dj.echo-delayed-reply-owner-scope.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let leaseA = makeLease(
            subject: "account-a-sensitive",
            vault: "vault-a",
            generation: 7,
            generationId: "00000000-0000-0000-0000-0000000000A1"
        )
        let leaseANext = makeLease(
            subject: leaseA.subjectId,
            vault: leaseA.vaultId,
            generation: 8,
            generationId: "00000000-0000-0000-0000-0000000000A2"
        )
        let leaseB = makeLease(
            subject: "account-b-sensitive",
            vault: "vault-b",
            generation: 3,
            generationId: "00000000-0000-0000-0000-0000000000B1"
        )
        let runtime = MutableLeaseRuntime(activeLease: leaseA)
        let store = EchoDelayedReplyStore(
            defaults: defaults,
            accountLeaseRuntime: runtime,
            now: { Date(timeIntervalSince1970: 1_784_000_000) }
        )
        let operationId = "same-reply-id"
        let replyA = makeReply(id: operationId, minutes: 11)
        let replyB = makeReply(id: operationId, minutes: 23)

        defaults.set(Data("ownerless-legacy".utf8), forKey: "dj.echo.delayedReply")
        require(
            store.load(
                resourceOwnerId: leaseA.subjectId,
                operationId: operationId,
                accountLease: leaseA
            ) == nil,
            "global legacy payload must not auto-mount into account A"
        )
        require(defaults.object(forKey: "dj.echo.delayedReply") == nil, "legacy live key must be retired")
        let legacyRecord = store.legacyIsolationRecord()
        require(
            legacyRecord?.reason == .missingAuthenticatedOwner,
            "legacy quarantine must explain the missing authenticated owner"
        )
        require(
            legacyRecord.flatMap { defaults.object(forKey: $0.quarantineStorageKey) } != nil,
            "legacy bytes must remain isolated for explicit disposition"
        )

        require(
            store.save(
                replyA,
                resourceOwnerId: leaseA.subjectId,
                operationId: operationId,
                accountLease: leaseA
            ),
            "account A save should succeed"
        )
        let keyA = requireStorageKey(store, lease: leaseA, operationId: operationId)
        require(
            store.load(
                resourceOwnerId: leaseA.subjectId,
                operationId: operationId,
                accountLease: leaseA
            ) == replyA,
            "account A reply must round-trip"
        )
        try verifyEnvelope(
            defaults: defaults,
            key: keyA,
            lease: leaseA,
            resourceOwnerId: leaseA.subjectId,
            operationId: operationId
        )

        runtime.activeLease = leaseB
        let keyB = requireStorageKey(store, lease: leaseB, operationId: operationId)
        require(keyA != keyB, "A/B must not share a storage key for the same reply id")
        require(
            store.load(
                resourceOwnerId: leaseB.subjectId,
                operationId: operationId,
                accountLease: leaseB
            ) == nil,
            "account B must not read account A state"
        )
        require(
            store.save(
                replyB,
                resourceOwnerId: leaseB.subjectId,
                operationId: operationId,
                accountLease: leaseB
            ),
            "account B may save the same reply id"
        )

        runtime.activeLease = leaseANext
        let keyANext = requireStorageKey(store, lease: leaseANext, operationId: operationId)
        require(keyANext != keyA, "a new generation must not reuse the old generation key")
        require(
            store.load(
                resourceOwnerId: leaseANext.subjectId,
                operationId: operationId,
                accountLease: leaseANext
            ) == nil,
            "a new generation must not read old generation state"
        )
        require(
            !store.save(
                makeReply(id: operationId, minutes: 99),
                resourceOwnerId: leaseA.subjectId,
                operationId: operationId,
                accountLease: leaseA
            ),
            "a stale generation must not write old state"
        )
        require(
            !store.clear(
                resourceOwnerId: leaseA.subjectId,
                operationId: operationId,
                accountLease: leaseA
            ),
            "a stale generation must not clear old state"
        )
        require(
            store.save(
                makeReply(id: operationId, minutes: 31),
                resourceOwnerId: leaseANext.subjectId,
                operationId: operationId,
                accountLease: leaseANext
            ),
            "the active new generation should write only its own state"
        )
        runtime.activeLease = leaseA
        require(
            store.load(
                resourceOwnerId: leaseA.subjectId,
                operationId: operationId,
                accountLease: leaseA
            ) == replyA,
            "new generation writes must preserve the old generation envelope"
        )

        let capturesBeforeSaveWrapper = runtime.captureCount
        let wrapperReply = makeReply(id: "wrapper-operation", minutes: 17)
        require(store.save(wrapperReply), "compatibility save wrapper should succeed")
        require(
            runtime.captureCount == capturesBeforeSaveWrapper + 1,
            "save wrapper must capture exactly one lease"
        )
        let capturesBeforeLoadWrapper = runtime.captureCount
        require(store.load() == wrapperReply, "compatibility load wrapper should use its scoped operation index")
        require(
            runtime.captureCount == capturesBeforeLoadWrapper + 1,
            "load wrapper must capture exactly one lease"
        )

        try verifyNotificationScoping(
            runtime: runtime,
            leaseA: leaseA,
            leaseANext: leaseANext,
            leaseB: leaseB,
            delayedReply: replyA,
            operationId: operationId
        )

        print("Echo delayed reply owner-scope model smoke passed")
    }

    private static func verifyNotificationScoping(
        runtime: MutableLeaseRuntime,
        leaseA: AccountLease,
        leaseANext: AccountLease,
        leaseB: AccountLease,
        delayedReply: EchoDelayedReply,
        operationId: String
    ) throws {
        let requestCenter = MockNotificationRequestCenter()
        let scheduler = EchoDelayedReplyNotificationScheduler(
            requestCenter: requestCenter,
            accountLeaseRuntime: runtime
        )
        var completionA = 0
        var completionB = 0

        runtime.activeLease = leaseA
        scheduler.schedule(
            delayedReply,
            resourceOwnerId: leaseA.subjectId,
            operationId: operationId,
            accountLease: leaseA
        ) { _ in completionA += 1 }
        let identifierA = requireIdentifier(
            lease: leaseA,
            owner: leaseA.subjectId,
            delayedReplyId: delayedReply.id,
            operationId: operationId
        )
        guard let requestA = requestCenter.requests[identifierA] else {
            fatalError("account A notification was not staged")
        }
        require(identifierA != EchoDelayedReplyNotificationScheduler.notificationIdentifier, "identifier must be scoped")
        try verifyUserInfo(
            requestA.content.userInfo,
            lease: leaseA,
            resourceOwnerId: leaseA.subjectId,
            delayedReply: delayedReply,
            operationId: operationId
        )

        runtime.activeLease = leaseB
        scheduler.schedule(
            delayedReply,
            resourceOwnerId: leaseB.subjectId,
            operationId: operationId,
            accountLease: leaseB
        ) { _ in completionB += 1 }
        let identifierB = requireIdentifier(
            lease: leaseB,
            owner: leaseB.subjectId,
            delayedReplyId: delayedReply.id,
            operationId: operationId
        )
        require(identifierA != identifierB, "A/B same reply id must use different notification identifiers")
        require(requestCenter.requests[identifierB] != nil, "account B notification was not staged")

        requestCenter.completeAdd(identifier: identifierA)
        require(completionA == 0, "stale add callback must not apply UI completion")
        require(requestCenter.requests[identifierA] == nil, "stale callback must remove its original request")
        require(requestCenter.requests[identifierB] != nil, "stale A callback must preserve B request")
        requestCenter.completeAdd(identifier: identifierB)
        require(completionB == 1, "active callback should apply exactly once")

        runtime.activeLease = leaseA
        scheduler.schedule(
            delayedReply,
            resourceOwnerId: leaseA.subjectId,
            operationId: operationId,
            accountLease: leaseA
        )
        requestCenter.completeAdd(identifier: identifierA)
        runtime.activeLease = leaseANext
        scheduler.schedule(
            delayedReply,
            resourceOwnerId: leaseANext.subjectId,
            operationId: operationId,
            accountLease: leaseANext
        )
        let identifierANext = requireIdentifier(
            lease: leaseANext,
            owner: leaseANext.subjectId,
            delayedReplyId: delayedReply.id,
            operationId: operationId
        )
        require(identifierANext != identifierA, "new generation must rotate notification identifier")
        require(requestCenter.requests[identifierANext] != nil, "new generation request is missing")

        scheduler.cancelPendingDelayedReply(
            resourceOwnerId: leaseA.subjectId,
            operationId: operationId,
            accountLease: leaseA
        )
        require(requestCenter.requests[identifierA] == nil, "stale cancel should clean its original lease request")
        require(requestCenter.requests[identifierANext] != nil, "stale cancel must preserve the new generation request")
        require(requestCenter.requests[identifierB] != nil, "stale cancel must preserve account B request")

        let capturesBeforeCancelWrapper = runtime.captureCount
        scheduler.cancelPendingDelayedReply()
        require(
            runtime.captureCount == capturesBeforeCancelWrapper + 1,
            "cancel wrapper must capture exactly one lease"
        )
        require(requestCenter.requests[identifierANext] == nil, "wrapper cancel should remove the active lease request")
        require(requestCenter.requests[identifierB] != nil, "wrapper cancel must preserve another lease request")
    }

    private static func verifyEnvelope(
        defaults: UserDefaults,
        key: String,
        lease: AccountLease,
        resourceOwnerId: String,
        operationId: String
    ) throws {
        guard let data = defaults.data(forKey: key),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fatalError("scoped envelope is missing")
        }
        require(object["subjectId"] as? String == lease.subjectId, "envelope subject mismatch")
        require(object["vaultId"] as? String == lease.vaultId, "envelope vault mismatch")
        require((object["generation"] as? NSNumber)?.uint64Value == lease.generation, "envelope generation mismatch")
        require(object["generationId"] as? String == lease.generationId.uuidString, "envelope generation id mismatch")
        require(object["authorityEpoch"] as? String == lease.authorityEpoch, "envelope epoch mismatch")
        require(object["resourceOwnerId"] as? String == resourceOwnerId, "envelope resource owner mismatch")
        require(object["operationId"] as? String == operationId, "envelope operation mismatch")
    }

    private static func verifyUserInfo(
        _ userInfo: [AnyHashable: Any],
        lease: AccountLease,
        resourceOwnerId: String,
        delayedReply: EchoDelayedReply,
        operationId: String
    ) throws {
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
            "notification userInfo must contain only the metadata allowlist"
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
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["subject", lease.subjectId]
                ),
            "notification subject identity digest mismatch"
        )
        require(
            (userInfo["accountLeaseGeneration"] as? NSNumber)?.uint64Value == lease.generation,
            "notification generation metadata mismatch"
        )
        require(
            userInfo["accountLeaseGenerationIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["generation-id", lease.generationId.uuidString]
                ),
            "notification generation identity digest mismatch"
        )
        require(
            userInfo["accountLeaseVaultIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["vault", lease.vaultId]
                ),
            "notification vault identity digest mismatch"
        )
        require(
            userInfo["accountLeaseAuthorityEpochIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["authority-epoch", lease.authorityEpoch]
                ),
            "notification authority identity digest mismatch"
        )
        require(
            userInfo["resourceOwnerIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["resource-owner", resourceOwnerId]
                ),
            "notification resource owner identity digest mismatch"
        )
        require(
            userInfo["operationIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["operation", operationId]
                ),
            "notification operation identity digest mismatch"
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
            "notification userInfo exposed a raw metadata field"
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
                    "notification userInfo exposed raw identity or operation metadata"
                )
            }
        }
    }

    private static func requireStorageKey(
        _ store: EchoDelayedReplyStore,
        lease: AccountLease,
        operationId: String
    ) -> String {
        guard let key = store.storageKey(
            resourceOwnerId: lease.subjectId,
            operationId: operationId,
            accountLease: lease
        ) else {
            fatalError("expected a valid scoped storage key")
        }
        return key
    }

    private static func requireIdentifier(
        lease: AccountLease,
        owner: String,
        delayedReplyId: String,
        operationId: String
    ) -> String {
        guard let identifier = EchoDelayedReplyNotificationScheduler.notificationIdentifier(
            resourceOwnerId: owner,
            operationId: operationId,
            accountLease: lease
        ) else {
            fatalError("expected a valid notification identifier")
        }
        for rawValue in rawNotificationMetadataValues(
            lease: lease,
            resourceOwnerId: owner,
            delayedReplyId: delayedReplyId,
            operationId: operationId
        ) {
            require(
                !identifier.contains(rawValue),
                "notification identifier exposed raw identity or operation metadata"
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
        vault: String,
        generation: UInt64,
        generationId: String
    ) -> AccountLease {
        AccountLease(
            subjectId: subject,
            vaultId: vault,
            sessionId: "session-\(subject)-\(generation)",
            generation: generation,
            generationId: UUID(uuidString: generationId)!,
            authorityEpoch: "authority-epoch-2026-07"
        )
    }

    private static func makeReply(id: String, minutes: Int) -> EchoDelayedReply {
        let scheduledAt = Date(timeIntervalSince1970: 1_784_000_000)
        return EchoDelayedReply(
            id: id,
            scheduledAt: scheduledAt,
            deliverAt: scheduledAt.addingTimeInterval(TimeInterval(minutes * 60)),
            minutes: minutes,
            userTurnCount: 10,
            trigger: .tenRoundBaseline
        )
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
