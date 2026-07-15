#!/usr/bin/env python3
"""Independently validate the DreamJourney V4 traceability matrix.

This checker intentionally does not import the matrix generator.  It reparses the
authoritative Markdown documents and the executable roadmap, then checks the
generated snapshot in both directions.
"""

from __future__ import annotations

import argparse
import copy
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, Mapping, Sequence


EXPECTED_COUNTS = {
    "FR": 36,
    "DR": 43,
    "FINDING": 22,
    "CR": 12,
    "PACKAGE": 13,
    "WI": 115,
}

FILE_NAMES = {
    "matrix": "docs/product/DreamJourney_V4_路线追踪矩阵_V1.0.md",
    "spec": "docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md",
    "evidence": "docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md",
    "decisions": "docs/product/DreamJourney_V4_产品决策登记册_V1.0.md",
    "review": "docs/product/DreamJourney_V4_Round3_独立架构评审响应_V1.0.md",
    "roadmap": "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md",
}

FR_PATTERN = re.compile(r"(?<![A-Z0-9])FR-[A-Z]+-\d{3}(?![A-Z0-9])")
DR_PATTERN = re.compile(r"(?<![A-Z0-9])DR-\d{3}(?![A-Z0-9])")
CR_PATTERN = re.compile(r"(?<![A-Z0-9])CR-\d{2}(?![A-Z0-9])")
FINDING_PATTERN = re.compile(r"(?<![A-Z0-9])(?:BAR|IAR|SOR)-\d{2}(?![A-Z0-9])")
PACKAGE_PATTERN = re.compile(r"(?<![A-Z0-9])WP-(?:S\d|V\d|MIG)-\d{2}(?![A-Z0-9])")
WI_PATTERN = re.compile(r"(?<![A-Z0-9])WI-(?:S\d|V\d|MIG)-\d{2}-\d{2}(?![A-Z0-9])")

# Deliberately avoid Unicode \b: in Python, Chinese characters are word chars.
# This must recognize forms such as "G4产品" and "G2真实".
GATE_PATTERN = re.compile(r"(?<![A-Z0-9])G[0-4](?![A-Z0-9])")

ANY_TRACE_ID_PATTERN = re.compile(
    r"(?<![A-Za-z0-9])(?:"
    r"FR-[A-Z]+-\d{3}|DR-\d{3}|CR-\d{2}|"
    r"WP-[A-Z0-9]+-\d{2}|WI-[A-Z0-9]+-\d{2}-\d{2}|"
    r"(?:BAR|IAR|SOR)-\d{2}"
    r")(?![A-Za-z0-9])"
)

FIELD_PATTERN = re.compile(r"^- \*\*(?P<label>.+?)\*\*[：:](?P<value>.*)$", re.MULTILINE)
WI_HEADING_PATTERN = re.compile(
    r"^###\s+`(?P<id>WI-(?:S\d|V\d|MIG)-\d{2}-\d{2})`.*$", re.MULTILINE
)

EXPECTED_WI_FIELDS = {
    "Outcome",
    "Product value",
    "Priority / lane",
    "Risk / requirement",
    "Dependencies",
    "iOS scope",
    "Backend scope",
    "Data/API/Event",
    "Migration",
    "Release policy",
    "Verification",
    "Deployment",
    "Rollback",
    "Definition of Done",
    "External gates",
    "Non-goals",
}

DR_RELATION_BY_STATUS = {
    "RECOMMENDED_PENDING": "BLOCKS_OR_GUIDES",
    "EXTERNAL_REQUIRED": "EXTERNAL_GATE",
    "REJECTED": "ENFORCES_REJECTION",
    "CONFIRMED": "GOVERNS_IMPLEMENTATION",
    "DEFERRED": "DEFERRED_POLICY_WITH_GUARDRAILS",
}

DR_CEILING_BY_STATUS = {
    "RECOMMENDED_PENDING": "INTERNAL_READY_MAX",
    "EXTERNAL_REQUIRED": "EXTERNAL_BLOCKED",
    "REJECTED": "NEGATIVE_CONTROL_ONLY",
    "CONFIRMED": "PRODUCT_CONFIRMED_IMPLEMENTATION_GATED",
    "DEFERRED": "BUDGET_DECISION_DEFERRED",
}


@dataclass(frozen=True)
class MarkdownTable:
    headers: tuple[str, ...]
    rows: tuple[Mapping[str, str], ...]


@dataclass(frozen=True)
class WorkItem:
    identifier: str
    package: str
    fields: Mapping[str, str]
    block: str
    fr: frozenset[str]
    dr: frozenset[str]
    findings: frozenset[str]
    cr: frozenset[str]
    gates: frozenset[str]


