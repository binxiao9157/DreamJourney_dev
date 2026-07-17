import Foundation
import UserNotifications

final class EchoDelayedReplyNotificationScheduler {
    static let shared = EchoDelayedReplyNotificationScheduler()
    static let notificationIdentifier = "dj.echo.delayedReply"

    private let center: UNUserNotificationCenter
    private let accountLeaseRuntime: AccountLeaseRuntimePort

    init(
        center: UNUserNotificationCenter = .current(),
        accountLeaseRuntime: AccountLeaseRuntimePort = AccountLeaseRuntime.shared
    ) {
        self.center = center
        self.accountLeaseRuntime = accountLeaseRuntime
    }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        requestAuthorizationIfNeeded(accountLease: accountLease, completion: completion)
    }

    func requestAuthorizationIfNeeded(
        accountLease: AccountLease,
        completion: @escaping (Bool) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed else { return }
        center.getNotificationSettings { [weak self] settings in
            guard let self,
                  self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed,
                  self.accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else {
                return
            }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.completeAuthorization(
                    true,
                    accountLease: accountLease,
                    completion: completion
                )
            case .denied:
                self.completeAuthorization(
                    false,
                    accountLease: accountLease,
                    completion: completion
                )
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                    guard let self,
                          self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
                        return
                    }
                    self.completeAuthorization(
                        granted,
                        accountLease: accountLease,
                        completion: completion
                    )
                }
            @unknown default:
                self.completeAuthorization(
                    false,
                    accountLease: accountLease,
                    completion: completion
                )
            }
        }
    }

    func schedule(_ delayedReply: EchoDelayedReply, completion: ((Error?) -> Void)? = nil) {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        schedule(delayedReply, accountLease: accountLease, completion: completion)
    }

    func schedule(
        _ delayedReply: EchoDelayedReply,
        accountLease: AccountLease,
        completion: ((Error?) -> Void)? = nil
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .request).allowed,
              accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
            return
        }
        cancelPendingDelayedReply(accountLease: accountLease)

        let content = UNMutableNotificationContent()
        content.title = "回响来信"
        content.body = "回信到了，回来听听这段回响。"
        content.sound = .default
        content.userInfo = [
            "type": "echoDelayedReply",
            "delayedReplyId": delayedReply.id,
            "trigger": delayedReply.trigger.rawValue,
            "accountLeaseGenerationId": accountLease.generationId.uuidString,
        ]

        let interval = max(delayedReply.deliverAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        guard accountLeaseRuntime.validate(accountLease, at: .runtime).allowed else { return }
        center.add(request) { [weak self] error in
            guard let self else { return }
            guard self.accountLeaseRuntime.validate(accountLease, at: .timer).allowed else {
                self.removeStaleRequestIfOwned(
                    delayedReplyId: delayedReply.id,
                    generationId: accountLease.generationId
                )
                return
            }
            guard self.accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
            completion?(error)
        }
    }

    func cancelPendingDelayedReply() {
        guard let accountLease = accountLeaseRuntime.capture(forSubjectId: nil) else { return }
        cancelPendingDelayedReply(accountLease: accountLease)
    }

    func cancelPendingDelayedReply(accountLease: AccountLease) {
        guard accountLeaseRuntime.validate(accountLease, at: .timer).allowed else { return }
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }

    private func completeAuthorization(
        _ granted: Bool,
        accountLease: AccountLease,
        completion: @escaping (Bool) -> Void
    ) {
        guard accountLeaseRuntime.validate(accountLease, at: .ui).allowed else { return }
        completion(granted)
    }

    private func removeStaleRequestIfOwned(delayedReplyId: String, generationId: UUID) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self,
                  let pendingRequest = requests.first(where: {
                      $0.identifier == Self.notificationIdentifier
                  }),
                  pendingRequest.content.userInfo["delayedReplyId"] as? String == delayedReplyId,
                  pendingRequest.content.userInfo["accountLeaseGenerationId"] as? String
                    == generationId.uuidString else {
                return
            }
            self.center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        }
    }
}
