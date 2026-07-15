#!/usr/bin/env python3
"""Independently check the Round 5A review disposition baseline."""

from __future__ import annotations

import argparse
import copy
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]

FILES = {
    "product": "docs/product/reviews/DreamJourney_V4_Round5A_产品独立复审.md",
    "engineering": "docs/product/reviews/DreamJourney_V4_Round5A_工程独立复审.md",
    "risk": "docs/product/reviews/DreamJourney_V4_Round5A_安全隐私运维独立复审.md",
    "index": "docs/product/reviews/DreamJourney_V4_Round5A_独立复审索引.md",
    "checklist": "docs/product/DreamJourney_V4_评审与验收清单_V1.0.md",
    "trace": "docs/product/DreamJourney_V4_路线追踪矩阵_V1.0.md",
    "registry": "docs/product/DreamJourney_V4_路线执行注册表_V1.0.json",
}

EXPECTED_REPORT_COUNTS = {"product": 7, "engineering": 8, "risk": 8}
EXPECTED_SEVERITY_COUNTS = {"P0": 7, "P1": 15, "P2": 1}
EXPECTED_DISPOSITIONS = {
    "FIXED": 3,
    "ACCEPTED": 18,
    "DECISION_REQUIRED": 0,
    "EXTERNAL_REQUIRED": 2,
    "REJECTED_WITH_REASON": 0,
}
EXPECTED_COVERAGE = {
    "Functional Requirements": "36",
    "Decision Records": "43",
    "Round 3 Findings": "22",
    "Canonical Risks": "12",
    "Work Packages": "13",
    "Work Items": "115",
    "Work Item fields": "1840",
}
EXPECTED_STATUS = "PRODUCT_DECISIONS_SYNCED_IMPLEMENTATION_UNVERIFIED"
ALLOWED_DISPOSITIONS = set(EXPECTED_DISPOSITIONS)
ALLOWED_DOCUMENT_STATUSES = {
    "CLOSED",
    "CLOSED_WITH_EXTERNAL_GATE",
    "CLOSED_WITH_EXTERNAL_GATES",
    "CLOSED_WITH_DECISION_GATE",
    "CLOSED_WITH_REASON",
    "OPEN",
    "OPEN_WITH_REASON",
}
ALLOWED_UNDERLYING_STATUSES = {
    "OPEN_BLOCKER",
    "PLANNED",
    "EXTERNAL_BLOCKED",
    "DECISION_OPEN",
    "ARTIFACT_COMMIT_REQUIRED",
    "PRODUCT_CONFIRMED_IMPLEMENTATION_OPEN",
    "METRIC_IMPLEMENTATION_OPEN",
}
FORBIDDEN_COMPLETION_WORDS = {"COMPLETE", "VERIFIED", "IMPLEMENTED"}

TABLE_HEADERS = {
    "clusters": (
        "Cluster",
        "Raw Findings",
        "Relationship",
        "Shared Issue",
        "Severity Range",
    ),
    "disposition": (
        "Finding",
        "Sev",
        "Cluster",
        "Disposition",
        "Document status",
        "Underlying status",
        "Authority / Gate",
        "Verification",
    ),
    "controls": ("Control", "Baseline"),
    "packages": ("Package", "Current state", "Required evidence before VERIFIED", "Current authorization"),
}

ID_PATTERNS = {
    "FR": re.compile(r"FR-[A-Z]+-\d{3}"),
    "DR": re.compile(r"DR-\d{3}"),
    "FINDING": re.compile(r"(?:BAR|IAR|SOR)-\d{2}"),
    "CR": re.compile(r"CR-\d{2}"),
    "PACKAGE": re.compile(r"WP-(?:S\d|V\d|MIG)-\d{2}"),
    "WI": re.compile(r"WI-(?:S\d|V\d|MIG)-\d{2}-\d{2}"),
}
R5A_ID = re.compile(r"R5A-(?:PROD|ENG|RISK)-\d{3}")
SEVERITY = re.compile(r"P[012]")
GATE = re.compile(r"(?<![A-Z0-9])G[0-4](?![A-Z0-9])")


def clean(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("`", "").strip())


