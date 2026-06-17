#!/usr/bin/env python3
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


BASE_URL = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:3100").rstrip("/")
API_TOKEN = sys.argv[2] if len(sys.argv) > 2 else "dj-local-test-token"
RUN_SUFFIX = str(int(time.time()))
USER_ID = f"backend_auth_{RUN_SUFFIX}"


def request_json(method, path, payload=None, expected=200, token=None):
    url = f"{BASE_URL}{path}"
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
        if error.code != expected:
            raise AssertionError(f"{method} {path} expected {expected}, got {error.code}: {body}") from error
        return json.loads(body) if body else {}
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body}")
    return json.loads(body) if body else {}


def assert_equal(actual, expected, message):
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def main():
    health = request_json("GET", "/health", expected=200)
    assert_equal(health.get("status"), "ok", "health should stay public")

    unauth = request_json("GET", "/config/runtime", expected=401)
    assert_equal(unauth.get("detail"), "invalid backend api token", "runtime should require backend token")

    runtime = request_json("GET", "/config/runtime", expected=200, token=API_TOKEN)
    if "capabilities" not in runtime:
        raise AssertionError("authorized runtime config should expose capabilities")

    archive_payload = {
        "userId": USER_ID,
        "id": f"archive_auth_{RUN_SUFFIX}",
        "kind": "photo",
        "title": "Authorized Backend Photo",
        "note": "Authorized metadata",
        "createdAt": "2026-06-17T09:00:00Z",
        "updatedAt": "2026-06-17T09:01:00Z",
        "analysisStatus": "analyzed",
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    archive = request_json("POST", "/archive/items", payload=archive_payload, expected=200, token=API_TOKEN)
    assert_equal(archive.get("status"), "saved", "authorized archive save")

    care_snapshot = {
        "generatedAt": "2026-06-17T09:02:00Z",
        "windowStart": "2026-06-10T00:00:00Z",
        "windowEnd": "2026-06-17T00:00:00Z",
        "windowDayCount": 7,
        "dataCoverageSummary": "Authorized aggregate context",
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
        "summary": "Authorized mild fluctuation",
        "trendSummary": "Authorized short family check-in",
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
    care = request_json("POST", "/care/snapshots", payload={"userId": USER_ID, "snapshot": care_snapshot}, expected=200, token=API_TOKEN)
    assert_equal(care.get("status"), "saved", "authorized care save")

    latest = request_json("GET", f"/care/snapshots/latest/{USER_ID}", expected=200, token=API_TOKEN)
    snapshot = ((latest.get("item") or {}).get("snapshot") or {})
    assert_equal(snapshot.get("riskLevel"), "watch", "authorized care latest")

    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": True,
        "healthPublic": True,
        "unauthorizedRuntimeStatus": 401,
        "authorizedArchiveStatus": archive.get("status"),
        "authorizedCareRiskLevel": snapshot.get("riskLevel"),
        "userId": USER_ID,
    }, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
