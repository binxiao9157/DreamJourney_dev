#!/usr/bin/env python3
"""Build fail-closed Stage 0 readiness input from real QA artifacts.

The adapter intentionally emits only value-free GateResult fields for the
strict readiness evaluator. It does not close an external gate, persist an
artifact, or echo backend payloads, owner hashes, commits, or URLs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Optional, Sequence
from urllib.error import URLError
from urllib.request import Request, urlopen

from stage0_strict_readiness import INPUT_SCHEMA_VERSION, format_timestamp, parse_timestamp, safe_code


ADAPTER_SCHEMA_VERSION = "dreamjourney.stage0-readiness-artifact-adapter.v1"
_COMMIT = re.compile(r"^[0-9a-f]{7,64}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _artifact_id(prefix: str, payload: bytes) -> str:
    digest = hashlib.sha256(payload).hexdigest()[:24]
    return f"{prefix}.{digest}"


def _not_applicable(gate: str, *, required: bool) -> dict[str, object]:
    return {
        "gate": gate,
        "applicability": "notApplicable",
        "required": required,
        "status": "notApplicable",
        "evidenceId": None,
        "reason": "artifactNotRequested",
        "checkedAt": None,
        "expiresAt": None,
    }


def _missing(gate: str, *, required: bool, reason: str) -> dict[str, object]:
    return {
        "gate": gate,
        "applicability": "applicable",
        "required": required,
        "status": "missing",
        "evidenceId": None,
        "reason": reason,
        "checkedAt": None,
        "expiresAt": None,
    }


def _unknown(gate: str, *, required: bool, reason: str) -> dict[str, object]:
    return {
        "gate": gate,
        "applicability": "applicable",
        "required": required,
        "status": "unknown",
        "evidenceId": None,
        "reason": reason,
        "checkedAt": None,
        "expiresAt": None,
    }


def _result(
    gate: str,
    *,
    required: bool,
    status: str,
    evidence_id: Optional[str],
    reason: str,
    checked_at: Optional[datetime],
    expires_at: Optional[datetime],
) -> dict[str, object]:
    return {
        "gate": gate,
        "applicability": "applicable",
        "required": required,
        "status": status,
        "evidenceId": evidence_id,
        "reason": reason,
        "checkedAt": format_timestamp(checked_at) if checked_at else None,
        "expiresAt": format_timestamp(expires_at) if expires_at else None,
    }


def _decode_json(path: Path) -> tuple[object, bytes]:
    payload = path.read_bytes()
    return json.loads(payload.decode("utf-8")), payload


def _backend_ready_gate(
    payload: object | None,
    *,
    artifact: bytes | None,
    required: bool,
    as_of: datetime,
    ttl_seconds: int,
    fetch_failed: bool = False,
) -> dict[str, object]:
    gate = "stage0.backendReadiness"
    if payload is None:
        if fetch_failed:
            return _result(
                gate,
                required=required,
                status="failed",
                evidence_id=None,
                reason="backendReadinessFetchFailed",
                checked_at=as_of,
                expires_at=None,
            )
        return _missing(gate, required=required, reason="backendReadinessArtifactMissing") if required else _not_applicable(gate, required=False)
    if not isinstance(payload, Mapping):
        return _unknown(gate, required=required, reason="backendReadinessPayloadInvalid")
    if payload.get("schemaVersion") != 1:
        return _unknown(gate, required=required, reason="backendReadinessSchemaInvalid")
    checked_at = parse_timestamp(payload.get("evidenceTimestamp"))
    if checked_at is None:
        return _unknown(gate, required=required, reason="backendReadinessTimestampInvalid")
    components = payload.get("components")
    if not isinstance(components, Sequence) or isinstance(components, (str, bytes)):
        return _unknown(gate, required=required, reason="backendReadinessComponentsInvalid")
    statuses: dict[str, str] = {}
    for component in components:
        if not isinstance(component, Mapping):
            return _unknown(gate, required=required, reason="backendReadinessComponentInvalid")
        name = safe_code(component.get("component"))
        status = component.get("status")
        if name is None or not isinstance(status, str):
            return _unknown(gate, required=required, reason="backendReadinessComponentInvalid")
        statuses[name] = status
    if any(statuses.get(name) != "ready" for name in ("database", "schema", "auth")):
        return _result(
            gate,
            required=required,
            status="failed",
            evidence_id=_artifact_id("backendReady", artifact or b""),
            reason="backendReadinessComponentNotReady",
            checked_at=checked_at,
            expires_at=checked_at + timedelta(seconds=ttl_seconds),
        )
    if payload.get("status") != "ready":
        return _result(
            gate,
            required=required,
            status="failed",
            evidence_id=_artifact_id("backendReady", artifact or b""),
            reason="backendReadinessNotReady",
            checked_at=checked_at,
            expires_at=checked_at + timedelta(seconds=ttl_seconds),
        )
    return _result(
        gate,
        required=required,
        status="passed",
        evidence_id=_artifact_id("backendReady", artifact or b""),
        reason="backendReadinessReady",
        checked_at=checked_at,
        expires_at=checked_at + timedelta(seconds=ttl_seconds),
    )


def _latest_manifest(payload: object) -> Optional[Mapping[str, object]]:
    if isinstance(payload, Mapping):
        nested = payload.get("manifests")
        if isinstance(nested, list):
            payload = nested
        else:
            return payload
    if not isinstance(payload, list):
        return None
    candidates = [item for item in payload if isinstance(item, Mapping)]
    return candidates[-1] if candidates else None


def _echo_manifest_gate(
    payload: object | None,
    *,
    artifact: bytes | None,
    required: bool,
    as_of: datetime,
) -> dict[str, object]:
    gate = "stage0.echoQaEvidence"
    if payload is None:
        return _missing(gate, required=required, reason="echoManifestArtifactMissing") if required else _not_applicable(gate, required=False)
    manifest = _latest_manifest(payload)
    if manifest is None:
        return _unknown(gate, required=required, reason="echoManifestPayloadInvalid")
    if manifest.get("schemaVersion") != 1 or manifest.get("manifestVersion") != 1:
        return _unknown(gate, required=required, reason="echoManifestSchemaInvalid")
    if manifest.get("manifestType") != "echoQaEvidenceBundle" or manifest.get("commandId") != "exportEchoQAEvidenceBundle":
        return _unknown(gate, required=required, reason="echoManifestTypeInvalid")
    evidence_id = safe_code(manifest.get("evidenceId"))
    if evidence_id is None:
        return _unknown(gate, required=required, reason="echoManifestEvidenceIdInvalid")
    source_commit = manifest.get("sourceCommit")
    if not isinstance(source_commit, str) or not _COMMIT.fullmatch(source_commit):
        return _unknown(gate, required=required, reason="echoManifestSourceCommitInvalid")
    hashes = manifest.get("artifactHashes")
    if not isinstance(hashes, list) or not hashes or any(not isinstance(item, str) or not _SHA256.fullmatch(item) for item in hashes):
        return _unknown(gate, required=required, reason="echoManifestArtifactHashInvalid")
    owner_lease_hash = manifest.get("ownerLeaseHash")
    if not isinstance(owner_lease_hash, str) or not _SHA256.fullmatch(owner_lease_hash):
        return _unknown(gate, required=required, reason="echoManifestOwnerScopeInvalid")
    sample_count = manifest.get("sampleCount")
    if not isinstance(sample_count, int) or isinstance(sample_count, bool) or sample_count < 1:
        return _unknown(gate, required=required, reason="echoManifestSampleInvalid")
    checked_at = parse_timestamp(manifest.get("issuedAt"))
    expires_at = parse_timestamp(manifest.get("expiresAt"))
    if checked_at is None or expires_at is None or expires_at <= checked_at:
        return _unknown(gate, required=required, reason="echoManifestWindowInvalid")
    if expires_at <= as_of:
        return _result(
            gate,
            required=required,
            status="expired",
            evidence_id=evidence_id,
            reason="echoManifestExpired",
            checked_at=checked_at,
            expires_at=expires_at,
        )
    if manifest.get("manifestStatus") != "passed":
        return _result(
            gate,
            required=required,
            status="unknown",
            evidence_id=evidence_id,
            reason="echoManifestUnverified",
            checked_at=checked_at,
            expires_at=expires_at,
        )
    return _result(
        gate,
        required=required,
        status="passed",
        evidence_id=evidence_id,
        reason="echoManifestCurrent",
        checked_at=checked_at,
        expires_at=expires_at,
    )


def build_readiness_input(
    *,
    backend_payload: object | None,
    backend_artifact: bytes | None,
    echo_manifest_payload: object | None,
    echo_manifest_artifact: bytes | None,
    require_backend_ready: bool,
    require_echo_manifest: bool,
    as_of: datetime,
    backend_ttl_seconds: int,
    backend_fetch_failed: bool = False,
) -> dict[str, object]:
    return {
        "schemaVersion": INPUT_SCHEMA_VERSION,
        "adapterSchemaVersion": ADAPTER_SCHEMA_VERSION,
        "gateResults": [
            _backend_ready_gate(
                backend_payload,
                artifact=backend_artifact,
                required=require_backend_ready,
                as_of=as_of,
                ttl_seconds=backend_ttl_seconds,
                fetch_failed=backend_fetch_failed,
            ),
            _echo_manifest_gate(
                echo_manifest_payload,
                artifact=echo_manifest_artifact,
                required=require_echo_manifest,
                as_of=as_of,
            ),
        ],
    }


def _fetch_backend_ready(url: str, *, timeout_seconds: float) -> tuple[object, bytes]:
    request = Request(url, headers={"Accept": "application/json"})
    with urlopen(request, timeout=timeout_seconds) as response:
        payload = response.read()
    return json.loads(payload.decode("utf-8")), payload


def main() -> None:
    parser = argparse.ArgumentParser(description="Build fail-closed Stage 0 readiness input from QA artifacts")
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--as-of", default=None, help="UTC ISO-8601 timestamp; defaults to current time")
    parser.add_argument("--backend-ready-file", type=Path)
    parser.add_argument("--backend-ready-url")
    parser.add_argument("--echo-manifest", type=Path)
    parser.add_argument("--require-backend-ready", action="store_true")
    parser.add_argument("--require-echo-manifest", action="store_true")
    parser.add_argument("--backend-ttl-seconds", type=int, default=900)
    parser.add_argument("--backend-timeout-seconds", type=float, default=5.0)
    arguments = parser.parse_args()

    if arguments.backend_ready_file and arguments.backend_ready_url:
        raise SystemExit("choose only one backend readiness artifact source")
    if arguments.backend_ttl_seconds < 1:
        raise SystemExit("--backend-ttl-seconds must be positive")
    if arguments.backend_timeout_seconds <= 0:
        raise SystemExit("--backend-timeout-seconds must be positive")
    as_of = parse_timestamp(arguments.as_of) if arguments.as_of else datetime.now(timezone.utc)
    if as_of is None:
        raise SystemExit("--as-of must be an ISO-8601 timestamp with a timezone")

    backend_payload: object | None = None
    backend_artifact: bytes | None = None
    backend_fetch_failed = False
    try:
        if arguments.backend_ready_file:
            backend_payload, backend_artifact = _decode_json(arguments.backend_ready_file)
        elif arguments.backend_ready_url:
            backend_payload, backend_artifact = _fetch_backend_ready(
                arguments.backend_ready_url,
                timeout_seconds=arguments.backend_timeout_seconds,
            )
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, URLError, TimeoutError):
        backend_fetch_failed = arguments.backend_ready_url is not None

    echo_payload: object | None = None
    echo_artifact: bytes | None = None
    if arguments.echo_manifest:
        try:
            echo_payload, echo_artifact = _decode_json(arguments.echo_manifest)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            echo_payload = {}

    output = build_readiness_input(
        backend_payload=backend_payload,
        backend_artifact=backend_artifact,
        echo_manifest_payload=echo_payload,
        echo_manifest_artifact=echo_artifact,
        require_backend_ready=arguments.require_backend_ready,
        require_echo_manifest=arguments.require_echo_manifest,
        as_of=as_of,
        backend_ttl_seconds=arguments.backend_ttl_seconds,
        backend_fetch_failed=backend_fetch_failed,
    )
    serialized = json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(serialized + "\n", encoding="utf-8")
    print(serialized)


if __name__ == "__main__":
    main()
