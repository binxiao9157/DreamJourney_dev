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
    }


if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2, sort_keys=True))
