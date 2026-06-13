#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
VIEW = ROOT / "DreamJourney/Sources/Modules/TimeMailbox/TimeMailboxViewController.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"TimeMailboxAutoDeliveryRefresh verification failed: {message}", file=sys.stderr)
        sys.exit(1)


view = VIEW.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")

reload_match = re.search(r"private func reloadLetters\([\s\S]*?\n    \}", view)
schedule_match = re.search(r"private func scheduleNextDeliveryRefresh\([\s\S]*?\n    \}", view)
timer_match = re.search(r"deliveryRefreshTimer\s*=\s*Timer\.scheduledTimer[\s\S]*?\n        \}", view)

require("private var deliveryRefreshTimer: Timer?" in view, "mailbox should keep a delivery refresh timer")
require("deinit" in view and "deliveryRefreshTimer?.invalidate()" in view, "mailbox should invalidate the timer")
require(reload_match is not None, "reloadLetters should exist")
require(schedule_match is not None, "scheduleNextDeliveryRefresh should exist")
require(timer_match is not None, "timer should be scheduled for the next sealed letter")

reload_body = reload_match.group(0)
schedule_body = schedule_match.group(0)
timer_body = timer_match.group(0)

require(
    "showDeliveryToast" in reload_body and "有信已到达" in reload_body,
    "automatic refresh should surface that a letter arrived while the page is open",
)
require(
    "scheduleNextDeliveryRefresh()" in reload_body,
    "reload should reschedule after every delivery refresh",
)
require(
    "letters.filter { $0.status == .sealed }" in schedule_body and ".map(\\.deliverAt).min()" in schedule_body,
    "timer should target the nearest sealed delivery time",
)
require(
    "max(1" in schedule_body and "timeIntervalSinceNow" in schedule_body,
    "timer should handle near-due letters without immediate tight loops",
)
require(
    "self?.reloadLetters(showDeliveryToast: true)" in timer_body,
    "timer should refresh delivery state with user-visible arrival feedback",
)
require(
    "TimeMailboxAutoDeliveryRefreshVerify/main.py" in phase1,
    "phase1 verification should include automatic mailbox delivery refresh coverage",
)

print("TimeMailboxAutoDeliveryRefresh verification passed")
