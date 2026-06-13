#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
USER_MANAGER = ROOT / "DreamJourney/Sources/Services/UserManager.swift"
PHASE1 = ROOT / "Scripts/verify_phase1.sh"


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"UserIdentityStability verification failed: {message}", file=sys.stderr)
        sys.exit(1)


source = USER_MANAGER.read_text(encoding="utf-8")
phase1 = PHASE1.read_text(encoding="utf-8")
login_match = re.search(r"func login\(phone: String, nickname: String\) \{[\s\S]*?\n    \}", source)
login_body = login_match.group(0) if login_match else ""
legacy_match = re.search(r"private static func isLegacyRoadshowUser\(_ user: UserModel\) -> Bool \{[\s\S]*?\n    \}", source)
legacy_body = legacy_match.group(0) if legacy_match else ""

require(
    "stableUserID(for: phone)" in login_body,
    "login should derive backend/local user id from a stable full-phone hash helper",
)
require(
    "phone.suffix(4)" not in login_body and "user_\\(phone.suffix(4))" not in source,
    "login must not use the last four phone digits as user id",
)
require(
    "private static func stableUserID(for phone: String) -> String" in source,
    "UserManager should expose a stable deterministic user id helper",
)
require(
    "normalizedPhoneDigits" in source and "fnvPrime" in source and "offsetBasis" in source,
    "stable user id should normalize the whole phone and use a deterministic local hash",
)
require(
    'user.id == "user_0001"' not in legacy_body,
    "legacy roadshow cleanup must not delete a real user only because their old id is user_0001",
)
require(
    'user.nickname == "路演家庭"' in legacy_body and 'user.phone == "18800000001"' in legacy_body,
    "legacy roadshow cleanup should still remove the known demo account by nickname/phone",
)
require(
    "UserIdentityStabilityVerify/main.py" in phase1,
    "phase1 verification should cover stable real-test user identity",
)

print("UserIdentityStability verification passed")
