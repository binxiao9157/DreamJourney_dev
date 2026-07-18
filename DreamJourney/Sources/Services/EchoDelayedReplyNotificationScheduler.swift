import Foundation
import UserNotifications

protocol EchoDelayedReplyNotificationRequestCenter: AnyObject, Sendable {
    func add(
        _ request: UNNotificationRequest,
        withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?
    )
    func getPendingNotificationRequests(
        completionHandler: @escaping @Sendable ([UNNotificationRequest]) -> Void
    )
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
}

extension UNUserNotificationCenter: EchoDelayedReplyNotificationRequestCenter {}

final class EchoDelayedReplyNotificationScheduler: @unchecked Sendable {
    static let shared = EchoDelayedReplyNotificationScheduler()
    static let notificationIdentifier = "dj.echo.delayedReply"

    private static let authorizationOperationId = "notification-authorization"

    private let center: UNUserNotificationCenter?
    private let requestCenter: EchoDelayedReplyNotificationRequestCenter
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    init(
        center: UNUserNotificationCenter = .current(),
        requestCenter: EchoDelayedReplyNotificationRequestCenter? = nil,
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.center = center
        self.requestCenter = requestCenter ?? center
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    init(
        requestCenter: EchoDelayedReplyNotificationRequestCenter,
        accountLeaseRuntime: AccountLeaseRuntimePort
    ) {
        center = nil
        self.requestCenter = requestCenter
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    static func notificationIdentifier(
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease
    ) -> String? {
        EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        )?.notificationIdentifier
    }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        requestAuthorizationIfNeeded(
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.authorizationOperationId,
            accountLease: accountLease,
            completion: completion
        )
    }

    func requestAuthorizationIfNeeded(
        accountLease: AccountLease,
        completion: @escaping (Bool) -> Void
    ) {
        requestAuthorizationIfNeeded(
            resourceOwnerId: accountLease.subjectId,
            operationId: Self.authorizationOperationId,
            accountLease: accountLease,
            completion: completion
        )
    }