def table_cells(line: str) -> list[str]:
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        raise ValueError(f"not a Markdown table row: {line}")
    return [part.strip() for part in stripped[1:-1].split("|")]


def separator(line: str) -> bool:
    try:
        cells = table_cells(line)
    except ValueError:
        return False
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def section(text: str, heading: str, level: int) -> str:
    match = re.search(rf"^{'#' * level}\s+{re.escape(heading)}\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"missing heading: {heading}")
    end = re.search(rf"^#{{1,{level}}}\s+", text[match.end() :], re.MULTILINE)
    return text[match.end() : match.end() + (end.start() if end else len(text[match.end() :]))]


def find_table(block: str, headers: tuple[str, ...]) -> list[dict[str, str]]:
    lines = block.splitlines()
    for index in range(len(lines) - 1):
        if not lines[index].lstrip().startswith("|"):
            continue
        if tuple(table_cells(lines[index])) != headers or not separator(lines[index + 1]):
            continue
        rows: list[dict[str, str]] = []
        cursor = index + 2
        while cursor < len(lines) and lines[cursor].lstrip().startswith("|"):
            cells = table_cells(lines[cursor])
            if len(cells) != len(headers):
                raise ValueError(f"table row has {len(cells)} cells, expected {len(headers)}")
            rows.append(dict(zip(headers, cells)))
            cursor += 1
        return rows
    raise ValueError(f"missing table header: {headers[0]}")


def read_inputs() -> dict[str, Any]:
    values: dict[str, Any] = {}
    for name, relative in FILES.items():
        path = ROOT / relative
        if not path.is_file():
            raise ValueError(f"missing input: {relative}")
        if name == "registry":
            try:
                values[name] = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid registry JSON: {exc}") from exc
        else:
            values[name] = path.read_text(encoding="utf-8")
    return values


def report_expected_ids(kind: str) -> set[str]:
    prefix = {"product": "PROD", "engineering": "ENG", "risk": "RISK"}[kind]
    return {f"R5A-{prefix}-{number:03d}" for number in range(1, EXPECTED_REPORT_COUNTS[kind] + 1)}


def parse_report(kind: str, text: str, errors: list[str]) -> dict[str, str]:
    findings: dict[str, str] = {}
    try:
        block = section(text, "Findings", 2)
    except ValueError as exc:
        errors.append(f"REPORT_FINDINGS: {kind}: {exc}")
        return findings

    matches = list(re.finditer(r"^###\s+(\S+)\s*$", block, re.MULTILINE))
    for index, match in enumerate(matches):
        identifier = match.group(1)
        if not R5A_ID.fullmatch(identifier):
            continue
        if identifier in findings:
            errors.append(f"REPORT_FINDINGS: {kind}: duplicate {identifier}")
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else len(block)
        finding_block = block[match.end() : end]
        first_nonempty = next((line.strip() for line in finding_block.splitlines() if line.strip()), "")
        severity_match = re.fullmatch(r"-\s*Severity[：:]\s*`?(P[012])`?", first_nonempty)
        if not severity_match:
            errors.append(f"REPORT_SEVERITY: {identifier}: Severity is not the first field")
            continue
        findings[identifier] = severity_match.group(1)

    expected = report_expected_ids(kind)
    actual = set(findings)
    unknown = sorted(actual - expected)
    missing = sorted(expected - actual)
    if unknown or missing or len(findings) != EXPECTED_REPORT_COUNTS[kind]:
        errors.append(
            f"REPORT_FINDINGS: {kind}: expected {EXPECTED_REPORT_COUNTS[kind]} exact findings; "
            f"actual={len(findings)} missing={missing} extra={unknown}"
        )
    return findings


def parse_index(text: str, errors: list[str]) -> None:
    try:
        block = section(text, "Cross-Review Clusters", 2)
        rows = find_table(block, TABLE_HEADERS["clusters"])
    except ValueError as exc:
        errors.append(f"CLUSTERS: {exc}")
        return
    actual: list[str] = []
    for row in rows:
        identifier = clean(row["Cluster"])
        if not re.fullmatch(r"R5A-C\d{2}", identifier):
            errors.append(f"CLUSTERS: invalid cluster ID {identifier!r}")
        actual.append(identifier)
    expected = [f"R5A-C{number:02d}" for number in range(1, 14)]
    if len(rows) != 13 or len(actual) != len(set(actual)) or actual != expected:
        errors.append(f"CLUSTERS: expected exactly {expected}, actual={actual}")


def parse_controls(text: str, errors: list[str]) -> None:
    try:
        block = section(text, "2. 当前基线与精确覆盖", 2)
        rows = find_table(block, TABLE_HEADERS["controls"])
    except ValueError as exc:
        errors.append(f"COVERAGE: {exc}")
        return
    controls = {clean(row["Control"]): clean(row["Baseline"]) for row in rows}
    for control, expected in EXPECTED_COVERAGE.items():
        if controls.get(control) != expected:
            errors.append(f"COVERAGE: {control} expected {expected}, actual={controls.get(control)!r}")
    if len(controls) != len(rows):
        errors.append("COVERAGE: duplicate control row")
    status_match = re.search(r"^状态：`([^`]+)`", text, re.MULTILINE)
    if not status_match or status_match.group(1) != EXPECTED_STATUS:
        errors.append(f"COVERAGE: expected status {EXPECTED_STATUS}")
    raw_match = re.search(r"Round 5A raw findings\s*\|\s*23（P0=7 / P1=15 / P2=1）", block)
    if not raw_match:
        errors.append("COVERAGE: raw finding severity summary drift")


def parse_dispositions(
    text: str,
    report_findings: dict[str, str],
    errors: list[str],
) -> list[dict[str, str]]:
    try:
        block = section(text, "3.1 精确处置表", 3)
        rows = find_table(block, TABLE_HEADERS["disposition"])
    except ValueError as exc:
        errors.append(f"DISPOSITION: {exc}")
        return []

    parsed: list[dict[str, str]] = []
    seen: set[str] = set()
    for row in rows:
        identifier = clean(row["Finding"])
        parsed_row = {key: clean(value) for key, value in row.items()}
        parsed.append(parsed_row)
        if identifier in seen:
            errors.append(f"DISPOSITION: duplicate finding {identifier}")
        seen.add(identifier)
        if identifier not in report_findings:
            errors.append(f"DISPOSITION: unknown finding {identifier}")
            continue
        if parsed_row["Sev"] != report_findings[identifier]:
            errors.append(
                f"DISPOSITION: {identifier}: severity {parsed_row['Sev']} != {report_findings[identifier]}"
            )
        if parsed_row["Disposition"] not in ALLOWED_DISPOSITIONS:
            errors.append(f"DISPOSITION: {identifier}: invalid disposition {parsed_row['Disposition']}")
        if parsed_row["Document status"] not in ALLOWED_DOCUMENT_STATUSES:
            errors.append(
                f"DOCUMENT_STATUS: {identifier}: invalid status {parsed_row['Document status']}"
            )
        if parsed_row["Underlying status"] not in ALLOWED_UNDERLYING_STATUSES:
            errors.append(
                f"UNDERLYING_STATUS: {identifier}: invalid status {parsed_row['Underlying status']}"
            )
        if not parsed_row["Authority / Gate"] or not parsed_row["Verification"]:
            errors.append(f"DISPOSITION: {identifier}: Authority/Gate and Verification must be non-empty")
        if parsed_row["Sev"] in {"P1", "P2"}:
            authority_gate = parsed_row["Authority / Gate"]
            if (
                "/" not in authority_gate
                or not authority_gate.split("/", 1)[0].strip()
                or not authority_gate.split("/", 1)[1].strip()
            ):
                errors.append(f"DISPOSITION: {identifier}: P1/P2 requires non-empty Authority and Gate")
        if parsed_row["Sev"] == "P0":
            if not parsed_row["Document status"].startswith("CLOSED"):
                errors.append(f"P0_STATUS: {identifier}: document status is not CLOSED*")
            if parsed_row["Underlying status"] in FORBIDDEN_COMPLETION_WORDS:
                errors.append(f"P0_UNDERLYING: {identifier}: completion claim is forbidden")
        if (
            parsed_row["Disposition"] == "EXTERNAL_REQUIRED"
            and parsed_row["Underlying status"] != "EXTERNAL_BLOCKED"
        ):
            errors.append(
                f"EXTERNAL_STATUS: {identifier}: EXTERNAL_REQUIRED must remain EXTERNAL_BLOCKED"
            )

    expected_ids = set(report_findings)
    actual_ids = {clean(row["Finding"]) for row in rows}
    if len(rows) != 23 or actual_ids != expected_ids:
        errors.append(
            f"DISPOSITION: expected 23 exact findings; actual={len(rows)} "
            f"missing={sorted(expected_ids - actual_ids)} extra={sorted(actual_ids - expected_ids)}"
        )
    return parsed


def validate_disposition_stats(rows: list[dict[str, str]], errors: list[str]) -> None:
    counts = {name: 0 for name in EXPECTED_DISPOSITIONS}
    for row in rows:
        disposition = row.get("Disposition", "")
        if disposition in counts:
            counts[disposition] += 1
    if counts != EXPECTED_DISPOSITIONS:
        errors.append(f"DISPOSITION_STATS: expected {EXPECTED_DISPOSITIONS}, actual={counts}")

    p0 = [row for row in rows if row.get("Sev") == "P0"]
    closed = sum(row.get("Document status", "").startswith("CLOSED") for row in p0)
    complete = sum(row.get("Underlying status") in FORBIDDEN_COMPLETION_WORDS for row in p0)
    if len(p0) != 7 or closed != 7:
        errors.append(f"P0_STATUS: expected document closed 7/7, actual={closed}/{len(p0)}")
    if complete != 0:
        errors.append(f"P0_UNDERLYING: expected complete 0/7, actual={complete}/7")


def trace_section_rows(text: str, heading_prefix: str, headers: tuple[str, ...], errors: list[str], label: str) -> list[dict[str, str]]:
    try:
        match = re.search(rf"^##\s+{re.escape(heading_prefix)}.*$", text, re.MULTILINE)
        if not match:
            raise ValueError(f"missing heading {heading_prefix}")
        tail = text[match.end() :]
        next_heading = re.search(r"^##\s+", tail, re.MULTILINE)
        block = tail[: next_heading.start() if next_heading else len(tail)]
        return find_table(block, headers)
    except ValueError as exc:
        errors.append(f"TRACE: {label}: {exc}")
        return []


def trace_ids(rows: list[dict[str, str]], column: str, pattern: re.Pattern[str], label: str, errors: list[str]) -> set[str]:
    result: set[str] = set()
    for row in rows:
        identifier = clean(row[column])
        if not pattern.fullmatch(identifier):
            errors.append(f"TRACE: {label}: invalid ID {identifier!r}")
        if identifier in result:
            errors.append(f"TRACE: {label}: duplicate ID {identifier}")
        result.add(identifier)
    return result


def parse_trace(text: str, errors: list[str]) -> tuple[set[str], set[str]]:
    specs = [
        ("2. FR Registry", ("FR", "Priority", "Primary relation", "Primary target", "Supporting WIs", "Current maturity", "Exposure", "Main stage", "Decision / external gates"), "FR", 36),
        ("3. DR Registry", ("DR", "Status", "Relation", "Targets", "Decision owner", "Gate", "State ceiling"), "DR", 43),
        ("4. Finding → CR → Package → Work Item", ("Finding", "Severity", "Disposition", "CR", "Declared packages", "Package/WI edges"), "FINDING", 22),
        ("5. CR Registry", ("CR", "Findings", "Packages", "Canonical outcome"), "CR", 12),
        ("6. Package Registry", ("Package", "Name", "Primary CR", "Lane / Priority", "Work Items", "Current package state", "Authority owner role", "Exit gate summary"), "PACKAGE", 13),
        ("7. Work Item Reverse Registry", ("Work Item", "Package", "FR", "DR", "Findings", "CR", "Lifecycle", "Decision", "Ceiling", "Authority owner role", "Execution owner", "Gates"), "WI", 115),
    ]
    package_ids: set[str] = set()
    wi_ids: set[str] = set()
    for heading, headers, kind, expected in specs:
        rows = trace_section_rows(text, heading, headers, errors, kind)
        column = {
            "FR": "FR",
            "DR": "DR",
            "FINDING": "Finding",
            "CR": "CR",
            "PACKAGE": "Package",
            "WI": "Work Item",
        }[kind]
        ids = trace_ids(rows, column, ID_PATTERNS[kind], kind, errors)
        if len(rows) != expected:
            errors.append(f"TRACE: {kind}: expected {expected} rows, actual={len(rows)}")
        if kind == "PACKAGE":
            package_ids = ids
        if kind == "WI":
            wi_ids = ids
    return package_ids, wi_ids


def parse_registry(registry: Any, errors: list[str]) -> tuple[set[str], set[str]]:
    if not isinstance(registry, dict):
        errors.append("REGISTRY: root must be an object")
        return set(), set()
    counts = registry.get("counts")
    if not isinstance(counts, dict):
        errors.append("REGISTRY: missing counts object")
    else:
        expected_counts = {"packages": 13, "workItems": 115, "sourceFields": 1840}
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"REGISTRY: counts.{key} expected {expected}, actual={counts.get(key)!r}")

    packages = registry.get("packages")
    work_items = registry.get("workItems")
    if not isinstance(packages, list) or not isinstance(work_items, list):
        errors.append("REGISTRY: packages and workItems must be arrays")
        return set(), set()
    package_ids: set[str] = set()
    for item in packages:
        identifier = item.get("id") if isinstance(item, dict) else None
        if not isinstance(identifier, str) or not ID_PATTERNS["PACKAGE"].fullmatch(identifier):
            errors.append(f"REGISTRY: invalid package ID {identifier!r}")
        elif identifier in package_ids:
            errors.append(f"REGISTRY: duplicate package ID {identifier}")
        else:
            package_ids.add(identifier)
    wi_ids: set[str] = set()
    field_total = 0
    for item in work_items:
        if not isinstance(item, dict):
            errors.append("REGISTRY: work item must be an object")
            continue
        identifier = item.get("id")
        if not isinstance(identifier, str) or not ID_PATTERNS["WI"].fullmatch(identifier):
            errors.append(f"REGISTRY: invalid work item ID {identifier!r}")
        elif identifier in wi_ids:
            errors.append(f"REGISTRY: duplicate work item ID {identifier}")
        else:
            wi_ids.add(identifier)
        value = item.get("sourceFieldCount")
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            errors.append(f"REGISTRY: invalid sourceFieldCount for {identifier!r}")
        else:
            field_total += value
    if field_total != 1840:
        errors.append(f"REGISTRY: sourceFieldCount sum expected 1840, actual={field_total}")
    return package_ids, wi_ids


