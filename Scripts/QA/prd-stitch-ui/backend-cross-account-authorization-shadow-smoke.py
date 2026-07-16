#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone


BASE_URL = (
    sys.argv[1]
    if len(sys.argv) > 1
    else os.getenv("DREAMJOURNEY_BACKEND_BASE_URL", "http://127.0.0.1:3100")
).rstrip("/")
BACKEND_TOKEN = (
    sys.argv[2]
    if len(sys.argv) > 2
    else os.getenv("DREAMJOURNEY_BACKEND_API_TOKEN", "")
)


def request_json(method, path, payload=None, expected=200, *, access_token=None, params=None):
    headers = {"Accept": "application/json"}
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    if BACKEND_TOKEN:
        headers["X-DreamJourney-Api-Token"] = BACKEND_TOKEN
    if params:
        path = f"{path}?{urllib.parse.urlencode(params)}"
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(
        f"{BASE_URL}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.status
            response_headers = dict(response.headers.items())
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        status = error.code
        response_headers = dict(error.headers.items())
        body = error.read().decode("utf-8", errors="replace")
    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body[:240]}")
    return (json.loads(body) if body else {}), response_headers


def header(headers, name):
    return next((value for key, value in headers.items() if key.lower() == name.lower()), None)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def access_token(login):
    token = str((login.get("auth") or {}).get("accessToken") or "")
    require(token.startswith("dja_"), "login must return opaque access token")
    return token


def care_snapshot(now_iso):
    return {
        "generatedAt": now_iso,
        "windowStart": now_iso,
        "windowEnd": now_iso,
        "windowDayCount": 7,
        "dataCoverageSummary": "跨账号授权 smoke 聚合数据",
        "totalTurns": 3,
        "userTurnCount": 2,
        "characterCount": 32,
        "uniqueTokenCount": 12,
        "lexicalDiversity": 0.6,
        "negativeEmotionMentions": 0,
        "sleepMentions": 0,
        "bodyDiscomfortMentions": 0,
        "repetitionRatio": 0.0,
        "averageWordsPerMinute": 90.0,
        "slowSpeechTurnCount": 0,
        "longPauseTurnCount": 0,
        "emotionVolatilityScore": 0.1,
        "riskLevel": "stable",
        "summary": "跨账号授权 smoke 摘要",
        "suggestions": [],
        "weeklyHighlights": [],
        "riskSignalDescriptions": [],
        "dailyTrend": [
            {
                "date": now_iso,
                "userTurnCount": 2,
                "negativeEmotionMentions": 0,
                "sleepMentions": 0,
                "bodyDiscomfortMentions": 0,
                "repetitionRatio": 0.0,
                "averageWordsPerMinute": 90.0,
                "slowSpeechTurnCount": 0,
                "longPauseTurnCount": 0,
                "emotionVolatilityScore": 0.1,
                "signalScore": 0,
            }
        ],
        "trendSummary": "状态平稳。",
    }


