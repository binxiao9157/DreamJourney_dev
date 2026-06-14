#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request
from typing import Any, Dict, Iterable, Optional

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Scripts"))
from backend_repo import resolve_backend_repo  # noqa: E402

BACKEND = resolve_backend_repo(ROOT)
SELF_TEST_TOKEN = "phase1-smoke-secret"


class SmokeFailure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SmokeFailure(message)


def assert_no_secret_leaks(payload: Any, secrets: Iterable[Optional[str]]) -> None:
    serialized = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    for secret in secrets:
        if not secret:
            continue
        require(secret not in serialized, "response leaked a configured secret")
    suspicious_tokens = ["sk-", "x-api-key: ", "Bearer phase1", "Bearer volc", "Bearer deepseek"]
    for token in suspicious_tokens:
        require(token not in serialized, f"response contains suspicious credential marker: {token}")


def assert_runtime_shape(payload: Dict[str, Any]) -> None:
    require("capabilities" in payload and isinstance(payload["capabilities"], dict), "runtime should expose capabilities")
    for name, value in payload["capabilities"].items():
        allowed = isinstance(value, bool) or value in {"configured", "missing"}
        require(allowed, f"runtime capability {name} should be bool or configured/missing")
    require("privacy" in payload and isinstance(payload["privacy"], dict), "runtime should expose privacy policy labels")


def auth_headers(token: str) -> Dict[str, str]:
    return {
        "Authorization": f"Bearer {token}",
        "X-DreamJourney-API-Token": token,
    }


def run_self_test() -> None:
    os.environ["STORE_BACKEND"] = "memory"
    os.environ["BACKEND_API_TOKEN"] = SELF_TEST_TOKEN
    os.environ["APP_ENV"] = "phase1-smoke-self-test"
    os.environ.setdefault("PUBLIC_BASE_URL", "https://dreamjourney-api.liftora.cn")

    sys.path.insert(0, str(BACKEND))
    from fastapi.testclient import TestClient  # type: ignore
    from app.main import app  # type: ignore

    client = TestClient(app)
    health = client.get("/health")
    missing = client.get("/config/runtime")
    invalid = client.get("/config/runtime", headers={"Authorization": "Bearer wrong-secret"})
    bearer = client.get("/config/runtime", headers={"Authorization": f"Bearer {SELF_TEST_TOKEN}"})
    explicit = client.get("/config/runtime", headers={"X-DreamJourney-API-Token": SELF_TEST_TOKEN})

    require(health.status_code == 200, f"/health should stay public, got {health.status_code}")
    require(missing.status_code == 401, f"/config/runtime without token should be 401, got {missing.status_code}")
    require(invalid.status_code == 401, f"/config/runtime with invalid token should be 401, got {invalid.status_code}")
    require(bearer.status_code == 200, f"/config/runtime with bearer token should be 200, got {bearer.status_code}")
    require(explicit.status_code == 200, f"/config/runtime with DreamJourney token header should be 200, got {explicit.status_code}")

    runtime = bearer.json()
    assert_runtime_shape(runtime)
    assert_no_secret_leaks(runtime, [SELF_TEST_TOKEN])
    print("BackendAuthenticatedSmoke self-test passed")


def request_json(
    base_url: str,
    method: str,
    path: str,
    *,
    token: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None,
) -> tuple[int, Dict[str, Any]]:
    data = None if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/{path.lstrip('/')}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    if token:
        for key, value in auth_headers(token).items():
            request.add_header(key, value)

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            body = response.read().decode("utf-8")
            return response.status, json.loads(body or "{}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8")
        try:
            parsed = json.loads(body or "{}")
        except json.JSONDecodeError:
            parsed = {"raw": body}
        return exc.code, parsed


def run_remote_smoke(base_url: str, token: str) -> None:
    secret_candidates = [
        token,
        os.getenv("DREAMJOURNEY_BACKEND_API_TOKEN"),
        os.getenv("BACKEND_API_TOKEN"),
        os.getenv("DEEPSEEK_API_KEY"),
        os.getenv("VOLCENGINE_API_KEY"),
        os.getenv("AMAP_WEB_SERVICE_KEY"),
    ]

    health_status, health = request_json(base_url, "GET", "/health")
    require(health_status == 200, f"remote /health should be 200, got {health_status}: {health}")

    missing_status, _ = request_json(base_url, "GET", "/config/runtime")
    require(
        missing_status == 401,
        f"remote /config/runtime without token should be 401 when DREAMJOURNEY_BACKEND_API_TOKEN is supplied, got {missing_status}",
    )

    runtime_status, runtime = request_json(base_url, "GET", "/config/runtime", token=token)
    require(runtime_status == 200, f"remote /config/runtime with token should be 200, got {runtime_status}: {runtime}")
    assert_runtime_shape(runtime)
    assert_no_secret_leaks(runtime, secret_candidates)

    analysis_status, analysis = request_json(
        base_url,
        "POST",
        "/archive/image-analysis?dryRun=true",
        token=token,
        payload={
            "userId": "_phase1_smoke_user",
            "archiveItemId": "_phase1_smoke_archive_item",
            "imageBase64": "aGVsbG8=",
            "privacyMetadata": {
                "scope": "generationAllowed",
                "sourceRefs": [
                    {
                        "kind": "archiveItem",
                        "id": "_phase1_smoke_archive_item",
                        "title": "phase1 smoke image",
                    }
                ],
            },
        },
    )
    require(analysis_status == 200, f"remote image dryRun should be 200, got {analysis_status}: {analysis}")
    assert_no_secret_leaks(analysis, secret_candidates)

    sync_status, sync = request_json(
        base_url,
        "POST",
        "/kb/sync",
        token=token,
        payload={"userId": "_phase1_smoke_user", "graph": {"people": [], "places": [], "events": [], "facts": []}},
    )
    require(sync_status == 200, f"remote kb sync should be 200, got {sync_status}: {sync}")

    snapshot_status, snapshot = request_json(
        base_url,
        "GET",
        "/kb/snapshot/_phase1_smoke_user",
        token=token,
    )
    require(snapshot_status == 200, f"remote kb snapshot should be 200, got {snapshot_status}: {snapshot}")
    assert_no_secret_leaks(snapshot, secret_candidates)
    print(f"BackendAuthenticatedSmoke remote passed: {base_url.rstrip('/')}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Phase1 authenticated backend smoke.")
    parser.add_argument("--remote", action="store_true", help="Require and run remote smoke using DREAMJOURNEY_* env vars.")
    args = parser.parse_args()

    run_self_test()

    base_url = (os.getenv("DREAMJOURNEY_BACKEND_BASE_URL") or "").strip()
    token = (os.getenv("DREAMJOURNEY_BACKEND_API_TOKEN") or "").strip()
    if base_url and token:
        run_remote_smoke(base_url, token)
    elif args.remote:
        raise SmokeFailure("remote smoke requires DREAMJOURNEY_BACKEND_BASE_URL and DREAMJOURNEY_BACKEND_API_TOKEN")
    else:
        print("BackendAuthenticatedSmoke remote skipped: DREAMJOURNEY_BACKEND_BASE_URL/API_TOKEN not set")


if __name__ == "__main__":
    try:
        main()
    except SmokeFailure as exc:
        print(f"BackendAuthenticatedSmoke failed: {exc}", file=sys.stderr)
        sys.exit(1)
