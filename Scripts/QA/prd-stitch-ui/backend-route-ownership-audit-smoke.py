#!/usr/bin/env python3
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request


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
EXPECTED_ROUTE_COUNT = 173
MODE = os.getenv("ROUTE_OWNERSHIP_AUDIT_MODE", "full").strip()
OWNER_ACCESS_TOKEN = os.getenv("DREAMJOURNEY_ROUTE_AUDIT_OWNER_ACCESS_TOKEN", "").strip()
OWNER_USER_ID = os.getenv("DREAMJOURNEY_ROUTE_AUDIT_OWNER_USER_ID", "").strip()
ATTACKER_ACCESS_TOKEN = os.getenv("DREAMJOURNEY_ROUTE_AUDIT_ATTACKER_ACCESS_TOKEN", "").strip()
SENSITIVE_PATH_VALUES = set()


def safe_path(path):
    safe = re.sub(r"user_[A-Za-z0-9_-]+", "<user>", path)
    for value in SENSITIVE_PATH_VALUES:
        safe = safe.replace(value, "<user>")
    return safe


def request_json(method, path, payload=None, expected=200, *, access_token=None):
    headers = {"Accept": "application/json"}
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    elif BACKEND_TOKEN:
        headers["X-DreamJourney-Api-Token"] = BACKEND_TOKEN
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
        raise AssertionError(
            f"{method} {safe_path(path)} expected {expected}, got {status}: {body[:160]}"
        )
    return (json.loads(body) if body else {}), response_headers


def header(headers, name):
    return next((value for key, value in headers.items() if key.lower() == name.lower()), None)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def assert_denied(method, path, attacker_token, payload=None):
    _, headers = request_json(
        method,
        path,
        payload,
        expected=403,
        access_token=attacker_token,
    )
    require(header(headers, "X-DreamJourney-Ownership-Mode") == "shadow", "global mode must remain shadow")
    require(header(headers, "X-DreamJourney-Authorization-Decision") == "deny", "request must be denied")
    return str(header(headers, "X-DreamJourney-Authorization-Policy") or "")


def runtime_contract(*, access_token=None):
    runtime, runtime_headers = request_json(
        "GET",
        "/config/runtime",
        access_token=access_token,
    )
    policy = (runtime.get("auth") or {}).get("crossAccountPolicy") or {}
    audit = policy.get("routeOwnershipAudit") or {}
    require(policy.get("mode") == "shadow", "deployed global ownership mode must remain shadow")
    require(policy.get("productionEnforceReady") is False, "deployed runtime must not claim global enforce readiness")
    require(policy.get("principalBoundRouteEnforcement") is True, "principal-bound enforcement is missing")
    require(audit.get("routeCount") == EXPECTED_ROUTE_COUNT, "deployed route audit count mismatch")
    require(audit.get("unclassifiedCount") == 0, "deployed backend contains unclassified routes")
    identity_challenge = (runtime.get("auth") or {}).get("identityChallenge") or {}
    return runtime, runtime_headers, policy, audit, identity_challenge


def emit_runtime_only(*, policy, audit, identity_challenge):
    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": True,
        "scope": "runtimeOnly",
        "ownershipMode": policy.get("mode"),
        "principalBoundRouteEnforcement": True,
        "routeCount": audit.get("routeCount"),
        "unclassifiedCount": audit.get("unclassifiedCount"),
        "identityChallengeReady": identity_challenge.get("clientFlowEnabled") is True,
        "crossAccountVerified": False,
        "tokensRedacted": True,
    }, ensure_ascii=False, sort_keys=True))


def exit_blocked(*, reason, audit, identity_challenge):
    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": False,
        "status": "blocked",
        "reason": reason,
        "routeCount": audit.get("routeCount"),
        "identityChallengeReady": identity_challenge.get("clientFlowEnabled") is True,
        "crossAccountVerified": False,
        "tokensRedacted": True,
    }, ensure_ascii=False, sort_keys=True), file=sys.stderr)
    raise SystemExit(2)


