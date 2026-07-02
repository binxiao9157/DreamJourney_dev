#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


if len(sys.argv) < 4:
    raise SystemExit("Usage: backend-time-letter-lifecycle-smoke.py <app-root> <user-id> <marker>")

APP_ROOT = Path(sys.argv[1])
BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
USER_ID = sys.argv[2]
MARKER = re.sub(r"[^A-Za-z0-9_-]", "_", sys.argv[3])

if not BASE_URL:
    raise SystemExit("BACKEND_BASE_URL is required")
if not API_TOKEN:
    raise SystemExit("BACKEND_API_TOKEN is required")


def request_json(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    expected: int = 200,
    timeout: int = 45,
) -> Dict[str, Any]:
    url = f"{BASE_URL}{path}"
    data = None
    headers = {"Accept": "application/json"}
    if auth:
        headers["Authorization"] = f"Bearer {API_TOKEN}"
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"

    request = urllib.request.Request(url, data=data, headers=headers, method=method)
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


def assert_not_in(key: str, obj: Dict[str, Any], message: str) -> None:
    if key in obj:
        raise AssertionError(f"{message}: unexpected key {key!r} in {obj!r}")


def stable_user_id(phone: str) -> str:
    source = "".join(ch for ch in str(phone or "") if ch.isdigit()) or str(phone or "").strip()
    value = 1_469_598_103_934_665_603
    for byte in source.encode("utf-8"):
        value ^= byte
        value = (value * 1_099_511_628_211) & ((1 << 64) - 1)
    return f"user_{value:016x}"


def post_archive(payload: Dict[str, Any]) -> Dict[str, Any]:
    response = request_json("POST", "/archive/items", payload)
    item = response.get("item")
    if not isinstance(item, dict):
        raise AssertionError("archive item response missing item object")
    return item


def list_archive_items() -> List[Dict[str, Any]]:
    response = request_json("GET", f"/archive/items/{urllib.parse.quote(USER_ID)}")
    items = response.get("items")
    if not isinstance(items, list):
        raise AssertionError("archive item list response missing items list")
    return [item for item in items if isinstance(item, dict)]


def list_mailbox_letters(user_id: str) -> List[Dict[str, Any]]:
    response = request_json("GET", f"/mailbox/letters/{urllib.parse.quote(user_id)}")
    items = response.get("items")
    if not isinstance(items, list):
        raise AssertionError("mailbox list response missing items list")
    return [item for item in items if isinstance(item, dict)]


def get_time_letter_detail(
    owner_user_id: str,
    item_id: str,
    viewer_user_id: str,
    now: str,
    expected: int = 200,
) -> Dict[str, Any]:
    query = urllib.parse.urlencode({"viewerUserId": viewer_user_id, "now": now})
    return request_json(
        "GET",
        (
            f"/archive/time-letters/{urllib.parse.quote(owner_user_id)}"
            f"/{urllib.parse.quote(item_id)}/detail?{query}"
        ),
        expected=expected,
    )


def matching_items(item_id: str) -> List[Dict[str, Any]]:
    return [item for item in list_archive_items() if item.get("id") == item_id]


def assert_time_letter_contract(
    item: Dict[str, Any],
    note: str,
    delivery_state: str,
    open_at: str,
    recipients: List[Dict[str, str]],
    sealed_at: Optional[str],
) -> None:
    metadata = item.get("metadata") or {}
    if not isinstance(metadata, dict):
        raise AssertionError("timeLetter metadata should be an object")
    assert_equal(item.get("kind"), "timeLetter", "timeLetter kind")
    assert_equal(item.get("note"), note, "timeLetter note")
    assert_equal(item.get("deliveryState"), delivery_state, "timeLetter deliveryState")
    assert_equal(item.get("openAt"), open_at, "timeLetter openAt")
    assert_equal(item.get("recipients"), recipients, "timeLetter recipients")
    assert_equal(metadata.get("deliveryState"), delivery_state, "metadata deliveryState")
    assert_equal(metadata.get("timeLetterStatus"), delivery_state, "metadata timeLetterStatus")
    assert_equal(metadata.get("openAt"), open_at, "metadata openAt")
    assert_equal(metadata.get("recipientIds"), "|".join(recipient["id"] for recipient in recipients), "metadata recipientIds")
    assert_equal(metadata.get("recipientNames"), "、".join(recipient["name"] for recipient in recipients), "metadata recipientNames")
    assert_equal(item.get("metadataOnly"), True, "metadataOnly")
    assert_not_in("localPath", metadata, "timeLetter metadata should strip local paths")

    if delivery_state == "draft":
        assert_equal(item.get("deliveryPolicy"), "draft", "draft deliveryPolicy")
        assert_equal(item.get("deliveryStatus"), "draft", "draft deliveryStatus")
        assert_equal(item.get("deliveryNotificationScheduled"), False, "draft notification")
        assert_equal(metadata.get("deliveryPolicy"), "draft", "metadata draft deliveryPolicy")
        assert_equal(metadata.get("deliveryStatus"), "draft", "metadata draft deliveryStatus")
    else:
        assert_equal(item.get("deliveryPolicy"), "scheduled_local_and_in_app", "sealed deliveryPolicy")
        assert_equal(item.get("sealedAt"), sealed_at, "sealedAt")
        assert_equal(item.get("deliveryStatus"), "scheduled", "sealed deliveryStatus")
        assert_equal(item.get("deliveryNotificationScheduled"), True, "sealed notification")
        assert_equal(metadata.get("deliveryPolicy"), "scheduled_local_and_in_app", "metadata sealed deliveryPolicy")
        assert_equal(metadata.get("sealedAt"), sealed_at, "metadata sealedAt")
        assert_equal(metadata.get("deliveryStatus"), "scheduled", "metadata sealed deliveryStatus")
        assert_equal(metadata.get("deliveryProviderState"), "local_notification_and_in_app", "metadata provider state")


