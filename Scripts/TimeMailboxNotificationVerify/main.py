#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

scheduler_file = ROOT / "DreamJourney/Sources/Services/TimeMailbox/TimeMailboxNotificationScheduler.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
app_delegate_file = ROOT / "DreamJourney/Sources/AppDelegate.swift"
scene_delegate_file = ROOT / "DreamJourney/Sources/SceneDelegate.swift"
tab_coordinator_file = ROOT / "DreamJourney/Sources/App/TabCoordinator.swift"
project_file = ROOT / "DreamJourney.xcodeproj/project.pbxproj"

missing = []

if not scheduler_file.exists():
    missing.append(f"{scheduler_file.name}: file is missing")
    scheduler_text = ""
else:
    scheduler_text = scheduler_file.read_text(encoding="utf-8")

vc_text = vc_file.read_text(encoding="utf-8")
app_delegate_text = app_delegate_file.read_text(encoding="utf-8")
scene_delegate_text = scene_delegate_file.read_text(encoding="utf-8")
tab_coordinator_text = tab_coordinator_file.read_text(encoding="utf-8")
project_text = project_file.read_text(encoding="utf-8")

required_scheduler_fragments = [
    "import UserNotifications",
    "final class TimeMailboxNotificationScheduler",
    "static let shared",
    "func scheduleDeliveryNotification",
    "func cancelDeliveryNotification",
    "UNUserNotificationCenter.current()",
    "requestAuthorization",
    "UNCalendarNotificationTrigger",
    "TimeMailboxDeliveryStatus.sealed",
    "content.userInfo",
]

required_vc_fragments = [
    "let letter = try repository.createLetter",
    "TimeMailboxNotificationScheduler.shared.scheduleDeliveryNotification",
    "func refreshForNotificationDelivery()",
    "func openLetterFromNotification(id letterID: String?)",
    "reloadLetters(showDeliveryToast: true)",
    "presentReader(for: letter)",
]

required_app_delegate_fragments = [
    "import UserNotifications",
    "UNUserNotificationCenter.current().delegate = self",
    "extension AppDelegate: UNUserNotificationCenterDelegate",
    "func userNotificationCenter(",
    "didReceive response: UNNotificationResponse",
    "TimeMailboxNotificationScheduler.isDeliveryNotification(userInfo: response.notification.request.content.userInfo)",
    "NotificationCenter.default.post(",
    "name: .djTimeMailboxDeliveryNotificationReceived",
]

required_tab_coordinator_fragments = [
    "private var timeMailboxNotificationObserver: NSObjectProtocol?",
    "forName: .djTimeMailboxDeliveryNotificationReceived",
    "notification in",
    "notification.object as? String",
    "openTimeMailboxFromNotification(letterID:",
    "tabBarController.selectedIndex = 3",
    "openLetterFromNotification(id: letterID)",
]

required_scene_delegate_fragments = [
    "connectionOptions.notificationResponse",
    "TimeMailboxNotificationScheduler.isDeliveryNotification(userInfo: notificationResponse.notification.request.content.userInfo)",
    "NotificationCenter.default.post(",
    "name: .djTimeMailboxDeliveryNotificationReceived",
]

required_project_fragments = [
    "TimeMailboxNotificationScheduler.swift",
    "TimeMailboxNotificationScheduler.swift in Sources",
]

for fragment in required_scheduler_fragments:
    if fragment not in scheduler_text:
        missing.append(f"{scheduler_file.name}: missing {fragment!r}")
for fragment in required_vc_fragments:
    if fragment not in vc_text:
        missing.append(f"{vc_file.name}: missing {fragment!r}")
for fragment in required_app_delegate_fragments:
    if fragment not in app_delegate_text:
        missing.append(f"{app_delegate_file.name}: missing {fragment!r}")
for fragment in required_tab_coordinator_fragments:
    if fragment not in tab_coordinator_text:
        missing.append(f"{tab_coordinator_file.name}: missing {fragment!r}")
for fragment in required_scene_delegate_fragments:
    if fragment not in scene_delegate_text:
        missing.append(f"{scene_delegate_file.name}: missing {fragment!r}")
for fragment in required_project_fragments:
    if fragment not in project_text:
        missing.append(f"{project_file.name}: missing {fragment!r}")

if "content.body = \"你写给\\(letter.recipientName)的信已到达。打开时空信箱查看回声边界说明。\"" in scheduler_text:
    missing.append(f"{scheduler_file.name}: notification body should not expose recipientName on lock screen")
if "recipientName" in scheduler_text.split("private func addDeliveryRequest", 1)[-1].split("private func notificationIdentifier", 1)[0]:
    missing.append(f"{scheduler_file.name}: delivery notification request should keep recipientName out of visible/userInfo payload")

if missing:
    raise SystemExit("\n".join(missing))

print("TimeMailboxNotification verification passed")
