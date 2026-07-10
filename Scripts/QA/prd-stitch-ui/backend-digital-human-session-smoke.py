#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Optional


if len(sys.argv) < 3:
    raise SystemExit("Usage: backend-digital-human-session-smoke.py <user-id> <marker>")

BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
USER_ID = sys.argv[1]
MARKER = sys.argv[2]

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


def main() -> None:
    health = request_json("GET", "/health", auth=False)
    runtime = request_json("GET", "/config/runtime")
    assert_equal(health.get("status"), "ok", "health status")
    assert_equal(health.get("store"), "postgres", "deployed store")

    digital_human = runtime.get("digitalHuman") or {}
    assert_equal(digital_human.get("provider"), "tencent", "runtime digitalHuman provider")
    assert_equal(digital_human.get("providerMode"), "cloudRender", "runtime digitalHuman providerMode")
    assert_equal(digital_human.get("realProviderReady"), True, "runtime realProviderReady")
    assert_equal(digital_human.get("sdkAuthMode"), "appkeyAccessToken", "runtime sdkAuthMode")
    assert_equal(digital_human.get("sdkAdapterLinked"), True, "runtime sdkAdapterLinked")
    assert_true(
        digital_human.get("assetMode") in ("asset", "project"),
        "runtime assetMode must be asset or project",
    )
    assert_equal(
        digital_human.get("requiresBackendIssuedCredential"),
        True,
        "runtime requiresBackendIssuedCredential",
    )
    assert_equal(
        digital_human.get("defaultReleaseVisible"),
        False,
        "runtime defaultReleaseVisible",
    )
    session_lease_capability = digital_human.get("sessionLease") or {}
    assert_equal(session_lease_capability.get("enabled"), True, "runtime session lease enabled")
    assert_true(session_lease_capability.get("ttlSeconds", 0) > 0, "runtime session lease ttlSeconds")
    assert_true(
        session_lease_capability.get("heartbeatIntervalSeconds", 0) > 0,
        "runtime session lease heartbeatIntervalSeconds",
    )
    assert_equal(
        session_lease_capability.get("conflictStatusCode"),
        409,
        "runtime session lease conflictStatusCode",
    )

    session_payload = {
        "userId": USER_ID,
        "personaId": f"persona_digital_human_{MARKER}",
        "scene": "echo",
        "deviceId": "deployed-contract-smoke",
        "lifecycleMode": "sunlight",
    }
    session = request_json("POST", "/digital-human/sessions", session_payload)
    assert_equal(session.get("provider"), "tencent", "session provider")
    assert_equal(session.get("providerMode"), "cloudRender", "session providerMode")
    assert_equal(session.get("personaId"), session_payload["personaId"], "session personaId")
    assert_equal(session.get("scene"), "echo", "session scene")
    assert_equal(session.get("lifecycleMode"), "sunlight", "session lifecycleMode")
    assert_equal(session.get("driveMode"), "streamText", "session driveMode")
    assert_equal(session.get("alphaEnabled"), True, "session alphaEnabled")

    credential = session.get("credential") or {}
    assert_equal(credential.get("mode"), "backend-issued-tencent-cloud", "credential mode")
    assert_true(credential.get("expiresAt"), "credential expiresAt")
    assert_true(credential.get("appkey"), "credential appkey")
    assert_true(credential.get("accesstoken"), "credential accesstoken")

    has_asset = bool(session.get("providerAssetId"))
    has_project = bool(session.get("providerProjectId"))
    assert_true(has_asset or has_project, "session must return providerAssetId or providerProjectId")

    fallback = session.get("fallback") or {}
    assert_equal(fallback.get("mode"), "none", "session fallback mode")

    lease = session.get("lease") or {}
    assert_equal(lease.get("status"), "active", "session lease status")
    assert_true(lease.get("heartbeatEndpoint"), "session lease heartbeatEndpoint")
    assert_true(lease.get("releaseEndpoint"), "session lease releaseEndpoint")

    reused_session = request_json("POST", "/digital-human/sessions", session_payload)
    assert_equal(reused_session.get("sessionId"), session.get("sessionId"), "same context session reuse")
    assert_equal((reused_session.get("lease") or {}).get("reused"), True, "same context lease reused")

    competing_payload = dict(session_payload)
    competing_payload["deviceId"] = "deployed-contract-smoke-competitor"
    capacity_conflict = request_json(
        "POST",
        "/digital-human/sessions",
        competing_payload,
        expected=409,
    )
    conflict_detail = capacity_conflict.get("detail") or {}
    assert_equal(
        conflict_detail.get("code"),
        "digital_human_session_capacity_exhausted",
        "competing device capacity conflict",
    )

    heartbeat = request_json(
        "POST",
        lease["heartbeatEndpoint"],
        {"userId": USER_ID, "deviceId": session_payload["deviceId"]},
    )
    assert_equal(heartbeat.get("status"), "active", "session heartbeat status")

    release = request_json(
        "POST",
        lease["releaseEndpoint"],
        {
            "userId": USER_ID,
            "deviceId": session_payload["deviceId"],
            "reason": "deployedContractSmokeCompleted",
        },
    )
    assert_true(release.get("status") in ("released", "alreadyReleased"), "session release status")

    next_session = request_json("POST", "/digital-human/sessions", competing_payload)
    next_lease = next_session.get("lease") or {}
    assert_equal(next_lease.get("status"), "active", "released capacity can be reacquired")
    next_release = request_json(
        "POST",
        next_lease["releaseEndpoint"],
        {
            "userId": USER_ID,
            "deviceId": competing_payload["deviceId"],
            "reason": "deployedContractSmokeCleanup",
        },
    )
    assert_true(next_release.get("status") in ("released", "alreadyReleased"), "cleanup release status")

    silent = request_json(
        "POST",
        "/digital-human/sessions",
        {
            "userId": USER_ID,
            "personaId": f"persona_silent_{MARKER}",
            "scene": "echo",
            "deviceId": "deployed-contract-smoke",
            "lifecycleMode": "silent",
        },
        expected=409,
    )
    assert_true("silent mode" in str(silent.get("detail")), "silent mode must be rejected")

    result = {
        "completed": True,
        "baseURL": BASE_URL,
        "token": "configured, value intentionally omitted",
        "health": health,
        "runtimeDigitalHuman": {
            "provider": digital_human.get("provider"),
            "providerMode": digital_human.get("providerMode"),
            "realProviderReady": digital_human.get("realProviderReady"),
            "sdkAuthMode": digital_human.get("sdkAuthMode"),
            "sdkAdapterLinked": digital_human.get("sdkAdapterLinked"),
            "assetMode": digital_human.get("assetMode"),
            "defaultReleaseVisible": digital_human.get("defaultReleaseVisible"),
            "sessionLeaseEnabled": session_lease_capability.get("enabled"),
            "sessionLeaseTTLSeconds": session_lease_capability.get("ttlSeconds"),
        },
        "session": {
            "sessionId": session.get("sessionId"),
            "providerMode": session.get("providerMode"),
            "credentialMode": credential.get("mode"),
            "credentialAppkey": "configured, value intentionally omitted",
            "credentialAccessToken": "configured, value intentionally omitted",
            "hasProviderAssetId": has_asset,
            "hasProviderProjectId": has_project,
            "fallbackMode": fallback.get("mode"),
            "leaseStatus": lease.get("status"),
            "leaseReused": (reused_session.get("lease") or {}).get("reused"),
            "heartbeatStatus": heartbeat.get("status"),
            "releaseStatus": release.get("status"),
            "capacityConflictCode": conflict_detail.get("code"),
            "capacityReacquired": next_lease.get("status") == "active",
        },
        "silentModeRejected": True,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