def validate_packages(text: str, registry_packages: set[str], trace_packages: set[str], errors: list[str]) -> None:
    try:
        block = section(text, "7. 13 Package Acceptance Summary", 2)
        rows = find_table(block, TABLE_HEADERS["packages"])
    except ValueError as exc:
        errors.append(f"PACKAGES: {exc}")
        return
    actual = [clean(row["Package"]) for row in rows]
    if len(rows) != 13 or len(actual) != len(set(actual)):
        errors.append(f"PACKAGES: expected 13 unique rows, actual={len(rows)}")
    package_set = set(actual)
    if package_set != registry_packages:
        errors.append(f"PACKAGES: checklist/registry mismatch missing={sorted(registry_packages - package_set)} extra={sorted(package_set - registry_packages)}")
    if package_set != trace_packages:
        errors.append(f"PACKAGES: checklist/trace mismatch missing={sorted(trace_packages - package_set)} extra={sorted(package_set - trace_packages)}")


def run_checks(documents: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    try:
        product = parse_report("product", documents["product"], errors)
        engineering = parse_report("engineering", documents["engineering"], errors)
        risk = parse_report("risk", documents["risk"], errors)
        report_findings = {**product, **engineering, **risk}
        if len(report_findings) != 23:
            errors.append(f"REPORT_FINDINGS: combined expected 23 unique findings, actual={len(report_findings)}")
        severities = {severity: sum(value == severity for value in report_findings.values()) for severity in ("P0", "P1", "P2")}
        if severities != EXPECTED_SEVERITY_COUNTS:
            errors.append(f"REPORT_SEVERITY: expected {EXPECTED_SEVERITY_COUNTS}, actual={severities}")
        parse_index(documents["index"], errors)
        parse_controls(documents["checklist"], errors)
        disposition_rows = parse_dispositions(documents["checklist"], report_findings, errors)
        validate_disposition_stats(disposition_rows, errors)
        trace_packages, trace_work_items = parse_trace(documents["trace"], errors)
        registry_packages, registry_work_items = parse_registry(documents["registry"], errors)
        if trace_packages != registry_packages:
            errors.append(f"TRACE_REGISTRY: package IDs differ missing={sorted(registry_packages - trace_packages)} extra={sorted(trace_packages - registry_packages)}")
        if trace_work_items != registry_work_items:
            errors.append(f"TRACE_REGISTRY: work item IDs differ missing={sorted(registry_work_items - trace_work_items)} extra={sorted(trace_work_items - registry_work_items)}")
        validate_packages(documents["checklist"], registry_packages, trace_packages, errors)
    except (KeyError, TypeError, ValueError) as exc:
        errors.append(f"PARSER: {exc}")
    return errors


def self_test() -> int:
    try:
        baseline = read_inputs()
    except ValueError as exc:
        print(f"FAIL SELF_TEST: {exc}", file=sys.stderr)
        return 1
    baseline_errors = run_checks(baseline)
    if baseline_errors:
        for error in baseline_errors:
            print(f"FAIL SELF_TEST_BASELINE: {error}", file=sys.stderr)
        return 1

    fixtures = [
        (
            "missing-finding",
            "REPORT_FINDINGS",
            lambda value: value.update(product=value["product"].replace("### R5A-PROD-007", "### R5A-PROD-999", 1)),
        ),
        (
            "p0-undispositioned",
            "P0_STATUS",
            lambda value: value.update(checklist=value["checklist"].replace("| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `CLOSED` |", "| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `OPEN` |", 1)),
        ),
        (
            "p0-underlying-overclaim",
            "P0_UNDERLYING",
            lambda value: value.update(checklist=value["checklist"].replace("| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `CLOSED` | `OPEN_BLOCKER` |", "| `R5A-PROD-001` | P0 | C04 | `ACCEPTED` | `CLOSED` | `COMPLETE` |", 1)),
        ),
        (
            "external-status-drift",
            "EXTERNAL_STATUS",
            lambda value: value.update(checklist=value["checklist"].replace("| `R5A-RISK-007` | P1 | C10 | `EXTERNAL_REQUIRED` | `CLOSED_WITH_EXTERNAL_GATE` | `EXTERNAL_BLOCKED` |", "| `R5A-RISK-007` | P1 | C10 | `EXTERNAL_REQUIRED` | `CLOSED_WITH_EXTERNAL_GATE` | `OPEN_BLOCKER` |", 1)),
        ),
        (
            "coverage-drift",
            "COVERAGE",
            lambda value: value.update(checklist=value["checklist"].replace("| Work Items | 115 |", "| Work Items | 114 |", 1)),
        ),
    ]
    passed = 0
    for name, prefix, mutate in fixtures:
        fixture = copy.deepcopy(baseline)
        mutate(fixture)
        fixture_errors = run_checks(fixture)
        if not fixture_errors or not any(error.startswith(prefix + ":") for error in fixture_errors):
            print(f"FAIL SELF_TEST: fixture {name} missing expected {prefix} error", file=sys.stderr)
            return 1
        if len(fixture_errors) <= len(baseline_errors):
            print(f"FAIL SELF_TEST: fixture {name} did not add an error", file=sys.stderr)
            return 1
        passed += 1
    print(f"PASS: self-test baseline_errors=0 fixtures={passed}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run in-memory negative fixtures")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    try:
        documents = read_inputs()
    except ValueError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    errors = run_checks(documents)
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: Round 5A disposition baseline validated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
