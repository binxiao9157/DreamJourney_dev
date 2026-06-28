#!/usr/bin/env python3
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


BASE_URL = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:3100").rstrip("/")
RUN_SUFFIX = str(int(time.time()))
USER_ID = sys.argv[2] if len(sys.argv) > 2 else f"backend_contract_{RUN_SUFFIX}"
API_TOKEN = sys.argv[3] if len(sys.argv) > 3 else None


def request_json(method, path, payload=None, params=None, expected=200, token=API_TOKEN):
    url = f"{BASE_URL}{path}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    data = None
    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            body = response.read().decode("utf-8")
            status = response.status
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        raise AssertionError(f"{method} {path} expected {expected}, got {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body}")
    return json.loads(body) if body else {}


def assert_equal(actual, expected, message):
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def assert_true(value, message):
    if not value:
        raise AssertionError(message)


def assert_not_in_mapping(mapping, key, message):
    if isinstance(mapping, dict) and key in mapping:
        raise AssertionError(message)


def assert_no_marker(value, marker, message):
    encoded = json.dumps(value, ensure_ascii=False).lower()
    if marker.lower() in encoded:
        raise AssertionError(message)


def main():
    health = request_json("GET", "/health")
    assert_equal(health.get("status"), "ok", "health status")

    runtime = request_json("GET", "/config/runtime")
    assert_true("capabilities" in runtime, "runtime config should expose capabilities")

    archive_id = f"archive_contract_{RUN_SUFFIX}"
    archive_payload = {
        "userId": USER_ID,
        "id": archive_id,
        "kind": "photo",
        "title": "Backend Contract Photo",
        "note": "Garden bench memory",
        "createdAt": "2026-06-17T09:00:00Z",
        "updatedAt": "2026-06-17T09:01:00Z",
        "analysisStatus": "analyzed",
        "analysisSummary": "A photo note ready for echo context.",
        "detectedPeople": ["mother"],
        "tags": ["photo", "backend-contract"],
        "metadata": {"source": "backend-contract"},
        "localPath": "/tmp/private-local-photo.jpg",
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    archive_created = request_json("POST", "/archive/items", archive_payload)
    archive_item = archive_created.get("item") or {}
    assert_equal(archive_created.get("status"), "saved", "archive create status")
    assert_equal(archive_item.get("metadataOnly"), True, "archive item should be metadata-only")
    assert_not_in_mapping(archive_item, "localPath", "archive item must not persist localPath")

    archive_list = request_json("GET", f"/archive/items/{USER_ID}")
    listed_archive = next((item for item in archive_list.get("items", []) if item.get("id") == archive_id), None)
    assert_true(listed_archive is not None, "archive list should return saved item")
    assert_not_in_mapping(listed_archive, "localPath", "archive list must not expose localPath")

    kb_payload = {
        "userId": USER_ID,
        "graph": {
            "version": 1,
            "sessionCount": 1,
            "people": [
                {"id": "p_sync", "name": "Mother", "privacyMetadata": {"scope": "generationAllowed"}},
                {"id": "p_local", "name": "Local Only", "privacyMetadata": {"scope": "localOnly"}},
            ],
            "places": [
                {"id": "place_sync", "name": "Garden", "privacyMetadata": {"scope": "familyCircle"}},
            ],
            "events": [
                {
                    "id": "event_sync",
                    "participantIds": ["p_sync", "p_local"],
                    "locationId": "place_sync",
                    "privacyMetadata": {"scope": "generationAllowed"},
                },
            ],
            "facts": [],
        },
    }
    kb_synced = request_json("POST", "/kb/sync", kb_payload)
    assert_equal(kb_synced.get("status"), "synced", "kb sync status")
    assert_equal(kb_synced.get("counts", {}).get("people"), 1, "kb should filter local-only people")
    kb_snapshot = request_json("GET", f"/kb/snapshot/{USER_ID}")
    assert_no_marker(kb_snapshot, "Local Only", "kb snapshot must not expose local-only entity")

    family_payload = {
        "userId": USER_ID,
        "name": "Daughter",
        "relation": "daughter",
        "phone": "13900000000",
    }
    family_created = request_json("POST", "/family/invite", family_payload)
    member = family_created.get("member") or {}
    member_id = member.get("id")
    assert_equal(family_created.get("status"), "created", "family invite status")
    assert_true(member_id is not None, "family invite should return member id")
    family_accepted = request_json(
        "POST",
        f"/family/members/{USER_ID}/{member_id}/accept",
        {"phone": "13900000000"},
    )
    assert_equal(family_accepted.get("status"), "accepted", "family accept status")
    family_list = request_json("GET", f"/family/members/{USER_ID}")
    assert_true(
        any(item.get("id") == member_id and item.get("accessStatus") == "active" for item in family_list.get("members", [])),
        "family list should include accepted member",
    )

    care_snapshot = {
        "generatedAt": "2026-06-17T09:02:00Z",
        "windowStart": "2026-06-10T00:00:00Z",
        "windowEnd": "2026-06-17T00:00:00Z",
        "windowDayCount": 7,
        "dataCoverageSummary": "Enough aggregate context",
        "totalTurns": 12,
        "userTurnCount": 8,
        "characterCount": 420,
        "uniqueTokenCount": 88,
        "lexicalDiversity": 0.72,
        "negativeEmotionMentions": 1,
        "sleepMentions": 2,
        "bodyDiscomfortMentions": 0,
        "repetitionRatio": 0.25,
        "averageWordsPerMinute": 88.5,
        "slowSpeechTurnCount": 0,
        "longPauseTurnCount": 1,
        "emotionVolatilityScore": 0.3,
        "riskLevel": "watch",
        "summary": "Mild fluctuation this week",
        "trendSummary": "A short family check-in is recommended today",
        "suggestions": ["Call today."],
        "weeklyHighlights": ["Shared one positive memory."],
        "riskSignalDescriptions": ["Sleep topic appeared twice."],
        "dailyTrend": [
            {
                "date": "2026-06-17",
                "userTurnCount": 8,
                "negativeEmotionMentions": 1,
                "sleepMentions": 2,
                "bodyDiscomfortMentions": 0,
                "repetitionRatio": 0.25,
                "averageWordsPerMinute": 88.5,
                "slowSpeechTurnCount": 0,
                "longPauseTurnCount": 1,
                "emotionVolatilityScore": 0.3,
                "signalScore": 0.64,
            }
        ],
    }
    care_created = request_json("POST", "/care/snapshots", {"userId": USER_ID, "snapshot": care_snapshot})
    assert_equal(care_created.get("status"), "saved", "care snapshot create status")
    latest_care = request_json("GET", f"/care/snapshots/latest/{USER_ID}")
    latest_snapshot = ((latest_care.get("item") or {}).get("snapshot") or {})
    assert_equal(latest_snapshot.get("riskLevel"), "watch", "latest care risk level")
    assert_equal(latest_snapshot.get("metadataOnly"), True, "care snapshot should be metadata-only")
    assert_equal(latest_snapshot.get("contentRedacted"), True, "care snapshot should be content-redacted")
    assert_no_marker(latest_care, "care_raw_sentinel", "care snapshot must not expose raw marker")

    result = {
        "baseURL": BASE_URL,
        "userId": USER_ID,
        "health": health,
        "archiveItemCount": len(archive_list.get("items", [])),
        "kbPeopleCount": kb_synced.get("counts", {}).get("people"),
        "familyMemberCount": len(family_list.get("members", [])),
        "careRiskLevel": latest_snapshot.get("riskLevel"),
        "careShape": "item.snapshot",
        "completed": True,
    }
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
