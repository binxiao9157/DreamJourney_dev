#!/usr/bin/env python3
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional


if len(sys.argv) < 4:
    raise SystemExit("Usage: backend-family-voice-contract-smoke.py <app-root> <user-id> <marker>")

APP_ROOT = Path(sys.argv[1])
BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
USER_ID = sys.argv[2]
MARKER = re.sub(r"[^A-Za-z0-9_-]", "_", sys.argv[3])

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
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
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


def family_member_payload(mode: str, label: str) -> Dict[str, Any]:
    return {
        "userId": USER_ID,
        "name": f"{label}测试成员",
        "relation": "家人",
        "phone": "13900001111",
        "personaScope": "family",
        "digitalHumanId": f"family_{mode}_{MARKER}",
        "digitalHumanMode": mode,
    }


def assert_family_member_contract(member: Dict[str, Any], mode: str, label: str) -> Dict[str, Any]:
    assert_equal(member.get("personaScope"), "family", f"{mode} personaScope")
    assert_equal(member.get("digitalHumanMode"), mode, f"{mode} digitalHumanMode")
    assert_equal(member.get("digitalHumanModeLabel"), label, f"{mode} digitalHumanModeLabel")
    assert_equal(member.get("backendContractMode"), "mockFamilyPersona", f"{mode} backendContractMode")
    assert_equal(member.get("familyPersonaContractVersion"), 1, f"{mode} familyPersonaContractVersion")
    assert_equal(member.get("defaultReleaseVisible"), False, f"{mode} defaultReleaseVisible")
    assert_true(member.get("digitalHumanId"), f"{mode} digitalHumanId")
    return {
        "id": member.get("id"),
        "digitalHumanId": member.get("digitalHumanId"),
        "digitalHumanMode": member.get("digitalHumanMode"),
        "digitalHumanModeLabel": member.get("digitalHumanModeLabel"),
        "defaultReleaseVisible": member.get("defaultReleaseVisible"),
    }


def main() -> None:
    health = request_json("GET", "/health", auth=False)
    runtime = request_json("GET", "/config/runtime")
    assert_equal(health.get("status"), "ok", "health status")
    assert_equal(health.get("store"), "postgres", "deployed store")
    archive_runtime = runtime.get("archive") or {}
    assert_equal(archive_runtime.get("storageProvider"), "mockObjectStorage", "archive storage provider")
    assert_equal(archive_runtime.get("providerSwitchContractVersion"), 1, "archive provider switch contract")

    family_results = []
    for mode, label in [("sunlight", "阳光"), ("star", "星辰"), ("silent", "静默")]:
        created = request_json("POST", "/family/invite", family_member_payload(mode, label))
        member = created.get("member")
        if not isinstance(member, dict):
            raise AssertionError("/family/invite response missing member")
        family_results.append(assert_family_member_contract(member, mode, label))

    listed = request_json("GET", f"/family/members/{urllib.parse.quote(USER_ID)}")
    listed_modes = {
        item.get("digitalHumanMode"): item
        for item in listed.get("members", [])
        if isinstance(item, dict) and str(item.get("digitalHumanId") or "").endswith(MARKER)
    }
    for mode, label in [("sunlight", "阳光"), ("star", "星辰"), ("silent", "静默")]:
        assert_true(mode in listed_modes, f"listed family member missing {mode}")
        assert_family_member_contract(listed_modes[mode], mode, label)

    invalid_response = request_json(
        "POST",
        "/family/invite",
        {
            "userId": USER_ID,
            "name": "非法状态成员",
            "relation": "家人",
            "phone": "13900001111",
            "digitalHumanMode": "storm",
        },
        expected=400,
    )

    voice_profile_id = f"voice_profile_{MARKER}"
    voice_payload = {
        "userId": USER_ID,
        "voiceProfileId": voice_profile_id,
        "sampleStatus": "pending",
        "sampleCount": 1,
        "authorizationConfirmed": True,
        "personaScope": "family",
        "digitalHumanId": f"family_star_{MARKER}",
        "privacyMetadata": {"scope": "generationAllowed"},
    }
    voice_created = request_json("POST", "/voice/profiles", voice_payload)
    profile = voice_created.get("profile")
    if not isinstance(profile, dict):
        raise AssertionError("/voice/profiles response missing profile")
    assert_equal(profile.get("voiceProfileId"), voice_profile_id, "voiceProfileId")
    assert_equal(profile.get("sampleStatus"), "pending", "voice sampleStatus")
    assert_equal(profile.get("authorizationConfirmed"), True, "voice authorizationConfirmed")
    assert_equal(profile.get("providerMode"), "mockContract", "voice providerMode")
    assert_equal(profile.get("defaultReleaseVisible"), False, "voice defaultReleaseVisible")

    voice_list = request_json("GET", f"/voice/profiles/{urllib.parse.quote(USER_ID)}")
    profiles = voice_list.get("profiles") or []
    listed_voice_profile = any(
        isinstance(item, dict) and item.get("voiceProfileId") == voice_profile_id for item in profiles
    )
    assert_true(listed_voice_profile, "voice profile list missing created profile")

    disabled = request_json(
        "POST",
        f"/voice/profiles/{urllib.parse.quote(USER_ID)}/{urllib.parse.quote(voice_profile_id)}/disable",
    )
    deleted = request_json(
        "DELETE",
        f"/voice/profiles/{urllib.parse.quote(USER_ID)}/{urllib.parse.quote(voice_profile_id)}",
    )
    assert_equal((disabled.get("profile") or {}).get("sampleStatus"), "disabled", "voice disabled sampleStatus")
    assert_equal((deleted.get("profile") or {}).get("sampleStatus"), "deleted", "voice deleted sampleStatus")

    result = {
        "completed": True,
        "baseURL": BASE_URL,
        "token": "configured, value intentionally omitted",
        "health": health,
        "runtimeArchive": {
            "storageProvider": archive_runtime.get("storageProvider"),
            "providerMode": archive_runtime.get("providerMode"),
            "providerSwitchContractVersion": archive_runtime.get("providerSwitchContractVersion"),
            "requiresClientUpload": archive_runtime.get("requiresClientUpload"),
        },
        "userId": USER_ID,
        "familyCreated": family_results,
        "listedFamilyModes": sorted(listed_modes.keys()),
        "invalidFamilyModeRejected": bool(invalid_response),
        "voiceProfileLifecycle": {
            "created": profile.get("sampleStatus"),
            "listed": listed_voice_profile,
            "disabled": (disabled.get("profile") or {}).get("sampleStatus"),
            "deleted": (deleted.get("profile") or {}).get("sampleStatus"),
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
