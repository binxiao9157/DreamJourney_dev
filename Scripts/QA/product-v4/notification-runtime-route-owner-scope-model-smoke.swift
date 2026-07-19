import Foundation

private final class MutableLeaseRuntime: AccountLeaseRuntimePort, @unchecked Sendable {
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
private enum NotificationRuntimeRouteOwnerScopeModelSmoke {
    static func main() {
        let runtime = MutableLeaseRuntime()
        let inbox = NotificationRuntimeRouteInbox(accountLeaseRuntime: runtime)
        let leaseA = makeLease(
            subject: "owner-a",
            generation: 7,
            generationId: "10000000-0000-0000-0000-000000000007"
        )
        let leaseANextGeneration = makeLease(
            subject: "owner-a",
            generation: 8,
            generationId: "10000000-0000-0000-0000-000000000008"
        )
        let leaseB = makeLease(
            subject: "owner-b",
            generation: 7,
            generationId: "20000000-0000-0000-0000-000000000007"
        )

        let routeA = makePayload(lease: leaseA, operation: "reply-a")
        require(
            inbox.ingest(userInfo: routeA, source: .notificationResponse) == .queued,
            "cold-start route must queue until an account lease is active"
        )
        require(
            inbox.ingest(userInfo: routeA, source: .notificationResponse) == .duplicate,
            "same opaque route must be deduplicated before it can be delivered"
        )
        require(
            inbox.consumeRoutesForCurrentAccount().isEmpty,
            "no active lease must never route a notification"
        )

        runtime.activeLease = leaseA
        let routesForA = inbox.consumeRoutesForCurrentAccount()
        require(routesForA.count == 1, "matching account must receive exactly one route")
        require(routesForA[0].accountLease == leaseA, "route must retain the validated lease")
        require(routesForA[0].payload.kind == .echoDelayedReply, "route kind mismatch")
        require(routesForA[0].payload.action == .open, "route action mismatch")
        require(routesForA[0].source == .notificationResponse, "route source mismatch")
        require(
            routesForA[0].payload.kind.selectedTabIndex == 1,
            "Echo route may only select the Echo tab; it must not activate audio runtime"
        )

        require(
            inbox.ingest(userInfo: routeA, source: .remoteNotification) == .queued,
            "a later remote ingress must be independently queued"
        )
        runtime.activeLease = leaseB
        require(
            inbox.consumeRoutesForCurrentAccount().isEmpty,
            "account B must never receive account A's notification route"
        )

        let staleGenerationRoute = makePayload(lease: leaseA, operation: "reply-stale")
        require(
            inbox.ingest(userInfo: staleGenerationRoute, source: .notificationResponse) == .queued,
            "stale generation fixture must be queued for negative validation"
        )
        runtime.activeLease = leaseANextGeneration
        require(
            inbox.consumeRoutesForCurrentAccount().isEmpty,
            "same subject with a newer generation must reject the prior route"
        )

        var alteredOwnerRoute = makePayload(lease: leaseANextGeneration, operation: "reply-owner")
        alteredOwnerRoute[NotificationRuntimeRoutePayload.Key.resourceOwnerIdentity] = "tampered-owner-digest"
        require(
            inbox.ingest(userInfo: alteredOwnerRoute, source: .notificationResponse) == .queued,
            "altered owner fixture must be queued for negative validation"
        )
        require(
            inbox.consumeRoutesForCurrentAccount().isEmpty,
            "owner digest mismatch must reject before any UI route"
        )

        runtime.activeLease = leaseA
        let routeAForTeardown = makePayload(lease: leaseA, operation: "reply-teardown")
        let routeBForTeardown = makePayload(lease: leaseB, operation: "reply-b")
        require(
            inbox.ingest(userInfo: routeAForTeardown, source: .notificationResponse) == .queued,
            "account A teardown fixture must queue"
        )
        require(
            inbox.ingest(userInfo: routeBForTeardown, source: .notificationResponse) == .queued,
            "account B teardown fixture must queue"
        )
        require(
            inbox.teardownForAccountLifecycle(oldAccountLease: leaseA),
            "account lifecycle must clear pending routes for the captured old lease"
        )
        runtime.activeLease = leaseB
        let remainingRoutes = inbox.consumeRoutesForCurrentAccount()
        require(
            remainingRoutes.count == 1 && remainingRoutes[0].payload.operationIdentity
                == NotificationRuntimeRoutePayload.identityDigest(values: ["operation", "reply-b"]),
            "teardown must clear only the old lease's route and preserve another owner"
        )

        runtime.activeLease = leaseA
        let deepLinkURL = makeDeepLink(lease: leaseA, operation: "reply-deep-link")
        require(
            inbox.ingest(deepLinkURL: deepLinkURL) == .queued,
            "well-formed opaque deep link must queue"
        )
        let deepLinkRoutes = inbox.consumeRoutesForCurrentAccount()
        require(
            deepLinkRoutes.count == 1 && deepLinkRoutes[0].source == .deepLink,
            "deep link must still pass the same account lease validation"
        )
        require(
            inbox.ingest(deepLinkURL: URL(string: "dreamjourney://runtime-route?type=echoDelayedReply")!)
                == .rejected(.malformedPayload),
            "partial deep link must fail closed"
        )

        let snapshot = inbox.snapshot()
        require(snapshot.queuedCount == 0, "all routes must be consumed or rejected")
        require(snapshot.deliveredCount == 3, "only matching routes may be delivered")
        require(snapshot.rejectedCount >= 3, "cross-owner, stale, and tampered routes must be observable")

        print("PASS: notification runtime route owner-scope model")
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
            authorityEpoch: "route-authority-epoch"
        )
    }

    private static func makePayload(
        lease: AccountLease,
        operation: String
    ) -> [AnyHashable: Any] {
        [
            NotificationRuntimeRoutePayload.Key.schemaVersion: NSNumber(
                value: NotificationRuntimeRoutePayload.schemaVersion
            ),
            NotificationRuntimeRoutePayload.Key.action: NotificationRuntimeRouteAction.open.rawValue,
            NotificationRuntimeRoutePayload.Key.type: NotificationRuntimeRouteKind.echoDelayedReply.rawValue,
            NotificationRuntimeRoutePayload.Key.subjectIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["subject", lease.subjectId]
            ),
            NotificationRuntimeRoutePayload.Key.generation: NSNumber(value: lease.generation),
            NotificationRuntimeRoutePayload.Key.generationIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["generation-id", lease.generationId.uuidString]
            ),
            NotificationRuntimeRoutePayload.Key.vaultIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["vault", lease.vaultId]
            ),
            NotificationRuntimeRoutePayload.Key.authorityEpochIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["authority-epoch", lease.authorityEpoch]
            ),
            NotificationRuntimeRoutePayload.Key.resourceOwnerIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["resource-owner", lease.subjectId]
            ),
            NotificationRuntimeRoutePayload.Key.operationIdentity: NotificationRuntimeRoutePayload.identityDigest(
                values: ["operation", operation]
            ),
        ]
    }

    private static func makeDeepLink(lease: AccountLease, operation: String) -> URL {
        let payload = makePayload(lease: lease, operation: operation)
        var components = URLComponents()
        components.scheme = "dreamjourney"
        components.host = "runtime-route"
        components.queryItems = payload.compactMap { key, value in
            guard let key = key as? String else { return nil }
            return URLQueryItem(name: key, value: String(describing: value))
        }
        return components.url!
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
}
