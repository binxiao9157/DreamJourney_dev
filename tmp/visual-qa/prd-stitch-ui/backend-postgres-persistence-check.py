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
PROFILE_NICKNAME = f"RL Profile {MARKER[-12:]}"
PROFILE_REGION = f"RL Region {MARKER[-12:]}"
AUTH_PHONE = f"release_like_password_{MARKER}"
AUTH_NICKNAME = f"ReleaseLike Password {MARKER[-12:]}"
AUTH_OLD_PASSWORD = f"Old-{MARKER[-12:]}-Pass9"
AUTH_NEW_PASSWORD = f"New-{MARKER[-12:]}-Pass9"
MISSING_CARE_USER_ID = f"{USER_ID}_missing_user"
STALE_CARE_USER_ID = f"{USER_ID}_stale_care"
STALE_CARE_WINDOW_END = "2026-05-01T00:00:00Z"
PUSH_DEVICE_TOKEN = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
PUSH_DEVICE_ID = f"ios-release-like-{MARKER[-12:]}"
DELAYED_REPLY_ID = f"echo_delayed_release_like_{MARKER}"
DELAYED_DELIVER_AT = "2026-06-18T12:05:00Z"


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


def make_care_snapshot(
    *,
    summary,
    risk_level="watch",
    generated_at="2026-06-18T09:02:00Z",
    window_start="2026-06-11T00:00:00Z",
    window_end="2026-06-18T00:00:00Z",
):
    return {
        "generatedAt": generated_at,
        "windowStart": window_start,
        "windowEnd": window_end,
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
        "riskLevel": risk_level,
        "summary": summary,
        "trendSummary": "A short family check-in is recommended today.",
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
                "signalScore": 0.66,
            }
        ],
    }


def make_auth_login_payload(password):
    return {
        "phone": AUTH_PHONE,
        "nickname": AUTH_NICKNAME,
        "password": password,
    }


