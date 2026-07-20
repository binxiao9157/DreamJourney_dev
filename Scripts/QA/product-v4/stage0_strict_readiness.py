#!/usr/bin/env python3
"""Fail-closed aggregation for Stage 0 operational readiness evidence.

This is deliberately a QA-side contract evaluator.  It does not make a
release decision, call a provider, or turn an external Gate into a pass.  Its
only job is to make the required evidence states explicit and deterministic so
that skipped, missing, unknown, or expired evidence cannot look complete.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Tuple


SCHEMA_VERSION = "dreamjourney.stage0-strict-readiness.v1"
INPUT_SCHEMA_VERSION = "dreamjourney.stage0-readiness-input.v1"
VALID_STATUSES = frozenset(
    {
        "passed",
        "failed",
        "blocked",
        "notRun",
        "missing",
        "unknown",
        "expired",
        "notApplicable",
    }
)
STATUS_ALIASES = {
    "skipped": "notRun",
    "not-run": "notRun",
    "not_run": "notRun",
    "notrun": "notRun",
    "not-applicable": "notApplicable",
    "not_applicable": "notApplicable",
    "notapplicable": "notApplicable",
}
BLOCKING_PRIORITY = {
    "failed": 0,
    "blocked": 1,
    "expired": 2,
    "missing": 3,
    "notRun": 4,
    "unknown": 5,
}
ACTION_BY_STATUS = {
    "failed": "remediateFailure",
    "blocked": "resolveExternalBlocker",
    "expired": "reissueEvidence",
    "missing": "attachRequiredEvidence",
    "notRun": "runRequiredGate",
    "unknown": "resolveUnknownGateState",
}
SAFE_CODE = re.compile(r"[A-Za-z0-9_.:-]{1,160}$")


def parse_timestamp(value: Any) -> Optional[datetime]:
    if not isinstance(value, str) or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(timezone.utc)


def format_timestamp(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def safe_code(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    candidate = value.strip()
    return candidate if SAFE_CODE.fullmatch(candidate) else None


def normalize_status(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    candidate = value.strip()
    if candidate in VALID_STATUSES:
        return candidate
    lowered = candidate.lower()
    return STATUS_ALIASES.get(lowered)


def normalize_applicability(raw: Mapping[str, Any]) -> Optional[str]:
    value = raw.get("applicability", raw.get("applicable"))
    if value is True or value == "applicable":
        return "applicable"
    if value is False or value == "notApplicable":
        return "notApplicable"
    return None


def evaluate_gate(raw: Mapping[str, Any], *, index: int, as_of: datetime) -> Dict[str, Any]:
    """Normalize a single untrusted gate result into a fail-closed record."""

    gate = safe_code(raw.get("gate")) or f"invalidGate.{index:03d}"
    applicability = normalize_applicability(raw)
    required = raw.get("required")
    requested_status = normalize_status(raw.get("status"))
    requested_reason = safe_code(raw.get("reason"))
    evidence_id = safe_code(raw.get("evidenceId"))
    checked_at = parse_timestamp(raw.get("checkedAt"))
    expires_at = parse_timestamp(raw.get("expiresAt"))

    result: Dict[str, Any] = {
        "gate": gate,
        "applicability": applicability or "applicable",
        "required": required is True,
        "status": requested_status or "missing",
        "evidenceId": evidence_id,
        "reason": requested_reason or "missingReasonCode",
        "checkedAt": format_timestamp(checked_at) if checked_at else None,
        "expiresAt": format_timestamp(expires_at) if expires_at else None,
        "current": False,
    }

    if not safe_code(raw.get("gate")):
        result.update(status="missing", reason="missingGateCode")
        return result
    if applicability is None:
        result.update(status="missing", reason="missingApplicability")
        return result
    if not isinstance(required, bool):
        result.update(status="missing", reason="missingRequiredFlag")
        return result
    if requested_status is None:
        result.update(status="unknown", reason="unknownGateStatus")
        return result
    if requested_reason is None:
        result.update(status="unknown", reason="invalidReasonCode")
        return result

    if applicability == "notApplicable":
        if requested_status not in {"notApplicable", "passed"}:
            result.update(status="unknown", reason="invalidNotApplicableStatus")
            return result
        result.update(status="notApplicable", reason="notApplicable", evidenceId=None)
        return result

    if requested_status == "notApplicable":
        result.update(status="unknown", reason="applicableGateCannotBeNotApplicable")
        return result

    if requested_status == "passed":
        if evidence_id is None:
            result.update(status="missing", reason="missingEvidenceId")
            return result
        if checked_at is None:
            result.update(status="missing", reason="missingCheckedAt")
            return result
        if expires_at is None:
            result.update(status="missing", reason="missingExpiresAt")
            return result
        if checked_at > as_of:
            result.update(status="unknown", reason="checkedAtInFuture")
            return result
        if expires_at <= checked_at:
            result.update(status="unknown", reason="invalidEvidenceWindow")
            return result
        if expires_at <= as_of:
            result.update(status="expired", reason="evidenceExpired")
            return result
        result["current"] = True
        return result

    if requested_status == "notRun":
        result["reason"] = "skippedIsNotPass" if str(raw.get("status")).strip() == "skipped" else requested_reason
    return result


def mark_duplicate_gates(results: Iterable[Dict[str, Any]]) -> None:
    by_gate: Dict[str, List[Dict[str, Any]]] = {}
    for result in results:
        by_gate.setdefault(str(result["gate"]), []).append(result)
    for duplicate_results in by_gate.values():
        if len(duplicate_results) < 2:
            continue
        for result in duplicate_results:
            result.update(status="unknown", reason="duplicateGateResult", current=False)


def aggregate(results: List[Dict[str, Any]]) -> Dict[str, Any]:
    required_applicable = [
        item
        for item in results
        if item.get("required") is True and item.get("applicability") == "applicable"
    ]
    blockers = [item for item in required_applicable if item.get("status") != "passed" or item.get("current") is not True]
    passed = [item for item in required_applicable if item.get("status") == "passed" and item.get("current") is True]

    if not required_applicable:
        return {
            "completed": False,
            "status": "unknown",
            "reason": "noRequiredApplicableGates",
            "requiredGateCount": 0,
            "currentPassedRequiredGateCount": 0,
            "blockingGateCount": 0,
            "nextAction": {
                "actionCode": "registerRequiredGate",
                "gate": None,
                "status": "unknown",
                "reason": "noRequiredApplicableGates",
            },
        }

    if not blockers:
        return {
            "completed": True,
            "status": "passed",
            "reason": "allRequiredApplicableGatesCurrent",
            "requiredGateCount": len(required_applicable),
            "currentPassedRequiredGateCount": len(passed),
            "blockingGateCount": 0,
            "nextAction": None,
        }

    def blocking_key(item: Mapping[str, Any]) -> Tuple[int, str]:
        status = str(item.get("status") or "unknown")
        return (BLOCKING_PRIORITY.get(status, len(BLOCKING_PRIORITY)), str(item.get("gate") or ""))

    selected = sorted(blockers, key=blocking_key)[0]
    status = str(selected.get("status") or "unknown")
    return {
        "completed": False,
        "status": status,
        "reason": "requiredGateNotCurrent",
        "requiredGateCount": len(required_applicable),
        "currentPassedRequiredGateCount": len(passed),
        "blockingGateCount": len(blockers),
        "nextAction": {
            "actionCode": ACTION_BY_STATUS.get(status, "resolveUnknownGateState"),
            "gate": selected.get("gate"),
            "status": status,
            "reason": selected.get("reason"),
        },
    }


def build_report(payload: Mapping[str, Any], *, as_of: datetime) -> Dict[str, Any]:
    input_schema = safe_code(payload.get("schemaVersion")) or "unknown"
    raw_results = payload.get("gateResults")
    if isinstance(raw_results, list):
        results = [
            evaluate_gate(raw, index=index, as_of=as_of)
            if isinstance(raw, Mapping)
            else evaluate_gate({}, index=index, as_of=as_of)
            for index, raw in enumerate(raw_results, start=1)
        ]
    else:
        results = [
            {
                "gate": "stage0.inputShape",
                "applicability": "applicable",
                "required": True,
                "status": "missing",
                "evidenceId": None,
                "reason": "missingGateResultsArray",
                "checkedAt": None,
                "expiresAt": None,
                "current": False,
            }
        ]
    if input_schema != INPUT_SCHEMA_VERSION:
        results.append(
            {
                "gate": "stage0.inputSchema",
                "applicability": "applicable",
                "required": True,
                "status": "unknown",
                "evidenceId": None,
                "reason": "inputSchemaMismatch",
                "checkedAt": None,
                "expiresAt": None,
                "current": False,
            }
        )
    mark_duplicate_gates(results)
    summary = aggregate(results)
    return {
        "schemaVersion": SCHEMA_VERSION,
        "inputSchemaVersion": input_schema,
        "asOf": format_timestamp(as_of),
        "completed": summary["completed"],
        "status": summary["status"],
        "reason": summary["reason"],
        "requiredGateCount": summary["requiredGateCount"],
        "currentPassedRequiredGateCount": summary["currentPassedRequiredGateCount"],
        "blockingGateCount": summary["blockingGateCount"],
        "nextAction": summary["nextAction"],
        "gateResults": results,
    }


def load_payload(path: Path) -> Mapping[str, Any]:
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, Mapping):
        raise ValueError("readiness input must be a JSON object")
    return decoded


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate Stage 0 readiness evidence fail-closed")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--as-of", default=None, help="UTC ISO-8601 timestamp; defaults to current time")
    parser.add_argument("--strict", action="store_true", help="exit nonzero unless every required applicable gate is current")
    arguments = parser.parse_args()

    as_of = parse_timestamp(arguments.as_of) if arguments.as_of else datetime.now(timezone.utc)
    if as_of is None:
        raise SystemExit("--as-of must be an ISO-8601 timestamp with a timezone")
    try:
        payload = load_payload(arguments.input)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(f"unable to read readiness input: {error}") from error

    report = build_report(payload, as_of=as_of)
    serialized = json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True)
    if arguments.output:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(serialized + "\n", encoding="utf-8")
    print(serialized)
    if arguments.strict and not report["completed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