def payload_for(
    item_id: str,
    note: str,
    delivery_state: str,
    now: str,
    open_at: str,
    recipients: List[Dict[str, str]],
    sealed_at: Optional[str] = None,
) -> Dict[str, Any]:
    is_sealed = delivery_state == "sealed"
    recipient_ids = "|".join(recipient["id"] for recipient in recipients)
    recipient_names = "、".join(recipient["name"] for recipient in recipients)
    return {
        "userId": USER_ID,
        "ownerUserId": USER_ID,
        "uploadedByUserId": USER_ID,
        "uploaderUserId": USER_ID,
        "id": item_id,
        "kind": "timeLetter",
        "title": "时间信件草稿" if delivery_state == "draft" else "时间信件",
        "note": note,
        "createdAt": now,
        "updatedAt": now,
        "analysisStatus": "manual",
        "deliveryState": delivery_state,
        "timeLetterStatus": delivery_state,
        "deliveryPolicy": "scheduled_local_and_in_app" if is_sealed else "draft",
        "openAt": open_at,
        "recipients": recipients,
        "sealedAt": sealed_at or "",
        "deliveryStatus": "scheduled" if is_sealed else "draft",
        "deliveryExecutionState": "scheduled" if is_sealed else "draft",
        "deliveryDecisionState": "confirmed" if is_sealed else "draft",
        "deliveryScheduleState": "scheduled" if is_sealed else "not_scheduled",
        "deliveryProviderState": "local_notification_and_in_app" if is_sealed else "not_scheduled",
        "deliveryNotificationScheduled": is_sealed,
        "metadata": {
            "contentKind": "time_letter",
            "deliveryState": delivery_state,
            "timeLetterStatus": delivery_state,
            "deliveryPolicy": "scheduled_local_and_in_app" if is_sealed else "draft",
            "openAt": open_at,
            "recipientIds": recipient_ids,
            "recipientNames": recipient_names,
            "sealedAt": sealed_at or "",
            "deliveryStatus": "scheduled" if is_sealed else "draft",
            "deliveryExecutionState": "scheduled" if is_sealed else "draft",
            "deliveryDecisionState": "confirmed" if is_sealed else "draft",
            "deliveryScheduleState": "scheduled" if is_sealed else "not_scheduled",
            "deliveryProviderState": "local_notification_and_in_app" if is_sealed else "not_scheduled",
            "deliveryNotificationScheduled": "true" if is_sealed else "false",
            "imageAttachmentCount": "1",
            "localPath": "/private/var/mobile/time-letter-draft.jpg",
        },
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "privacyMetadata": {"scope": "generationAllowed"},
    }


