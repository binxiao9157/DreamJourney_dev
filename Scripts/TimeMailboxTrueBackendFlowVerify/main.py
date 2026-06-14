#!/usr/bin/env python3
import json
import os
import sys
import uuid


os.environ["STORE_BACKEND"] = "memory"
os.environ["BACKEND_API_TOKEN"] = ""

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


BODY_SENTINEL = "MAILBOX_TRUE_BACKEND_BODY_SENTINEL"
ECHO_SENTINEL = "MAILBOX_TRUE_BACKEND_ECHO_SENTINEL"


def fail(message: str) -> None:
    print(f"TimeMailboxTrueBackendFlow verification failed: {message}", file=sys.stderr)
    sys.exit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def require_status(response, expected: int, context: str) -> None:
    if response.status_code != expected:
        fail(f"{context}: expected HTTP {expected}, got {response.status_code}: {response.text}")


def serialized(payload) -> str:
    return json.dumps(payload, ensure_ascii=False, sort_keys=True)


def letter_payload(user_id: str, letter_id: str, *, status: str, scope: str = "generationAllowed") -> dict:
    return {
        "userId": user_id,
        "id": letter_id,
        "recipientName": "林桂芳",
        "title": "西湖边的小照相馆",
        "body": f"{BODY_SENTINEL} 完整正文只允许留在本机。",
        "bodyPreview": f"{BODY_SENTINEL} 正文预览也不能同步。",
        "replyText": f"{ECHO_SENTINEL} 回声文本也不能同步到后端。",
        "createdAt": "2026-06-13T09:00:00Z",
        "deliverAt": "2026-06-14T09:00:00Z",
        "deliveredAt": "2026-06-14T09:01:00Z" if status == "delivered" else None,
        "status": status,
        "boundaryAcknowledged": True,
        "privacyMetadata": {"scope": scope},
        "rawTranscript": BODY_SENTINEL,
        "messages": [{"role": "user", "text": BODY_SENTINEL}],
    }


client = TestClient(app)
user_id = f"mailbox_true_backend_user_{uuid.uuid4().hex}"
letter_id = "letter-true-backend-001"

sealed = client.post(
    "/mailbox/letters",
    json=letter_payload(user_id, letter_id, status="sealed"),
)
require_status(sealed, 200, "sealed mailbox metadata save")
sealed_item = sealed.json()["item"]
require(sealed_item["id"] == letter_id, "saved mailbox metadata should preserve letter id")
require(sealed_item["status"] == "sealed", "saved mailbox metadata should preserve status")
require(sealed_item["metadataOnly"] is True, "mailbox metadata should be metadata-only")
require(sealed_item["contentRedacted"] is True, "mailbox metadata should be content-redacted")

listed = client.get(f"/mailbox/letters/{user_id}")
require_status(listed, 200, "mailbox metadata list")
require(len(listed.json()["items"]) == 1, "mailbox list should include the saved letter metadata")

delivered = client.post(
    "/mailbox/letters",
    json=letter_payload(user_id, letter_id, status="delivered"),
)
require_status(delivered, 200, "delivered mailbox metadata update")
require(delivered.json()["item"]["status"] == "delivered", "mailbox metadata update should preserve delivered status")
require("deliveredAt" in delivered.json()["item"], "delivered mailbox metadata should include delivery timestamp")

listed_after_update = client.get(f"/mailbox/letters/{user_id}")
require_status(listed_after_update, 200, "mailbox metadata list after update")
items_after_update = listed_after_update.json()["items"]
require(len(items_after_update) == 1, "mailbox metadata update should replace the same letter id")
require(items_after_update[0]["status"] == "delivered", "mailbox list should show the delivered update")

combined = serialized({
    "sealed": sealed.json(),
    "listed": listed.json(),
    "delivered": delivered.json(),
    "listed_after_update": listed_after_update.json(),
})
for forbidden in [
    BODY_SENTINEL,
    ECHO_SENTINEL,
    "body",
    "bodyPreview",
    "replyText",
    "rawTranscript",
    "messages",
]:
    require(forbidden not in combined, f"mailbox backend response should not contain {forbidden}")

for scope in ("privateOnly", "localOnly"):
    rejected = client.post(
        "/mailbox/letters",
        json=letter_payload(user_id, f"letter-{scope}", status="sealed", scope=scope),
    )
    require_status(rejected, 403, f"{scope} mailbox letter should not sync")

print("TimeMailboxTrueBackendFlow verification passed")