def clean_cell(value: str) -> str:
    return re.sub(r"\s+", " ", value.replace("`", "").strip())


def split_markdown_row(line: str) -> list[str]:
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        raise ValueError(f"not a Markdown table row: {line!r}")
    return [part.strip() for part in stripped[1:-1].split("|")]


def is_separator_row(line: str) -> bool:
    try:
        cells = split_markdown_row(line)
    except ValueError:
        return False
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells)


def parse_tables(text: str) -> list[MarkdownTable]:
    lines = text.splitlines()
    tables: list[MarkdownTable] = []
    index = 0
    while index + 1 < len(lines):
        if lines[index].lstrip().startswith("|") and is_separator_row(lines[index + 1]):
            headers = tuple(clean_cell(cell) for cell in split_markdown_row(lines[index]))
            index += 2
            rows: list[Mapping[str, str]] = []
            while index < len(lines) and lines[index].lstrip().startswith("|"):
                cells = split_markdown_row(lines[index])
                if len(cells) != len(headers):
                    raise ValueError(
                        f"table row has {len(cells)} cells, expected {len(headers)}: {lines[index]}"
                    )
                rows.append(dict(zip(headers, cells)))
                index += 1
            tables.append(MarkdownTable(headers=headers, rows=tuple(rows)))
            continue
        index += 1
    return tables


