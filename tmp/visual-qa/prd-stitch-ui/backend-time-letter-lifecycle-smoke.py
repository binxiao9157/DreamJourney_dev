#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
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


def assert_time_letter_contract(item: Dict[str, Any], note: str, delivery_state: str) -> None:
    metadata = item.get("metadata") or {}
    if not isinstance(metadata, dict):
        raise AssertionError("timeLetter metadata should be an object")
    assert_equal(item.get("kind"), "timeLetter", "timeLetter kind")
    assert_equal(item.get("note"), note, "timeLetter note")
    assert_equal(item.get("deliveryState"), delivery_state, "timeLetter deliveryState")
    assert_equal(item.get("deliveryPolicy"), "pending_product_decision", "timeLetter deliveryPolicy")
    assert_equal(metadata.get("deliveryState"), delivery_state, "metadata deliveryState")
    assert_equal(metadata.get("timeLetterStatus"), delivery_state, "metadata timeLetterStatus")
    assert_equal(metadata.get("deliveryDecisionRequired"), "true", "delivery decision flag")
    assert_equal(item.get("metadataOnly"), True, "metadataOnly")
    assert_not_in("localPath", metadata, "timeLetter metadata should strip local paths")


def payload_for(item_id: str, note: str, delivery_state: str, now: str) -> Dict[str, Any]:
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
        "deliveryPolicy": "pending_product_decision",
        "metadata": {
            "contentKind": "time_letter",
            "deliveryState": delivery_state,
            "timeLetterStatus": delivery_state,
            "deliveryPolicy": "pending_product_decision",
            "deliveryDecisionRequired": "true",
            "localPath": "/private/var/mobile/time-letter-draft.txt",
        },
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "privacyMetadata": {"scope": "generationAllowed"},
    }


def main() -> Dict[str, Any]:
    health = request_json("GET", "/health", auth=False)
    now = datetime.now(timezone.utc).isoformat()
    item_id = f"hidden_time_letter_lifecycle_{MARKER}"

    # POST draft timeLetter, edit the same id, seal it, then delete it.
    created = post_archive(payload_for(item_id, "第一版草稿", "draft", now))
    edited = post_archive(payload_for(item_id, "第二版草稿", "draft", now))
    sealed = post_archive(payload_for(item_id, "已经封存的正文", "sealed", now))

    listed_after_seal = matching_items(item_id)
    assert_equal(len(listed_after_seal), 1, "timeLetter upsert should keep exactly one backend row")
    listed = listed_after_seal[0]
    for item, note, state in [
        (created, "第一版草稿", "draft"),
        (edited, "第二版草稿", "draft"),
        (sealed, "已经封存的正文", "sealed"),
        (listed, "已经封存的正文", "sealed"),
    ]:
        assert_time_letter_contract(item, note, state)

    delete_response = request_json(
        "DELETE",
        f"/archive/items/{urllib.parse.quote(USER_ID)}/{urllib.parse.quote(item_id)}",
    )
    assert_equal(delete_response.get("status"), "deleted", "delete status")
    assert_equal(delete_response.get("id"), item_id, "delete id")
    listed_after_delete = matching_items(item_id)
    assert_equal(len(listed_after_delete), 0, "timeLetter delete should remove backend row")

    return {
        "completed": True,
        "health": health,
        "userId": USER_ID,
        "marker": MARKER,
        "itemId": item_id,
        "created": created,
        "edited": edited,
        "sealed": sealed,
        "listedAfterSeal": listed,
        "deleteResponse": delete_response,
        "listedAfterDeleteCount": len(listed_after_delete),
    }


if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2, sort_keys=True))
