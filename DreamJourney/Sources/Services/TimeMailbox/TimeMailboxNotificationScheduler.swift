import Foundation
import UserNotifications

final class TimeMailboxNotificationScheduler {
    static let shared = TimeMailboxNotificationScheduler()
    static let deliverySurface = "timeMailbox"
    static let deliverySurfaceUserInfoKey = "surface"
    static let deliveryLetterIDUserInfoKey = "letterID"

    private init() {}

    static func isDeliveryNotification(userInfo: [AnyHashable: Any]) -> Bool {
        userInfo[deliverySurfaceUserInfoKey] as? String == deliverySurface
    }

    func scheduleDeliveryNotification(for letter: TimeMailboxLetter, now: Date = Date()) {
        guard letter.status == TimeMailboxDeliveryStatus.sealed, letter.deliverAt > now else {
            cancelDeliveryNotification(for: letter.id)
            return
        }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            if let error {
                print("[TimeMailboxNotification] authorization failed: \(error.localizedDescription)")
                return
            }
            guard granted else {
                print("[TimeMailboxNotification] authorization denied")
                return
            }
            self?.addDeliveryRequest(for: letter, center: center)
        }
    }

    func cancelDeliveryNotification(for letterID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: letterID)]
        )
    }

    private func addDeliveryRequest(for letter: TimeMailboxLetter, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "时空信箱有一封信到达"
        content.body = "一封封存的信已到达。打开时空信箱查看回声边界说明。"
        content.sound = .default
        content.userInfo = [
            Self.deliverySurfaceUserInfoKey: Self.deliverySurface,
            Self.deliveryLetterIDUserInfoKey: letter.id
        ]

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: letter.deliverAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: letter.id),
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error {
                print("[TimeMailboxNotification] schedule failed: \(error.localizedDescription)")
            }
        }
    }

    private func notificationIdentifier(for letterID: String) -> String {
        "dreamjourney.timeMailbox.delivery.\(letterID)"
    }
}

extension Notification.Name {
    static let djTimeMailboxDeliveryNotificationReceived = Notification.Name("dj.timeMailbox.delivery.notification.received")
}
