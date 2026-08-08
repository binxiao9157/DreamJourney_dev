#!/usr/bin/env python3
import base64
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional, Tuple


if len(sys.argv) < 4:
    raise SystemExit("Usage: backend-voice-clone-deployed-smoke.py <app-root> <user-id> <marker>")

APP_ROOT = Path(sys.argv[1])
BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
USER_ACCESS_TOKEN = os.environ.get("BACKEND_USER_ACCESS_TOKEN", "")
USER_ID = sys.argv[2]
MARKER = re.sub(r"[^A-Za-z0-9_-]", "_", sys.argv[3])
READY_VOICE_PROFILE_ID = os.environ.get("VOICE_CLONE_READY_PROFILE_ID", "").strip()
READY_VOICE_PROFILE_USER_ID = os.environ.get("VOICE_CLONE_READY_PROFILE_USER_ID", "").strip()
NON_READY_VOICE_PROFILE_ID = os.environ.get("VOICE_CLONE_NON_READY_PROFILE_ID", "").strip()
NON_READY_VOICE_PROFILE_USER_ID = os.environ.get("VOICE_CLONE_NON_READY_PROFILE_USER_ID", "").strip()

if not BASE_URL:
    raise SystemExit("BACKEND_BASE_URL is required")
if not API_TOKEN:
    raise SystemExit("BACKEND_API_TOKEN is required")
if not USER_ACCESS_TOKEN:
    raise SystemExit("BACKEND_USER_ACCESS_TOKEN is required for user-owned voice routes")
if not READY_VOICE_PROFILE_ID:
    raise SystemExit("VOICE_CLONE_READY_PROFILE_ID is required")
if not READY_VOICE_PROFILE_USER_ID:
    raise SystemExit("VOICE_CLONE_READY_PROFILE_USER_ID is required")


def request_json(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    expected: Optional[int] = 200,
    timeout: int = 60,
) -> Tuple[int, Dict[str, Any]]:
    url = f"{BASE_URL}{path}"
    data = None
    headers = {"Accept": "application/json"}
    if path == "/config/runtime":
        headers["X-DreamJourney-Runtime-Contract-Version"] = "2"
        headers["X-DreamJourney-Client-Build"] = "9001"
    if auth:
        headers["Authorization"] = f"Bearer {USER_ACCESS_TOKEN}"
        headers["X-API-Token"] = API_TOKEN
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
        if expected is not None and error.code != expected:
            raise AssertionError(f"{method} {path} expected {expected}, got {error.code}: {body[:400]}") from error
        return error.code, json.loads(body) if body else {}
    except urllib.error.URLError as error:
        raise AssertionError(f"{method} {path} failed: {error}") from error

    if expected is not None and status != expected:
        raise AssertionError(f"{method} {path} expected {expected}, got {status}: {body[:400]}")
    return status, json.loads(body) if body else {}


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def assert_true(value: Any, message: str) -> None:
    if not value:
        raise AssertionError(message)


def refresh_profile(user_id: str, voice_profile_id: str) -> Dict[str, Any]:
    _, refreshed = request_json(
        "POST",
        f"/voice/profiles/{urllib.parse.quote(user_id)}/{urllib.parse.quote(voice_profile_id)}/refresh",
    )
    profile = refreshed.get("profile")
    if not isinstance(profile, dict):
        raise AssertionError("refresh response missing profile")
    if profile.get("sampleStatus") == "ready" and profile.get("qualityAcceptanceRequired"):
        _, accepted = request_json(
            "POST",
            f"/voice/profiles/{urllib.parse.quote(user_id)}/{urllib.parse.quote(voice_profile_id)}/quality-acceptance",
        )
        profile = accepted.get("profile")
        if not isinstance(profile, dict):
            raise AssertionError("quality acceptance response missing profile")
    return profile


def synthesize(
    user_id: str,
    voice_profile_id: str,
    *,
    profile_version: Optional[int] = None,
    expected: Optional[int] = 200,
) -> Tuple[int, Dict[str, Any]]:
    text = "你好。"
    payload: Dict[str, Any] = {
        "userId": user_id,
        "voiceProfileId": voice_profile_id,
        "text": text,
        "format": "wav",
        "sampleRate": 16000,
        "speechRate": -10,
        "loudnessRate": 10,
        "outputMode": "tencentAudioDrive",
        "requestPurpose": "echo",
        "roleKey": "personalOwner",
        "roleSubjectId": user_id,
        "personaScope": "personal",
        "digitalHumanId": user_id,
    }
    if profile_version is not None:
        payload["expectedProfileVersion"] = profile_version
    return request_json(
        "POST",
        "/voice/synthesis",
        payload,
        expected=expected,
        timeout=75,
    )


