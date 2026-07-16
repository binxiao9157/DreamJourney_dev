#!/usr/bin/env python3
import json
import os
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


def request_json(method, path, payload=None, expected=200, *, access_token=None, backend_token=None):
    headers = {"Accept": "application/json"}
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"
    if backend_token:
        headers["X-DreamJourney-Api-Token"] = backend_token
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
        with urllib.request.urlopen(request, timeout=12) as response:
            status = response.status
            response_headers = dict(response.headers.items())
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        status = error.code
        response_headers = dict(error.headers.items())
        body = error.read().decode("utf-8", errors="replace")
    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body[:300]}")
    return (json.loads(body) if body else {}), response_headers


def header(headers, name):
    return next((value for key, value in headers.items() if key.lower() == name.lower()), None)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    suffix = str(int(time.time()))[-8:]
    phone = f"139{suffix}"
    backend_headers = BACKEND_TOKEN or None

    login, _ = request_json(
        "POST",
        "/auth/login",
        {"phone": phone, "nickname": "auth smoke", "password": "smoke-password-123"},
        backend_token=backend_headers,
    )
    auth = login.get("auth") or {}
    access_token = auth.get("accessToken")
    refresh_token = auth.get("refreshToken")
    user_id = (login.get("user") or {}).get("id")
    require(str(access_token).startswith("dja_"), "login must return opaque access token")
    require(str(refresh_token).startswith("djr_"), "login must return opaque refresh token")
    require(auth.get("userId") == user_id, "auth principal must match login user")

    runtime, runtime_headers = request_json(
        "GET",
        "/config/runtime",
        access_token=access_token,
    )
    require(header(runtime_headers, "X-DreamJourney-Auth-Principal") == "user", "user principal header missing")
    require((runtime.get("auth") or {}).get("ownershipMode") == "shadow", "runtime must advertise shadow mode")

    _, own_headers = request_json(
        "POST",
        "/profile",
        {"userId": user_id, "nickname": "auth smoke"},
        access_token=access_token,
    )
    require(header(own_headers, "X-DreamJourney-Ownership-Decision") == "match", "own profile must match")

    _, shadow_headers = request_json(
        "POST",
        "/profile",
        {"userId": f"shadow-other-{suffix}", "nickname": "shadow evidence"},
        expected=403,
        access_token=access_token,
    )
    require(header(shadow_headers, "X-DreamJourney-Ownership-Decision") == "mismatch", "shadow mismatch must be observable")
    require(header(shadow_headers, "X-DreamJourney-Authorization-Decision") == "deny", "classified owner mismatch must be denied")
    require(header(shadow_headers, "X-DreamJourney-Authorization-Reason") == "ownerPrincipalMismatch", "owner mismatch reason missing")

    refreshed, _ = request_json(
        "POST",
        "/auth/refresh",
        {"refreshToken": refresh_token},
        backend_token=backend_headers,
    )
    new_auth = refreshed.get("auth") or {}
    new_access_token = new_auth.get("accessToken")
    require(new_access_token and new_access_token != access_token, "refresh must rotate access token")
    request_json("GET", "/config/runtime", expected=401, access_token=access_token)
    request_json(
        "POST",
        "/auth/refresh",
        {"refreshToken": refresh_token},
        expected=401,
        backend_token=backend_headers,
    )

    request_json(
        "POST",
        "/auth/logout",
        {"refreshToken": new_auth.get("refreshToken")},
        access_token=new_access_token,
    )
    request_json("GET", "/config/runtime", expected=401, access_token=new_access_token)

    print(json.dumps({
        "baseURL": BASE_URL,
        "completed": True,
        "contractVersion": auth.get("contractVersion"),
        "ownershipMode": "shadow",
        "principalBoundMismatchRejected": True,
        "refreshRotated": True,
        "refreshReplayRejected": True,
        "logoutRevoked": True,
        "tokensRedacted": True,
    }, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
