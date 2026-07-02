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
        trace = packet.get("trace") or {}
        debug = packet.get("debug") or {}
        source_counts = debug.get("sourceCounts") or {}
        selected_context = packet.get("selectedContext") or []
        filtered_context = packet.get("filteredContext") or []
        ranking_trace = packet.get("rankingTrace") or []
        selected_context_refs = [
            str(item.get("refId"))
            for item in selected_context
            if isinstance(item, dict) and item.get("refId")
        ]
        selected_context_refs_by_source: Dict[str, List[str]] = {}
        for item in selected_context:
            if not isinstance(item, dict):
                continue
            source = str(item.get("source") or "").strip()
            ref_id = str(item.get("refId") or "").strip()
            if source and ref_id:
                selected_context_refs_by_source.setdefault(source, []).append(ref_id)
        filtered_context_reasons = []
        for item in filtered_context:
            if not isinstance(item, dict):
                continue
            ref_id = str(item.get("refId") or "").strip()
            reason = str(item.get("reason") or "").strip()
            if reason:
                filtered_context_reasons.append(f"{ref_id}:{reason}" if ref_id else reason)
        memory = packet.get("memory") or {}
        voice = packet.get("voice") or {}
        digital_human = packet.get("digitalHuman") or {}
        policy = packet.get("policy") or {}
        privacy_scope = policy.get("privacyScope") or {}
        evidence.update({
            "schemaVersion": packet.get("schemaVersion"),
            "contextVersion": packet.get("contextVersion"),
            "traceId": packet.get("traceId"),
            "archiveItemIds": trace.get("archiveItemIds") or [],
            "archiveItemsIncluded": source_counts.get("archiveItemsIncluded", 0),
            "archiveItemsAvailable": source_counts.get("archiveItemsAvailable", 0),
            "kbFactCount": len(memory.get("kbFacts") or []),
            "selectedContextRefs": selected_context_refs,
            "selectedContextRefsBySource": selected_context_refs_by_source,
            "selectedContextSourceCounts": trace.get("selectedContextSourceCounts") or {},
            "selectedContextCount": trace.get("selectedContextCount", len(selected_context)),
            "filteredContextReasons": filtered_context_reasons,
            "filteredContextCount": trace.get("filteredContextCount", len(filtered_context)),
            "rankingTraceCount": trace.get("rankingTraceCount", len(ranking_trace)),
            "voiceProfileId": voice.get("voiceProfileId"),
            "voiceCloneReady": voice.get("cloneReady"),
            "voiceOutputMode": voice.get("outputMode"),
            "digitalHumanSessionReady": digital_human.get("sessionReady"),
            "digitalHumanProviderMode": digital_human.get("providerMode"),
            "privacyScopeLabel": privacy_scope.get("scopeLabel"),
            "canUseFamilyData": policy.get("canUseFamilyData"),
            "crossScopeArchiveIncluded": policy.get("crossScopeArchiveIncluded"),
            "fallbacks": packet.get("fallbacks") or [],
            "latencyMs": debug.get("latencyMs", 0),
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


def check_evidence(checks: List[Dict[str, Any]], name: str) -> Dict[str, Any]:
    for check in checks:
        if check.get("name") == name:
            evidence = check.get("evidence") or {}
            return evidence if isinstance(evidence, dict) else {}
    return {}


def check_status(checks: List[Dict[str, Any]], name: str) -> str:
    for check in checks:
        if check.get("name") == name:
            return str(check.get("status") or "missing")
    return "missing"


def source_refs(summary: Dict[str, Any], source: str, fallback: Optional[List[str]] = None) -> List[str]:
    refs_by_source = summary.get("selectedContextRefsBySource") or {}
    refs = refs_by_source.get(source) if isinstance(refs_by_source, dict) else None
    if isinstance(refs, list) and refs:
        return [str(item) for item in refs]
    return fallback or []


def make_context_clue_summary(context_evidence: Dict[str, Any]) -> Dict[str, Any]:
    archive_ids = context_evidence.get("archiveItemIds") or []
    return {
        "contextVersion": context_evidence.get("contextVersion") or "missing",
        "traceId": context_evidence.get("traceId") or "none",
        "selectedContextRefs": context_evidence.get("selectedContextRefs") or [],
        "selectedContextRefsBySource": context_evidence.get("selectedContextRefsBySource") or {},
        "archiveRefs": source_refs(context_evidence, "archive", archive_ids),
        "kbFactRefs": source_refs(context_evidence, "kbFact"),
        "personaRefs": source_refs(context_evidence, "persona"),
        "careRefs": source_refs(context_evidence, "care"),
        "filteredContextReasons": context_evidence.get("filteredContextReasons") or [],
        "selectedContextSourceCounts": context_evidence.get("selectedContextSourceCounts") or {},
        "rankingTraceCount": context_evidence.get("rankingTraceCount", 0),
        "fallbacks": context_evidence.get("fallbacks") or [],
        "latencyMs": context_evidence.get("latencyMs", 0),
    }


def make_digital_human_session_summary(
    runtime_evidence: Dict[str, Any],
    session_evidence: Dict[str, Any],
    context_evidence: Dict[str, Any],
) -> Dict[str, Any]:
    runtime_dh = runtime_evidence.get("digitalHuman") or {}
    return {
        "runtimeProvider": runtime_dh.get("provider"),
        "runtimeProviderMode": runtime_dh.get("providerMode"),
        "runtimeRealProviderReady": runtime_dh.get("realProviderReady"),
        "contextSessionReady": context_evidence.get("digitalHumanSessionReady"),
        "contextProviderMode": context_evidence.get("digitalHumanProviderMode"),
        "sessionStatusCode": session_evidence.get("statusCode"),
        "sessionId": session_evidence.get("sessionId"),
        "provider": session_evidence.get("provider"),
        "providerMode": session_evidence.get("providerMode"),
        "hasProviderAssetId": session_evidence.get("hasProviderAssetId"),
        "hasProviderProjectId": session_evidence.get("hasProviderProjectId"),
        "credentialMode": session_evidence.get("credentialMode"),
        "hasBackendIssuedCredential": bool(session_evidence.get("hasAppkey") and session_evidence.get("hasAccessToken")),
        "fallbackMode": session_evidence.get("fallbackMode"),
    }


def make_voice_synthesis_summary(
    runtime_evidence: Dict[str, Any],
    synthesis_evidence: Dict[str, Any],
    context_evidence: Dict[str, Any],
    status: str,
) -> Dict[str, Any]:
    voice_clone = runtime_evidence.get("voiceClone") or {}
    tencent_audio_drive = voice_clone.get("tencentAudioDrive") or {}
    return {
        "runtimeProvider": voice_clone.get("provider"),
        "runtimeEnabled": voice_clone.get("enabled"),
        "runtimeFallbackMode": voice_clone.get("fallbackMode"),
        "tencentAudioDrive": tencent_audio_drive,
        "contextVoiceProfileId": context_evidence.get("voiceProfileId"),
        "contextVoiceCloneReady": context_evidence.get("voiceCloneReady"),
        "contextOutputMode": context_evidence.get("voiceOutputMode"),
        "probeStatus": status,
        "voiceProfileId": synthesis_evidence.get("voiceProfileId"),
        "outputMode": synthesis_evidence.get("outputMode"),
        "audioFormat": synthesis_evidence.get("audioFormat"),
        "sampleRate": synthesis_evidence.get("sampleRate"),
        "byteCount": synthesis_evidence.get("byteCount"),
        "providerLogId": synthesis_evidence.get("providerLogId"),
        "providerRequestId": synthesis_evidence.get("providerRequestId"),
    }


def make_fallback_summary(
    checks: List[Dict[str, Any]],
    context_evidence: Dict[str, Any],
    digital_human_summary: Dict[str, Any],
    voice_synthesis_summary: Dict[str, Any],
) -> Dict[str, Any]:
    failed_checks = [check["name"] for check in checks if check.get("status") == "failed"]
    skipped_checks = [check["name"] for check in checks if check.get("status") == "skipped"]
    context_fallbacks = context_evidence.get("fallbacks") or []
    inferred: List[str] = []
    if digital_human_summary.get("contextSessionReady") is False:
        inferred.append("digital_human_not_ready")
    if voice_synthesis_summary.get("contextVoiceCloneReady") is False:
        inferred.append("voice_clone_not_ready")
    if check_status(checks, "backend.voice_synthesis") == "skipped":
        inferred.append("voice_synthesis_probe_skipped")
    return {
        "contextFallbacks": context_fallbacks,
        "failedChecks": failed_checks,
        "skippedChecks": skipped_checks,
        "inferredFallbacks": inferred,
    }


def make_echo_trace_summary(
    checks: List[Dict[str, Any]]
) -> Dict[str, Any]:
    runtime_evidence = check_evidence(checks, "backend.runtime")
    context_evidence = check_evidence(checks, "backend.context_build")
    session_evidence = check_evidence(checks, "backend.digital_human_session")
    synthesis_evidence = check_evidence(checks, "backend.voice_synthesis")
    context_clues = make_context_clue_summary(context_evidence)
    digital_human_session = make_digital_human_session_summary(
        runtime_evidence,
        session_evidence,
        context_evidence,
    )
    voice_synthesis = make_voice_synthesis_summary(
        runtime_evidence,
        synthesis_evidence,
        context_evidence,
        check_status(checks, "backend.voice_synthesis"),
    )
    fallback_summary = make_fallback_summary(checks, context_evidence, digital_human_session, voice_synthesis)
    return {
        "contextClues": context_clues,
        "digitalHumanSession": digital_human_session,
        "voiceSynthesis": voice_synthesis,
        "fallbackSummary": fallback_summary,
    }


def make_report(checks: List[Dict[str, Any]]) -> str:
    echo_trace = make_echo_trace_summary(checks)
    lines = [
        "# Echo Readiness Report v2",
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

    lines.extend(["", "## Echo Trace Summary", "", "```json"])
    lines.append(json.dumps(echo_trace, ensure_ascii=False, indent=2, sort_keys=True))
    lines.extend(["```", "", "## Evidence", ""])
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

    echo_trace = make_echo_trace_summary(checks)
    result = {
        "schemaVersion": 2,
        "completed": all(check["status"] in ("passed", "skipped") for check in checks),
        "strict": STRICT,
        "backendURLConfigured": bool(BASE_URL),
        "backendTokenConfigured": bool(API_TOKEN),
        "echoTrace": echo_trace,
        "contextClues": echo_trace["contextClues"],
        "digitalHumanSession": echo_trace["digitalHumanSession"],
        "voiceSynthesis": echo_trace["voiceSynthesis"],
        "fallbackSummary": echo_trace["fallbackSummary"],
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