def main():
    if MODE not in {"full", "runtimeOnly"}:
        raise AssertionError("ROUTE_OWNERSHIP_AUDIT_MODE must be full or runtimeOnly")

    _, runtime_headers, policy, audit, identity_challenge = runtime_contract()
    if MODE == "runtimeOnly":
        emit_runtime_only(
            policy=policy,
            audit=audit,
            identity_challenge=identity_challenge,
        )
        return

    if identity_challenge.get("clientFlowEnabled") is not True:
        exit_blocked(
            reason="identityChallengeUnavailable",
            audit=audit,
            identity_challenge=identity_challenge,
        )
    if not OWNER_ACCESS_TOKEN or not OWNER_USER_ID or not ATTACKER_ACCESS_TOKEN:
        exit_blocked(
            reason="v2UserCredentialsRequired",
            audit=audit,
            identity_challenge=identity_challenge,
        )
    require(OWNER_ACCESS_TOKEN != ATTACKER_ACCESS_TOKEN, "owner and attacker access tokens must differ")
    SENSITIVE_PATH_VALUES.add(OWNER_USER_ID)

    _, runtime_headers, policy, audit, _ = runtime_contract(access_token=OWNER_ACCESS_TOKEN)
    require(header(runtime_headers, "X-DreamJourney-Auth-Principal") == "user", "runtime user principal missing")
    suffix = str(int(time.time()))[-8:]

    _, own_headers = request_json(
        "POST",
        "/profile",
        {"userId": OWNER_USER_ID, "nickname": "route audit owner"},
        access_token=OWNER_ACCESS_TOKEN,
    )
    require(header(own_headers, "X-DreamJourney-Authorization-Decision") == "allowOwner", "owner profile must pass")

    path_policies = set()
    for path in [
        f"/profile/{OWNER_USER_ID}",
        f"/voice/profiles/{OWNER_USER_ID}",
        f"/kb/snapshot/{OWNER_USER_ID}",
        f"/kb/changes/{OWNER_USER_ID}?sinceRevision=0",
        f"/kb/source-ref-audit/{OWNER_USER_ID}",
        f"/archive/items/{OWNER_USER_ID}",
        f"/mailbox/letters/{OWNER_USER_ID}",
        f"/echo/delayed-replies/{OWNER_USER_ID}",
        f"/family/members/{OWNER_USER_ID}",
    ]:
        path_policies.add(assert_denied("GET", path, ATTACKER_ACCESS_TOKEN))

    body_policy = assert_denied(
        "POST",
        "/archive/items",
        ATTACKER_ACCESS_TOKEN,
        {"userId": OWNER_USER_ID, "id": f"denied-{suffix}", "kind": "text"},
    )
    knowledge_body_policy = assert_denied(
        "POST",
        "/kb/mutations",
        ATTACKER_ACCESS_TOKEN,
        {
            "userId": OWNER_USER_ID,
            "operationId": f"denied-{suffix}",
            "baseRevision": 0,
            "graph": {"facts": []},
        },
    )
    governance_body_policy = assert_denied(
        "POST",
        "/kb/governance/actions",
        ATTACKER_ACCESS_TOKEN,
        {
            "governanceSchemaVersion": 1,
            "userId": OWNER_USER_ID,
            "operationId": f"denied-governance-{suffix}",
            "baseRevision": 0,
            "action": {"kind": "reject", "entityType": "facts", "entityId": "denied"},
        },
    )
    system_policy = assert_denied(
        "POST",
        "/archive/time-letters/dispatch-due",
        ATTACKER_ACCESS_TOKEN,
        {"now": "2026-07-10T00:00:00Z", "limit": 1},
    )

    fingerprint = hashlib.sha256("|".join(sorted(path_policies)).encode("utf-8")).hexdigest()[:12]
    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": True,
        "scope": "full",
        "ownershipMode": policy.get("mode"),
        "principalBoundRouteEnforcement": True,
        "routeCount": audit.get("routeCount"),
        "unclassifiedCount": audit.get("unclassifiedCount"),
        "ownerWriteAllowed": True,
        "ownerPathDenyCount": 8,
        "ownerPathPolicyFingerprint": fingerprint,
        "ownerBodyDenied": body_policy == "archiveOwner",
        "knowledgeOwnerBodyDenied": knowledge_body_policy == "knowledgeOwner",
        "knowledgeGovernanceOwnerBodyDenied": governance_body_policy == "knowledgeOwner",
        "systemOnlyDenied": system_policy == "systemTimeLetterDispatch",
        "globalDispatchInvoked": False,
        "identifiersRedacted": True,
        "tokensRedacted": True,
    }, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
