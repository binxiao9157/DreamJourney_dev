#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

scheduler_file = ROOT / "DreamJourney/Sources/Services/TimeMailbox/TimeMailboxNotificationScheduler.swift"
vc_file = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
project_file = ROOT / "DreamJourney.xcodeproj/project.pbxproj"

missing = []

if not scheduler_file.exists():
    missing.append(f"{scheduler_file.name}: file is missing")
    scheduler_text = ""
else:
    scheduler_text = scheduler_file.read_text(encoding="utf-8")

vc_text = vc_file.read_text(encoding="utf-8")
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
]

required_vc_fragments = [
    "let letter = try repository.createLetter",
    "TimeMailboxNotificationScheduler.shared.scheduleDeliveryNotification",
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
for fragment in required_project_fragments:
    if fragment not in project_text:
        missing.append(f"{project_file.name}: missing {fragment!r}")

if missing:
    raise SystemExit("\n".join(missing))

print("TimeMailboxNotification verification passed")
