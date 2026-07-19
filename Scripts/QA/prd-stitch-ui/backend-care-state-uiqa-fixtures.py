#!/usr/bin/env python3
"""Seed and clean isolated authenticated fixtures for Profile care UIQA.

This helper is deliberately executed inside the deployed backend API container.
It creates disposable users directly in that container's Postgres network,
issues short-lived typed sessions, then exercises the public API as each user.
No machine service token may call a user-owned care route.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


BACKEND_ROOT = Path(os.environ.get("DREAMJOURNEY_BACKEND_ROOT", "/app"))
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.core.config import settings  # noqa: E402
from app.services.auth_sessions import AuthSessionService  # noqa: E402
from app.services.postgres_store import PostgresStore  # noqa: E402
from app.services.user_identity import stable_user_id  # noqa: E402


STALE_CARE_WINDOW_END = "2026-05-01T00:00:00Z"
SESSION_FIXTURE_SCHEMA_VERSION = 1
CLEANUP_MANIFEST_SCHEMA_VERSION = 2
CARE_DASHBOARD_FEATURE = "careDashboard"
QA_FIXTURE_MARKER_KEY = "qaFixtureMarker"
QA_FIXTURE_KIND = "profileCareBackendState"
QA_FIXTURE_CREATE_ATTEMPTS = 5


def require(value: bool, message: str) -> None:
    if not value:
        raise AssertionError(message)


def request_json(
    base_url: str,
    method: str,
    path: str,
    *,
    payload: dict[str, Any] | None = None,
    access_token: str | None = None,
    user_id: str | None = None,
    expected: int = 200,
) -> dict[str, Any]:
    headers = {
        "Accept": "application/json",
        "X-DreamJourney-Client-Build": "9001",
        "X-DreamJourney-Auth-Contract-Version": "2",
        "X-DreamJourney-Request-Purpose": "profileCareUIQA",
        "X-DreamJourney-Owner-Binding": "principal",
    }
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    if user_id:
        headers["X-DreamJourney-User-Id"] = user_id
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url}{path}",
        data=data,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status = response.status
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        status = error.code
        body = error.read().decode("utf-8", errors="replace")
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body}")
    return json.loads(body) if body else {}


def iso_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def make_care_snapshot(
    *,
    summary: str,
    risk_level: str,
    generated_at: str,
    window_start: str,
    window_end: str,
    signal_score: float,
) -> dict[str, Any]:
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


def open_store() -> PostgresStore:
    database_url = str(settings.database_url or "").strip()
    require(database_url, "DATABASE_URL is required for authenticated care UIQA fixtures")
    store = PostgresStore(
        dsn=database_url,
        pool_min_size=1,
        pool_max_size=2,
        pool_timeout_seconds=5.0,
    )
    store.open_pool(wait=True)
    return store


def require_care_dashboard_canary(base_url: str) -> dict[str, Any]:
    policy = request_json(
        base_url,
        "GET",
        "/v2/release-policy?audience=owner&cohort=closedPilotAdultSelf&clientBuild=9001",
    )
    decisions = policy.get("features") or []
    care_decision = next(
        (item for item in decisions if isinstance(item, dict) and item.get("feature") == CARE_DASHBOARD_FEATURE),
        {},
    )
    require(
        care_decision.get("enabled") is True,
        "careDashboardNotApprovedForClosedPilot",
    )
    return policy


def create_authenticated_user(
    store: PostgresStore,
    *,
    run_suffix: str,
    role: str,
) -> dict[str, Any]:
    user: dict[str, Any] | None = None
    fixture_marker = ""
    for _ in range(QA_FIXTURE_CREATE_ATTEMPTS):
        phone = f"199{secrets.randbelow(10**8):08d}"
        user_id = stable_user_id(phone)
        fixture_marker = f"{QA_FIXTURE_KIND}:{run_suffix}:{role}:{secrets.token_hex(8)}"
        candidate = {
            "id": user_id,
            "phone": phone,
            "nickname": f"UIQA care {role}",
            "updatedAt": iso_now(),
            "restoreCount": 0,
            "deletionState": "active",
            "accessState": "active",
            "authEpoch": 0,
            "providerCapabilityState": "enabled",
            QA_FIXTURE_MARKER_KEY: fixture_marker,
            "qaFixtureKind": QA_FIXTURE_KIND,
        }
        with store.auth_user_operation(user_id):
            inserted = store._fetchone(
                """
                INSERT INTO users (id, phone, nickname, payload, updated_at)
                VALUES (%s, %s, %s, %s, NOW())
                ON CONFLICT (id) DO NOTHING
                RETURNING payload
                """,
                (user_id, phone, candidate["nickname"], candidate),
            )
        if inserted is None:
            continue
        inserted_payload = dict(inserted.get("payload") or {})
        require(
            inserted_payload.get(QA_FIXTURE_MARKER_KEY) == fixture_marker,
            f"{role} fixture marker mismatch after insert",
        )
        user = inserted_payload
        break

    require(user is not None, f"{role} fixture identity collision")
    user_id = str(user.get("id") or "").strip()
    require(user_id, f"{role} fixture user id missing")
    # This probes the exact collision path without updating the newly created
    # fixture. A real account collision must take this same DO NOTHING path.
    collision_payload = {
        **user,
        "nickname": "collision probe must not persist",
        QA_FIXTURE_MARKER_KEY: f"collision:{secrets.token_hex(8)}",
    }
    with store.auth_user_operation(user_id):
        collision = store._fetchone(
            """
            INSERT INTO users (id, phone, nickname, payload, updated_at)
            VALUES (%s, %s, %s, %s, NOW())
            ON CONFLICT (id) DO NOTHING
            RETURNING payload
            """,
            (
                user_id,
                str(user.get("phone") or ""),
                str(collision_payload["nickname"]),
                collision_payload,
            ),
        )
    require(collision is None, f"{role} fixture collision unexpectedly inserted")
    unchanged = store.get_user(user_id) or {}
    require(
        unchanged.get(QA_FIXTURE_MARKER_KEY) == fixture_marker,
        f"{role} fixture collision changed existing user",
    )

    auth = AuthSessionService(
        store,
        access_ttl_seconds=900,
        refresh_ttl_seconds=1800,
    ).issue(user_id)
    access_token = str(auth.get("accessToken") or "").strip()
    require(access_token.startswith("dja_"), f"{role} fixture access token missing")
    return {
        "role": role,
        "runSuffix": run_suffix,
        "userId": user_id,
        "phone": str(user.get("phone") or ""),
        "nickname": str(user.get("nickname") or "UI QA"),
        "fixtureMarker": fixture_marker,
        "auth": auth,
    }


def cleanup(store: PostgresStore, fixtures: list[dict[str, Any]]) -> list[str]:
    normalized_fixtures: list[dict[str, str]] = []
    seen_user_ids: set[str] = set()
    for fixture in fixtures:
        user_id = str(fixture.get("userId") or "").strip()
        fixture_marker = str(fixture.get("fixtureMarker") or "").strip()
        require(user_id and fixture_marker, "cleanup fixture identity missing")
        require(user_id not in seen_user_ids, "cleanup fixture user id duplicated")
        seen_user_ids.add(user_id)
        normalized_fixtures.append(
            {"userId": user_id, "fixtureMarker": fixture_marker}
        )
    if not normalized_fixtures:
        return []

    normalized_user_ids = [fixture["userId"] for fixture in normalized_fixtures]
    with store.request_unit_of_work(
        correlation_id="profile-care-uiqa-cleanup",
        command_id="cleanupProfileCareUIQAFixtures",
    ) as unit_of_work:
        with unit_of_work.connection.cursor(row_factory=store._dict_row_factory()) as cursor:
            cursor.execute(
                "SELECT id, payload FROM users WHERE id = ANY(%s)",
                (normalized_user_ids,),
            )
            existing_users = {
                str(row["id"]): dict(row["payload"] or {})
                for row in cursor.fetchall()
            }
            for fixture in normalized_fixtures:
                payload = existing_users.get(fixture["userId"])
                require(payload is not None, "cleanup fixture user missing")
                require(
                    payload.get(QA_FIXTURE_MARKER_KEY) == fixture["fixtureMarker"],
                    "cleanup fixture marker mismatch",
                )
            for table in (
                "kb_operation_receipts",
                "kb_changes",
                "kb_change_feed_state",
                "kb_snapshots",
                "care_snapshots",
                "family_members",
                "voice_profiles",
                "voice_clone_slots",
                "digital_human_sessions",
                "push_device_tokens",
                "echo_delayed_replies",
                "mailbox_letters",
                "archive_items",
                "memories",
                "profiles",
                "password_credentials",
                "session_events",
                "auth_sessions",
                "token_families",
            ):
                cursor.execute(f"DELETE FROM {table} WHERE user_id = ANY(%s)", (normalized_user_ids,))
            for fixture in normalized_fixtures:
                cursor.execute(
                    """
                    DELETE FROM users
                    WHERE id = %s AND payload->>'qaFixtureMarker' = %s
                    RETURNING id
                    """,
                    (fixture["userId"], fixture["fixtureMarker"]),
                )
                deleted = cursor.fetchone()
                require(deleted is not None, "cleanup fixture user delete rejected")

    for fixture in normalized_fixtures:
        require(
            store.get_user(fixture["userId"]) is None,
            "cleanup fixture user still present",
        )
    return normalized_user_ids


def write_private_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, sort_keys=True), encoding="utf-8")
    path.chmod(0o600)


def seed(base_url: str, marker: str, session_output: Path, cleanup_output: Path) -> None:
    store: PostgresStore | None = None
    fixtures: list[dict[str, Any]] = []
    try:
        health = request_json(base_url, "GET", "/health")
        require(health.get("status") == "ok", "health status")
        require(health.get("store") == "postgres", "care UIQA fixture requires Postgres backend")
        release_policy = require_care_dashboard_canary(base_url)

        run_suffix = "".join(ch if ch.isalnum() else "_" for ch in marker)[-24:] or secrets.token_hex(6)
        store = open_store()
        active = create_authenticated_user(store, run_suffix=run_suffix, role="active")
        stale = create_authenticated_user(store, run_suffix=run_suffix, role="stale")
        empty = create_authenticated_user(store, run_suffix=run_suffix, role="empty")
        fixtures = [active, stale, empty]

        active_window_end = iso_now()
        active_snapshot = make_care_snapshot(
            summary=f"UIQA care active {run_suffix}",
            risk_level="watch",
            generated_at=active_window_end,
            window_start="2026-06-12T00:00:00Z",
            window_end=active_window_end,
            signal_score=0.66,
        )
        active_created = request_json(
            base_url,
            "POST",
            "/care/snapshots",
            payload={"userId": active["userId"], "snapshot": active_snapshot},
            access_token=active["auth"]["accessToken"],
            user_id=active["userId"],
        )
        require(active_created.get("status") == "saved", "active care snapshot create status")

        stale_snapshot = make_care_snapshot(
            summary=f"UIQA care stale {run_suffix}",
            risk_level="stable",
            generated_at="2026-05-01T08:00:00Z",
            window_start="2026-04-24T00:00:00Z",
            window_end=STALE_CARE_WINDOW_END,
            signal_score=0.82,
        )
        stale_created = request_json(
            base_url,
            "POST",
            "/care/snapshots",
            payload={"userId": stale["userId"], "snapshot": stale_snapshot},
            access_token=stale["auth"]["accessToken"],
            user_id=stale["userId"],
        )
        require(stale_created.get("status") == "saved", "stale care snapshot create status")

        active_latest = request_json(
            base_url,
            "GET",
            f"/care/snapshots/latest/{active['userId']}",
            access_token=active["auth"]["accessToken"],
            user_id=active["userId"],
        )
        stale_latest = request_json(
            base_url,
            "GET",
            f"/care/snapshots/latest/{stale['userId']}",
            access_token=stale["auth"]["accessToken"],
            user_id=stale["userId"],
        )
        missing_latest = request_json(
            base_url,
            "GET",
            f"/care/snapshots/latest/{empty['userId']}",
            access_token=empty["auth"]["accessToken"],
            user_id=empty["userId"],
            expected=404,
        )
        invalid_write = request_json(
            base_url,
            "POST",
            "/care/snapshots",
            payload={"userId": active["userId"], "snapshot": {"riskLevel": "stable", "summary": "字段不足"}},
            access_token=active["auth"]["accessToken"],
            user_id=active["userId"],
            expected=400,
        )

        active_payload = ((active_latest.get("item") or {}).get("snapshot") or {})
        stale_payload = ((stale_latest.get("item") or {}).get("snapshot") or {})
        require(active_payload.get("riskLevel") == "watch", "active latest risk level")
        require(run_suffix in str(active_payload.get("summary") or ""), "active latest summary marker")
        require(stale_payload.get("windowEnd") == STALE_CARE_WINDOW_END, "stale latest windowEnd")
        require(stale_payload.get("riskLevel") == "stable", "stale latest risk level")
        require(missing_latest.get("detail") == "care snapshot not found", "missing care detail")
        require(
            "missing required care snapshot fields" in str(invalid_write.get("detail") or ""),
            "invalid care should be rejected as failed-state boundary",
        )

        write_private_json(
            session_output,
            {
                "schemaVersion": SESSION_FIXTURE_SCHEMA_VERSION,
                "users": fixtures,
            },
        )
        write_private_json(
            cleanup_output,
            {
                "schemaVersion": CLEANUP_MANIFEST_SCHEMA_VERSION,
                "fixtures": [
                    {
                        "userId": item["userId"],
                        "fixtureMarker": item["fixtureMarker"],
                    }
                    for item in fixtures
                ],
            },
        )
        print(json.dumps(
            {
                "completed": True,
                "healthStore": health.get("store"),
                "activeUserId": active["userId"],
                "staleUserId": stale["userId"],
                "missingUserId": empty["userId"],
                "careActiveRiskLevel": active_payload.get("riskLevel"),
                "careStaleWindowEnd": stale_payload.get("windowEnd"),
                "careMissingStatus": missing_latest.get("detail"),
                "careInvalidStatus": invalid_write.get("detail"),
                "sessionFixtureSchemaVersion": SESSION_FIXTURE_SCHEMA_VERSION,
                "releasePolicyRevision": release_policy.get("policyRevision"),
            },
            ensure_ascii=False,
            sort_keys=True,
        ))
    except Exception:
        if store is not None:
            cleanup(store, fixtures)
        raise
    finally:
        if store is not None:
            store.close_pool()


def seed_failure_retry(
    base_url: str,
    marker: str,
    session_output: Path,
    cleanup_output: Path,
) -> None:
    """Issue one short-lived user session for the local unreachable-backend UIQA path.

    This mode deliberately does not call a protected care route and therefore
    does not require the deployed careDashboard closed-pilot canary. The iOS
    app is built with an unreachable backend URL and proves its authenticated
    failure/retry UI against this real server-issued principal.
    """
    store: PostgresStore | None = None
    fixtures: list[dict[str, Any]] = []
    try:
        health = request_json(base_url, "GET", "/health")
        require(health.get("status") == "ok", "health status")
        require(health.get("store") == "postgres", "failure retry UIQA fixture requires Postgres backend")

        run_suffix = "".join(ch if ch.isalnum() else "_" for ch in marker)[-24:] or secrets.token_hex(6)
        store = open_store()
        active = create_authenticated_user(store, run_suffix=run_suffix, role="failure-retry")
        fixtures = [active]
        write_private_json(
            session_output,
            {
                "schemaVersion": SESSION_FIXTURE_SCHEMA_VERSION,
                "users": [active],
            },
        )
        write_private_json(
            cleanup_output,
            {
                "schemaVersion": CLEANUP_MANIFEST_SCHEMA_VERSION,
                "fixtures": [
                    {
                        "userId": active["userId"],
                        "fixtureMarker": active["fixtureMarker"],
                    }
                ],
            },
        )
        print(json.dumps(
            {
                "completed": True,
                "healthStore": health.get("store"),
                "activeUserId": active["userId"],
                "sessionFixtureSchemaVersion": SESSION_FIXTURE_SCHEMA_VERSION,
                "fixtureMode": "failureRetryOnly",
            },
            ensure_ascii=False,
            sort_keys=True,
        ))
    except Exception:
        if store is not None:
            cleanup(store, fixtures)
        raise
    finally:
        if store is not None:
            store.close_pool()


def clean(cleanup_input: Path) -> None:
    payload = json.loads(cleanup_input.read_text(encoding="utf-8"))
    require(payload.get("schemaVersion") == CLEANUP_MANIFEST_SCHEMA_VERSION, "cleanup manifest schema mismatch")
    fixtures = payload.get("fixtures")
    require(isinstance(fixtures, list), "cleanup manifest fixtures missing")
    store = open_store()
    try:
        cleaned_user_ids = cleanup(
            store,
            [item for item in fixtures if isinstance(item, dict)],
        )
        print(
            json.dumps(
                {
                    "completed": True,
                    "cleanedUserIds": cleaned_user_ids,
                    "cleanupVerification": "fixtureUsersAbsent",
                },
                ensure_ascii=False,
                sort_keys=True,
            )
        )
    finally:
        store.close_pool()


def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit(
            "Usage: backend-care-state-uiqa-fixtures.py seed|seed-failure-retry <base-url> <marker> <session-output> <cleanup-output> | clean <cleanup-input>"
        )
    command = sys.argv[1].strip().lower()
    if command == "seed" and len(sys.argv) == 6:
        seed(
            sys.argv[2].rstrip("/"),
            sys.argv[3],
            Path(sys.argv[4]),
            Path(sys.argv[5]),
        )
        return
    if command == "seed-failure-retry" and len(sys.argv) == 6:
        seed_failure_retry(
            sys.argv[2].rstrip("/"),
            sys.argv[3],
            Path(sys.argv[4]),
            Path(sys.argv[5]),
        )
        return
    if command == "clean" and len(sys.argv) == 3:
        clean(Path(sys.argv[2]))
        return
    raise SystemExit("invalid fixture command")


if __name__ == "__main__":
    main()
