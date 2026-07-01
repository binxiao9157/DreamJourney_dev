#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


if len(sys.argv) < 3:
    raise SystemExit("Usage: echo-readiness-report.py <app-root> <output-dir>")

APP_ROOT = Path(sys.argv[1])
OUTPUT_DIR = Path(sys.argv[2])
BASE_URL = os.environ.get("BACKEND_BASE_URL", "").rstrip("/")
API_TOKEN = os.environ.get("BACKEND_API_TOKEN", "")
USER_ID = os.environ.get("READINESS_USER_ID", "readiness_echo_user")
VOICE_PROFILE_ID = os.environ.get("VOICE_CLONE_READY_PROFILE_ID", "").strip()
RUN_VOICE_SYNTHESIS = os.environ.get("RUN_READINESS_VOICE_SYNTHESIS", "0") == "1"
STRICT = os.environ.get("READINESS_STRICT", "0") == "1"


def read(relative_path: str) -> str:
    path = APP_ROOT / relative_path
    return path.read_text(encoding="utf-8")


def make_check(name: str, status: str, detail: str, evidence: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    return {
        "name": name,
        "status": status,
        "detail": detail,
        "evidence": evidence or {},
    }


def local_contains(relative_path: str, needles: List[str]) -> Tuple[bool, List[str]]:
    try:
        content = read(relative_path)
    except OSError:
        return False, needles
    missing = [needle for needle in needles if needle not in content]
    return len(missing) == 0, missing


def request_json(
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    timeout: int = 30,
) -> Tuple[int, Dict[str, Any], int]:
    url = f"{BASE_URL}{path}"
    data = None
    headers = {"Accept": "application/json"}
    if auth and API_TOKEN:
        headers["Authorization"] = f"Bearer {API_TOKEN}"
        headers["X-API-Token"] = API_TOKEN
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"

    started = time.monotonic()
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
            elapsed_ms = int((time.monotonic() - started) * 1000)
            return response.status, json.loads(body) if body else {}, elapsed_ms
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")
        elapsed_ms = int((time.monotonic() - started) * 1000)
        parsed = json.loads(body) if body and body[:1] in "{[" else {"detail": body[:500]}
        return error.code, parsed, elapsed_ms


def backend_check(
    name: str,
    method: str,
    path: str,
    payload: Optional[Dict[str, Any]] = None,
    *,
    auth: bool = True,
    expect_status: int = 200,
) -> Dict[str, Any]:
    if not BASE_URL:
        return make_check(name, "skipped", "BACKEND_BASE_URL 未配置")
    if auth and not API_TOKEN:
        return make_check(name, "skipped", "BACKEND_API_TOKEN 未配置")

    try:
        status, body, elapsed_ms = request_json(method, path, payload, auth=auth)
    except Exception as error:
        return make_check(name, "failed", str(error), {"path": path})

    check_status = "passed" if status == expect_status else "failed"
    evidence: Dict[str, Any] = {
        "path": path,
        "statusCode": status,
        "elapsedMs": elapsed_ms,
    }
    if path == "/config/runtime":
        voice_clone = body.get("voiceClone") or {}
        digital_human = body.get("digitalHuman") or {}
        context_packet = body.get("contextPacket") or body.get("context") or {}
        evidence.update({
            "voiceClone": {
                "enabled": voice_clone.get("enabled"),
                "provider": voice_clone.get("provider"),
                "fallbackMode": voice_clone.get("fallbackMode"),
                "tencentAudioDrive": voice_clone.get("tencentAudioDrive"),
            },
            "digitalHuman": {
                "provider": digital_human.get("provider"),
                "providerMode": digital_human.get("providerMode"),
                "realProviderReady": digital_human.get("realProviderReady"),
                "assetMode": digital_human.get("assetMode"),
            },
            "contextPacket": context_packet,
        })
    elif path == "/context/build":
        packet = body.get("contextPacket") or {}
        evidence.update({
            "schemaVersion": packet.get("schemaVersion"),
            "traceId": packet.get("traceId"),
            "archiveItemsIncluded": packet.get("archiveItemsIncluded"),
            "kbFactCount": packet.get("kbFactCount"),
            "voiceProfileId": packet.get("voiceProfileId"),
            "privacyScopeLabel": packet.get("privacyScopeLabel"),
            "crossScopeArchiveIncluded": packet.get("crossScopeArchiveIncluded"),
        })
    elif path == "/digital-human/sessions":
        credential = body.get("credential") or {}
        evidence.update({
            "provider": body.get("provider"),
            "providerMode": body.get("providerMode"),
            "sessionId": body.get("sessionId"),
            "hasProviderAssetId": bool(body.get("providerAssetId")),
            "hasProviderProjectId": bool(body.get("providerProjectId")),
            "credentialMode": credential.get("mode"),
            "hasAppkey": bool(credential.get("appkey")),
            "hasAccessToken": bool(credential.get("accesstoken")),
            "fallbackMode": (body.get("fallback") or {}).get("mode"),
        })
    elif path == "/voice/synthesis":
        evidence.update({
            "voiceProfileId": body.get("voiceProfileId"),
            "outputMode": body.get("outputMode"),
            "audioFormat": body.get("audioFormat"),
            "sampleRate": body.get("sampleRate"),
            "byteCount": body.get("byteCount"),
            "providerLogId": body.get("providerLogId"),
            "providerRequestId": body.get("providerRequestId"),
        })
    else:
        evidence["bodyKeys"] = sorted(body.keys())

    return make_check(name, check_status, "ok" if check_status == "passed" else "unexpected status", evidence)


def make_report(checks: List[Dict[str, Any]]) -> str:
    lines = [
        "# Echo Readiness Report",
        "",
        f"- Backend URL: `{BASE_URL or 'not configured'}`",
        f"- Backend token: `{'configured' if API_TOKEN else 'not configured'}`",
        f"- Voice synthesis probe: `{RUN_VOICE_SYNTHESIS}`",
        "",
        "| Check | Status | Detail |",
        "| --- | --- | --- |",
    ]
    for check in checks:
        lines.append(f"| {check['name']} | `{check['status']}` | {check['detail']} |")

    lines.extend(["", "## Evidence", ""])
    for check in checks:
        lines.append(f"### {check['name']}")
        lines.append("")
        lines.append("```json")
        lines.append(json.dumps(check["evidence"], ensure_ascii=False, indent=2, sort_keys=True))
        lines.append("```")
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    checks: List[Dict[str, Any]] = []

    local_specs = [
        (
            "local.context_packet",
            "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift",
            ["/context/build", "struct EchoContextPacket", "struct EchoTraceRecord"],
        ),
        (
            "local.echo_trace_export",
            "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift",
            ["final class EchoTraceStore", "echo-trace-records.json"],
        ),
        (
            "local.runtime_diagnostics",
            "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift",
            ["struct EchoRuntimeDiagnosticsSnapshot", "final class EchoRuntimeDiagnosticsStore"],
        ),
        (
            "local.echo_diagnostics_panel",
            "DreamJourney/Sources/Modules/Echo/EchoViewController.swift",
            ["DJShowEchoRuntimeDiagnosticsPanel", "Echo QA clues", "renderEchoRuntimeDiagnosticsPanel(snapshot:"],
        ),
        (
            "local.digital_human_session",
            "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift",
            ["/digital-human/sessions", "DigitalHumanRuntimeCapability", "sdkReadinessMessage"],
        ),
        (
            "local.voice_clone_synthesis",
            "DreamJourney/Sources/Services/DreamJourneyBackendClient.swift",
            ["/voice/synthesis", "providerLogId", "providerRequestId", "outputMode"],
        ),
        (
            "local.apns_boundary",
            "DreamJourney/Sources/AppDelegate.swift",
            ["hasAPNsEntitlement", "APNs entitlement missing; skip remote notification registration"],
        ),
        (
            "local.kblite",
            "DreamJourney/Sources/Services/KBLiteManager.swift",
            ["final class KBLiteManager", "exportJSON"],
        ),
    ]
    for name, path, needles in local_specs:
        passed, missing = local_contains(path, needles)
        checks.append(make_check(name, "passed" if passed else "failed", "ok" if passed else "missing local contract", {
            "path": path,
            "missing": missing,
        }))

    checks.append(backend_check("backend.health", "GET", "/health", auth=False))
    checks.append(backend_check("backend.runtime", "GET", "/config/runtime"))
    checks.append(
        backend_check(
            "backend.context_build",
            "POST",
            "/context/build",
            {
                "userId": USER_ID,
                "intent": "echo_chat",
                "query": "readiness report context probe",
                "personaScope": "personal",
                "digitalHumanId": USER_ID,
                "lifecycleMode": "sunlight",
            },
        )
    )
    checks.append(
        backend_check(
            "backend.digital_human_session",
            "POST",
            "/digital-human/sessions",
            {
                "userId": USER_ID,
                "personaId": USER_ID,
                "scene": "echo",
                "deviceId": "readiness-report",
                "lifecycleMode": "sunlight",
            },
        )
    )
    if RUN_VOICE_SYNTHESIS and VOICE_PROFILE_ID:
        checks.append(
            backend_check(
                "backend.voice_synthesis",
                "POST",
                "/voice/synthesis",
                {
                    "userId": USER_ID,
                    "voiceProfileId": VOICE_PROFILE_ID,
                    "text": "回响 readiness 复刻音色检查。",
                    "audioFormat": "wav",
                    "sampleRate": 16000,
                    "outputMode": "tencentAudioDrive",
                },
            )
        )
    else:
        checks.append(make_check(
            "backend.voice_synthesis",
            "skipped",
            "设置 RUN_READINESS_VOICE_SYNTHESIS=1 且提供 VOICE_CLONE_READY_PROFILE_ID 后启用",
        ))

    result = {
        "schemaVersion": 1,
        "completed": all(check["status"] in ("passed", "skipped") for check in checks),
        "strict": STRICT,
        "backendURLConfigured": bool(BASE_URL),
        "backendTokenConfigured": bool(API_TOKEN),
        "checks": checks,
    }
    json_path = OUTPUT_DIR / "echo-readiness-report.json"
    md_path = OUTPUT_DIR / "echo-readiness-report.md"
    json_path.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True), encoding="utf-8")
    md_path.write_text(make_report(checks), encoding="utf-8")
    print(json.dumps({
        "completed": result["completed"],
        "jsonPath": str(json_path),
        "markdownPath": str(md_path),
        "failedChecks": [check["name"] for check in checks if check["status"] == "failed"],
    }, ensure_ascii=False, indent=2))
    if STRICT and not result["completed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
