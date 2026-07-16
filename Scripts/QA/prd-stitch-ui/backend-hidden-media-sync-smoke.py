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
    raise SystemExit("Usage: backend-hidden-media-sync-smoke.py <app-root> <user-id> <marker>")

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
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
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


def assert_true(value: Any, message: str) -> None:
    if not value:
        raise AssertionError(message)


def assert_not_in(key: str, obj: Dict[str, Any], message: str) -> None:
    if key in obj:
        raise AssertionError(f"{message}: unexpected key {key!r} in {obj!r}")


def upload_intent(archive_item_id: str, kind: str, file_name: str, content_type: str, file_size_bytes: int) -> Dict[str, Any]:
    payload = {
        "userId": USER_ID,
        "archiveItemId": archive_item_id,
        "kind": kind,
        "fileName": file_name,
        "contentType": content_type,
        "fileSizeBytes": file_size_bytes,
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "ownerUserId": USER_ID,
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    response = request_json("POST", "/archive/media/upload-intent", payload)
    intent = response.get("uploadIntent")
    if not isinstance(intent, dict):
        raise AssertionError("upload intent response missing uploadIntent object")
    assert_equal(intent.get("archiveItemId"), archive_item_id, "upload intent archiveItemId")
    assert_equal(intent.get("kind"), kind, "upload intent kind")
    assert_equal(intent.get("storageProvider"), "mockObjectStorage", "upload intent provider")
    assert_equal(intent.get("providerDisplayName"), "Mock Object Storage", "upload intent provider display name")
    assert_equal(intent.get("providerMode"), "mock", "upload intent provider mode")
    assert_equal(intent.get("requiresClientUpload"), False, "upload intent should not require client file PUT")
    assert_equal(intent.get("uploadURLScheme"), "mock", "upload intent URL scheme")
    assert_equal(intent.get("realProviderReady"), False, "upload intent real provider readiness")
    assert_equal(intent.get("providerSwitchContractVersion"), 1, "upload intent provider switch version")
    assert_equal(intent.get("clientUploadAction"), "metadataOnly", "upload intent client upload action")
    assert_true(intent.get("objectKey"), "upload intent objectKey should be present")
    assert_true(str(intent.get("uploadURL", "")).startswith("mock://"), "upload intent should stay mock://")
    return intent


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


def by_id(items: List[Dict[str, Any]], item_id: str) -> Dict[str, Any]:
    for item in items:
        if item.get("id") == item_id:
            return item
    raise AssertionError(f"listed archive item missing {item_id}")


def assert_backend_media_privacy(item: Dict[str, Any], metadata_keys: List[str]) -> None:
    for key in ["localPath", "rawAudioURL", "rawVideoURL", "rawTranscript", "thumbnailPath", "localThumbnailPath"]:
        assert_not_in(key, item, "backend archive item should strip local/raw media fields")
    metadata = item.get("metadata") or {}
    if not isinstance(metadata, dict):
        raise AssertionError("archive item metadata should be object")
    for key in metadata_keys:
        assert_not_in(key, metadata, "backend archive metadata should strip local media fields")


def main() -> Dict[str, Any]:
    health = request_json("GET", "/health", auth=False)
    runtime = request_json("GET", "/config/runtime")
    runtime_archive = runtime.get("archive")
    if not isinstance(runtime_archive, dict):
        raise AssertionError("runtime config missing archive object")
    assert_equal(runtime_archive.get("storageProvider"), "mockObjectStorage", "runtime archive provider")
    assert_equal(runtime_archive.get("providerDisplayName"), "Mock Object Storage", "runtime archive provider display name")
    assert_equal(runtime_archive.get("providerMode"), "mock", "runtime archive provider mode")
    assert_equal(runtime_archive.get("requiresClientUpload"), False, "runtime archive should not require client file PUT")
    assert_equal(runtime_archive.get("uploadURLScheme"), "mock", "runtime archive upload URL scheme")
    assert_equal(runtime_archive.get("realProviderReady"), False, "runtime archive real provider readiness")
    assert_equal(runtime_archive.get("providerSwitchContractVersion"), 1, "runtime archive provider switch version")
    assert_equal(runtime_archive.get("clientUploadAction"), "metadataOnly", "runtime archive client upload action")
    now = datetime.now(timezone.utc).isoformat()
    audio_id = f"hidden_audio_{MARKER}"
    video_id = f"hidden_video_{MARKER}"
    letter_id = f"hidden_time_letter_{MARKER}"

    audio_intent = upload_intent(audio_id, "audio", "uiqa-hidden.m4a", "audio/mp4", 4096)
    video_intent = upload_intent(video_id, "video", "uiqa-hidden.mov", "video/quicktime", 8192)

    audio_payload = {
        "userId": USER_ID,
        "ownerUserId": USER_ID,
        "uploadedByUserId": USER_ID,
        "uploaderUserId": USER_ID,
        "id": audio_id,
        "kind": "audio",
        "title": "语音档案",
        "note": "隐藏媒体同步 smoke 的 mock 音频。",
        "createdAt": now,
        "updatedAt": now,
        "analysisStatus": "manual",
        "localPath": "/private/var/mobile/archive-audio/uiqa-hidden.m4a",
        "rawAudioURL": "file:///private/var/mobile/archive-audio/uiqa-hidden.m4a",
        "rawTranscript": "未审转写不应回传",
        "transcriptText": "这是一段可持久化的转写文本。",
        "metadata": {
            "contentKind": "audio",
            "uploadStatus": "uploaded",
            "transcriptionStatus": "completed",
            "transcriptText": "这是一段可持久化的转写文本。",
            "uploadIntentId": audio_intent["uploadIntentId"],
            "objectKey": audio_intent["objectKey"],
            "uploadProvider": audio_intent["storageProvider"],
            "localPath": "/private/var/mobile/archive-audio/uiqa-hidden.m4a",
        },
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    video_payload = {
        "userId": USER_ID,
        "ownerUserId": USER_ID,
        "uploadedByUserId": USER_ID,
        "uploaderUserId": USER_ID,
        "id": video_id,
        "kind": "video",
        "title": "视频片段",
        "note": "隐藏媒体同步 smoke 的 mock 视频。",
        "createdAt": now,
        "updatedAt": now,
        "analysisStatus": "pending",
        "localPath": "/private/var/mobile/archive-video/uiqa-hidden.mov",
        "rawVideoURL": "file:///private/var/mobile/archive-video/uiqa-hidden.mov",
        "thumbnailPath": "/private/var/mobile/archive-video/uiqa-thumb.jpg",
        "localThumbnailPath": "/private/var/mobile/archive-video/uiqa-thumb.jpg",
        "thumbnailObjectKey": f"{video_intent['objectKey']}.thumb.jpg",
        "fileSizeBytes": 8192,
        "fileSizeLimitMB": 200,
        "metadata": {
            "contentKind": "video",
            "uploadStatus": "uploaded",
            "thumbnailStatus": "generated",
            "thumbnailObjectKey": f"{video_intent['objectKey']}.thumb.jpg",
            "fileSizeBytes": "8192",
            "fileSizeLimitMB": "200",
            "uploadIntentId": video_intent["uploadIntentId"],
            "objectKey": video_intent["objectKey"],
            "uploadProvider": video_intent["storageProvider"],
            "thumbnailPath": "/private/var/mobile/archive-video/uiqa-thumb.jpg",
        },
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    open_at = now
    letter_payload = {
        "userId": USER_ID,
        "ownerUserId": USER_ID,
        "id": letter_id,
        "kind": "timeLetter",
        "title": "时间信件",
        "note": "这是一封已封存并等待提醒的时间信件。",
        "createdAt": now,
        "updatedAt": now,
        "analysisStatus": "manual",
        "deliveryState": "sealed",
        "deliveryPolicy": "scheduled_local_and_in_app",
        "openAt": open_at,
        "recipients": [
            {"id": "self", "name": "我", "type": "self"},
            {"id": "family_001", "name": "家人", "type": "family"},
        ],
        "sealedAt": now,
        "deliveryStatus": "scheduled",
        "deliveryNotificationScheduled": True,
        "metadata": {
            "contentKind": "time_letter",
            "deliveryState": "sealed",
            "timeLetterStatus": "sealed",
            "deliveryPolicy": "scheduled_local_and_in_app",
            "openAt": open_at,
            "recipientIds": "self|family_001",
            "recipientNames": "我、家人",
            "sealedAt": now,
            "deliveryStatus": "scheduled",
            "deliveryExecutionState": "scheduled",
            "deliveryDecisionState": "confirmed",
            "deliveryScheduleState": "scheduled",
            "deliveryProviderState": "local_notification_and_in_app",
            "deliveryNotificationScheduled": "true",
            "localPath": "/private/var/mobile/time-letter.txt",
        },
        "personaScope": "personal",
        "digitalHumanId": USER_ID,
        "privacyMetadata": {"scope": "generationAllowed"},
    }

    created_audio = post_archive(audio_payload)
    created_video = post_archive(video_payload)
    created_letter = post_archive(letter_payload)
    listed_items = list_archive_items()
    listed_audio = by_id(listed_items, audio_id)
    listed_video = by_id(listed_items, video_id)
    listed_letter = by_id(listed_items, letter_id)

    for item in [created_audio, listed_audio]:
        assert_equal(item.get("kind"), "audio", "audio kind")
        assert_equal(item.get("transcriptText"), "这是一段可持久化的转写文本。", "audio transcriptText")
        assert_equal((item.get("metadata") or {}).get("uploadStatus"), "uploaded", "audio upload status")
        assert_equal((item.get("metadata") or {}).get("objectKey"), audio_intent["objectKey"], "audio objectKey")
        assert_backend_media_privacy(item, ["localPath"])

    for item in [created_video, listed_video]:
        assert_equal(item.get("kind"), "video", "video kind")
        assert_equal(item.get("analysisStatus"), "pending", "video analysis status")
        assert_equal(item.get("thumbnailObjectKey"), f"{video_intent['objectKey']}.thumb.jpg", "video thumbnailObjectKey")
        assert_equal((item.get("metadata") or {}).get("uploadStatus"), "uploaded", "video upload status")
        assert_equal((item.get("metadata") or {}).get("objectKey"), video_intent["objectKey"], "video objectKey")
        assert_backend_media_privacy(item, ["thumbnailPath"])

    for item in [created_letter, listed_letter]:
        assert_equal(item.get("kind"), "timeLetter", "timeLetter kind")
        assert_equal(item.get("deliveryState"), "sealed", "timeLetter delivery state")
        assert_equal(item.get("deliveryPolicy"), "scheduled_local_and_in_app", "timeLetter delivery policy")
        assert_equal(item.get("openAt"), open_at, "timeLetter openAt")
        assert_equal(item.get("deliveryStatus"), "scheduled", "timeLetter delivery status")
        assert_equal(item.get("deliveryNotificationScheduled"), True, "timeLetter notification scheduled")
        assert_equal((item.get("metadata") or {}).get("deliveryProviderState"), "local_notification_and_in_app", "timeLetter provider state")
        assert_backend_media_privacy(item, ["localPath"])

    return {
        "completed": True,
        "health": health,
        "runtimeArchive": runtime_archive,
        "userId": USER_ID,
        "marker": MARKER,
        "createdIds": [audio_id, video_id, letter_id],
        "audioUploadIntent": {
            "storageProvider": audio_intent["storageProvider"],
            "providerMode": audio_intent["providerMode"],
            "requiresClientUpload": audio_intent["requiresClientUpload"],
            "uploadURLScheme": audio_intent["uploadURLScheme"],
            "objectKey": audio_intent["objectKey"],
        },
        "videoUploadIntent": {
            "storageProvider": video_intent["storageProvider"],
            "providerMode": video_intent["providerMode"],
            "requiresClientUpload": video_intent["requiresClientUpload"],
            "uploadURLScheme": video_intent["uploadURLScheme"],
            "objectKey": video_intent["objectKey"],
        },
        "listedAudio": listed_audio,
        "listedVideo": listed_video,
        "listedTimeLetter": listed_letter,
    }


if __name__ == "__main__":
    print(json.dumps(main(), ensure_ascii=False, indent=2, sort_keys=True))