def seed():
    auth_created = request_json("POST", "/auth/login", make_auth_login_payload(AUTH_OLD_PASSWORD))
    auth_user = auth_created.get("user") or {}
    assert_true(auth_user.get("id"), "password login should return a user id")
    assert_equal(auth_user.get("passwordConfigured"), True, "passwordConfigured should be true after credential init")

    password_changed = request_json(
        "POST",
        "/auth/password",
        {
            "userId": auth_user.get("id"),
            "oldPassword": AUTH_OLD_PASSWORD,
            "newPassword": AUTH_NEW_PASSWORD,
        },
    )
    assert_equal(password_changed.get("status"), "changed", "password change status")
    assert_equal(password_changed.get("userId"), auth_user.get("id"), "password change should preserve user id")

    profile_payload = {
        "userId": USER_ID,
        "nickname": PROFILE_NICKNAME,
        "gender": "不便透露",
        "region": PROFILE_REGION,
        "avatarName": "person.crop.circle.fill",
    }
    profile_saved = request_json("POST", "/profile", profile_payload)
    assert_equal(profile_saved.get("status"), "saved", "profile save status")
    saved_profile = profile_saved.get("profile") or {}
    assert_equal(saved_profile.get("nickname"), PROFILE_NICKNAME, "profile nickname should echo from save")
    assert_equal(saved_profile.get("gender"), "不便透露", "profile gender should echo from save")
    assert_equal(saved_profile.get("region"), PROFILE_REGION, "profile region should echo from save")

    push_registered = request_json(
        "POST",
        "/devices/push-token",
        {
            "userId": USER_ID,
            "deviceToken": PUSH_DEVICE_TOKEN,
            "platform": "ios",
            "environment": "sandbox",
            "deviceId": PUSH_DEVICE_ID,
        },
    )
    assert_equal(push_registered.get("status"), "registered", "push device token register status")
    push_item = push_registered.get("item") or {}
    assert_true(push_item.get("deviceTokenId"), "push token registration should return deviceTokenId")
    assert_equal(push_item.get("deliveryProviderState"), "pending", "push token provider state should be pending")
    assert_not_in_mapping(push_item, "deviceToken", "push token response must not expose raw deviceToken")
    assert_true(PUSH_DEVICE_TOKEN not in json.dumps(push_registered), "push token response must not include raw token")

    delayed_reply = request_json(
        "POST",
        "/echo/delayed-replies",
        {
            "userId": USER_ID,
            "delayedReplyId": DELAYED_REPLY_ID,
            "deliverAt": DELAYED_DELIVER_AT,
            "minutes": 7,
            "trigger": "tenRoundBaseline",
            "deviceTokenId": push_item.get("deviceTokenId"),
        },
    )
    assert_equal(delayed_reply.get("status"), "scheduled", "echo delayed reply status")
    delayed_item = delayed_reply.get("item") or {}
    assert_equal(delayed_item.get("deviceTokenId"), push_item.get("deviceTokenId"), "delayed reply should reference deviceTokenId")
    assert_true(PUSH_DEVICE_TOKEN not in json.dumps(delayed_reply), "delayed reply response must not include raw token")

    archive_payload = {
        "userId": USER_ID,
        "viewerUserId": f"viewer_{MARKER}",
        "ownerId": f"elder_{MARKER}",
        "ownerUserId": f"viewer_{MARKER}",
        "personaScope": "family",
        "digitalHumanId": "family_default",
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

    care_snapshot = make_care_snapshot(summary=f"Release-like care marker {MARKER}")
    care_created = request_json("POST", "/care/snapshots", {"userId": USER_ID, "snapshot": care_snapshot})
    assert_equal(care_created.get("status"), "saved", "care snapshot create status")

    stale_snapshot = make_care_snapshot(
        summary=f"Release-like stale care marker {MARKER}",
        risk_level="stable",
        generated_at="2026-05-01T08:00:00Z",
        window_start="2026-04-24T00:00:00Z",
        window_end=STALE_CARE_WINDOW_END,
    )
    stale_created = request_json("POST", "/care/snapshots", {"userId": STALE_CARE_USER_ID, "snapshot": stale_snapshot})
    assert_equal(stale_created.get("status"), "saved", "stale care snapshot create status")


def verify():
    old_password_login = request_json(
        "POST",
        "/auth/login",
        make_auth_login_payload(AUTH_OLD_PASSWORD),
        expected=401,
    )
    assert_equal(
        old_password_login.get("detail"),
        "invalid password",
        "old password should be rejected after password change",
    )

    new_password_login = request_json("POST", "/auth/login", make_auth_login_payload(AUTH_NEW_PASSWORD))
    new_password_user = new_password_login.get("user") or {}
    assert_true(new_password_user.get("id"), "new password login should return a user id")
    assert_equal(
        new_password_user.get("passwordConfigured"),
        True,
        "new password should login after password change",
    )

    loaded_profile = request_json("GET", f"/profile/{USER_ID}")
    profile = loaded_profile.get("profile") or {}
    assert_equal(profile.get("userId"), USER_ID, "profile user id should persist")
    assert_equal(profile.get("nickname"), PROFILE_NICKNAME, "profile nickname should persist")
    assert_equal(profile.get("gender"), "不便透露", "profile gender should persist")
    assert_equal(profile.get("region"), PROFILE_REGION, "profile region should persist")
    assert_equal(profile.get("avatarName"), "person.crop.circle.fill", "profile avatar metadata should persist")

    delayed_reply_list = request_json("GET", f"/echo/delayed-replies/{USER_ID}")
    listed_delayed_reply = next(
        (item for item in delayed_reply_list.get("items", []) if item.get("delayedReplyId") == DELAYED_REPLY_ID),
        None,
    )
    assert_true(listed_delayed_reply is not None, "delayed reply list should contain release-like marker item")
    assert_equal(listed_delayed_reply.get("deliveryState"), "scheduled", "delayed reply delivery state should persist")
    assert_equal(listed_delayed_reply.get("pushProviderState"), "pending", "delayed reply push provider state should persist")
    assert_true(listed_delayed_reply.get("deviceTokenId"), "delayed reply should persist deviceTokenId")
    assert_true(PUSH_DEVICE_TOKEN not in json.dumps(delayed_reply_list), "delayed reply list must not expose raw device token")

    archive_list = request_json("GET", f"/archive/items/{USER_ID}")
    listed_archive = next((item for item in archive_list.get("items", []) if item.get("id") == ARCHIVE_ID), None)
    assert_true(listed_archive is not None, "archive list should contain release-like marker item")
    assert_equal((listed_archive.get("metadata") or {}).get("marker"), MARKER, "archive marker should persist")
    assert_equal(listed_archive.get("personaScope"), "family", "archive persona scope should persist")
    assert_equal(listed_archive.get("digitalHumanId"), "family_default", "archive digital human id should persist")
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

    missing_care = request_json("GET", f"/care/snapshots/latest/{MISSING_CARE_USER_ID}", expected=404)
    assert_equal(missing_care.get("detail"), "care snapshot not found", "missing_user should map to empty care state")

    invalid_care = request_json(
        "POST",
        "/care/snapshots",
        {"userId": f"{USER_ID}_invalid_care", "snapshot": {"riskLevel": "stable", "summary": "字段不足"}},
        expected=400,
    )
    assert_true(
        "missing required care snapshot fields" in str(invalid_care.get("detail") or ""),
        "invalid care snapshot should be rejected",
    )

    stale_care = request_json("GET", f"/care/snapshots/latest/{STALE_CARE_USER_ID}")
    stale_snapshot = ((stale_care.get("item") or {}).get("snapshot") or {})
    assert_equal(
        stale_snapshot.get("windowEnd"),
        STALE_CARE_WINDOW_END,
        "stale care snapshot should preserve stale window",
    )
    assert_equal(stale_snapshot.get("riskLevel"), "stable", "stale care risk level should persist")

    return {
        "passwordChangeStatus": "changed",
        "passwordOldLoginStatus": old_password_login.get("detail"),
        "passwordNewLoginConfigured": new_password_user.get("passwordConfigured"),
        "passwordUserId": new_password_user.get("id"),
        "profileNickname": profile.get("nickname"),
        "profileRegion": profile.get("region"),
        "echoDelayedReplyState": listed_delayed_reply.get("deliveryState"),
        "echoDelayedReplyPushProviderState": listed_delayed_reply.get("pushProviderState"),
        "echoDelayedReplyDeviceTokenId": listed_delayed_reply.get("deviceTokenId"),
        "archiveItemCount": len(archive_list.get("items", [])),
        "archivePersonaScope": listed_archive.get("personaScope"),
        "archiveDigitalHumanId": listed_archive.get("digitalHumanId"),
        "familyMemberCount": len(family_list.get("members", [])),
        "careRiskLevel": latest_snapshot.get("riskLevel"),
        "careActiveRiskLevel": latest_snapshot.get("riskLevel"),
        "careMissingStatus": missing_care.get("detail"),
        "careInvalidStatus": invalid_care.get("detail"),
        "careStaleWindowEnd": stale_snapshot.get("windowEnd"),
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
