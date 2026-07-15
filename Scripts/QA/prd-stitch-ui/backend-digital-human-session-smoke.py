#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Mapping, Optional, Tuple


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


def request_json_response(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    expected: int = 200,
    timeout: int = 45,
) -> Tuple[Dict[str, Any], Mapping[str, str]]:
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
            response_headers = response.headers
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        if error.code == expected:
            return (json.loads(body) if body else {}, error.headers)
        raise AssertionError(f"{method} {path} expected {expected}, got {error.code}: {body}") from error
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body}")
    return (json.loads(body) if body else {}, response_headers)


def request_json(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    expected: int = 200,
    timeout: int = 45,
) -> Dict[str, Any]:
    body, _ = request_json_response(
        method,
        path,
        payload,
        auth=auth,
        expected=expected,
        timeout=timeout,
    )
    return body


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def assert_true(value: Any, message: str) -> None:
    if not value:
        raise AssertionError(message)


def assert_no_store(headers: Mapping[str, str], message: str) -> None:
    cache_control = headers.get("Cache-Control", "")
    assert_true("no-store" in cache_control.lower(), f"{message}: Cache-Control must include no-store")


def assert_value_free(payload: Dict[str, Any], message: str) -> None:
    forbidden_keys = {"appkey", "accesstoken", "access_token", "secret", "secretkey"}

    def walk(value: Any, path: str) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                if key.lower() in forbidden_keys:
                    raise AssertionError(f"{message}: forbidden credential key at {path}.{key}")
                walk(child, f"{path}.{key}")
        elif isinstance(value, list):
            for index, child in enumerate(value):
                walk(child, f"{path}[{index}]")

    walk(payload, "response")


def main() -> None:
    health = request_json("GET", "/health", auth=False)
    runtime, runtime_headers = request_json_response("GET", "/config/runtime")
    assert_equal(health.get("status"), "ok", "health status")
    assert_equal(health.get("store"), "postgres", "deployed store")
    assert_no_store(runtime_headers, "runtime response")
    assert_value_free(runtime, "runtime response")

    digital_human = runtime.get("digitalHuman") or {}
    assert_equal(digital_human.get("provider"), "tencent", "runtime digitalHuman provider")
    assert_equal(digital_human.get("providerMode"), "blocked", "runtime digitalHuman providerMode")
    assert_equal(digital_human.get("realProviderReady"), False, "runtime realProviderReady")
    assert_equal(
        digital_human.get("sdkAuthMode"),
        "staticProjectCredentialUnsupportedOnMobile",
        "runtime sdkAuthMode",
    )
    assert_equal(digital_human.get("sdkAdapterLinked"), False, "runtime sdkAdapterLinked")
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
    assert_equal(digital_human.get("credentialMode"), "blockedStaticCredential", "runtime credentialMode")
    assert_equal(digital_human.get("accessPath"), "textFallback", "runtime accessPath")
    assert_equal(digital_human.get("mobileDirectAllowed"), False, "runtime mobileDirectAllowed")
    assert_equal(digital_human.get("brokerStatus"), "providerContractNotVerified", "runtime brokerStatus")
    assert_equal(digital_human.get("releaseVisible"), False, "runtime releaseVisible")
    assert_equal(digital_human.get("fallbackMode"), "text", "runtime fallbackMode")
    assert_equal(
        (digital_human.get("credentialBroker") or {}).get("status"),
        "providerContractNotVerified",
        "runtime credential broker status",
    )
    required_credential_properties = ["scope", "ttl", "audience", "revocation"]
    runtime_receipt = digital_human.get("decisionReceipt") or {}
    assert_equal(runtime_receipt.get("decision"), "keepDirectMobileClosed", "runtime decision")
    assert_equal(
        runtime_receipt.get("missingProperties"),
        required_credential_properties,
        "runtime missing credential properties",
    )
    session_lease_capability = digital_human.get("sessionLease") or {}
    assert_equal(session_lease_capability.get("enabled"), False, "runtime session lease enabled")
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
    blocked_session, session_headers = request_json_response(
        "POST",
        "/digital-human/sessions",
        session_payload,
        expected=503,
    )
    assert_no_store(session_headers, "digital-human session response")
    assert_value_free(blocked_session, "digital-human session response")
    blocked_detail = blocked_session.get("detail") or {}
    assert_equal(blocked_detail.get("code"), "digital_human_credential_broker_unavailable", "blocked code")
    assert_equal(blocked_detail.get("provider"), "tencent", "blocked provider")
    assert_equal(blocked_detail.get("credentialMode"), "blockedStaticCredential", "blocked credential mode")
    assert_equal(blocked_detail.get("accessPath"), "textFallback", "blocked access path")
    assert_equal(blocked_detail.get("mobileDirectAllowed"), False, "blocked mobileDirectAllowed")
    assert_equal(blocked_detail.get("brokerStatus"), "providerContractNotVerified", "blocked brokerStatus")
    assert_equal(blocked_detail.get("providerReady"), False, "blocked providerReady")
    assert_equal(blocked_detail.get("releaseVisible"), False, "blocked releaseVisible")
    assert_equal(blocked_detail.get("retryable"), False, "blocked retryable")
    assert_equal(blocked_detail.get("fallbackMode"), "text", "blocked fallbackMode")
    blocked_receipt = blocked_detail.get("decisionReceipt") or {}
    assert_equal(blocked_receipt.get("decision"), "keepDirectMobileClosed", "blocked decision")
    assert_equal(
        blocked_receipt.get("missingProperties"),
        required_credential_properties,
        "blocked missing credential properties",
    )
    assert_true("expiresAt" not in blocked_detail, "blocked response must not invent expiresAt")
    assert_true("expiresInSeconds" not in blocked_detail, "blocked response must not invent expiresInSeconds")
    assert_equal(blocked_detail.get("contractVersion"), 4, "blocked contractVersion")

    repeated_session = request_json(
        "POST",
        "/digital-human/sessions",
        session_payload,
        expected=503,
    )
    assert_equal(
        (repeated_session.get("detail") or {}).get("code"),
        "digital_human_credential_broker_unavailable",
        "repeated request stays blocked",
    )
    assert_value_free(repeated_session, "repeated digital-human session response")

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
            "credentialMode": digital_human.get("credentialMode"),
            "credentialBrokerStatus": (digital_human.get("credentialBroker") or {}).get("status"),
            "fallbackMode": digital_human.get("fallbackMode"),
            "defaultReleaseVisible": digital_human.get("defaultReleaseVisible"),
            "sessionLeaseEnabled": session_lease_capability.get("enabled"),
            "sessionLeaseTTLSeconds": session_lease_capability.get("ttlSeconds"),
        },
        "session": {
            "status": "blocked",
            "code": blocked_detail.get("code"),
            "credentialMode": blocked_detail.get("credentialMode"),
            "providerReady": blocked_detail.get("providerReady"),
            "releaseVisible": blocked_detail.get("releaseVisible"),
            "retryable": blocked_detail.get("retryable"),
            "fallbackMode": blocked_detail.get("fallbackMode"),
            "contractVersion": blocked_detail.get("contractVersion"),
            "responseNoStore": "no-store" in session_headers.get("Cache-Control", "").lower(),
            "valueFree": True,
            "repeatedRequestStayedBlocked": True,
        },
        "silentModeRejected": True,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