def validate_tencent_audio_drive(
    payload: Dict[str, Any],
    voice_profile_id: str,
    user_id: str,
    profile_version: int,
) -> Dict[str, Any]:
    assert_equal(payload.get("status"), "synthesized", "synthesis status")
    assert_equal(payload.get("voiceProfileId"), voice_profile_id, "synthesis voiceProfileId")
    assert_equal(payload.get("outputMode"), "tencentAudioDrive", "synthesis outputMode")
    audio = payload.get("audio")
    if not isinstance(audio, dict):
        raise AssertionError("synthesis response missing audio")
    assert_equal(audio.get("format"), "pcm16kMono", "audio format")
    assert_equal(audio.get("sampleRate"), 16000, "audio sampleRate")
    assert_equal(audio.get("bitsPerSample"), 16, "audio bitsPerSample")
    assert_equal(audio.get("channelCount"), 1, "audio channelCount")
    byte_count = int(audio.get("byteCount") or 0)
    assert_true(byte_count > 0, "audio byteCount should be positive")
    audio_base64 = str(audio.get("data") or "")
    assert_true(bool(audio_base64), "audio data should be present")
    audio_data = base64.b64decode(audio_base64)
    assert_equal(len(audio_data), byte_count, "audio decoded byteCount")
    assert_true(len(audio_data) % 2 == 0, "pcm16 data should be 16-bit aligned")
    assert_true(not audio_data.startswith(b"RIFF"), "tencent audio-drive payload should be raw PCM, not WAV")
    binding = payload.get("synthesisBinding")
    if not isinstance(binding, dict):
        raise AssertionError("synthesis response missing binding")
    assert_equal(binding.get("schemaVersion"), "voice-synthesis-binding-v2", "binding schema")
    assert_equal(binding.get("ownerUserId"), user_id, "binding owner")
    assert_equal(binding.get("voiceProfileId"), voice_profile_id, "binding voiceProfileId")
    assert_equal(binding.get("profileVersion"), profile_version, "binding profileVersion")
    assert_equal(binding.get("roleKey"), "personalOwner", "binding roleKey")
    assert_equal(binding.get("requestPurpose"), "echo", "binding requestPurpose")
    assert_equal(binding.get("audioOwner"), "tencentDigitalHuman", "binding audioOwner")
    assert_equal(
        binding.get("textHash"),
        hashlib.sha256("你好。".encode("utf-8")).hexdigest(),
        "binding textHash",
    )
    return {
        "status": payload.get("status"),
        "voiceProfileId": payload.get("voiceProfileId"),
        "providerMode": payload.get("providerMode"),
        "outputMode": payload.get("outputMode"),
        "audioFormat": audio.get("format"),
        "sampleRate": audio.get("sampleRate"),
        "bitsPerSample": audio.get("bitsPerSample"),
        "channelCount": audio.get("channelCount"),
        "byteCount": byte_count,
        "bindingSchemaVersion": binding.get("schemaVersion"),
        "bindingProfileVersion": binding.get("profileVersion"),
        "bindingTextHash": binding.get("textHash"),
        "bindingResult": "matched",
        "audioDataOmitted": True,
    }


def diagnostic_failure_payload(status: int, payload: Dict[str, Any]) -> Dict[str, Any]:
    detail = payload.get("detail", payload)
    text = json.dumps(detail, ensure_ascii=False) if isinstance(detail, (dict, list)) else str(detail)
    return {
        "httpStatus": status,
        "diagnosticFailure": text[:260],
    }