def section_text(text: str, section_number: int) -> str:
    match = re.search(rf"^##\s+{section_number}\.\s+.*$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"missing section {section_number}")
    end = re.search(r"^##\s+", text[match.end() :], re.MULTILINE)
    return text[match.start() : match.end() + (end.start() if end else len(text[match.end() :]))]


def section_table(text: str, section_number: int) -> MarkdownTable:
    tables = parse_tables(section_text(text, section_number))
    if len(tables) != 1:
        raise ValueError(f"section {section_number} expected one table, found {len(tables)}")
    return tables[0]


def ids(pattern: re.Pattern[str], value: str) -> frozenset[str]:
    return frozenset(pattern.findall(value))


def extract_gates(value: str) -> frozenset[str]:
    # Keep this implementation independent from the generator: locate all
    # negative spans, then ignore only tokens whose offsets fall inside them.
    gate_atom = r"`?G[0-4]`?"
    negative_patterns = (
        re.compile(rf"(?:无|不依赖|无需)\s*{gate_atom}(?:\s*/\s*{gate_atom})*"),
        re.compile(rf"{gate_atom}\s*(?:不适用|不发(?:送)?|不调用)"),
    )
    ignored_spans = [
        match.span()
        for pattern in negative_patterns
        for match in pattern.finditer(value)
    ]
    return frozenset(
        match.group(0)
        for match in GATE_PATTERN.finditer(value)
        if not any(start <= match.start() and match.end() <= end for start, end in ignored_spans)
    )


def expand_numeric_ids(value: str, prefix: str, width: int) -> frozenset[str]:
    """Expand compact authority references such as DR-023/035 or CR-01..04."""
    result = set(
        re.findall(rf"(?<![A-Z0-9]){re.escape(prefix)}-\d{{{width}}}(?![A-Z0-9])", value)
    )
    compact = re.compile(
        rf"(?<![A-Z0-9]){re.escape(prefix)}-(\d{{{width}}})((?:/\d{{{width}}})+)(?![A-Z0-9])"
    )
    for match in compact.finditer(value):
        result.add(f"{prefix}-{match.group(1)}")
        result.update(f"{prefix}-{part}" for part in match.group(2).split("/") if part)
    ranges = re.compile(
        rf"(?<![A-Z0-9]){re.escape(prefix)}-(\d{{{width}}})\.\.(\d{{{width}}})(?![A-Z0-9])"
    )
    for match in ranges.finditer(value):
        start, end = int(match.group(1)), int(match.group(2))
        result.update(f"{prefix}-{number:0{width}d}" for number in range(start, end + 1))
    return frozenset(result)


def expand_finding_ids(value: str) -> frozenset[str]:
    result: set[str] = set()
    for prefix in ("BAR", "IAR", "SOR"):
        result.update(expand_numeric_ids(value, prefix, 2))
    return frozenset(result)


def only_id(pattern: re.Pattern[str], value: str, context: str) -> str:
    found = list(dict.fromkeys(pattern.findall(value)))
    if len(found) != 1:
        raise ValueError(f"{context}: expected one ID, found {found}")
    return found[0]


def rows_by_id(
    table: MarkdownTable,
    id_header: str,
    pattern: re.Pattern[str],
    context: str,
) -> dict[str, Mapping[str, str]]:
    if id_header not in table.headers:
        raise ValueError(f"{context}: missing column {id_header!r}")
    result: dict[str, Mapping[str, str]] = {}
    for row in table.rows:
        identifier = only_id(pattern, row[id_header], context)
        if identifier in result:
            raise ValueError(f"{context}: duplicate ID {identifier}")
        result[identifier] = row
    return result


def parse_matrix(text: str) -> dict[str, dict[str, Mapping[str, str]]]:
    definitions = {
        "fr": (2, "FR", FR_PATTERN),
        "dr": (3, "DR", DR_PATTERN),
        "finding": (4, "Finding", FINDING_PATTERN),
        "cr": (5, "CR", CR_PATTERN),
        "package": (6, "Package", PACKAGE_PATTERN),
        "wi": (7, "Work Item", WI_PATTERN),
    }
    parsed: dict[str, dict[str, Mapping[str, str]]] = {}
    for name, (number, header, pattern) in definitions.items():
        table = section_table(text, number)
        parsed[name] = rows_by_id(table, header, pattern, f"matrix section {number}")
    return parsed


def find_table(text: str, required_headers: Iterable[str], context: str) -> MarkdownTable:
    required = set(required_headers)
    matches = [table for table in parse_tables(text) if required.issubset(table.headers)]
    if len(matches) != 1:
        raise ValueError(f"{context}: expected one table for {sorted(required)}, found {len(matches)}")
    return matches[0]


def parse_evidence_fr(text: str) -> dict[str, Mapping[str, str]]:
    table = find_table(
        text,
        {"Requirement", "PRD", "当前暴露", "实现成熟度", "主交付阶段"},
        "evidence FR",
    )
    return rows_by_id(table, "Requirement", FR_PATTERN, "evidence FR")


def parse_spec_fr_stages(text: str) -> dict[str, str]:
    table = find_table(text, {"主阶段", "Requirement IDs", "数量"}, "spec FR stages")
    result: dict[str, str] = {}
    for row in table.rows:
        stage = clean_cell(row["主阶段"])
        if stage == "合计":
            continue
        for identifier in FR_PATTERN.findall(row["Requirement IDs"]):
            if identifier in result:
                raise ValueError(f"spec FR stages: duplicate {identifier}")
            result[identifier] = stage
    return result


def parse_decisions(text: str) -> dict[str, Mapping[str, str]]:
    result: dict[str, Mapping[str, str]] = {}
    for table in parse_tables(text):
        if not {"ID", "状态", "决策 Owner", "Gate"}.issubset(table.headers):
            continue
        for row in table.rows:
            found = DR_PATTERN.findall(row["ID"])
            if not found:
                continue
            identifier = found[0]
            if identifier in result:
                raise ValueError(f"decision register: duplicate {identifier}")
            result[identifier] = row
    return result


def parse_review(text: str) -> tuple[
    dict[str, Mapping[str, str]], dict[str, Mapping[str, str]]
]:
    risk_table = find_table(text, {"Risk", "Canonical issue", "Round 4 package"}, "review CR")
    finding_table = find_table(
        text,
        {"Finding", "Severity", "Disposition", "Canonical risk", "Roadmap package"},
        "review findings",
    )
    risks = rows_by_id(risk_table, "Risk", CR_PATTERN, "review CR")
    findings = rows_by_id(finding_table, "Finding", FINDING_PATTERN, "review findings")
    return risks, findings


def package_for_work_item(identifier: str) -> str:
    return identifier.rsplit("-", 1)[0].replace("WI-", "WP-", 1)


def parse_roadmap_work_items(text: str) -> dict[str, WorkItem]:
    matches = list(WI_HEADING_PATTERN.finditer(text))
    result: dict[str, WorkItem] = {}
    for index, match in enumerate(matches):
        identifier = match.group("id")
        if identifier in result:
            raise ValueError(f"roadmap WI: duplicate {identifier}")
        block_end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        next_h2 = re.search(r"^##\s+", text[match.end() : block_end], re.MULTILINE)
        if next_h2:
            block_end = match.end() + next_h2.start()
        block = text[match.start() : block_end]
        fields = {m.group("label").strip(): m.group("value").strip() for m in FIELD_PATTERN.finditer(block)}
        risk = fields.get("Risk / requirement", "")
        gate_text = f"{fields.get('Verification', '')} {fields.get('External gates', '')}"
        work_item_gates = set(extract_gates(gate_text))
        if not work_item_gates:
            work_item_gates.add("G0")
        result[identifier] = WorkItem(
            identifier=identifier,
            package=package_for_work_item(identifier),
            fields=fields,
            block=block,
            fr=ids(FR_PATTERN, risk),
            dr=expand_numeric_ids(risk, "DR", 3),
            findings=expand_finding_ids(risk),
            cr=expand_numeric_ids(risk, "CR", 2),
            gates=frozenset(work_item_gates),
        )
    return result


def parse_roadmap_packages(text: str) -> dict[str, Mapping[str, str]]:
    table = find_table(
        text,
        {"Package", "名称", "Risk", "Priority", "Lane", "当前状态", "主要退出门"},
        "roadmap packages",
    )
    return rows_by_id(table, "Package", PACKAGE_PATTERN, "roadmap packages")


def parse_explicit_edges(text: str) -> dict[str, tuple[str, str]]:
    table = find_table(text, {"From", "Relation", "To", "说明"}, "roadmap explicit edges")
    result: dict[str, tuple[str, str]] = {}
    for row in table.rows:
        fr = FR_PATTERN.findall(row["From"])
        if not fr:
            continue
        result[fr[0]] = (clean_cell(row["Relation"]), clean_cell(row["To"]))
    return result


def reverse_work_item_refs(
    work_items: Mapping[str, WorkItem], attribute: str
) -> dict[str, set[str]]:
    result: dict[str, set[str]] = {}
    for wi_id, work_item in work_items.items():
        for identifier in getattr(work_item, attribute):
            result.setdefault(identifier, set()).add(wi_id)
    return result


def expected_ceiling(gates: Iterable[str]) -> str:
    gate_set = set(gates)
    if gate_set.intersection({"G3", "G4"}):
        return "EXTERNAL_BLOCKED"
    if "G2" in gate_set:
        return "DEPLOYED_UNVERIFIED"
    return "INTERNAL_READY"


def edge_pairs(value: str) -> set[tuple[str, str]]:
    return set(
        re.findall(
            r"(WP-(?:S\d|V\d|MIG)-\d{2})\s*->\s*(WI-(?:S\d|V\d|MIG)-\d{2}-\d{2})",
            clean_cell(value),
        )
    )


def format_set(values: Iterable[str]) -> str:
    return "[" + ", ".join(sorted(values)) + "]"


def validate_documents(documents: Mapping[str, str]) -> list[str]:
    errors: list[str] = []

    def error(prefix: str, message: str) -> None:
        errors.append(f"{prefix}: {message}")

    try:
        matrix = parse_matrix(documents["matrix"])
        evidence_fr = parse_evidence_fr(documents["evidence"])
        spec_fr_stages = parse_spec_fr_stages(documents["spec"])
        decisions = parse_decisions(documents["decisions"])
        review_cr, review_findings = parse_review(documents["review"])
        work_items = parse_roadmap_work_items(documents["roadmap"])
        roadmap_packages = parse_roadmap_packages(documents["roadmap"])
        explicit_fr_edges = parse_explicit_edges(documents["roadmap"])
    except ValueError as exc:
        return [f"PARSE_ERROR: {exc}"]

    source_sets = {
        "FR": set(evidence_fr),
        "DR": set(decisions),
        "FINDING": set(review_findings),
        "CR": set(review_cr),
        "PACKAGE": set(roadmap_packages),
        "WI": set(work_items),
    }
    matrix_sets = {
        "FR": set(matrix["fr"]),
        "DR": set(matrix["dr"]),
        "FINDING": set(matrix["finding"]),
        "CR": set(matrix["cr"]),
        "PACKAGE": set(matrix["package"]),
        "WI": set(matrix["wi"]),
    }

    for kind, expected_count in EXPECTED_COUNTS.items():
        source = source_sets[kind]
        snapshot = matrix_sets[kind]
        if len(source) != expected_count:
            error("SOURCE_COUNT", f"{kind} expected {expected_count}, source has {len(source)}")
        if len(snapshot) != expected_count:
            error("MATRIX_COUNT", f"{kind} expected {expected_count}, matrix has {len(snapshot)}")
        extras = snapshot - source
        missing = source - snapshot
        if extras:
            prefix = "WI_ORPHAN" if kind == "WI" else "ID_INVALID"
            error(prefix, f"matrix {kind} not in authority: {format_set(extras)}")
        if missing:
            prefix = "WI_MISSING" if kind == "WI" else "ID_MISSING"
            error(prefix, f"matrix {kind} missing authority IDs: {format_set(missing)}")

    if set(spec_fr_stages) != source_sets["FR"]:
        error(
            "FR_SOURCE_SET",
            f"Product Spec/evidence FR differ: spec-only={format_set(set(spec_fr_stages)-source_sets['FR'])}, "
            f"evidence-only={format_set(source_sets['FR']-set(spec_fr_stages))}",
        )

    canonical_by_prefix = {
        "FR": source_sets["FR"],
        "DR": source_sets["DR"],
        "CR": source_sets["CR"],
        "WP": source_sets["PACKAGE"],
        "WI": source_sets["WI"],
        "BAR": source_sets["FINDING"],
        "IAR": source_sets["FINDING"],
        "SOR": source_sets["FINDING"],
    }
    for identifier in sorted(set(ANY_TRACE_ID_PATTERN.findall(documents["matrix"]))):
        prefix = identifier.split("-", 1)[0]
        if identifier not in canonical_by_prefix[prefix]:
            error("ID_INVALID", f"non-canonical matrix reference {identifier}")

    fr_reverse = reverse_work_item_refs(work_items, "fr")
    dr_reverse = reverse_work_item_refs(work_items, "dr")

    for fr_id in sorted(source_sets["FR"] & matrix_sets["FR"]):
        source = evidence_fr[fr_id]
        row = matrix["fr"][fr_id]
        scalar_pairs = {
            "Priority": "PRD",
            "Current maturity": "实现成熟度",
            "Exposure": "当前暴露",
            "Main stage": "主交付阶段",
        }
        for matrix_column, source_column in scalar_pairs.items():
            actual = clean_cell(row[matrix_column])
            expected = clean_cell(source[source_column])
            if actual != expected:
                error("FR_SOURCE_FIELD", f"{fr_id} {matrix_column}: {actual!r} != {expected!r}")

        actual_support = set(WI_PATTERN.findall(row["Supporting WIs"]))
        expected_support = fr_reverse.get(fr_id, set())
        if actual_support != expected_support:
            error(
                "FR_REVERSE",
                f"{fr_id} supporting WIs {format_set(actual_support)} != roadmap reverse {format_set(expected_support)}",
            )

        relation = clean_cell(row["Primary relation"])
        target = clean_cell(row["Primary target"])
        explicit = explicit_fr_edges.get(fr_id)
        if explicit:
            expected_relation, expected_target = explicit
            if relation != expected_relation or target != expected_target:
                error(
                    "FR_PRIMARY",
                    f"{fr_id} ({relation}, {target}) != roadmap ({expected_relation}, {expected_target})",
                )
        elif relation != "PRIMARY_WI":
            error("FR_PRIMARY", f"{fr_id} must be PRIMARY_WI, got {relation}")

        if relation == "PRIMARY_WI":
            target_ids = WI_PATTERN.findall(target)
            if len(target_ids) != 1 or target_ids[0] not in expected_support:
                error("FR_PRIMARY", f"{fr_id} primary target {target!r} is not a supporting roadmap WI")
        elif relation == "DEFERRED_BY_GATE":
            if actual_support:
                error("FR_PRIMARY", f"{fr_id} deferred FR must not have implementation WIs")
        else:
            error("FR_PRIMARY", f"{fr_id} unsupported primary relation {relation!r}")

        if "PROD_VERIFIED" in clean_cell(row["Current maturity"]):
            error("STATE_OVERCLAIM", f"{fr_id} is marked PROD_VERIFIED")

    for dr_id in sorted(source_sets["DR"] & matrix_sets["DR"]):
        source = decisions[dr_id]
        row = matrix["dr"][dr_id]
        expected_status = clean_cell(source["状态"])
        actual_status = clean_cell(row["Status"])
        if actual_status != expected_status:
            error("DR_STATUS", f"{dr_id} status {actual_status!r} != {expected_status!r}")

        expected_relation = DR_RELATION_BY_STATUS.get(expected_status)
        if clean_cell(row["Relation"]) != expected_relation:
            error(
                "DR_RELATION",
                f"{dr_id} relation {clean_cell(row['Relation'])!r} != {expected_relation!r}",
            )
        expected_dr_ceiling = DR_CEILING_BY_STATUS.get(expected_status)
        if clean_cell(row["State ceiling"]) != expected_dr_ceiling:
            error(
                "DR_CEILING",
                f"{dr_id} ceiling {clean_cell(row['State ceiling'])!r} != {expected_dr_ceiling!r}",
            )
        if clean_cell(row["Decision owner"]) != clean_cell(source["决策 Owner"]):
            error("DR_OWNER", f"{dr_id} decision owner drift")
        if clean_cell(row["Gate"]) != clean_cell(source["Gate"]):
            error("DR_GATE", f"{dr_id} decision gate drift")

        actual_wi_targets = set(WI_PATTERN.findall(row["Targets"]))
        unknown_targets = actual_wi_targets - source_sets["WI"]
        if unknown_targets:
            error("DR_TARGET", f"{dr_id} targets unknown WIs {format_set(unknown_targets)}")
        if not clean_cell(row["Targets"]):
            error("DR_TARGET", f"{dr_id} has no WI or explicit governance target")

    finding_to_cr: dict[str, str] = {}
    finding_to_packages: dict[str, set[str]] = {}
    for finding_id in sorted(source_sets["FINDING"] & matrix_sets["FINDING"]):
        source = review_findings[finding_id]
        row = matrix["finding"][finding_id]
        expected_cr = only_id(CR_PATTERN, source["Canonical risk"], f"review {finding_id}")
        expected_packages = set(PACKAGE_PATTERN.findall(source["Roadmap package"]))
        finding_to_cr[finding_id] = expected_cr
        finding_to_packages[finding_id] = expected_packages
        if clean_cell(row["Severity"]) != clean_cell(source["Severity"]):
            error("FINDING_SOURCE", f"{finding_id} severity drift")
        if clean_cell(row["Disposition"]) != clean_cell(source["Disposition"]):
            error("FINDING_SOURCE", f"{finding_id} disposition drift")
        if set(CR_PATTERN.findall(row["CR"])) != {expected_cr}:
            error("FINDING_CR", f"{finding_id} CR does not match {expected_cr}")
        actual_packages = set(PACKAGE_PATTERN.findall(row["Declared packages"]))
        if actual_packages != expected_packages:
            error(
                "FINDING_PACKAGE",
                f"{finding_id} packages {format_set(actual_packages)} != {format_set(expected_packages)}",
            )

        pairs = edge_pairs(row["Package/WI edges"])
        edge_packages = {package for package, _ in pairs}
        if edge_packages != expected_packages or len(pairs) != len(expected_packages):
            error(
                "FINDING_DRILLDOWN",
                f"{finding_id} must have exactly one valid WI edge per declared package",
            )
        for package, wi_id in sorted(pairs):
            work_item = work_items.get(wi_id)
            if not work_item or work_item.package != package or finding_id not in work_item.findings:
                error(
                    "FINDING_DRILLDOWN",
                    f"{finding_id} edge {package}->{wi_id} is not backed by the roadmap WI risk field",
                )

    for cr_id in sorted(source_sets["CR"] & matrix_sets["CR"]):
        source = review_cr[cr_id]
        row = matrix["cr"][cr_id]
        expected_findings = {key for key, value in finding_to_cr.items() if value == cr_id}
        expected_packages = set(PACKAGE_PATTERN.findall(source["Round 4 package"]))
        if set(FINDING_PATTERN.findall(row["Findings"])) != expected_findings:
            error("CR_REVERSE", f"{cr_id} finding reverse set drift")
        if set(PACKAGE_PATTERN.findall(row["Packages"])) != expected_packages:
            error("CR_PACKAGE", f"{cr_id} package set drift")
        if not clean_cell(row["Canonical outcome"]):
            error("CR_SOURCE", f"{cr_id} canonical outcome is empty")

    source_wis_by_package: dict[str, set[str]] = {}
    for wi_id, work_item in work_items.items():
        source_wis_by_package.setdefault(work_item.package, set()).add(wi_id)

    for package_id in sorted(source_sets["PACKAGE"] & matrix_sets["PACKAGE"]):
        source = roadmap_packages[package_id]
        row = matrix["package"][package_id]
        comparisons = {
            "Name": clean_cell(source["名称"]),
            "Primary CR": only_id(CR_PATTERN, source["Risk"], f"roadmap package {package_id}"),
            "Lane / Priority": f"{clean_cell(source['Lane'])} / {clean_cell(source['Priority'])}",
            "Current package state": clean_cell(source["当前状态"]),
            "Exit gate summary": clean_cell(source["主要退出门"]),
        }
        for column, expected in comparisons.items():
            actual = clean_cell(row[column])
            if actual != expected:
                error("PACKAGE_SOURCE", f"{package_id} {column}: {actual!r} != {expected!r}")
        actual_wis = set(WI_PATTERN.findall(row["Work Items"]))
        expected_wis = source_wis_by_package.get(package_id, set())
        if actual_wis != expected_wis:
            error(
                "PACKAGE_WI",
                f"{package_id} WIs {format_set(actual_wis)} != roadmap {format_set(expected_wis)}",
            )

    for wi_id in sorted(source_sets["WI"] & matrix_sets["WI"]):
        source = work_items[wi_id]
        row = matrix["wi"][wi_id]
        if set(source.fields) != EXPECTED_WI_FIELDS:
            error(
                "WI_FIELDS",
                f"{wi_id} field set differs: missing={format_set(EXPECTED_WI_FIELDS-set(source.fields))}, "
                f"extra={format_set(set(source.fields)-EXPECTED_WI_FIELDS)}",
            )
        actual_package = only_id(PACKAGE_PATTERN, row["Package"], f"matrix WI {wi_id}")
        if actual_package != source.package:
            error("WI_PARENT", f"{wi_id} parent {actual_package} != {source.package}")

        ref_pairs = {
            "FR": (FR_PATTERN, source.fr),
            "DR": (DR_PATTERN, source.dr),
            "Findings": (FINDING_PATTERN, source.findings),
            "CR": (CR_PATTERN, source.cr),
        }
        for column, (pattern, expected) in ref_pairs.items():
            actual = set(pattern.findall(row[column]))
            if actual != set(expected):
                error(
                    "WI_REVERSE",
                    f"{wi_id} {column} {format_set(actual)} != roadmap risk field {format_set(expected)}",
                )

        actual_gates = set(extract_gates(row["Gates"]))
        if actual_gates != set(source.gates):
            error(
                "GATE_MISMATCH",
                f"{wi_id} matrix {format_set(actual_gates)} != source WI {format_set(source.gates)}",
            )
        expected_wi_ceiling = expected_ceiling(source.gates)
        actual_ceiling = clean_cell(row["Ceiling"])
        if actual_ceiling != expected_wi_ceiling:
            error(
                "CEILING_MISMATCH",
                f"{wi_id} ceiling {actual_ceiling!r} != {expected_wi_ceiling!r} from source gates",
            )

        lifecycle = clean_cell(row["Lifecycle"])
        decision = clean_cell(row["Decision"])
        expected_decision = "NO_GO" if source.package == "WP-MIG-01" else "STOP"
        if lifecycle != "PLANNED":
            error("STATE_OVERCLAIM", f"{wi_id} lifecycle must remain PLANNED, got {lifecycle!r}")
        if decision != expected_decision:
            error("DECISION_OVERCLAIM", f"{wi_id} decision {decision!r} != {expected_decision!r}")
        if clean_cell(row["Execution owner"]) != "UNASSIGNED":
            error("STATE_OVERCLAIM", f"{wi_id} execution owner is assigned without authority evidence")

        package_row = matrix["package"].get(source.package)
        if package_row and clean_cell(row["Authority owner role"]) != clean_cell(
            package_row["Authority owner role"]
        ):
            error("WI_AUTHORITY", f"{wi_id} authority role differs from {source.package}")

    structured_states: list[str] = []
    structured_states.extend(clean_cell(row["Current maturity"]) for row in matrix["fr"].values())
    structured_states.extend(clean_cell(row["Status"]) for row in matrix["dr"].values())
    structured_states.extend(clean_cell(row["Current package state"]) for row in matrix["package"].values())
    for row in matrix["wi"].values():
        structured_states.extend(
            [
                clean_cell(row["Lifecycle"]),
                clean_cell(row["Decision"]),
                clean_cell(row["Ceiling"]),
            ]
        )
    forbidden = {"VERIFIED", "PROD_VERIFIED"}
    for state in structured_states:
        if state in forbidden:
            error("STATE_OVERCLAIM", f"forbidden current state {state}")

    return sorted(set(errors))


def load_documents(repo_root: Path) -> dict[str, str]:
    documents: dict[str, str] = {}
    for name, relative in FILE_NAMES.items():
        path = repo_root / relative
        if not path.is_file():
            raise FileNotFoundError(path)
        documents[name] = path.read_text(encoding="utf-8")
    return documents


def mutate_table_row(
    text: str,
    row_identifier: str,
    column_index: int,
    transform: Callable[[str], str],
) -> str:
    lines = text.splitlines()
    marker = f"| `{row_identifier}` |"
    for index, line in enumerate(lines):
        if not line.startswith(marker):
            continue
        cells = split_markdown_row(line)
        cells[column_index] = transform(cells[column_index])
        lines[index] = "| " + " | ".join(cells) + " |"
        return "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    raise AssertionError(f"self-test row not found: {row_identifier}")


def run_self_test(documents: Mapping[str, str]) -> int:
    if extract_gates("G4产品 / G2真实 / G1 UIQA") != frozenset({"G1", "G2", "G4"}):
        print("SELF_TEST_FAIL: ASCII gate boundary parser missed Chinese-adjacent gates")
        return 1
    gate_cases = {
        "无G2/G3/G4；Xcode owner review": frozenset(),
        "G0 shadow；G2部署；无G3真实调用；G4产品": frozenset({"G0", "G2", "G4"}),
        "G0 fixture；G3不适用；不依赖G2；无需G4；G3不发真实effect": frozenset({"G0"}),
        "G2 schema；G3/G4尚不由schema关闭": frozenset({"G2", "G3", "G4"}),
    }
    for source, expected in gate_cases.items():
        actual = extract_gates(source)
        if actual != expected:
            print(f"SELF_TEST_FAIL: gate semantics {source!r} -> {sorted(actual)}, expected {sorted(expected)}")
            return 1

    baseline_errors = set(validate_documents(documents))
    cases: Sequence[tuple[str, str, Callable[[dict[str, str]], None]]] = (
        (
            "orphan WI",
            "WI_ORPHAN:",
            lambda docs: docs.__setitem__(
                "matrix",
                mutate_table_row(
                    docs["matrix"],
                    "WI-MIG-01-01",
                    0,
                    lambda cell: cell.replace("WI-MIG-01-01", "WI-MIG-99-99"),
                ),
            ),
        ),
        (
            "missing FR reverse edge",
            "FR_REVERSE:",
            lambda docs: docs.__setitem__(
                "matrix",
                mutate_table_row(
                    docs["matrix"],
                    "FR-ACC-001",
                    4,
                    lambda cell: cell.replace("<br>`WI-S0-02-01`", ""),
                ),
            ),
        ),
        (
            "illegal ID",
            "ID_INVALID:",
            lambda docs: docs.__setitem__(
                "matrix",
                mutate_table_row(
                    docs["matrix"],
                    "FR-ACC-001",
                    0,
                    lambda cell: cell.replace("FR-ACC-001", "FR-FAKE-999"),
                ),
            ),
        ),
        (
            "finding drilldown missing",
            "FINDING_DRILLDOWN:",
            lambda docs: docs.__setitem__(
                "matrix",
                mutate_table_row(
                    docs["matrix"],
                    "BAR-01",
                    5,
                    lambda cell: cell.replace("WI-S0-02-01", "WI-S0-02-06"),
                ),
            ),
        ),
        (
            "DR status drift",
            "DR_STATUS:",
            lambda docs: docs.__setitem__(
                "matrix",
                mutate_table_row(
                    docs["matrix"],
                    "DR-001",
                    1,
                    lambda _cell: "`DEFERRED`",
                ),
            ),
        ),
        (
            "state overclaim",
            "STATE_OVERCLAIM:",
            lambda docs: docs.__setitem__(
                "matrix",
                mutate_table_row(
                    docs["matrix"],
                    "WI-MIG-01-01",
                    6,
                    lambda _cell: "`VERIFIED`",
                ),
            ),
        ),
    )

    failures: list[str] = []
    for name, prefix, mutate in cases:
        mutated = copy.deepcopy(dict(documents))
        mutate(mutated)
        mutated_errors = set(validate_documents(mutated))
        new_expected = [
            item for item in mutated_errors - baseline_errors if item.startswith(prefix)
        ]
        if not new_expected:
            failures.append(f"{name}: expected a new {prefix} error")
        else:
            print(f"SELF_TEST_PASS: {name} -> {new_expected[0]}")

    if failures:
        for failure in failures:
            print(f"SELF_TEST_FAIL: {failure}")
        return 1
    print(
        "SELF_TEST_PASS: 6 negative variants + positive/negative gate semantics; "
        f"baseline_errors={len(baseline_errors)}"
    )
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run in-memory negative variants")
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[3],
        help="DreamJourney_dev repository root",
    )
    args = parser.parse_args(argv)

    try:
        documents = load_documents(args.repo_root.resolve())
    except (FileNotFoundError, OSError) as exc:
        print(f"INPUT_ERROR: {exc}")
        return 2

    if args.self_test:
        return run_self_test(documents)

    errors = validate_documents(documents)
    if errors:
        print(f"FAIL product-v4-traceability-check: {len(errors)} error(s)")
        for item in errors:
            print(f"- {item}")
        return 1

    print(
        "PASS product-v4-traceability-check: "
        "36 FR / 43 DR / 22 Finding / 12 CR / 13 Package / 115 WI"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
