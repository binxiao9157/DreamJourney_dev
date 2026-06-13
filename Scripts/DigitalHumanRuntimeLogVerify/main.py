#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
AI_RECORDING = ROOT / "DreamJourney/Sources/Modules/Home/AIRecordingViewController.swift"
POLICY = ROOT / "DreamJourney/Sources/Services/DigitalHumanSpeechPlaybackPolicy.swift"
EVIDENCE_STORE = ROOT / "DreamJourney/Sources/Services/DigitalHumanPlaybackEvidenceStore.swift"
REPORTER = ROOT / "Scripts/roadshow_evidence_report.py"
PLAYBACK_AUDIT = ROOT / "Scripts/roadshow_digital_human_playback_audit.py"
PREFLIGHT = ROOT / "Scripts/roadshow_device_smoke_preflight.sh"


def fail(message: str) -> int:
    print(f"DigitalHumanRuntimeLog verification failed: {message}", file=sys.stderr)
    return 1


def main() -> int:
    ai_recording = AI_RECORDING.read_text(encoding="utf-8")
    policy = POLICY.read_text(encoding="utf-8")
    evidence_store = EVIDENCE_STORE.read_text(encoding="utf-8")
    reporter = REPORTER.read_text(encoding="utf-8")
    preflight = PREFLIGHT.read_text(encoding="utf-8")

    runtime_tokens = [
        'DDLogInfo("[DigitalHumanSpeech] wav_synth_success',
        'DDLogInfo("[DigitalHumanSpeech] native_audio_started',
        "audio_route stage=",
        'DDLogWarn("[DigitalHumanSpeech] \\(logReason ?? reason) requestID=\\(digitalHumanSpeechRequestID) fallback=systemTTS")',
        'DDLogWarn("[DigitalHumanSpeech] playback_timeout',
        'finishDigitalHumanSpeechPlayback(source: "native_audio")',
        'finishDigitalHumanSpeechPlayback(source: "system_tts")',
        'finishDigitalHumanSpeechPlayback(source: "timeout")',
        'DDLogInfo("[DigitalHumanSpeech] playback_finished source=\\(source)',
        "DigitalHumanPlaybackEvidenceStore.shared.appendEvent",
        "AVAudioPlayerDelegate",
        "digitalHumanNativeAudioPlayer",
        "pauseRealtimeDialogForDigitalHumanPlayback",
        "mode: .spokenAudio",
        "audio_module_unavailable",
        "markShellReady",
    ]
    missing_runtime_tokens = [token for token in runtime_tokens if token not in ai_recording]
    if missing_runtime_tokens:
        return fail(f"runtime playback logs drifted: {missing_runtime_tokens}")

    expected_evidence_logs = [
        "wav_synth_success -> playback_finished source=native_audio",
        "fallback=systemTTS -> playback_finished source=system_tts",
        "playback_timeout -> playback_finished source=timeout",
    ]
    missing_policy_tokens = [token for token in expected_evidence_logs if token not in policy]
    if missing_policy_tokens:
        return fail(f"diagnostic evidence policy missing logs: {missing_policy_tokens}")

    missing_reporter_tokens = [
        token
        for token in [
            '["wav_synth_success", "playback_finished source=native_audio"]',
            '["fallback=systemTTS", "playback_finished source=system_tts"]',
            '["playback_timeout", "playback_finished source=timeout"]',
            "playback-log-missing-accepted-chain",
        ]
        if token not in reporter
    ]
    if missing_reporter_tokens:
        return fail(f"evidence report playback quality gate drifted: {missing_reporter_tokens}")

    missing_store_tokens = [
        token
        for token in [
            'static let relativeLogPath = "diagnostics/digital_human_playback.log"',
            "appendingPathComponent(Self.relativeLogPath)",
            "try? fileManager.createDirectory",
            "_ = try? handle.seekToEnd()",
            "redacted_private_event",
            '"x-api-key"',
            '"authorization"',
            '"voiceType="',
        ]
        if token not in evidence_store
    ]
    if missing_store_tokens:
        return fail(f"playback evidence store contract drifted: {missing_store_tokens}")

    if "Documents/diagnostics/digital_human_playback.log" not in preflight:
        return fail("preflight should copy app-persisted digital-human playback log from Documents")

    if not PLAYBACK_AUDIT.exists():
        return fail("strict playback audit script is missing")

    with tempfile.TemporaryDirectory(prefix="dreamjourney_playback_audit_verify_") as tmp:
        tmp_path = Path(tmp)
        complete_log = tmp_path / "complete.log"
        complete_log.write_text(
            "\n".join(
                [
                    "[DigitalHumanSpeech] wav_synth_success requestID=1 bytes=120",
                    "[DigitalHumanSpeech] playback_finished source=native_audio requestID=1",
                    "[DigitalHumanSpeech] wav_synth_failed requestID=2 fallback=systemTTS",
                    "[DigitalHumanSpeech] playback_finished source=system_tts requestID=2",
                    "[DigitalHumanSpeech] playback_timeout requestID=3",
                    "[DigitalHumanSpeech] playback_finished source=timeout requestID=3",
                ]
            ),
            encoding="utf-8",
        )
        complete = subprocess.run(
            [sys.executable, str(PLAYBACK_AUDIT), str(complete_log), "--json"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if complete.returncode != 0:
            return fail(f"strict playback audit should pass complete logs: {complete.stderr}")
        complete_payload = json.loads(complete.stdout)
        if complete_payload.get("status") != "pass" or set(complete_payload.get("foundSources", [])) != {
            "native_audio",
            "system_tts",
            "timeout",
        }:
            return fail("strict playback audit should report all three sources")

        missing_log = tmp_path / "missing.log"
        missing_log.write_text(
            "\n".join(
                [
                    "[DigitalHumanSpeech] wav_synth_success requestID=1 bytes=120",
                    "[DigitalHumanSpeech] playback_finished source=native_audio requestID=1",
                    "[DigitalHumanSpeech] playback_timeout requestID=3",
                    "[DigitalHumanSpeech] playback_finished source=timeout requestID=3",
                ]
            ),
            encoding="utf-8",
        )
        missing = subprocess.run(
            [sys.executable, str(PLAYBACK_AUDIT), str(missing_log), "--json"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if missing.returncode != 2:
            return fail("strict playback audit should fail when system_tts sample is missing")
        missing_payload = json.loads(missing.stdout)
        if "system_tts" not in missing_payload.get("missingSources", []):
            return fail("strict playback audit should name missing playback sources")

        private_log = tmp_path / "private.log"
        secret_value = "sk-thisShouldNeverEcho1234567890"
        private_log.write_text(
            "\n".join(
                [
                    "x-api-key: " + secret_value,
                    "[DigitalHumanSpeech] wav_synth_success requestID=1 bytes=120",
                    "[DigitalHumanSpeech] playback_finished source=native_audio requestID=1",
                    "[DigitalHumanSpeech] fallback=systemTTS requestID=2",
                    "[DigitalHumanSpeech] playback_finished source=system_tts requestID=2",
                    "[DigitalHumanSpeech] playback_timeout requestID=3",
                    "[DigitalHumanSpeech] playback_finished source=timeout requestID=3",
                ]
            ),
            encoding="utf-8",
        )
        private = subprocess.run(
            [sys.executable, str(PLAYBACK_AUDIT), str(private_log), "--json"],
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        if private.returncode != 3:
            return fail("strict playback audit should fail on credential-shaped log content")
        if secret_value in private.stdout or secret_value in private.stderr:
            return fail("strict playback audit must not echo raw secret values")

    print("DigitalHumanRuntimeLog verification passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
