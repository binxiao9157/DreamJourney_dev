import CryptoKit
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

enum AppLifecycleEventNotification {
    static let eventKey = "event"
    static let sequenceKey = "sequence"
    static let runtimeDispositionKey = "runtimeDisposition"
    static let lifecycleGenerationKey = "lifecycleGeneration"

    static func userInfo(
        for receipt: AppLifecycleEventReceipt
    ) -> [AnyHashable: Any] {
        var userInfo: [AnyHashable: Any] = [
            eventKey: receipt.event.rawValue,
            sequenceKey: NSNumber(value: receipt.sequence),
            runtimeDispositionKey: receipt.runtimeDisposition.rawValue,
        ]
        if let lifecycleGeneration = receipt.lifecycleGeneration {
            userInfo[lifecycleGenerationKey] = NSNumber(value: lifecycleGeneration)
        }
        return userInfo
    }

    static func event(from userInfo: [AnyHashable: Any]?) -> AppLifecycleEvent? {
        guard let rawValue = userInfo?[eventKey] as? String else {
            return nil
        }
        return AppLifecycleEvent(rawValue: rawValue)
    }
}

extension Notification.Name {
    static let djAppLifecycleEventForwarded = Notification.Name(
        "dj.appLifecycle.eventForwarded"
    )
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

// MARK: - Notification and deeplink runtime routing

/// Notification and deeplink delivery is an untrusted ingress. It can select a
/// safe in-app destination only after its owner-scoped digest envelope matches
/// the currently active AccountLease. It never carries raw owner, vault, or
/// provider runtime values into the UI.
enum NotificationRuntimeRouteKind: String, Codable, CaseIterable, Sendable {
    case echoDelayedReply
    case timeLetter
    case familyInvitation
    case careSignal
    case systemNotice

    var selectedTabIndex: Int {
        switch self {
        case .echoDelayedReply:
            return 1
        case .timeLetter, .familyInvitation, .careSignal, .systemNotice:
            return 0
        }
    }
}

enum NotificationRuntimeRouteAction: String, Codable, Sendable {
    case open
    case markRead
    case archive
}

enum NotificationRuntimeRouteSource: String, Codable, Sendable {
    case notificationResponse
    case remoteNotification
    case deepLink
}

enum NotificationRuntimeRouteIngressResult: Equatable, Sendable {
    case queued
    case duplicate
    case rejected(NotificationRuntimeRouteRejectionReason)

    var shouldNotifyRouter: Bool {
        self == .queued
    }
}

enum NotificationRuntimeRouteRejectionReason: String, Codable, Equatable, Sendable {
    case malformedPayload
    case unsupportedSchema
    case noActiveLease
    case leaseInvalid
    case ownerMismatch
    case duplicate
}

/// Value-minimized route payload shared by local notifications, APNs and future
/// deeplinks. `operationIdentity` is an opaque digest rather than a raw
/// message/resource identifier, so the lock screen payload cannot become a
/// private data side channel.
struct NotificationRuntimeRoutePayload: Equatable, Sendable {
    static let schemaVersion = 1

    enum Key {
        static let schemaVersion = "runtimeRouteSchemaVersion"
        static let action = "runtimeRouteAction"
        static let type = "type"
        static let subjectIdentity = "accountSubjectIdentity"
        static let generation = "accountLeaseGeneration"
        static let generationIdentity = "accountLeaseGenerationIdentity"
        static let vaultIdentity = "accountLeaseVaultIdentity"
        static let authorityEpochIdentity = "accountLeaseAuthorityEpochIdentity"
        static let resourceOwnerIdentity = "resourceOwnerIdentity"
        static let operationIdentity = "operationIdentity"
    }

    let kind: NotificationRuntimeRouteKind
    let action: NotificationRuntimeRouteAction
    let subjectIdentity: String
    let generation: UInt64
    let generationIdentity: String
    let vaultIdentity: String
    let authorityEpochIdentity: String
    let resourceOwnerIdentity: String
    let operationIdentity: String

