#!/usr/bin/env python3
import json
import sys
import urllib.error
import urllib.parse
import urllib.request


if len(sys.argv) < 6:
    raise SystemExit(
        "Usage: backend-postgres-persistence-check.py <base-url> <user-id> <api-token> <marker> <seed|verify>"
    )

BASE_URL = sys.argv[1].rstrip("/")
USER_ID = sys.argv[2]
API_TOKEN = sys.argv[3]
MARKER = sys.argv[4]
MODE = sys.argv[5]

ARCHIVE_ID = f"archive_release_like_{MARKER}"
FAMILY_ID = f"family_release_like_{MARKER}"
PERSON_ID = f"person_release_like_{MARKER}"
EVENT_ID = f"event_release_like_{MARKER}"
PHONE = "13900008888"


def request_json(method, path, payload=None, params=None, expected=200):
    url = f"{BASE_URL}{path}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    data = None
    headers = {
        "Accept": "application/json",
        "Authorization": f"Bearer {API_TOKEN}",
    }
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
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


def request_public_json(method, path, expected=200):
    url = f"{BASE_URL}{path}"
    request = urllib.request.Request(url, headers={"Accept": "application/json"}, method=method)
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
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


def health_check():
    health = request_public_json("GET", "/health")
    assert_equal(health.get("status"), "ok", "health status")
    assert_equal(health.get("store"), "postgres", "release-like backend must use Postgres")
    return health


