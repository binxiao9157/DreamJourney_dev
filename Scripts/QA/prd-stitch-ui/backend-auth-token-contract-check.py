#!/usr/bin/env python3
"""Compatibility smoke for public, user, and machine route boundaries.

The second CLI argument is a server-only machine token. It must never be copied
into an iOS build artifact.
"""

import json
import sys
import urllib.error
import urllib.request


BASE_URL = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:3100").rstrip("/")
MACHINE_TOKEN = sys.argv[2] if len(sys.argv) > 2 else "dj-local-test-token"


def request_json(method, path, *, expected=200, token=None):
    headers = {"Accept": "application/json"}
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(f"{BASE_URL}{path}", headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=8) as response:
            status = response.status
            response_headers = {key.lower(): value for key, value in response.headers.items()}
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        status = error.code
        response_headers = {key.lower(): value for key, value in error.headers.items()}
        body = error.read().decode("utf-8", errors="replace")
    if status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body[:160]}")
    return (json.loads(body) if body else {}), response_headers


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def main():
    health, _ = request_json("GET", "/health")
    require(health.get("status") == "ok", "health must remain public")

    runtime, public_headers = request_json("GET", "/config/runtime")
    route_auth = ((runtime.get("auth") or {}).get("routeAuthentication") or {})
    require(route_auth.get("routeCount") == 64, "route auth inventory must pin 64 routes")
    require(route_auth.get("unclassifiedCount") == 0, "route auth inventory is incomplete")
    require(
        public_headers.get("x-dreamjourney-route-auth-reason") == "publicRoute",
        "runtime must use the explicit public route contract",
    )

    _, anonymous_headers = request_json(
        "GET",
        "/kb/snapshot/backend_auth_probe",
        expected=401,
    )
    require(
        anonymous_headers.get("x-dreamjourney-route-auth-reason") == "userPrincipalRequired",
        "anonymous business request must fail closed",
    )

    _, machine_business_headers = request_json(
        "GET",
        "/kb/snapshot/backend_auth_probe",
        expected=403,
        token=MACHINE_TOKEN,
    )
    require(
        machine_business_headers.get("x-dreamjourney-route-auth-reason") == "userPrincipalRequired",
        "machine credential must not impersonate a user",
    )

    observations, machine_headers = request_json(
        "GET",
        "/ops/release-policy/observations",
        token=MACHINE_TOKEN,
    )
    require(
        machine_headers.get("x-dreamjourney-auth-principal") == "machine",
        "server credential must resolve to a typed machine principal",
    )
    require("routeAuthentication" in observations, "route decision evidence is missing")

    print(json.dumps({
        "anonymousBusinessDenied": True,
        "completed": True,
        "machineBusinessDenied": True,
        "machineSystemAllowed": True,
        "publicRuntimeAllowed": True,
        "routeCount": route_auth.get("routeCount"),
        "tokensRedacted": True,
    }, ensure_ascii=True, sort_keys=True))


if __name__ == "__main__":
    main()