def main() -> Dict[str, Any]:
    health = request_json("GET", "/health", auth=False)
    now_dt = datetime.now(timezone.utc)
    now = now_dt.isoformat()
    open_at = (now_dt + timedelta(days=3)).isoformat()
    sealed_at = (now_dt + timedelta(minutes=1)).isoformat()
    recipients = [
        {"id": "self", "name": "我", "type": "self"},
        {"id": "family-001", "name": "林静文", "type": "family"},
    ]
    draft_item_id = f"time_letter_draft_delete_{MARKER}"
    sealed_item_id = f"time_letter_sealed_{MARKER}"
    due_item_id = f"time_letter_due_dispatch_{MARKER}"
    future_item_id = f"time_letter_future_dispatch_{MARKER}"
    family_member_id = f"family_dispatch_{MARKER}"
    phone_suffix = f"{sum((index + 1) * ord(ch) for index, ch in enumerate(MARKER)) % 100000000:08d}"
    recipient_phone = f"+86139{phone_suffix}"
    recipient_user_id = stable_user_id(recipient_phone)

    created = post_archive(payload_for(draft_item_id, "第一版草稿", "draft", now, open_at, recipients))
    edited = post_archive(payload_for(draft_item_id, "第二版草稿", "draft", now, open_at, recipients))
    assert_time_letter_contract(created, "第一版草稿", "draft", open_at, recipients, None)
    assert_time_letter_contract(edited, "第二版草稿", "draft", open_at, recipients, None)

    draft_delete_response = request_json(
        "DELETE",
        f"/archive/items/{urllib.parse.quote(USER_ID)}/{urllib.parse.quote(draft_item_id)}",
    )
    assert_equal(draft_delete_response.get("status"), "deleted", "draft delete status")
    assert_equal(len(matching_items(draft_item_id)), 0, "draft delete should remove backend row")

    post_archive(payload_for(sealed_item_id, "封存前草稿", "draft", now, open_at, recipients))
    sealed = post_archive(
        payload_for(sealed_item_id, "已经封存的正文", "sealed", now, open_at, recipients, sealed_at)
    )
    listed_after_seal = matching_items(sealed_item_id)
    assert_equal(len(listed_after_seal), 1, "sealed timeLetter upsert should keep exactly one backend row")
    listed = listed_after_seal[0]
    assert_time_letter_contract(sealed, "已经封存的正文", "sealed", open_at, recipients, sealed_at)
    assert_time_letter_contract(listed, "已经封存的正文", "sealed", open_at, recipients, sealed_at)

    sealed_delete_response = request_json(
        "DELETE",
        f"/archive/items/{urllib.parse.quote(USER_ID)}/{urllib.parse.quote(sealed_item_id)}",
        expected=409,
    )
    assert_equal(sealed_delete_response.get("detail"), "sealed timeLetter cannot be deleted", "sealed delete detail")
    assert_equal(len(matching_items(sealed_item_id)), 1, "sealed timeLetter delete should be rejected")

    request_json(
        "POST",
        "/family/invite",
        {
            "userId": USER_ID,
            "id": family_member_id,
            "name": "林静文",
            "relation": "女儿",
            "phone": recipient_phone,
        },
    )
    request_json(
        "POST",
        f"/family/members/{urllib.parse.quote(USER_ID)}/{urllib.parse.quote(family_member_id)}/accept",
        {"phone": recipient_phone},
    )
    dispatch_recipients = [
        {"id": "self", "name": "我", "type": "self"},
        {"id": family_member_id, "name": "林静文", "type": "family"},
    ]
    due = post_archive(
        payload_for(
            due_item_id,
            "这段正文不应该进入提醒列表。",
            "sealed",
            "2026-07-02T07:00:00Z",
            "2026-07-02T08:00:00Z",
            dispatch_recipients,
            "2026-07-02T07:30:00Z",
        )
    )
    future = post_archive(
        payload_for(
            future_item_id,
            "未到期内容不应对收件人可见。",
            "sealed",
            "2026-07-02T07:00:00Z",
            "2999-01-01T00:00:00Z",
            [{"id": family_member_id, "name": "林静文", "type": "family"}],
            "2026-07-02T07:30:00Z",
        )
    )
    dispatch_due = request_json(
        "POST",
        "/archive/time-letters/dispatch-due",
        {"now": "2026-07-02T09:00:00Z", "limit": 10},
    )
    dispatch_due_repeat = request_json(
        "POST",
        "/archive/time-letters/dispatch-due",
        {"now": "2026-07-02T09:00:00Z", "limit": 10},
    )
    assert_equal(dispatch_due.get("status"), "dispatched", "dispatch-due status")
    assert_equal(dispatch_due.get("itemCount"), 1, "dispatch-due item count")
    assert_equal(dispatch_due.get("reminderCount"), 2, "dispatch-due reminder count")
    assert_equal(dispatch_due_repeat.get("itemCount"), 0, "dispatch-due repeat item count")
    assert_equal(dispatch_due_repeat.get("reminderCount"), 0, "dispatch-due repeat reminder count")

    dispatched_due = matching_items(due_item_id)[0]
    dispatch_future = matching_items(future_item_id)[0]
    assert_equal(dispatched_due.get("deliveryStatus"), "delivered", "delivered item status")
    assert_equal((dispatched_due.get("metadata") or {}).get("deliveryStatus"), "delivered", "delivered metadata status")
    assert_equal((dispatched_due.get("metadata") or {}).get("deliveryExecutionState"), "delivered", "delivered execution state")
    assert_equal((dispatched_due.get("metadata") or {}).get("deliveredAt"), "2026-07-02T09:00:00Z", "delivered timestamp")
    assert_equal(dispatch_future.get("deliveryStatus"), "scheduled", "future item status")

    owner_mailbox = [
        item for item in list_mailbox_letters(USER_ID)
        if item.get("sourceArchiveItemId") == due_item_id
    ]
    recipient_mailbox = [
        item for item in list_mailbox_letters(recipient_user_id)
        if item.get("sourceArchiveItemId") == due_item_id
    ]
    recipient_future_mailbox = [
        item for item in list_mailbox_letters(recipient_user_id)
        if item.get("sourceArchiveItemId") == future_item_id
    ]
    assert_equal([item.get("id") for item in owner_mailbox], [f"time-letter-{due_item_id}-self"], "owner mailbox")
    assert_equal([item.get("id") for item in recipient_mailbox], [f"time-letter-{due_item_id}-{family_member_id}"], "recipient mailbox")
    assert_equal(recipient_mailbox[0].get("metadataOnly"), True, "recipient mailbox metadataOnly")
    assert_equal(recipient_mailbox[0].get("contentRedacted"), True, "recipient mailbox contentRedacted")
    assert_equal(recipient_mailbox[0].get("recipientRole"), "recipient", "recipient mailbox role")
    assert_equal(len(recipient_future_mailbox), 0, "future timeLetter should not be visible in recipient mailbox")
    if "这段正文" in json.dumps(recipient_mailbox, ensure_ascii=False):
        raise AssertionError("recipient mailbox should not include full timeLetter body")
    recipient_detail = get_time_letter_detail(
        USER_ID,
        due_item_id,
        recipient_user_id,
        "2026-07-02T09:00:00Z",
    )
    owner_detail = get_time_letter_detail(
        USER_ID,
        due_item_id,
        USER_ID,
        "2026-07-02T09:00:00Z",
    )
    future_detail = get_time_letter_detail(
        USER_ID,
        future_item_id,
        recipient_user_id,
        "2026-07-02T09:00:00Z",
        expected=403,
    )
    non_recipient_detail = get_time_letter_detail(
        USER_ID,
        due_item_id,
        "not_a_recipient",
        "2026-07-02T09:00:00Z",
        expected=403,
    )
    assert_equal(recipient_detail.get("status"), "available", "recipient detail status")
    assert_equal((recipient_detail.get("access") or {}).get("role"), "recipient", "recipient detail role")
    assert_equal((recipient_detail.get("item") or {}).get("note"), "这段正文不应该进入提醒列表。", "recipient detail body")
    assert_equal((recipient_detail.get("item") or {}).get("contentRedacted"), False, "recipient detail contentRedacted")
    assert_equal((owner_detail.get("access") or {}).get("role"), "owner", "owner detail role")
    assert_equal(future_detail.get("detail"), "timeLetter is not open yet", "future detail blocked")
    assert_equal(non_recipient_detail.get("detail"), "viewer is not a recipient", "non-recipient detail blocked")

    return {
        "completed": True,
        "health": health,
        "userId": USER_ID,
        "marker": MARKER,
        "draftItemId": draft_item_id,
        "sealedItemId": sealed_item_id,
        "created": created,
        "edited": edited,
        "draftDeleteResponse": draft_delete_response,
        "sealed": sealed,
        "listedAfterSeal": listed,
        "sealedDeleteResponse": sealed_delete_response,
        "listedAfterSealedDeleteCount": len(matching_items(sealed_item_id)),
        "dispatchDue": dispatch_due,
        "dispatchDueRepeat": dispatch_due_repeat,
        "dueDispatchItem": due,
        "futureDispatchItem": future,
        "listedAfterDispatch": dispatched_due,
        "listedFutureAfterDispatch": dispatch_future,
        "ownerMailbox": owner_mailbox,
        "recipientMailbox": recipient_mailbox,
        "recipientDetail": recipient_detail,
        "ownerDetail": owner_detail,
        "futureDetail": future_detail,
        "nonRecipientDetail": non_recipient_detail,
        "recipientFutureMailboxCount": len(recipient_future_mailbox),
        "recipientUserId": recipient_user_id,
    }


if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2, sort_keys=True))
