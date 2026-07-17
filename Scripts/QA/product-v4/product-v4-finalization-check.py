#!/usr/bin/env python3
"""Validate the reviewed DreamJourney V4 product/architecture baseline."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[3]
STATUS = "2026-07-16"
IOS_BASELINE = "feature/prd-stitch-ui-adaptation@8a1922b"
BACKEND_BASELINE = "main@4c0538b"
CANONICAL_SOURCE_CHECK = ROOT / "Scripts/QA/product-v4/product-v4-canonical-source-check.py"
CURRENT_HANDOFF_CHECK = ROOT / "Scripts/QA/product-v4/product-v4-current-handoff-check.py"

FILES = {
    "spec": "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md",
    "evidence": "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md",
    "decisions": "docs/product/DreamJourney_V4_产品决策登记册_V1.0.md",
    "roadmap": "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md",
    "checklist": "docs/product/DreamJourney_V4_评审与验收清单_V1.0.md",
    "wave1_product": "docs/product/reviews/DreamJourney_V4_Round5A_产品独立复审.md",
    "wave1_engineering": "docs/product/reviews/DreamJourney_V4_Round5A_工程独立复审.md",
    "wave1_risk": "docs/product/reviews/DreamJourney_V4_Round5A_安全隐私运维独立复审.md",
    "wave2_product": "docs/product/reviews/DreamJourney_V4_Round5C_产品盲审.md",
    "wave2_engineering": "docs/product/reviews/DreamJourney_V4_Round5C_工程盲审.md",
    "wave2_risk": "docs/product/reviews/DreamJourney_V4_Round5C_风险盲审.md",
    "wave2_index": "docs/product/reviews/DreamJourney_V4_Round5C_盲审覆盖索引.md",
    "trace": "docs/product/DreamJourney_V4_路线追踪矩阵_V1.0.md",
    "registry": "docs/product/DreamJourney_V4_路线执行注册表_V1.0.json",
}

ARTIFACT_KEYS = ("spec", "evidence", "decisions", "roadmap", "checklist")
WAVE1_KEYS = ("wave1_product", "wave1_engineering", "wave1_risk")
WAVE2_KEYS = ("wave2_product", "wave2_engineering", "wave2_risk", "wave2_index")
EXPECTED_WAVE1 = {
    *(f"R5A-PROD-{number:03d}" for number in range(1, 8)),
    *(f"R5A-ENG-{number:03d}" for number in range(1, 9)),
    *(f"R5A-RISK-{number:03d}" for number in range(1, 9)),
}
EXPECTED_WAVE2 = EXPECTED_WAVE1 - {"R5A-ENG-008"}
EXPECTED_COUNTS = {
    "Functional Requirements": "36",
    "Decision Records": "43",
    "Round 3 Findings": "22",
    "Canonical Risks": "12",
    "Work Packages": "13",
    "Work Items": "115",
    "Work Item fields": "1840",
}
REQUIRED_CHECKLIST_LINKS = {
    "spec": "DreamJourney_V4_评审与验收清单_V1.0.md",
    "evidence": "DreamJourney_V4_评审与验收清单_V1.0.md",
    "decisions": "DreamJourney_V4_评审与验收清单_V1.0.md",
    "roadmap": "DreamJourney_V4_评审与验收清单_V1.0.md",
}
CHECKLIST_BACKLINKS = (
    "DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md",
    "DreamJourney_V4_当前实现证据矩阵_V1.0.md",
    "DreamJourney_V4_产品决策登记册_V1.0.md",
    "2026-07-12-dreamjourney-v4-executable-development-roadmap.md",
)


def clean(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("`", "").strip())


def markdown_rows(text: str, identifier_pattern: str) -> dict[str, list[str]]:
    rows: dict[str, list[str]] = {}
    pattern = re.compile(identifier_pattern)
    for line in text.splitlines():
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [part.strip() for part in line[1:-1].split("|")]
        if not cells:
            continue
        identifier = clean(cells[0])
        if pattern.fullmatch(identifier):
            rows[identifier] = [clean(cell) for cell in cells]
    return rows


def read_inputs() -> dict[str, Any]:
    values: dict[str, Any] = {}
    for key, relative in FILES.items():
        path = ROOT / relative
        if not path.is_file():
            values[key] = None
            continue
        if key == "registry":
            try:
                values[key] = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                values[key] = {"__invalid_json__": True}
        else:
            values[key] = path.read_text(encoding="utf-8")
    return values


def validate_artifacts(values: dict[str, Any], errors: list[str]) -> None:
    for key in ARTIFACT_KEYS:
        text = values.get(key)
        if not isinstance(text, str):
            errors.append(f"ARTIFACT_MISSING: {FILES[key]}")
            continue
        header = "\n".join(text.splitlines()[:16])
        if STATUS not in header:
            errors.append(f"ARTIFACT_STATUS: {key} missing {STATUS}")
        if IOS_BASELINE not in header or BACKEND_BASELINE not in header:
            errors.append(f"ARTIFACT_BASELINE: {key} code baseline drift")
        if "115" not in header or not any(word in header for word in ("不表示", "不证明", "不代表")):
            errors.append(f"IMPLEMENTATION_OVERCLAIM: {key} lacks explicit non-implementation boundary")

    for key, required in REQUIRED_CHECKLIST_LINKS.items():
        text = values.get(key)
        if isinstance(text, str) and required not in text[:1600]:
            errors.append(f"ARTIFACT_LINK: {key} cannot locate review checklist")

    checklist = values.get("checklist")
    if isinstance(checklist, str):
        for required in CHECKLIST_BACKLINKS:
            if required not in checklist[:3000]:
                errors.append(f"ARTIFACT_LINK: checklist missing backlink {required}")


def validate_wave1(values: dict[str, Any], errors: list[str]) -> dict[str, list[str]]:
    report_ids: set[str] = set()
    for key in WAVE1_KEYS:
        text = values.get(key)
        if not isinstance(text, str):
            errors.append(f"REVIEW_WAVE_MISSING: {key}")
            continue
        report_ids.update(re.findall(r"^###\s+(R5A-(?:PROD|ENG|RISK)-\d{3})\s*$", text, re.MULTILINE))
    if report_ids != EXPECTED_WAVE1:
        errors.append(
            "WAVE1_SET: expected 23 exact IDs; "
            f"missing={sorted(EXPECTED_WAVE1 - report_ids)} extra={sorted(report_ids - EXPECTED_WAVE1)}"
        )

    checklist = values.get("checklist")
    if not isinstance(checklist, str):
        return {}
    rows = markdown_rows(checklist, r"R5A-(?:PROD|ENG|RISK)-\d{3}")
    if set(rows) != EXPECTED_WAVE1:
        errors.append(
            "DISPOSITION_SET: expected 23 exact IDs; "
            f"missing={sorted(EXPECTED_WAVE1 - set(rows))} extra={sorted(set(rows) - EXPECTED_WAVE1)}"
        )
        return rows

    for identifier, cells in rows.items():
        if len(cells) < 8:
            errors.append(f"DISPOSITION_ROW: {identifier} has {len(cells)} cells")
            continue
        severity, disposition = cells[1], cells[3]
        document_status, underlying = cells[4], cells[5]
        authority_gate = cells[6]
        if severity == "P0" and not document_status.startswith("CLOSED"):
            errors.append(f"P0_UNDISPOSITIONED: {identifier} document={document_status}")
        if severity == "P0" and underlying in {"IMPLEMENTED", "VERIFIED", "COMPLETE"}:
            errors.append(f"IMPLEMENTATION_OVERCLAIM: {identifier} underlying={underlying}")
        if severity == "P1":
            left, separator, right = authority_gate.partition("/")
            if not separator or not left.strip() or not right.strip():
                errors.append(f"P1_GATE_OWNER: {identifier} authority/gate is incomplete")
        if disposition == "EXTERNAL_REQUIRED" and underlying != "EXTERNAL_BLOCKED":
            errors.append(f"EXTERNAL_GATE_CLOSED: {identifier} underlying={underlying}")

    eng008 = rows.get("R5A-ENG-008", [])
    if "ARTIFACT_COMMIT_REQUIRED" not in eng008:
        errors.append("ARTIFACT_COMMIT: R5A-ENG-008 must remain ARTIFACT_COMMIT_REQUIRED")
    return rows


def validate_wave2(
    values: dict[str, Any],
    disposition_rows: dict[str, list[str]],
    errors: list[str],
) -> None:
    raw_ids: set[str] = set()
    for key in WAVE2_KEYS[:-1]:
        text = values.get(key)
        if not isinstance(text, str):
            errors.append(f"REVIEW_WAVE_MISSING: {key}")
            continue
        rows = markdown_rows(text, r"R5A-(?:PROD|ENG|RISK)-\d{3}")
        raw_ids.update(rows)
        for identifier, cells in rows.items():
            if "VERIFIED" not in cells:
                errors.append(f"WAVE2_VALIDATION: {identifier} is not VERIFIED in {key}")
    if raw_ids != EXPECTED_WAVE2:
        errors.append(
            "WAVE2_RAW_SET: expected 22 exact IDs; "
            f"missing={sorted(EXPECTED_WAVE2 - raw_ids)} extra={sorted(raw_ids - EXPECTED_WAVE2)}"
        )

    index = values.get("wave2_index")
    if not isinstance(index, str):
        errors.append("REVIEW_WAVE_MISSING: wave2_index")
        return
    rows = markdown_rows(index, r"R5A-(?:PROD|ENG|RISK)-\d{3}")
    if set(rows) != EXPECTED_WAVE2:
        errors.append(
            "WAVE2_INDEX_SET: expected 22 exact IDs; "
            f"missing={sorted(EXPECTED_WAVE2 - set(rows))} extra={sorted(set(rows) - EXPECTED_WAVE2)}"
        )
    for identifier, cells in rows.items():
        if "VERIFIED" not in cells:
            errors.append(f"WAVE2_VALIDATION: {identifier} index status is not VERIFIED")
    if "CHALLENGED` | 0" not in index and "CHALLENGED | 0" not in clean(index):
        errors.append("WAVE2_CHALLENGE: index must report CHALLENGED=0")

    checklist = values.get("checklist")
    if isinstance(checklist, str):
        fixed = re.search(
            r"^\|\s*`R5C-PROD-001`\s*\|.*\|\s*`FIXED`\s*\|\s*`CLOSED`\s*\|",
            checklist,
            re.MULTILINE,
        )
        if not fixed:
            errors.append("R5C_DISPOSITION: R5C-PROD-001 is not FIXED/CLOSED")

    expected_from_disposition = {
        identifier for identifier, cells in disposition_rows.items() if len(cells) > 1 and cells[1] in {"P0", "P1"}
    }
    if expected_from_disposition and expected_from_disposition != set(rows):
        errors.append("WAVE2_COVERAGE: P0/P1 disposition set differs from Wave2 index")


def validate_counts_and_freshness(values: dict[str, Any], errors: list[str]) -> None:
    checklist = values.get("checklist")
    if isinstance(checklist, str):
        for label, expected in EXPECTED_COUNTS.items():
            if not re.search(rf"\|\s*{re.escape(label)}\s*\|\s*{expected}\s*\|", checklist):
                errors.append(f"COUNT_DRIFT: checklist {label} != {expected}")
        if "expected=22 / covered=22 / `VERIFIED=22` / `CHALLENGED=0`" not in checklist:
            errors.append("COUNT_DRIFT: checklist Wave2 summary is not 22/22/22/0")

    trace = values.get("trace")
    if not isinstance(trace, str):
        errors.append("ARTIFACT_MISSING: trace")
    elif "36 FR / 43 DR / 22 Finding / 12 CR / 13 Package / 115 Work Item" not in trace:
        errors.append("COUNT_DRIFT: trace baseline mismatch")

    registry = values.get("registry")
    if not isinstance(registry, dict) or registry.get("__invalid_json__"):
        errors.append("REGISTRY_INVALID: registry is missing or invalid")
        return
    counts = registry.get("counts", {})
    expected_registry = {"packages": 13, "workItems": 115, "sourceFields": 1840}
    if counts != expected_registry:
        errors.append(f"COUNT_DRIFT: registry counts={counts!r}")
    if len(registry.get("packages", [])) != 13 or len(registry.get("workItems", [])) != 115:
        errors.append("COUNT_DRIFT: registry list lengths mismatch")

    baseline = registry.get("baseline", {})
    if baseline.get("implementationClaim") != "NONE":
        errors.append("IMPLEMENTATION_OVERCLAIM: registry implementationClaim must be NONE")
    if baseline.get("gateEvidence") != "MISSING":
        errors.append("IMPLEMENTATION_OVERCLAIM: registry gateEvidence must remain MISSING")
    decision = baseline.get("decision", {})
    if decision.get("coreAndMvpExtension") != "STOP" or decision.get("migration") != "NO_GO":
        errors.append("IMPLEMENTATION_OVERCLAIM: registry STOP/NO_GO baseline drift")

    roadmap = values.get("roadmap")
    source = registry.get("source", {})
    if not isinstance(roadmap, str):
        errors.append("REGISTRY_STALE: roadmap unavailable")
        return
    actual_hash = hashlib.sha256(roadmap.encode("utf-8")).hexdigest()
    if source.get("path") != FILES["roadmap"] or source.get("sha256") != actual_hash:
        errors.append("REGISTRY_STALE: roadmap source path/hash mismatch")


def validate(values: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    validate_artifacts(values, errors)
    disposition_rows = validate_wave1(values, errors)
    validate_wave2(values, disposition_rows, errors)
    validate_counts_and_freshness(values, errors)
    return errors


def replace_once(values: dict[str, Any], key: str, old: str, new: str) -> None:
    text = values[key]
    if not isinstance(text, str) or old not in text:
        raise AssertionError(f"fixture source missing for {key}: {old!r}")
    values[key] = text.replace(old, new, 1)


def run_self_test(values: dict[str, Any]) -> int:
    baseline_errors = validate(values)
    if baseline_errors:
        print("FAIL: self-test baseline is invalid", file=sys.stderr)
        for error in baseline_errors:
            print(error, file=sys.stderr)
        return 1

    fixtures: list[tuple[str, str, Callable[[dict[str, Any]], None]]] = [
        ("missing_artifact", "ARTIFACT_MISSING", lambda item: item.__setitem__("spec", None)),
        ("missing_review_wave", "REVIEW_WAVE_MISSING", lambda item: item.__setitem__("wave2_product", None)),
        (
            "p0_undispositioned",
            "P0_UNDISPOSITIONED",
            lambda item: replace_once(item, "checklist", "| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `CLOSED` |", "| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `OPEN` |"),
        ),
        (
            "p1_without_gate_owner",
            "P1_GATE_OWNER",
            lambda item: replace_once(item, "checklist", "| `R5A-PROD-004` | P1 | C06 | `ACCEPTED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-S3-01` / G2、G4 |", "| `R5A-PROD-004` | P1 | C06 | `ACCEPTED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` | `WP-S3-01` |"),
        ),
        (
            "external_gate_closed",
            "EXTERNAL_GATE_CLOSED",
            lambda item: replace_once(item, "checklist", "| `R5A-RISK-007` | P1 | C10 | `EXTERNAL_REQUIRED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` |", "| `R5A-RISK-007` | P1 | C10 | `EXTERNAL_REQUIRED` | `CLOSED_WITH_EXTERNAL_GATE` | `IMPLEMENTED` |"),
        ),
        (
            "count_drift",
            "COUNT_DRIFT",
            lambda item: item["registry"]["counts"].__setitem__("workItems", 114),
        ),
        (
            "broken_link",
            "ARTIFACT_LINK",
            lambda item: replace_once(item, "spec", "DreamJourney_V4_评审与验收清单_V1.0.md", "missing-review-checklist.md"),
        ),
        (
            "stale_registry",
            "REGISTRY_STALE",
            lambda item: item["registry"]["source"].__setitem__("sha256", "0" * 64),
        ),
        (
            "implementation_overclaim",
            "IMPLEMENTATION_OVERCLAIM",
            lambda item: item["registry"]["baseline"].__setitem__("implementationClaim", "IMPLEMENTED"),
        ),
        (
            "wave2_challenged",
            "WAVE2_VALIDATION",
            lambda item: replace_once(item, "wave2_index", "| `R5A-PROD-001` | P0 | `ACCEPTED` | Product | `VERIFIED` |", "| `R5A-PROD-001` | P0 | `ACCEPTED` | Product | `CHALLENGED` |"),
        ),
    ]

    failures: list[str] = []
    for name, expected_code, mutate in fixtures:
        candidate = copy.deepcopy(values)
        mutate(candidate)
        errors = validate(candidate)
        if not any(error.startswith(expected_code) for error in errors):
            failures.append(f"{name}: expected {expected_code}, actual={errors}")
    if failures:
        print("FAIL: finalization self-test", file=sys.stderr)
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1

    print(f"PASS: finalization self-test baseline_errors=0 fixtures={len(fixtures)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    for label, check_path in (
        ("canonical source guard", CANONICAL_SOURCE_CHECK),
        ("current execution handoff", CURRENT_HANDOFF_CHECK),
    ):
        check_result = subprocess.run(
            [sys.executable, str(check_path)],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )
        if check_result.returncode != 0:
            if check_result.stdout:
                print(check_result.stdout.rstrip(), file=sys.stderr)
            if check_result.stderr:
                print(check_result.stderr.rstrip(), file=sys.stderr)
            print(f"Product V4 finalization check failed: {label}", file=sys.stderr)
            return 1

    values = read_inputs()
    if args.self_test:
        return run_self_test(values)

    errors = validate(values)
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"Product V4 finalization check failed: errors={len(errors)}", file=sys.stderr)
        return 1

    print(
        "Product V4 finalization check passed: "
        "canonical_sources=guarded current_handoff=guarded artifacts=5 wave1=23 wave2=22 verified=22 challenged=0 "
        "FR=36 DR=43 findings=22 risks=12 packages=13 work_items=115 fields=1840"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
