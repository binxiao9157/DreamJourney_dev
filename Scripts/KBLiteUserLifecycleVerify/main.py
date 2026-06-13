#!/usr/bin/env python3
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[2]
manager = (root / "DreamJourney/Sources/Services/KBLiteManager.swift").read_text()
user_manager = (root / "DreamJourney/Sources/Services/UserManager.swift").read_text()
phase1 = (root / "Scripts/verify_phase1.sh").read_text()

login_body = re.search(r"func login\(phone: String, nickname: String\) \{([\s\S]*?)\n    \}", user_manager)
logout_body = re.search(r"func logout\(\) \{([\s\S]*?)\n    \}", user_manager)

checks = [
    (
        "KBLite should expose explicit user graph reload",
        "func reloadForCurrentUser" in manager and "load()" in re.search(
            r"func reloadForCurrentUser[\s\S]*?\n    \}",
            manager,
        ).group(0),
    ),
    (
        "KBLite should expose logged-out graph clearing",
        "func clearForLoggedOutUser" in manager and "graph = KBLiteGraph()" in manager,
    ),
    (
        "KBLite user reload should reset backend bootstrap user state",
        "didAttemptBackendBootstrapForUserId = nil" in manager,
    ),
    (
        "login should reload KBLite for the authenticated user before notification",
        bool(login_body)
        and "KBLiteManager.shared.reloadForCurrentUser" in login_body.group(1)
        and login_body.group(1).find("KBLiteManager.shared.reloadForCurrentUser") < login_body.group(1).find("NotificationCenter.default.post"),
    ),
    (
        "logout should clear KBLite in-memory graph before notification",
        bool(logout_body)
        and "KBLiteManager.shared.clearForLoggedOutUser" in logout_body.group(1)
        and logout_body.group(1).find("KBLiteManager.shared.clearForLoggedOutUser") < logout_body.group(1).find("NotificationCenter.default.post"),
    ),
    (
        "phase1 verification should cover KBLite user lifecycle",
        "KBLiteUserLifecycleVerify" in phase1,
    ),
]

failed = [message for message, passed in checks if not passed]
if failed:
    for message in failed:
        print(f"KBLiteUserLifecycle verification failed: {message}", file=sys.stderr)
    sys.exit(1)

print("KBLiteUserLifecycle verification passed")