def seed():
    archive_payload = {
        "userId": USER_ID,
        "id": ARCHIVE_ID,
        "kind": "photo",
        "title": f"Release-like Postgres Photo {MARKER}",
        "note": "Persistent archive metadata for release-like acceptance.",
        "createdAt": "2026-06-18T09:00:00Z",
        "updatedAt": "2026-06-18T09:01:00Z",
        "analysisStatus": "analyzed",
        "analysisSummary": f"Persistent archive marker {MARKER}.",
        "tags": ["backend-contract", "release-like-postgres", MARKER],
        "metadata": {"source": "release-like-postgres", "marker": MARKER},
        "localPath": "/tmp/should-not-persist-release-like-photo.jpg",
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    archive_created = request_json("POST", "/archive/items", archive_payload)
    assert_equal(archive_created.get("status"), "saved", "archive create status")
    assert_not_in_mapping(archive_created.get("item") or {}, "localPath", "archive item must not persist localPath")

    kb_payload = {
        "userId": USER_ID,
        "graph": {
            "version": 1,
            "sessionCount": 1,
            "people": [
                {
                    "id": PERSON_ID,
                    "name": f"ReleaseLike Person {MARKER}",
                    "privacyMetadata": {"scope": "generationAllowed"},
                }
            ],
            "places": [],
            "events": [
                {
                    "id": EVENT_ID,
                    "title": f"ReleaseLike Event {MARKER}",
                    "participantIds": [PERSON_ID],
                    "privacyMetadata": {"scope": "generationAllowed"},
                }
            ],
            "facts": [],
        },
    }
    kb_synced = request_json("POST", "/kb/sync", kb_payload)
    assert_equal(kb_synced.get("status"), "synced", "kb sync status")

    family_payload = {
        "userId": USER_ID,
        "id": FAMILY_ID,
        "name": f"ReleaseLike Daughter {MARKER}",
        "relation": "daughter",
        "phone": PHONE,
        "invitationCode": f"RL{MARKER[-8:]}".upper(),
    }
    family_created = request_json("POST", "/family/invite", family_payload)
    assert_equal(family_created.get("status"), "created", "family invite status")
    family_accepted = request_json("POST", f"/family/members/{USER_ID}/{FAMILY_ID}/accept", {"phone": PHONE})
    assert_equal(family_accepted.get("status"), "accepted", "family accept status")

    care_snapshot = {
        "generatedAt": "2026-06-18T09:02:00Z",
        "windowStart": "2026-06-11T00:00:00Z",
        "windowEnd": "2026-06-18T00:00:00Z",
        "windowDayCount": 7,
        "dataCoverageSummary": "Release-like aggregate context is sufficient.",
        "totalTurns": 16,
        "userTurnCount": 10,
        "characterCount": 520,
        "uniqueTokenCount": 98,
        "lexicalDiversity": 0.73,
        "negativeEmotionMentions": 1,
        "sleepMentions": 2,
        "bodyDiscomfortMentions": 0,
        "repetitionRatio": 0.22,
        "averageWordsPerMinute": 89.5,
        "slowSpeechTurnCount": 0,
        "longPauseTurnCount": 1,
        "emotionVolatilityScore": 0.31,
        "riskLevel": "watch",
        "summary": f"Release-like care marker {MARKER}",
        "trendSummary": "A short family check-in is recommended today.",
        "suggestions": ["Call today."],
        "weeklyHighlights": ["Shared one positive memory."],
        "riskSignalDescriptions": ["Sleep topic appeared twice."],
        "dailyTrend": [
            {
                "date": "2026-06-18",
                "userTurnCount": 10,
                "negativeEmotionMentions": 1,
                "sleepMentions": 2,
                "bodyDiscomfortMentions": 0,
                "repetitionRatio": 0.22,
                "averageWordsPerMinute": 89.5,
                "slowSpeechTurnCount": 0,
                "longPauseTurnCount": 1,
                "emotionVolatilityScore": 0.31,
                "signalScore": 0.66,
            }
        ],
    }
    care_created = request_json("POST", "/care/snapshots", {"userId": USER_ID, "snapshot": care_snapshot})
    assert_equal(care_created.get("status"), "saved", "care snapshot create status")


def verify():
    archive_list = request_json("GET", f"/archive/items/{USER_ID}")
    listed_archive = next((item for item in archive_list.get("items", []) if item.get("id") == ARCHIVE_ID), None)
    assert_true(listed_archive is not None, "archive list should contain release-like marker item")
    assert_equal((listed_archive.get("metadata") or {}).get("marker"), MARKER, "archive marker should persist")
    assert_not_in_mapping(listed_archive, "localPath", "archive list must not expose localPath")

    kb_snapshot = request_json("GET", f"/kb/snapshot/{USER_ID}")
    encoded_kb = json.dumps(kb_snapshot, ensure_ascii=False)
    assert_true(PERSON_ID in encoded_kb, "kb snapshot should persist marker person")
    assert_true(EVENT_ID in encoded_kb, "kb snapshot should persist marker event")

    family_list = request_json("GET", f"/family/members/{USER_ID}")
    family_member = next((item for item in family_list.get("members", []) if item.get("id") == FAMILY_ID), None)
    assert_true(family_member is not None, "family list should contain release-like marker member")
    assert_equal(family_member.get("accessStatus"), "active", "family member should remain active")
    assert_equal(family_member.get("invitationStatus"), "accepted", "family member should remain accepted")

    latest_care = request_json("GET", f"/care/snapshots/latest/{USER_ID}")
    latest_snapshot = ((latest_care.get("item") or {}).get("snapshot") or {})
    assert_equal(latest_snapshot.get("riskLevel"), "watch", "latest care risk level")
    assert_true(MARKER in str(latest_snapshot.get("summary") or ""), "latest care summary should contain marker")
    assert_equal(latest_snapshot.get("metadataOnly"), True, "care snapshot should be metadata-only")
    assert_equal(latest_snapshot.get("contentRedacted"), True, "care snapshot should be content-redacted")

    return {
        "archiveItemCount": len(archive_list.get("items", [])),
        "familyMemberCount": len(family_list.get("members", [])),
        "careRiskLevel": latest_snapshot.get("riskLevel"),
    }


def main():
    if MODE not in {"seed", "verify"}:
        raise SystemExit(f"Unsupported mode: {MODE}")
    health = health_check()
    if MODE == "seed":
        seed()
    verification = verify()
    print(json.dumps({
        "baseURL": BASE_URL,
        "mode": MODE,
        "userId": USER_ID,
        "marker": MARKER,
        "health": health,
        "completed": True,
        **verification,
    }, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
