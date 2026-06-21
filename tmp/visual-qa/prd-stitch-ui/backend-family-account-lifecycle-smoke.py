#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional


if len(sys.argv) < 4:
    raise SystemExit("Usage: backend-family-account-lifecycle-smoke.py <app-root> <phone> <marker>")

APP_ROOT = Path(sys.argv[1])
BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
PHONE = re.sub(r"\D", "", sys.argv[2])
MARKER = re.sub(r"[^A-Za-z0-9_-]", "_", sys.argv[3])

if not BASE_URL:
    raise SystemExit("BACKEND_BASE_URL is required")
if not API_TOKEN:
    raise SystemExit("BACKEND_API_TOKEN is required")
if len(PHONE) < 11:
    raise SystemExit("phone must contain at least 11 digits")


def request_json(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    expected: int = 200,
    timeout: int = 45,
) -> Dict[str, Any]:
    data = None
    headers = {"Accept": "application/json"}
    if auth:
        headers["Authorization"] = f"Bearer {API_TOKEN}"
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(f"{BASE_URL}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
            status = response.status
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        if error.code == expected:
            return json.loads(body) if body else {}
        raise AssertionError(f"{method} {path} expected {expected}, got {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body}")
    return json.loads(body) if body else {}


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def assert_true(value: Any, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> None:
    health = request_json("GET", "/health", auth=False)
    assert_equal(health.get("status"), "ok", "health")

    login = request_json(
        "POST",
        "/auth/login",
        {"phone": PHONE, "nickname": f"账号注销验收{MARKER}"},
    )
    user = login.get("user") or {}
    user_id = user.get("id")
    assert_true(user_id, "login should return user.id")

    invite_phone = f"139{abs(hash(MARKER)) % 100000000:08d}"[-11:]
    invited = request_json(
        "POST",
        "/family/invite",
        {
            "userId": user_id,
            "name": "陈岚",
            "relation": "女儿",
            "phone": invite_phone,
        },
    )
    member = invited.get("member") or {}
    member_id = member.get("id")
    assert_true(member_id, "family invite should return member.id")
    assert_equal(member.get("invitationStatus"), "pending", "family invite pending")
    assert_equal(member.get("accessStatus"), "pending", "family access pending")

    revoke = request_json(
        "POST",
        f"/family/members/{urllib.parse.quote(user_id)}/{urllib.parse.quote(member_id)}/revoke",
        expected=409,
    )
    assert_equal(revoke.get("detail"), "family member removal is not supported", "family revoke blocked")

    accepted = request_json(
        "POST",
        f"/family/members/{urllib.parse.quote(user_id)}/{urllib.parse.quote(member_id)}/accept",
        {"phone": invite_phone},
    )
    assert_equal((accepted.get("member") or {}).get("invitationStatus"), "accepted", "family accepted")

    missing_confirm = request_json(
        "POST",
        "/auth/delete",
        {"userId": user_id, "phone": PHONE, "firstConfirmation": True},
        expected=400,
    )
    assert_equal(missing_confirm.get("detail"), "two deletion confirmations are required", "delete needs two confirmations")

    deleted = request_json(
        "POST",
        "/auth/delete",
        {
            "userId": user_id,
            "phone": PHONE,
            "firstConfirmation": True,
            "secondConfirmation": True,
        },
    )
    deletion = deleted.get("deletion") or {}
    assert_equal(deleted.get("status"), "softDeleted", "delete status")
    assert_equal(deletion.get("deletionState"), "softDeleted", "soft delete state")
    assert_equal(deletion.get("retentionDays"), 30, "retention days")
    assert_equal(deletion.get("dataExportSupported"), False, "no data export")
    assert_true(deletion.get("restoreDeadline"), "restoreDeadline")

    restored = request_json("POST", "/auth/login", {"phone": PHONE, "nickname": "恢复账号"})
    assert_equal(restored.get("status"), "restored", "same-phone login restores")
    assert_equal((restored.get("user") or {}).get("restoreCount"), 1, "restoreCount")

    deleted_again = request_json(
        "POST",
        "/auth/delete",
        {
            "userId": user_id,
            "phone": PHONE,
            "firstConfirmation": True,
            "secondConfirmation": True,
        },
    )
    assert_equal(deleted_again.get("status"), "softDeleted", "second delete allowed")
    second_restore = request_json("POST", "/auth/restore", {"phone": PHONE}, expected=410)
    assert_equal(second_restore.get("detail"), "account restore chance already used", "restore only once")

    result = {
        "completed": True,
        "baseURL": BASE_URL,
        "token": "configured, value intentionally omitted",
        "health": health,
        "userId": user_id,
        "familyInvite": {
            "memberId": member_id,
            "initialStatus": member.get("invitationStatus"),
            "revokeBlocked": revoke.get("detail"),
            "acceptedStatus": (accepted.get("member") or {}).get("invitationStatus"),
        },
        "accountDeletion": {
            "missingSecondConfirmation": missing_confirm.get("detail"),
            "deletedAt": deletion.get("deletedAt"),
            "restoreDeadline": deletion.get("restoreDeadline"),
            "retentionDays": deletion.get("retentionDays"),
            "dataExportSupported": deletion.get("dataExportSupported"),
            "samePhoneRestoreStatus": restored.get("status"),
            "secondRestoreRejected": second_restore.get("detail"),
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