    func requestAuthorizationIfNeeded(
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease,
        completion: @escaping (Bool) -> Void
    ) {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ), accountLeaseRuntime.validate(accountLease, at: .request).allowed,
           let center else {
            return
        }
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  self.accountLeaseRuntime.validate(scope.accountLease, at: .timer).allowed,
                  self.accountLeaseRuntime.validate(scope.accountLease, at: .runtime).allowed else {
                return
            }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.completeAuthorization(true, scope: scope, completion: completion)
            case .denied:
                self.completeAuthorization(false, scope: scope, completion: completion)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                    guard let self,
                          self.accountLeaseRuntime.validate(scope.accountLease, at: .timer).allowed,
                          self.accountLeaseRuntime.validate(scope.accountLease, at: .runtime).allowed else {
                        return
                    }
                    self.completeAuthorization(granted, scope: scope, completion: completion)
                }
            @unknown default:
                self.completeAuthorization(false, scope: scope, completion: completion)
            }
        }
    }

    func schedule(_ delayedReply: EchoDelayedReply, completion: ((Error?) -> Void)? = nil) {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        schedule(
            delayedReply,
            resourceOwnerId: accountLease.subjectId,
            operationId: delayedReply.id,
            accountLease: accountLease,
            completion: completion
        )
    }

    func schedule(
        _ delayedReply: EchoDelayedReply,
        accountLease: AccountLease,
        completion: ((Error?) -> Void)? = nil
    ) {
        schedule(
            delayedReply,
            resourceOwnerId: accountLease.subjectId,
            operationId: delayedReply.id,
            accountLease: accountLease,
            completion: completion
        )
    }

    func schedule(
        _ delayedReply: EchoDelayedReply,
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ), accountLeaseRuntime.validate(accountLease, at: .request).allowed,
           accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
            return
        }
        let request = makeRequest(for: delayedReply, scope: scope)

        removeRequestsOwned(
            accountLease: scope.accountLease,
            resourceOwnerId: scope.resourceOwnerId,
            operationId: nil
        ) { [weak self] in
            guard let self,
                  self.accountLeaseRuntime.validate(scope.accountLease, at: .timer).allowed,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            self.requestCenter.add(request) { [weak self] error in
                guard let self else { return }
                guard self.accountLeaseRuntime.validate(scope.accountLease, at: .timer).allowed,
                      self.accountLeaseRuntime.validate(scope.accountLease, at: .runtime).allowed else {
                    self.removeStaleRequestIfOwned(scope: scope)
                    return
                }
                guard self.accountLeaseRuntime.validate(scope.accountLease, at: .ui).allowed else {
                    return
                }
                completion?(error)
            }
        }
    }

    func cancelPendingDelayedReply() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        cancelPendingDelayedReply(accountLease: accountLease)
    }

    func cancelPendingDelayedReply(accountLease: AccountLease) {
        removeRequestsOwned(
            accountLease: accountLease,
            resourceOwnerId: accountLease.subjectId,
            operationId: nil
        )
    }

    func cancelPendingDelayedReply(
        resourceOwnerId: String,
        operationId: String,
        accountLease: AccountLease
    ) {
        guard let scope = EchoDelayedReplyOperationScope(
            accountLease: accountLease,
            resourceOwnerId: resourceOwnerId,
            operationId: operationId
        ) else {
            return
        }
        removeRequestsOwned(
            accountLease: scope.accountLease,
            resourceOwnerId: scope.resourceOwnerId,
            operationId: operationId
        )
    }

    private func makeRequest(
        for delayedReply: EchoDelayedReply,
        scope: EchoDelayedReplyOperationScope
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "回响来信"
        content.body = "回信到了，回来听听这段回响。"
        content.sound = .default
        content.userInfo = [
            "type": "echoDelayedReply",
            "delayedReplyId": delayedReply.id,
            "trigger": delayedReply.trigger.rawValue,
            "accountSubjectIdentity": scope.subjectIdentity,
            "accountLeaseGeneration": NSNumber(value: scope.accountLease.generation),
            "accountLeaseGenerationId": scope.accountLease.generationId.uuidString,
            "accountLeaseVaultIdentity": scope.vaultIdentity,
            "accountLeaseAuthorityEpochIdentity": scope.authorityEpochIdentity,
            "resourceOwnerIdentity": scope.resourceOwnerIdentity,
            "operationIdentity": scope.operationIdentity,
        ]

        let interval = max(delayedReply.deliverAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return UNNotificationRequest(
            identifier: scope.notificationIdentifier,
            content: content,
            trigger: trigger
        )
    }

    private func completeAuthorization(
        _ granted: Bool,
        scope: EchoDelayedReplyOperationScope,
        completion: @escaping (Bool) -> Void
    ) {
        guard accountLeaseRuntime.validate(scope.accountLease, at: .ui).allowed else { return }
        completion(granted)
    }

    private func removeStaleRequestIfOwned(scope: EchoDelayedReplyOperationScope) {
        requestCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self,
                  let request = requests.first(where: { request in
                      request.identifier == scope.notificationIdentifier
                  }),
                  self.requestIsOwned(request, by: scope) else {
                return
            }
            self.requestCenter.removePendingNotificationRequests(
                withIdentifiers: [scope.notificationIdentifier]
            )
        }
    }

    private func removeRequestsOwned(
        accountLease: AccountLease,
        resourceOwnerId: String,
        operationId: String?,
        completion: (() -> Void)? = nil
    ) {
        let operationScope = operationId.flatMap {
            EchoDelayedReplyOperationScope(
                accountLease: accountLease,
                resourceOwnerId: resourceOwnerId,
                operationId: $0
            )
        }
        guard operationId == nil || operationScope != nil,
              let ownerScope = EchoDelayedReplyOperationScope(
                  accountLease: accountLease,
                  resourceOwnerId: resourceOwnerId,
                  operationId: operationId ?? "owner-request-enumeration"
              ) else {
            completion?()
            return
        }

        requestCenter.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let identifiers = requests.compactMap { request -> String? in
                if let operationScope {
                    return self.requestIsOwned(request, by: operationScope)
                        ? request.identifier
                        : nil
                }
                return self.requestIsOwned(
                    request,
                    by: ownerScope.accountLease,
                    resourceOwnerIdentity: ownerScope.resourceOwnerIdentity
                ) ? request.identifier : nil
            }
            if !identifiers.isEmpty {
                self.requestCenter.removePendingNotificationRequests(
                    withIdentifiers: identifiers
                )
            }
            completion?()
        }
    }

    private func requestIsOwned(
        _ request: UNNotificationRequest,
        by scope: EchoDelayedReplyOperationScope
    ) -> Bool {
        request.identifier == scope.notificationIdentifier
            && requestIsOwned(
                request,
                by: scope.accountLease,
                resourceOwnerIdentity: scope.resourceOwnerIdentity
            )
            && request.content.userInfo["operationIdentity"] as? String
                == scope.operationIdentity
    }

    private func requestIsOwned(
        _ request: UNNotificationRequest,
        by accountLease: AccountLease,
        resourceOwnerIdentity: String
    ) -> Bool {
        let userInfo = request.content.userInfo
        return userInfo["accountSubjectIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["subject", accountLease.subjectId]
                )
            && userInfo["accountLeaseVaultIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["vault", accountLease.vaultId]
                )
            && (userInfo["accountLeaseGeneration"] as? NSNumber)?.uint64Value
                == accountLease.generation
            && userInfo["accountLeaseGenerationId"] as? String
                == accountLease.generationId.uuidString
            && userInfo["accountLeaseAuthorityEpochIdentity"] as? String
                == EchoDelayedReplyOperationScope.identityDigest(
                    values: ["authority-epoch", accountLease.authorityEpoch]
                )
            && userInfo["resourceOwnerIdentity"] as? String == resourceOwnerIdentity
    }
}