    init?(
        userInfo: [AnyHashable: Any]
    ) {
        guard let schemaVersion = Self.unsignedInteger(userInfo[Key.schemaVersion]),
              schemaVersion == UInt64(Self.schemaVersion) else {
            return nil
        }
        guard let rawKind = Self.nonEmptyString(userInfo[Key.type]),
              let kind = NotificationRuntimeRouteKind(rawValue: rawKind),
              let rawAction = Self.nonEmptyString(userInfo[Key.action]),
              let action = NotificationRuntimeRouteAction(rawValue: rawAction),
              let subjectIdentity = Self.nonEmptyString(userInfo[Key.subjectIdentity]),
              let generation = Self.unsignedInteger(userInfo[Key.generation]),
              let generationIdentity = Self.nonEmptyString(userInfo[Key.generationIdentity]),
              let vaultIdentity = Self.nonEmptyString(userInfo[Key.vaultIdentity]),
              let authorityEpochIdentity = Self.nonEmptyString(userInfo[Key.authorityEpochIdentity]),
              let resourceOwnerIdentity = Self.nonEmptyString(userInfo[Key.resourceOwnerIdentity]),
              let operationIdentity = Self.nonEmptyString(userInfo[Key.operationIdentity]) else {
            return nil
        }
        self.kind = kind
        self.action = action
        self.subjectIdentity = subjectIdentity
        self.generation = generation
        self.generationIdentity = generationIdentity
        self.vaultIdentity = vaultIdentity
        self.authorityEpochIdentity = authorityEpochIdentity
        self.resourceOwnerIdentity = resourceOwnerIdentity
        self.operationIdentity = operationIdentity
    }

