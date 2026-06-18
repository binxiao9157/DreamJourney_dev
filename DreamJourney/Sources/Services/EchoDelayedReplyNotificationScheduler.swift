import Foundation
import UserNotifications

final class EchoDelayedReplyNotificationScheduler {
    static let shared = EchoDelayedReplyNotificationScheduler()
    static let notificationIdentifier = "dj.echo.delayedReply"

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                completion(true)
            case .denied:
                completion(false)
            case .notDetermined:
                self?.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    completion(granted)
                }
            @unknown default:
                completion(false)
            }
        }
    }

    func schedule(_ delayedReply: EchoDelayedReply, completion: ((Error?) -> Void)? = nil) {
        cancelPendingDelayedReply()

        let content = UNMutableNotificationContent()
        content.title = "回响来信"
        content.body = "回信到了，回来听听这段回响。"
        content.sound = .default
        content.userInfo = [
            "type": "echoDelayedReply",
            "delayedReplyId": delayedReply.id,
            "trigger": delayedReply.trigger.rawValue,
        ]

        let interval = max(delayedReply.deliverAt.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            completion?(error)
        }
    }

    func cancelPendingDelayedReply() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
}
