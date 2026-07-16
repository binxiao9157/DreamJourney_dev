#!/usr/bin/env python3
import base64
import json
import sys
from pathlib import Path
from typing import Any, Dict
from unittest.mock import patch


if len(sys.argv) < 3:
    raise SystemExit("Usage: backend-voice-synthesis-viseme-smoke.py <app-root> <backend-root>")

APP_ROOT = Path(sys.argv[1])
BACKEND_ROOT = Path(sys.argv[2])
sys.path.insert(0, str(BACKEND_ROOT))

from fastapi.testclient import TestClient  # noqa: E402

from app.main import app  # noqa: E402


class FakeVoiceCloneTTSProvider:
    provider_mode = "mockProviderVisemeTimeline"
    is_configured = True

    def __init__(self, include_timeline: bool):
        self.include_timeline = include_timeline

    def synthesize(
        self,
        *,
        text: str,
        user_id: str,
        voice_profile_id: str,
        audio_format: str,
        sample_rate: int,
        speech_rate: int,
        loudness_rate: int,
    ) -> Dict[str, Any]:
        result: Dict[str, Any] = {
            "audioBase64": base64.b64encode(b"MOCK_AUDIO").decode("ascii"),
            "audioFormat": audio_format,
            "byteCount": len(b"MOCK_AUDIO"),
            "providerMode": self.provider_mode,
            "voiceProfileId": voice_profile_id,
        }
        if self.include_timeline:
            result["visemeTimeline"] = {
                "source": "providerVisemeTimeline",
                "duration": 0.48,
                "frames": [
                    {"timeOffset": 0.0, "mouthShape": "neutral", "intensity": 0.12},
                    {"timeOffset": 0.12, "mouthShape": "aa", "intensity": 0.86},
                    {"timeOffset": 0.24, "mouthShape": "oh", "intensity": 0.72},
                    {"timeOffset": 0.36, "mouthShape": "ee", "intensity": 0.64},
                ],
            }
        return result


class FakeFactory:
    def __init__(self, include_timeline: bool):
        self.include_timeline = include_timeline

    def make(self) -> FakeVoiceCloneTTSProvider:
        return FakeVoiceCloneTTSProvider(include_timeline=self.include_timeline)


def post_synthesis(client: TestClient, include_timeline: bool) -> Dict[str, Any]:
    with patch("app.main.VoiceCloneTTSProviderFactory", return_value=FakeFactory(include_timeline)):
        response = client.post(
            "/voice/synthesis",
            json={
                "userId": "digital_human_tts_viseme_user",
                "voiceProfileId": "S_mock_viseme_voice",
                "text": "我在这里，慢慢听你说。",
                "format": "mp3",
                "sampleRate": 24000,
                "speechRate": -10,
                "loudnessRate": 10,
            },
        )
    if response.status_code != 200:
        raise AssertionError(f"/voice/synthesis expected 200, got {response.status_code}: {response.text}")
    return response.json()


def assert_equal(actual: Any, expected: Any, message: str) -> None:
    if actual != expected:
        raise AssertionError(f"{message}: expected {expected!r}, got {actual!r}")


def assert_true(value: Any, message: str) -> None:
    if not value:
        raise AssertionError(message)


def main() -> None:
    client = TestClient(app)
    runtime = client.get(
        "/config/runtime",
        headers={
            "X-DreamJourney-Runtime-Contract-Version": "2",
            "X-DreamJourney-Client-Build": "9001",
        },
    ).json()
    lip_sync = (runtime.get("voiceClone") or {}).get("lipSyncTimeline") or {}
    assert_equal(lip_sync.get("field"), "visemeTimeline", "runtime lip sync field")
    assert_equal(lip_sync.get("source"), "providerOptional", "runtime lip sync source")
    assert_equal(lip_sync.get("fallbackMode"), "avAudioPlayerMetering", "runtime fallback mode")

    provider_payload = post_synthesis(client, include_timeline=True)
    provider_timeline = provider_payload.get("visemeTimeline")
    assert_true(isinstance(provider_timeline, dict), "/voice/synthesis must return visemeTimeline object")
    provider_frames = provider_timeline.get("frames") or []
    assert_equal(provider_timeline.get("source"), "providerVisemeTimeline", "viseme source")
    assert_true(len(provider_frames) > 0, "lipSyncFrameCount must be greater than zero")
    assert_equal(provider_frames[1].get("mouthShape"), "aa", "second mouth shape")
    assert_equal(provider_payload.get("audio", {}).get("data"), base64.b64encode(b"MOCK_AUDIO").decode("ascii"), "audio data")

    missing_payload = post_synthesis(client, include_timeline=False)
    assert_true(
        "visemeTimeline" in missing_payload and missing_payload.get("visemeTimeline") is None,
        "missing provider timeline should return null visemeTimeline for metering fallback",
    )

    result = {
        "completed": True,
        "appRoot": str(APP_ROOT),
        "backendRoot": str(BACKEND_ROOT),
        "runtimeLipSyncTimeline": lip_sync,
        "providerTimeline": {
            "source": provider_timeline.get("source"),
            "duration": provider_timeline.get("duration"),
            "lipSyncFrameCount": len(provider_frames),
            "currentMouthShape": provider_frames[1].get("mouthShape"),
        },
        "missingTimelineFallbackAccepted": True,
        "audio": {
            "format": provider_payload.get("audio", {}).get("format"),
            "byteCount": provider_payload.get("audio", {}).get("byteCount"),
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