def main() -> None:
    _, health = request_json("GET", "/health", auth=False)
    _, runtime = request_json("GET", "/config/runtime")
    assert_equal(health.get("status"), "ok", "health status")
    voice_clone = runtime.get("voiceClone")
    if not isinstance(voice_clone, dict):
        raise AssertionError("/config/runtime missing voiceClone")
    assert_equal(voice_clone.get("provider"), "volcengineVoiceCloneV3", "voiceClone provider")
    assert_true(voice_clone.get("realProviderReady"), "voiceClone realProviderReady should be true")
    assert_true(voice_clone.get("synthesisProviderReady"), "voiceClone synthesisProviderReady should be true")
    assert_equal(voice_clone.get("speakerIdMode"), "trialSpeakerIdPool", "voiceClone speakerIdMode")
    assert_true(voice_clone.get("speakerIdPoolConfigured"), "voiceClone speakerIdPoolConfigured should be true")
    assert_true(int(voice_clone.get("speakerIdPoolCount") or 0) >= 1, "voiceClone speakerIdPoolCount")
    assert_equal(voice_clone.get("modelType"), 5, "voiceClone modelType")
    assert_equal(voice_clone.get("ttsResourceId"), "seed-icl-2.0", "voiceClone ttsResourceId")
    assert_true(voice_clone.get("voiceClone2TrialReady"), "voiceClone2TrialReady should be true")
    tencent_audio_drive = voice_clone.get("tencentAudioDrive") or {}
    assert_true(tencent_audio_drive.get("supported"), "tencentAudioDrive should be supported")
    assert_equal(tencent_audio_drive.get("requestOutputMode"), "tencentAudioDrive", "tencentAudioDrive output mode")
    assert_equal(tencent_audio_drive.get("audioFormat"), "pcm16kMono", "tencentAudioDrive audioFormat")

    ready_profile = refresh_profile(READY_VOICE_PROFILE_USER_ID, READY_VOICE_PROFILE_ID)
    assert_equal(ready_profile.get("voiceProfileId"), READY_VOICE_PROFILE_ID, "ready voiceProfileId")
    assert_equal(ready_profile.get("sampleStatus"), "ready", "ready sampleStatus")
    assert_equal(ready_profile.get("isEnabled"), True, "ready isEnabled")

    assert_equal(ready_profile.get("qualityAcceptanceRequired"), False, "ready quality acceptance")
    ready_profile_version = int(ready_profile.get("profileVersion") or 0)
    assert_true(ready_profile_version > 0, "ready profileVersion should be positive")

    _, ready_synthesis = synthesize(
        READY_VOICE_PROFILE_USER_ID,
        READY_VOICE_PROFILE_ID,
        profile_version=ready_profile_version,
        expected=200,
    )
    ready_result = validate_tencent_audio_drive(
        ready_synthesis,
        READY_VOICE_PROFILE_ID,
        READY_VOICE_PROFILE_USER_ID,
        ready_profile_version,
    )

    non_ready_result: Dict[str, Any] = {"configured": bool(NON_READY_VOICE_PROFILE_ID)}
    if NON_READY_VOICE_PROFILE_ID:
        non_ready_owner = NON_READY_VOICE_PROFILE_USER_ID or READY_VOICE_PROFILE_USER_ID
        non_ready_profile = refresh_profile(non_ready_owner, NON_READY_VOICE_PROFILE_ID)
        non_ready_result.update({
            "voiceProfileId": NON_READY_VOICE_PROFILE_ID,
            "sampleStatus": non_ready_profile.get("sampleStatus"),
            "providerStatus": non_ready_profile.get("providerStatus"),
            "providerLogId": non_ready_profile.get("providerLogId"),
        })
        if non_ready_profile.get("sampleStatus") == "ready":
            non_ready_result["diagnosticFailure"] = "skipped because probe voice is now ready"
        else:
            non_ready_version = int(non_ready_profile.get("profileVersion") or 0) or None
            status, failure = synthesize(
                non_ready_owner,
                NON_READY_VOICE_PROFILE_ID,
                profile_version=non_ready_version,
                expected=None,
            )
            if 200 <= status < 300:
                raise AssertionError("non-ready voice unexpectedly synthesized successfully")
            non_ready_result.update(diagnostic_failure_payload(status, failure))

    result = {
        "completed": True,
        "baseURL": BASE_URL,
        "token": "configured, value intentionally omitted",
        "health": {
            "status": health.get("status"),
            "store": health.get("store"),
        },
        "runtimeVoiceClone": {
            "provider": voice_clone.get("provider"),
            "realProviderReady": voice_clone.get("realProviderReady"),
            "synthesisProviderReady": voice_clone.get("synthesisProviderReady"),
            "speakerIdMode": voice_clone.get("speakerIdMode"),
            "speakerIdPoolConfigured": voice_clone.get("speakerIdPoolConfigured"),
            "speakerIdPoolCount": voice_clone.get("speakerIdPoolCount"),
            "modelType": voice_clone.get("modelType"),
            "ttsResourceId": voice_clone.get("ttsResourceId"),
            "voiceClone2TrialReady": voice_clone.get("voiceClone2TrialReady"),
            "tencentAudioDriveSupported": tencent_audio_drive.get("supported"),
        },
        "readyProbe": {
            "userId": READY_VOICE_PROFILE_USER_ID,
            "voiceProfileId": READY_VOICE_PROFILE_ID,
            "sampleStatus": ready_profile.get("sampleStatus"),
            "providerStatus": ready_profile.get("providerStatus"),
            "providerLogId": ready_profile.get("providerLogId"),
            "synthesis": ready_result,
        },
        "nonReadyProbe": non_ready_result,
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
