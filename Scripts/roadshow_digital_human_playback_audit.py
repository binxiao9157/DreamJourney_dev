#!/usr/bin/env python3
import argparse
import json
import re
import sys
from pathlib import Path


PLAYBACK_LOG_RELATIVE_PATH = "diagnostics/digital_human_playback.log"
PLAYBACK_CHAINS = [
    (
        "native_audio",
        ["wav_synth_success", "playback_finished source=native_audio"],
        "WAV synthesis succeeds and iOS native audio reports playback_finished source=native_audio.",
    ),
    (
        "system_tts",
        ["fallback=systemTTS", "playback_finished source=system_tts"],
        "Digital-human audio falls back to system TTS and finishes without blocking recording.",
    ),
    (
        "timeout",
        ["playback_timeout", "playback_finished source=timeout"],
        "Watchdog timeout closes a missing callback instead of leaving the avatar speaking.",
    ),
]
SECRET_PATTERNS = [
    (
        "credential-assignment",
        re.compile(
            r"\b(api[_-]?key|x-api-key|token|access[_-]?token|secret|secret[_-]?key|"
            r"app[_-]?key|app[_-]?token|volcengine[_-]?api[_-]?key)\b"
            r"\s*[:=]\s*[\"']?[A-Za-z0-9._\-]{12,}",
            re.IGNORECASE,
        ),
    ),
    ("secret-key-token", re.compile(r"\bsk-[A-Za-z0-9_\-]{16,}\b")),
    ("authorization-bearer-token", re.compile(r"\bBearer\s+[A-Za-z0-9._\-]{12,}\b", re.IGNORECASE)),
]


def resolve_log_path(input_path: Path) -> Path:
    if input_path.is_dir():
        return input_path / PLAYBACK_LOG_RELATIVE_PATH
    return input_path


def scan_privacy(content: str) -> list[dict]:
    findings = []
    for line_number, line in enumerate(content.splitlines(), start=1):
        for pattern_name, pattern in SECRET_PATTERNS:
            if pattern.search(line):
                findings.append(
                    {
                        "line": line_number,
                        "pattern": pattern_name,
                    }
                )
    return findings


def audit_log(log_path: Path) -> tuple[int, dict]:
    if not log_path.exists():
        return 4, {
            "status": "missing",
            "logPath": str(log_path),
            "message": "Playback log is missing.",
        }

    try:
        content = log_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return 4, {
            "status": "unreadable",
            "logPath": str(log_path),
            "message": "Playback log must be UTF-8 text.",
        }

    privacy_findings = scan_privacy(content)
    found_sources = [
        source
        for source, tokens, _description in PLAYBACK_CHAINS
        if all(token in content for token in tokens)
    ]
    missing_sources = [
        source
        for source, _tokens, _description in PLAYBACK_CHAINS
        if source not in found_sources
    ]
    checks = [
        {
            "source": source,
            "requiredTokens": tokens,
            "description": description,
            "present": source in found_sources,
        }
        for source, tokens, description in PLAYBACK_CHAINS
    ]

    payload = {
        "status": "pass",
        "logPath": str(log_path),
        "foundSources": found_sources,
        "missingSources": missing_sources,
        "checks": checks,
        "privacyFindings": privacy_findings,
        "redaction": "No raw credential, token, or API key values are echoed by this audit.",
    }

    if privacy_findings:
        payload["status"] = "privacy_review"
        payload["message"] = "Credential-shaped content was detected in the playback log."
        return 3, payload

    if missing_sources:
        payload["status"] = "incomplete"
        payload["message"] = "Strict roadshow rehearsal expects all three playback closure samples."
        return 2, payload

    payload["message"] = "All digital-human playback closure samples are present."
    return 0, payload


def print_text(payload: dict) -> None:
    print(f"Digital-human playback audit: {payload['status']}")
    print(f"Log: {payload['logPath']}")
    if payload.get("foundSources"):
        print("Found: " + ", ".join(payload["foundSources"]))
    if payload.get("missingSources"):
        print("Missing: " + ", ".join(payload["missingSources"]))
    if payload.get("privacyFindings"):
        print("Privacy findings:")
        for finding in payload["privacyFindings"]:
            print(f"- line {finding['line']}: {finding['pattern']}")
    if payload.get("message"):
        print(payload["message"])


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Strictly audit roadshow digital-human playback logs for all closure paths."
    )
    parser.add_argument(
        "path",
        help=(
            "Path to diagnostics/digital_human_playback.log, or an evidence directory "
            "containing that file."
        ),
    )
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON.")
    args = parser.parse_args()

    log_path = resolve_log_path(Path(args.path))
    exit_code, payload = audit_log(log_path)
    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print_text(payload)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