def main():
    suffix = str(int(time.time()))[-8:]
    owner_phone = f"136{suffix}"
    family_phone = f"137{suffix}"
    attacker_phone = f"135{suffix}"
    password = "authorization-smoke-123"
    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    open_at = (now - timedelta(minutes=2)).isoformat()

    runtime, _ = request_json("GET", "/config/runtime")
    policy = (runtime.get("auth") or {}).get("crossAccountPolicy") or {}
    require(policy.get("contractVersion") == 1, "runtime cross-account policy contract missing")
    require(policy.get("mode") == "shadow", "deployed authorization policy must remain shadow")
    require(policy.get("productionEnforceReady") is False, "runtime must not claim enforce readiness")

    def login(phone, nickname):
        body, _ = request_json(
            "POST",
            "/auth/login",
            {"phone": phone, "nickname": nickname, "password": password},
        )
        return body

    owner = login(owner_phone, "授权 smoke owner")
    family = login(family_phone, "授权 smoke family")
    attacker = login(attacker_phone, "授权 smoke attacker")
    owner_id = owner["user"]["id"]
    family_id = family["user"]["id"]

    invitation, _ = request_json(
        "POST",
        "/family/invite",
        {
            "userId": owner_id,
            "name": "授权 smoke 家人",
            "relation": "家人",
            "phone": family_phone,
        },
        access_token=access_token(owner),
    )
    pending_member = invitation["member"]
    accepted, accept_headers = request_json(
        "POST",
        f"/family/invitations/{pending_member['invitationCode']}/accept",
        {"phone": family_phone},
        access_token=access_token(family),
    )
    member = accepted["member"]
    require(header(accept_headers, "X-DreamJourney-Ownership-Decision") == "delegated", "invite acceptance must delegate")
    require(header(accept_headers, "X-DreamJourney-Authorization-Decision") == "allowRecipient", "invite acceptance policy mismatch")

    _, care_write_headers = request_json(
        "POST",
        "/care/snapshots",
        {
            "userId": owner_id,
            "viewerFamilyMemberID": member["id"],
            "snapshot": care_snapshot(now_iso),
        },
        access_token=access_token(owner),
    )
    require(header(care_write_headers, "X-DreamJourney-Authorization-Decision") == "allowOwner", "care write must be owner-only")

    care_params = {
        "viewerFamilyMemberID": member["id"],
    }
    _, family_care_headers = request_json(
        "GET",
        f"/care/snapshots/latest/{owner_id}",
        access_token=access_token(family),
        params=care_params,
    )
    _, forged_care_headers = request_json(
        "GET",
        f"/care/snapshots/latest/{owner_id}",
        expected=403,
        access_token=access_token(attacker),
        params=care_params,
    )
    require(header(family_care_headers, "X-DreamJourney-Ownership-Decision") == "delegated", "family care read must delegate")
    require(header(family_care_headers, "X-DreamJourney-Authorization-Decision") == "allowFamily", "family care policy mismatch")
    require(header(forged_care_headers, "X-DreamJourney-Authorization-Decision") == "deny", "forged care viewer must be denied in shadow evidence")

    letter_id = f"authorization-shadow-{suffix}"
    letter_payload = {
        "userId": owner_id,
        "ownerUserId": owner_id,
        "uploadedByUserId": owner_id,
        "uploaderUserId": owner_id,
        "id": letter_id,
        "kind": "timeLetter",
        "title": "跨账号授权 smoke 时间信件",
        "note": "仅用于授权 smoke，不输出正文。",
        "createdAt": now_iso,
        "updatedAt": now_iso,
        "analysisStatus": "manual",
        "deliveryState": "sealed",
        "timeLetterStatus": "sealed",
        "openAt": open_at,
        "sealedAt": now_iso,
        "deliveryStatus": "scheduled",
        "recipients": [
            {"id": "self", "name": "我", "type": "self"},
            {"id": member["id"], "name": "授权 smoke 家人", "type": "family"},
        ],
        "metadata": {
            "contentKind": "time_letter",
            "deliveryState": "sealed",
            "timeLetterStatus": "sealed",
            "openAt": open_at,
            "recipientIds": f"self|{member['id']}",
            "recipientNames": "我、授权 smoke 家人",
            "sealedAt": now_iso,
            "deliveryStatus": "scheduled",
        },
        "personaScope": "personal",
        "digitalHumanId": owner_id,
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    request_json(
        "POST",
        "/archive/items",
        letter_payload,
        access_token=access_token(owner),
    )
    detail_params = {"viewerUserId": family_id, "now": now_iso}
    _, recipient_headers = request_json(
        "GET",
        f"/archive/time-letters/{owner_id}/{letter_id}/detail",
        access_token=access_token(family),
        params=detail_params,
    )
    _, forged_letter_headers = request_json(
        "GET",
        f"/archive/time-letters/{owner_id}/{letter_id}/detail",
        expected=403,
        access_token=access_token(attacker),
        params=detail_params,
    )
    require(header(recipient_headers, "X-DreamJourney-Authorization-Decision") == "allowRecipient", "time-letter recipient policy mismatch")
    require(header(recipient_headers, "X-DreamJourney-Ownership-Decision") == "delegated", "time-letter recipient must delegate")
    require(header(forged_letter_headers, "X-DreamJourney-Authorization-Decision") == "deny", "forged time-letter viewer must be denied in shadow evidence")

    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": True,
        "contractVersion": policy.get("contractVersion"),
        "ownershipMode": policy.get("mode"),
        "inviteRecipientDelegated": True,
        "familyCareDelegated": True,
        "forgedCareViewerRejected": True,
        "timeLetterRecipientDelegated": True,
        "forgedTimeLetterViewerRejected": True,
        "productionEnforceReady": False,
        "identifiersRedacted": True,
        "tokensRedacted": True,
        "globalDispatchInvoked": False,
    }, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
