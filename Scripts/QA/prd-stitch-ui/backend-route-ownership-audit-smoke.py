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


def safe_path(path):
    return re.sub(r"user_[A-Za-z0-9_-]+", "<user>", path)


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


def login(phone, nickname):
    body, _ = request_json(
        "POST",
        "/auth/login",
        {"phone": phone, "nickname": nickname, "password": "ownership-smoke-123"},
    )
    token = str((body.get("auth") or {}).get("accessToken") or "")
    user_id = str((body.get("user") or {}).get("id") or "")
    require(token.startswith("dja_"), "login must return an opaque access token")
    require(user_id, "login must return a user id")
    return {"token": token, "userId": user_id}


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


def main():
    suffix = str(int(time.time()))[-8:]
    owner = login(f"132{suffix}", "ownership owner")
    attacker = login(f"133{suffix}", "ownership attacker")

    runtime, runtime_headers = request_json("GET", "/config/runtime", access_token=owner["token"])
    policy = (runtime.get("auth") or {}).get("crossAccountPolicy") or {}
    audit = policy.get("routeOwnershipAudit") or {}
    require(policy.get("mode") == "shadow", "deployed global ownership mode must remain shadow")
    require(policy.get("productionEnforceReady") is False, "deployed runtime must not claim global enforce readiness")
    require(policy.get("principalBoundRouteEnforcement") is True, "principal-bound enforcement is missing")
    require(audit.get("routeCount") == 68, "deployed route audit count mismatch")
    require(audit.get("unclassifiedCount") == 0, "deployed backend contains unclassified routes")
    require(header(runtime_headers, "X-DreamJourney-Auth-Principal") == "user", "runtime user principal missing")

    _, own_headers = request_json(
        "POST",
        "/profile",
        {"userId": owner["userId"], "nickname": "ownership owner"},
        access_token=owner["token"],
    )
    require(header(own_headers, "X-DreamJourney-Authorization-Decision") == "allowOwner", "owner profile must pass")

    path_policies = set()
    for path in [
        f"/profile/{owner['userId']}",
        f"/voice/profiles/{owner['userId']}",
        f"/kb/snapshot/{owner['userId']}",
        f"/kb/changes/{owner['userId']}?sinceRevision=0",
        f"/kb/source-ref-audit/{owner['userId']}",
        f"/archive/items/{owner['userId']}",
        f"/mailbox/letters/{owner['userId']}",
        f"/echo/delayed-replies/{owner['userId']}",
        f"/family/members/{owner['userId']}",
    ]:
        path_policies.add(assert_denied("GET", path, attacker["token"]))

    body_policy = assert_denied(
        "POST",
        "/archive/items",
        attacker["token"],
        {"userId": owner["userId"], "id": f"denied-{suffix}", "kind": "text"},
    )
    knowledge_body_policy = assert_denied(
        "POST",
        "/kb/mutations",
        attacker["token"],
        {
            "userId": owner["userId"],
            "operationId": f"denied-{suffix}",
            "baseRevision": 0,
            "graph": {"facts": []},
        },
    )
    governance_body_policy = assert_denied(
        "POST",
        "/kb/governance/actions",
        attacker["token"],
        {
            "governanceSchemaVersion": 1,
            "userId": owner["userId"],
            "operationId": f"denied-governance-{suffix}",
            "baseRevision": 0,
            "action": {"kind": "reject", "entityType": "facts", "entityId": "denied"},
        },
    )
    system_policy = assert_denied(
        "POST",
        "/archive/time-letters/dispatch-due",
        attacker["token"],
        {"now": "2026-07-10T00:00:00Z", "limit": 1},
    )

    fingerprint = hashlib.sha256("|".join(sorted(path_policies)).encode("utf-8")).hexdigest()[:12]
    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": True,
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
