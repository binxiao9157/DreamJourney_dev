#!/usr/bin/env python3
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone


if len(sys.argv) < 5:
    raise SystemExit(
        "Usage: backend-care-state-uiqa-fixtures.py <base-url> <user-id> <api-token> <marker>"
    )

BASE_URL = sys.argv[1].rstrip("/")
USER_ID = sys.argv[2]
API_TOKEN = sys.argv[3]
MARKER = sys.argv[4]

MARKER_SUFFIX = "".join(ch if ch.isalnum() else "_" for ch in MARKER)[-24:]
ACTIVE_USER_ID = f"{USER_ID}_care_active"
STALE_USER_ID = f"{USER_ID}_care_stale"
MISSING_USER_ID = f"{USER_ID}_care_missing"
INVALID_USER_ID = f"{USER_ID}_care_invalid"
STALE_CARE_WINDOW_END = "2026-05-01T00:00:00Z"


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
        with urllib.request.urlopen(request, timeout=12) as response:
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


def request_public_json(method, path, expected=200):
    url = f"{BASE_URL}{path}"
    request = urllib.request.Request(url, headers={"Accept": "application/json"}, method=method)
    try:
        with urllib.request.urlopen(request, timeout=12) as response:
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


def iso_now():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def make_care_snapshot(
    *,
    summary,
    risk_level,
    generated_at,
    window_start,
    window_end,
    signal_score,
):
    return {
        "generatedAt": generated_at,
        "windowStart": window_start,
        "windowEnd": window_end,
        "windowDayCount": 7,
        "dataCoverageSummary": "UIQA aggregate context is sufficient.",
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
        "riskLevel": risk_level,
        "summary": summary,
        "trendSummary": "Family check-in recommended today.",
        "suggestions": ["Call today."],
        "weeklyHighlights": ["Shared one positive memory."],
        "riskSignalDescriptions": ["Sleep topic appeared twice."],
        "dailyTrend": [
            {
                "date": window_end[:10],
                "userTurnCount": 10,
                "negativeEmotionMentions": 1,
                "sleepMentions": 2,
                "bodyDiscomfortMentions": 0,
                "repetitionRatio": 0.22,
                "averageWordsPerMinute": 89.5,
                "slowSpeechTurnCount": 0,
                "longPauseTurnCount": 1,
                "emotionVolatilityScore": 0.31,
                "signalScore": signal_score,
            }
        ],
    }


def latest_snapshot(user_id):
    latest = request_json("GET", f"/care/snapshots/latest/{user_id}")
    return ((latest.get("item") or {}).get("snapshot") or {})


def main():
    health = request_public_json("GET", "/health")
    assert_equal(health.get("status"), "ok", "health status")
    assert_equal(health.get("store"), "postgres", "care UIQA fixture requires Postgres backend")

    active_window_end = iso_now()
    active_snapshot = make_care_snapshot(
        summary=f"UIQA care active {MARKER_SUFFIX}",
        risk_level="watch",
        generated_at=active_window_end,
        window_start="2026-06-12T00:00:00Z",
        window_end=active_window_end,
        signal_score=0.66,
    )
    active_created = request_json(
        "POST",
        "/care/snapshots",
        {"userId": ACTIVE_USER_ID, "snapshot": active_snapshot},
    )
    assert_equal(active_created.get("status"), "saved", "active care snapshot create status")

    stale_snapshot = make_care_snapshot(
        summary=f"UIQA care stale {MARKER_SUFFIX}",
        risk_level="stable",
        generated_at="2026-05-01T08:00:00Z",
        window_start="2026-04-24T00:00:00Z",
        window_end=STALE_CARE_WINDOW_END,
        signal_score=0.82,
    )
    stale_created = request_json(
        "POST",
        "/care/snapshots",
        {"userId": STALE_USER_ID, "snapshot": stale_snapshot},
    )
    assert_equal(stale_created.get("status"), "saved", "stale care snapshot create status")

    active_latest = latest_snapshot(ACTIVE_USER_ID)
    stale_latest = latest_snapshot(STALE_USER_ID)
    missing_latest = request_json("GET", f"/care/snapshots/latest/{MISSING_USER_ID}", expected=404)
    invalid_write = request_json(
        "POST",
        "/care/snapshots",
        {"userId": INVALID_USER_ID, "snapshot": {"riskLevel": "stable", "summary": "字段不足"}},
        expected=400,
    )

    assert_equal(active_latest.get("riskLevel"), "watch", "active latest risk level")
    assert_true(MARKER_SUFFIX in str(active_latest.get("summary") or ""), "active latest summary marker")
    assert_equal(stale_latest.get("windowEnd"), STALE_CARE_WINDOW_END, "stale latest windowEnd")
    assert_equal(stale_latest.get("riskLevel"), "stable", "stale latest risk level")
    assert_equal(missing_latest.get("detail"), "care snapshot not found", "missing care detail")
    assert_true(
        "missing required care snapshot fields" in str(invalid_write.get("detail") or ""),
        "invalid care should be rejected as failed-state boundary",
    )

    print(json.dumps(
        {
            "completed": True,
            "healthStore": health.get("store"),
            "activeUserId": ACTIVE_USER_ID,
            "staleUserId": STALE_USER_ID,
            "missingUserId": MISSING_USER_ID,
            "invalidUserId": INVALID_USER_ID,
            "careActiveRiskLevel": active_latest.get("riskLevel"),
            "careStaleWindowEnd": stale_latest.get("windowEnd"),
            "careMissingStatus": missing_latest.get("detail"),
            "careInvalidStatus": invalid_write.get("detail"),
        },
        ensure_ascii=False,
        sort_keys=True,
    ))


if __name__ == "__main__":
    main()