    init?(deepLinkURL: URL) {
        guard deepLinkURL.scheme?.lowercased() == "dreamjourney",
              deepLinkURL.host?.lowercased() == "runtime-route",
              let components = URLComponents(url: deepLinkURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var userInfo: [AnyHashable: Any] = [:]
        components.queryItems?.forEach { item in
            if let value = item.value {
                userInfo[item.name] = value
            }
        }
        self.init(userInfo: userInfo)
    }

    func matches(_ accountLease: AccountLease) -> Bool {
        generation == accountLease.generation
            && subjectIdentity == Self.identityDigest(
                values: ["subject", accountLease.subjectId]
            )
            && generationIdentity == Self.identityDigest(
                values: ["generation-id", accountLease.generationId.uuidString]
            )
            && vaultIdentity == Self.identityDigest(
                values: ["vault", accountLease.vaultId]
            )
            && authorityEpochIdentity == Self.identityDigest(
                values: ["authority-epoch", accountLease.authorityEpoch]
            )
            // Cross-account and delegated routes require a separate server
            // authorization result. This local v1 router only permits the
            // current account's own opaque owner identity.
            && resourceOwnerIdentity == Self.identityDigest(
                values: ["resource-owner", accountLease.subjectId]
            )
    }

    var deduplicationIdentity: String {
        [
            kind.rawValue,
            action.rawValue,
            subjectIdentity,
            String(generation),
            generationIdentity,
            vaultIdentity,
            authorityEpochIdentity,
            resourceOwnerIdentity,
            operationIdentity,
        ].joined(separator: "|")
    }

    static func identityDigest(values: [String]) -> String {
        let canonicalIdentity = values
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
        return SHA256.hash(data: Data(canonicalIdentity.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func unsignedInteger(_ value: Any?) -> UInt64? {
        if let value = value as? NSNumber {
            let signedValue = value.int64Value
            return signedValue >= 0 ? UInt64(signedValue) : nil
        }
        if let value = nonEmptyString(value) {
            return UInt64(value)
        }
        return nil
    }
}

struct NotificationRuntimeRoute: Equatable, Sendable {
    let payload: NotificationRuntimeRoutePayload
    let source: NotificationRuntimeRouteSource
    let accountLease: AccountLease
}

struct NotificationRuntimeRouteInboxSnapshot: Equatable, Sendable {
    let queuedCount: Int
    let rejectedCount: Int
    let deliveredCount: Int
}

/// Keeps opaque ingress payloads in memory until the root coordinator has an
/// active lease. Routes are removed on a mismatch or account lifecycle teardown
/// and are never persisted across process launches.
final class NotificationRuntimeRouteInbox: @unchecked Sendable {
    static let shared = NotificationRuntimeRouteInbox()

    private struct PendingRoute: Equatable {
        let payload: NotificationRuntimeRoutePayload
        let source: NotificationRuntimeRouteSource
    }

    private let accountLeaseRuntime: AccountLeaseRuntimePort
    private let lock = NSLock()
    private var pendingRoutes: [PendingRoute] = []
    private var rejectedCount = 0
    private var deliveredCount = 0

    init(accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared) {
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    @discardableResult
    func ingest(
        userInfo: [AnyHashable: Any],
        source: NotificationRuntimeRouteSource
    ) -> NotificationRuntimeRouteIngressResult {
        guard let payload = NotificationRuntimeRoutePayload(userInfo: userInfo) else {
            recordRejected()
            return .rejected(.malformedPayload)
        }
        return enqueue(payload: payload, source: source)
    }

    @discardableResult
    func ingest(
        deepLinkURL: URL,
        source: NotificationRuntimeRouteSource = .deepLink
    ) -> NotificationRuntimeRouteIngressResult {
        guard let payload = NotificationRuntimeRoutePayload(deepLinkURL: deepLinkURL) else {
            recordRejected()
            return .rejected(.malformedPayload)
        }
        return enqueue(payload: payload, source: source)
    }

    func consumeRoutesForCurrentAccount() -> [NotificationRuntimeRoute] {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else {
            return []
        }
        return consumeRoutes(accountLease: accountLease)
    }

    func consumeRoutes(accountLease: AccountLease) -> [NotificationRuntimeRoute] {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              accountLeaseRuntime.validate(accountLease, at: .runtime).allowed,
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
            recordRejected()
            return []
        }

        lock.lock()
        let routes = pendingRoutes
        pendingRoutes.removeAll()
        lock.unlock()

        var accepted: [NotificationRuntimeRoute] = []
        var rejected = 0
        for pendingRoute in routes {
            guard pendingRoute.payload.matches(accountLease),
                  accountLeaseRuntime.validate(accountLease, at: .runtime).allowed,
                  accountLeaseRuntime.validate(accountLease, at: .ui).allowed else {
                rejected += 1
                continue
            }
            accepted.append(
                NotificationRuntimeRoute(
                    payload: pendingRoute.payload,
                    source: pendingRoute.source,
                    accountLease: accountLease
                )
            )
        }

        lock.lock()
        rejectedCount += rejected
        deliveredCount += accepted.count
        lock.unlock()
        return accepted
    }

    func canPresent(userInfo: [AnyHashable: Any]) -> Bool {
        guard let payload = NotificationRuntimeRoutePayload(userInfo: userInfo),
              let accountLease = accountLeaseRuntime.capture(forSubjectId: nil),
              accountLeaseRuntime.validate(accountLease, at: .ui).allowed,
              payload.matches(accountLease) else {
            return false
        }
        return true
    }

    @discardableResult
    func teardownForAccountLifecycle(oldAccountLease: AccountLease?) -> Bool {
        guard let oldAccountLease else { return false }
        lock.lock()
        pendingRoutes.removeAll { $0.payload.matches(oldAccountLease) }
        lock.unlock()
        return true
    }

    func snapshot() -> NotificationRuntimeRouteInboxSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return NotificationRuntimeRouteInboxSnapshot(
            queuedCount: pendingRoutes.count,
            rejectedCount: rejectedCount,
            deliveredCount: deliveredCount
        )
    }

    private func enqueue(
        payload: NotificationRuntimeRoutePayload,
        source: NotificationRuntimeRouteSource
    ) -> NotificationRuntimeRouteIngressResult {
        let pendingRoute = PendingRoute(payload: payload, source: source)
        lock.lock()
        defer { lock.unlock() }
        guard !pendingRoutes.contains(pendingRoute) else {
            return .duplicate
        }
        pendingRoutes.append(pendingRoute)
        return .queued
    }

    private func recordRejected() {
        lock.lock()
        rejectedCount += 1
        lock.unlock()
    }
}

extension Notification.Name {
    static let djNotificationRuntimeRouteQueued = Notification.Name(
        "dj.notificationRuntime.routeQueued"
    )
}
