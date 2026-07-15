#!/usr/bin/env python3
"""Independently validate the DreamJourney V4 executable roadmap.

This checker intentionally does not import any generator or traceability
checker.  Roadmap Markdown, the generated execution registry, and the trace
matrix are parsed independently and compared as three separate inputs.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[3]
ROADMAP = ROOT / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
REGISTRY = ROOT / "docs/product/DreamJourney_V4_路线执行注册表_V1.0.json"
TRACE_MATRIX = ROOT / "docs/product/DreamJourney_V4_路线追踪矩阵_V1.0.md"

ROADMAP_SOURCE_PATH = ROADMAP.relative_to(ROOT).as_posix()
REGISTRY_SCHEMA = "dreamjourney.execution-registry.v1.1"
ROUND4_ACCEPTANCE = "ROUND4_STATIC_ACCEPTANCE_PASSED_ROUND5_PENDING"

WORK_ITEM_FIELDS = (
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
)

EXPECTED_ENUMS = {
    "authorityLeaseState": ["UNHELD", "HELD", "EXPIRED", "REVOKED"],
    "authorityLock": [
        "ACCOUNT_LOCAL_STATE",
        "IDENTITY_AUTHZ",
        "CREDENTIAL_CONTROL",
        "DB_RECOVERY",
        "RIGHTS_DELETION",
        "RELEASE_POLICY",
        "OPERATIONS_EVIDENCE",
        "OWNER_TRUTH",
        "ASYNC_EFFECT",
        "IOS_COMPOSITION",
        "PUBLICATION",
        "VOICE_DH_GOVERNANCE",
        "MIGRATION_EVIDENCE",
    ],
    "decision": ["STOP", "NO_GO", "GO"],
    "defaultExposure": ["DEFAULT_OFF", "EXISTING_PUBLIC_SHELL"],
    "gate": ["G0", "G1", "G2", "G3", "G4"],
    "gateEvidence": ["MISSING", "PASS", "FAIL", "EXPIRED"],
    "lifecycle": [
        "PLANNED",
        "IN_PROGRESS",
        "INTERNAL_READY",
        "EXTERNAL_BLOCKED",
        "DEPLOYED_UNVERIFIED",
        "VERIFIED",
        "PAUSED",
        "RETIRED",
    ],
    "priorityClass": ["P0", "P1", "P2"],
    "releaseClass": ["CORE", "MVP_EXTENSION", "MIGRATION"],
}

PACKAGE_INVENTORY_HEADERS = (
    "Package",
    "名称",
    "Risk",
    "Priority",
    "Lane",
    "Start dependencies",
    "Exit dependencies",
    "当前状态",
    "主要退出门",
)
PACKAGE_CONTROL_HEADERS = (
    "Package",
    "releaseClass",
    "authorityLock",
    "selectorBand",
    "defaultExposure",
)
TRACE_WORK_ITEM_HEADERS = (
    "Work Item",
    "Package",
    "FR",
    "DR",
    "Findings",
    "CR",
    "Lifecycle",
    "Decision",
    "Ceiling",
    "Authority owner role",
    "Execution owner",
    "Gates",
)

PACKAGE_KEYS = {
    "authorityLock",
    "decision",
    "defaultExposure",
    "exitPackageDependencies",
    "id",
    "lifecycle",
    "migrationGateRefs",
    "name",
    "priorityClass",
    "releaseClass",
    "roadmapLane",
    "selectorBand",
    "startPackageDependencies",
}
WORK_ITEM_KEYS = {
    "authorityLock",
    "decision",
    "dependencyNotesHash",
    "directDependencies",
    "executionOwner",
    "gateEvidence",
    "id",
    "lifecycle",
    "packageId",
    "priorityClass",
    "releaseClass",
    "requiredGates",
    "sourceFieldCount",
    "stableRank",
}

GATE_PATTERN = re.compile(r"(?<![A-Z0-9])G[0-4](?![A-Z0-9])")
GATE_ATOM = r"`?G[0-4]`?"
NEGATED_GATE_PATTERNS = (
    re.compile(rf"(?:无|不依赖|无需)\s*{GATE_ATOM}(?:\s*/\s*{GATE_ATOM})*"),
    re.compile(rf"{GATE_ATOM}\s*(?:不适用|不发(?:送)?|不调用)"),
)
WORK_ITEM_DEPENDENCY_PATTERN = re.compile(
    r"(?<![A-Z0-9-])WI-([A-Z0-9]+)-(\d{2})-(\d{2})"
    r"(?:(\.\.)(\d{2})|((?:/\d{2})+))?"
    r"(?![A-Z0-9-])"
)
PACKAGE_REFERENCE_PATTERN = re.compile(
    r"(?<![A-Z0-9-])(?:WP-)?((?:S[013]|V0)-\d{2})(?![A-Z0-9-])"
)


def error(errors: list[str], prefix: str, detail: str) -> None:
    errors.append(f"{prefix}: {detail}")


def markdown_cells(line: str) -> list[str]:
    return [part.strip() for part in line.strip().strip("|").split("|")]


def strip_ticks(value: str) -> str:
    return value.replace("`", "").strip()


def normalized_text(value: str) -> str:
    return " ".join(value.split())


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def priority_class(value: str) -> str | None:
    values = set(re.findall(r"(?<![A-Z0-9])P[0-2](?![A-Z0-9])", value))
    return min(values, key=lambda item: int(item[1])) if values else None


def package_id_for(work_item_id: str) -> str:
    return "WP-" + "-".join(work_item_id.split("-")[1:-1])


def expected_stable_rank(work_item_id: str, selector_band: int) -> int:
    return selector_band * 100 + int(work_item_id.rsplit("-", 1)[1])


def table_after_heading(
    text: str,
    heading: str,
    headers: tuple[str, ...],
    errors: list[str],
    prefix: str,
) -> list[list[str]]:
    heading_match = re.search(rf"^{re.escape(heading)}$", text, re.MULTILINE)
    if not heading_match:
        error(errors, prefix, f"missing heading {heading}")
        return []
    lines = text[heading_match.end() :].splitlines()
    header_index: int | None = None
    for index, line in enumerate(lines):
        if line.startswith("#"):
            break
        if line.startswith("|") and tuple(markdown_cells(line)) == headers:
            header_index = index
            break
    if header_index is None:
        error(errors, prefix, f"missing table header after {heading}")
        return []
    if header_index + 1 >= len(lines) or not lines[header_index + 1].startswith("|"):
        error(errors, prefix, f"missing separator after {heading}")
        return []
    rows: list[list[str]] = []
    for line in lines[header_index + 2 :]:
        if not line.startswith("|"):
            break
        row = markdown_cells(line)
        if len(row) != len(headers):
            error(errors, prefix, f"invalid row width after {heading}: {line}")
            continue
        rows.append(row)
    return rows


def parse_package_inventory(text: str, errors: list[str]) -> dict[str, dict[str, str]]:
    rows = table_after_heading(
        text,
        "### 2.1 Package Inventory",
        PACKAGE_INVENTORY_HEADERS,
        errors,
        "PACKAGE_INVENTORY",
    )
    result: dict[str, dict[str, str]] = {}
    for row in rows:
        package_id = strip_ticks(row[0])
        if not re.fullmatch(r"WP-(?:S[013]|V0|MIG)-\d{2}", package_id):
            error(errors, "PACKAGE_INVENTORY", f"invalid Package id {package_id}")
            continue
        if package_id in result:
            error(errors, "PACKAGE_INVENTORY", f"duplicate Package {package_id}")
            continue
        result[package_id] = {
            "name": row[1],
            "risk": row[2],
            "priority": row[3],
            "lane": row[4],
            "startText": row[5],
            "exitText": row[6],
            "currentState": strip_ticks(row[7]),
            "exitSummary": row[8],
        }
    if len(result) != 13:
        error(errors, "COUNT", f"Package Inventory expected 13, got {len(result)}")
    return result


def parse_package_controls(text: str, errors: list[str]) -> tuple[dict[str, dict[str, Any]], list[str]]:
    rows = table_after_heading(
        text,
        "#### 6.2.1 Package Control Registry（13）",
        PACKAGE_CONTROL_HEADERS,
        errors,
        "PACKAGE_CONTROL",
    )
    result: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    for row in rows:
        package_id = strip_ticks(row[0])
        try:
            selector_band = int(strip_ticks(row[3]))
        except ValueError:
            error(errors, "ENUM", f"invalid selectorBand for {package_id}: {row[3]}")
            selector_band = -1
        if package_id in result:
            error(errors, "PACKAGE_CONTROL", f"duplicate Package {package_id}")
            continue
        order.append(package_id)
        result[package_id] = {
            "releaseClass": strip_ticks(row[1]),
            "authorityLock": strip_ticks(row[2]),
            "selectorBand": selector_band,
            "defaultExposure": strip_ticks(row[4]),
        }
    if len(result) != 13:
        error(errors, "COUNT", f"Package Control expected 13, got {len(result)}")
    return result, order


def package_references(value: str) -> list[str]:
    refs = [f"WP-{match.group(1)}" for match in PACKAGE_REFERENCE_PATTERN.finditer(value)]
    return list(dict.fromkeys(refs))


def parse_work_items(text: str, errors: list[str]) -> tuple[dict[str, dict[str, str]], list[str]]:
    matches = list(re.finditer(r"^### `(WI-[A-Z0-9-]+)`(?:\s|$)", text, re.MULTILINE))
    result: dict[str, dict[str, str]] = {}
    order: list[str] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[match.start() : end]
        pairs = re.findall(r"^- \*\*([^*]+)\*\*：(.*)$", block, re.MULTILINE)
        names = tuple(name for name, _ in pairs)
        work_item_id = match.group(1)
        if work_item_id in result:
            error(errors, "WI_FIELDS", f"duplicate Work Item {work_item_id}")
            continue
        if names != WORK_ITEM_FIELDS:
            error(
                errors,
                "WI_FIELDS",
                f"{work_item_id} expected exact 16 fields, got {len(names)}: {names}",
            )
        order.append(work_item_id)
        result[work_item_id] = dict(pairs)
    if len(result) != 115:
        error(errors, "COUNT", f"Roadmap expected 115 Work Items, got {len(result)}")
    field_count = sum(len(fields) for fields in result.values())
    if field_count != 1840:
        error(errors, "COUNT", f"Roadmap expected 1840 fields, got {field_count}")
    return result, order


def applicable_gates(value: str) -> list[str]:
    positive_text = value
    for pattern in NEGATED_GATE_PATTERNS:
        positive_text = pattern.sub(" ", positive_text)
    gates = sorted(set(GATE_PATTERN.findall(positive_text)))
    return gates or ["G0"]


def start_dependency_text(value: str) -> str:
    markers = ("exit依赖", "退出依赖", "退出前", "exit dependency")
    positions = [value.index(marker) for marker in markers if marker in value]
    return value[: min(positions)] if positions else value


def expand_work_item_dependencies(value: str) -> list[str]:
    result: list[str] = []
    for match in WORK_ITEM_DEPENDENCY_PATTERN.finditer(start_dependency_text(value)):
        lane, package, first_text = match.group(1), match.group(2), match.group(3)
        first = int(first_text)
        numbers = [first]
        if match.group(4):
            last = int(match.group(5))
            if last >= first:
                numbers = list(range(first, last + 1))
        elif match.group(6):
            numbers.extend(int(part) for part in match.group(6).split("/") if part)
        result.extend(f"WI-{lane}-{package}-{number:02d}" for number in numbers)
    return list(dict.fromkeys(result))


def dependency_notes_hash(value: str) -> str:
    notes = WORK_ITEM_DEPENDENCY_PATTERN.sub("<WI_DEPENDENCY>", value)
    return sha256_bytes(normalized_text(notes).encode("utf-8"))


def parse_selector_baseline(text: str, errors: list[str]) -> dict[str, Any]:
    section_match = re.search(
        r"^### 6\.3 确定性 Next Selector$(.*?)^### 6\.4 ",
        text,
        re.MULTILINE | re.DOTALL,
    )
    if not section_match:
        error(errors, "SELECTOR_PARSE", "missing section 6.3")
        return {}
    section = section_match.group(1)
    block_match = re.search(
        r"当前baseline的机器判定为：\s*```json\s*(\{.*?\})\s*```",
        section,
        re.DOTALL,
    )
    if not block_match:
        error(errors, "SELECTOR_PARSE", "missing current baseline JSON")
        return {}
    raw = block_match.group(1)
    if len(re.findall(r'"currentAction"\s*:', raw)) != 1:
        error(errors, "SELECTOR_CARDINALITY", "current baseline must declare currentAction exactly once")
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        error(errors, "SELECTOR_PARSE", f"invalid baseline JSON: {exc.msg}")
        return {}
    action = payload.get("currentAction")
    if not isinstance(action, str) or not re.fullmatch(
        r"(?:STOP_THE_LINE|NO_EXECUTABLE_ACTION|(?:EXECUTE|PLAN_ASSIGN_OWNER):WI-[A-Z0-9-]+)",
        action or "",
    ):
        error(errors, "SELECTOR_CARDINALITY", "currentAction must be one scalar typed action")
    return payload


def parse_trace_work_items(text: str, errors: list[str]) -> dict[str, dict[str, str]]:
    rows = table_after_heading(
        text,
        "## 7. Work Item Reverse Registry（115）",
        TRACE_WORK_ITEM_HEADERS,
        errors,
        "TRACE_MATRIX",
    )
    result: dict[str, dict[str, str]] = {}
    for row in rows:
        work_item_id = strip_ticks(row[0])
        if not work_item_id.startswith("WI-"):
            error(errors, "TRACE_MATRIX", f"invalid Work Item id {work_item_id}")
            continue
        if work_item_id in result:
            error(errors, "TRACE_MATRIX", f"duplicate Work Item {work_item_id}")
            continue
        result[work_item_id] = {
            "packageId": strip_ticks(row[1]),
            "lifecycle": strip_ticks(row[6]),
            "decision": strip_ticks(row[7]),
            "ceiling": strip_ticks(row[8]),
            "executionOwner": strip_ticks(row[10]),
            "gates": row[11],
        }
    if len(result) != 115:
        error(errors, "COUNT", f"Trace Matrix expected 115 Work Items, got {len(result)}")
    return result


def cycle_path(edges: dict[str, set[str]]) -> list[str] | None:
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str, path: list[str]) -> list[str] | None:
        if node in visiting:
            try:
                start = path.index(node)
            except ValueError:
                start = 0
            return path[start:] + [node]
        if node in visited:
            return None
        visiting.add(node)
        for dependency in sorted(edges.get(node, set())):
            found = visit(dependency, path + [node])
            if found:
                return found
        visiting.remove(node)
        visited.add(node)
        return None

    for node in sorted(edges):
        found = visit(node, [])
        if found:
            return found
    return None


def expected_matrix_ceiling(gates: Iterable[str]) -> str:
    gate_set = set(gates)
    if gate_set & {"G3", "G4"}:
        return "EXTERNAL_BLOCKED"
    if "G2" in gate_set:
        return "DEPLOYED_UNVERIFIED"
    return "INTERNAL_READY"


def evidence_blocks_verified(work_item: dict[str, Any]) -> bool:
    evidence = work_item.get("gateEvidence")
    if not isinstance(evidence, dict):
        return True
    return any(
        gate in {"G2", "G3", "G4"} and evidence.get(gate) != "PASS"
        for gate in work_item.get("requiredGates", [])
    )


def evidence_fails_execution(work_item: dict[str, Any]) -> bool:
    evidence = work_item.get("gateEvidence")
    if not isinstance(evidence, dict):
        return True
    return any(value in {"FAIL", "EXPIRED"} for value in evidence.values())


def dependency_satisfied(lifecycle: Any) -> bool:
    return lifecycle in {"INTERNAL_READY", "DEPLOYED_UNVERIFIED", "VERIFIED"}


def recompute_selector(registry: dict[str, Any], source_fresh: bool) -> tuple[str, str | None]:
    if not source_fresh:
        return "STOP_THE_LINE", None
    baseline = registry.get("baseline", {})
    if baseline.get("openIncidents"):
        return "STOP_THE_LINE", None
    authority_leases = baseline.get("authorityLeases", {})
    packages = {
        item.get("id"): item
        for item in registry.get("packages", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    work_items = {
        item.get("id"): item
        for item in registry.get("workItems", [])
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }
    release_rank = {"CORE": 0, "MIGRATION": 1, "MVP_EXTENSION": 2}
    priority_rank = {"P0": 0, "P1": 1, "P2": 2}
    candidates: list[tuple[tuple[Any, ...], str]] = []

    for work_item_id, work_item in work_items.items():
        package = packages.get(work_item.get("packageId"))
        if not package:
            continue
        package_dependencies = package.get("startPackageDependencies", [])
        if not all(
            dependency_satisfied(packages.get(dep, {}).get("lifecycle"))
            for dep in package_dependencies
        ):
            continue
        if not all(
            dependency_satisfied(work_items.get(dep, {}).get("lifecycle"))
            for dep in work_item.get("directDependencies", [])
        ):
            continue

        action: str | None = None
        action_rank = 99
        if (
            work_item.get("decision") == "GO"
            and work_item.get("executionOwner") != "UNASSIGNED"
            and work_item.get("lifecycle") in {"PLANNED", "IN_PROGRESS", "PAUSED"}
            and not evidence_fails_execution(work_item)
            and authority_leases.get(work_item.get("authorityLock"))
            == {
                "owner": work_item.get("executionOwner"),
                "state": "HELD",
            }
        ):
            action = f"EXECUTE:{work_item_id}"
            action_rank = 0
        elif (
            work_item.get("lifecycle") == "PLANNED"
            and work_item.get("decision") in {"STOP", "NO_GO"}
            and work_item.get("executionOwner") == "UNASSIGNED"
            and (
                work_item.get("releaseClass") == "CORE"
                or (
                    work_item.get("releaseClass") == "MIGRATION"
                    and work_item_id == "WI-MIG-01-01"
                )
            )
        ):
            action = f"PLAN_ASSIGN_OWNER:{work_item_id}"
            action_rank = 1
        if action is None:
            continue
        key = (
            action_rank,
            release_rank.get(work_item.get("releaseClass"), 99),
            package.get("selectorBand", 9999),
            priority_rank.get(work_item.get("priorityClass"), 99),
            work_item.get("stableRank", 999999),
            work_item_id,
        )
        candidates.append((key, action))

    candidates.sort(key=lambda item: item[0])
    current = candidates[0][1] if candidates else "NO_EXECUTABLE_ACTION"
    migration_action = "PLAN_ASSIGN_OWNER:WI-MIG-01-01"
    secondary = (
        "WI-MIG-01-01"
        if any(action == migration_action for _, action in candidates)
        else None
    )
    return current, secondary


def validate_inputs(
    roadmap_bytes: bytes,
    registry: dict[str, Any],
    matrix_text: str,
) -> list[str]:
    errors: list[str] = []
    try:
        roadmap_text = roadmap_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        return [f"ROADMAP_PARSE: invalid UTF-8 at byte {exc.start}"]

    inventory = parse_package_inventory(roadmap_text, errors)
    controls, control_order = parse_package_controls(roadmap_text, errors)
    work_item_fields, _ = parse_work_items(roadmap_text, errors)
    selector = parse_selector_baseline(roadmap_text, errors)
    trace_items = parse_trace_work_items(matrix_text, errors)

    header = roadmap_text[:900]
    if not all(
        marker in header
        for marker in (
            "V1.2 Product Confirmed Baseline + Staged Validation + Startup Lean Profile",
            "115 个 Work Item",
            "产品范围已确认不代表工程实现",
            "当前 Operating Profile",
        )
    ):
        error(errors, "ROUND4_STATUS", "Roadmap header is not the July 15 product-confirmed/implementation-unverified state")
    if selector.get("round4Acceptance") != ROUND4_ACCEPTANCE:
        error(
            errors,
            "ROUND4_STATUS",
            f"round4Acceptance expected {ROUND4_ACCEPTANCE}, got {selector.get('round4Acceptance')!r}",
        )

    expected_source_hash = sha256_bytes(roadmap_bytes)
    source = registry.get("source") if isinstance(registry.get("source"), dict) else {}
    source_fresh = source.get("sha256") == expected_source_hash
    if not source_fresh:
        error(
            errors,
            "SOURCE_HASH",
            f"registry={source.get('sha256')} roadmap={expected_source_hash}",
        )
    if source.get("path") != ROADMAP_SOURCE_PATH:
        error(errors, "REGISTRY_SOURCE", f"unexpected source.path {source.get('path')}")
    if source.get("authority") != "ROADMAP_WORK_ITEMS_PLUS_TYPED_PACKAGE_CONTROLS":
        error(errors, "REGISTRY_SOURCE", f"unexpected source.authority {source.get('authority')}")
    if registry.get("schemaVersion") != REGISTRY_SCHEMA:
        error(errors, "ENUM", f"invalid schemaVersion {registry.get('schemaVersion')}")
    if registry.get("enums") != EXPECTED_ENUMS:
        error(errors, "ENUM", "registry enums differ from the finite roadmap contract")
    expected_baseline = {
        "authorityLeases": {
            authority_lock: {"owner": "UNASSIGNED", "state": "UNHELD"}
            for authority_lock in EXPECTED_ENUMS["authorityLock"]
        },
        "decision": {"coreAndMvpExtension": "STOP", "migration": "NO_GO"},
        "executionOwner": "UNASSIGNED",
        "gateEvidence": "MISSING",
        "implementationClaim": "NONE",
        "lifecycle": "PLANNED",
        "openIncidents": [],
    }
    if registry.get("baseline") != expected_baseline:
        error(errors, "ENUM", "registry baseline is not the conservative Round 4 baseline")

    counts = registry.get("counts")
    expected_counts = {"packages": 13, "sourceFields": 1840, "workItems": 115}
    if counts != expected_counts:
        error(errors, "COUNT", f"registry counts expected {expected_counts}, got {counts}")

    raw_packages = registry.get("packages")
    if not isinstance(raw_packages, list):
        error(errors, "PACKAGE_SCHEMA", "packages must be a list")
        raw_packages = []
    raw_work_items = registry.get("workItems")
    if not isinstance(raw_work_items, list):
        error(errors, "WI_SCHEMA", "workItems must be a list")
        raw_work_items = []

    packages: dict[str, dict[str, Any]] = {}
    registry_package_order: list[str] = []
    for item in raw_packages:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str):
            error(errors, "PACKAGE_SCHEMA", f"invalid Package entry {item!r}")
            continue
        package_id = item["id"]
        if package_id in packages:
            error(errors, "PACKAGE_SCHEMA", f"duplicate Package {package_id}")
            continue
        if set(item) != PACKAGE_KEYS:
            error(errors, "PACKAGE_SCHEMA", f"{package_id} keys differ: {sorted(set(item) ^ PACKAGE_KEYS)}")
        packages[package_id] = item
        registry_package_order.append(package_id)
    if len(packages) != 13:
        error(errors, "COUNT", f"registry expected 13 unique Packages, got {len(packages)}")
    if registry_package_order != control_order:
        error(errors, "PACKAGE_CONTROL", "registry Package order differs from selectorBand control order")
    if set(inventory) != set(controls):
        error(errors, "PACKAGE_CONTROL", "Package Inventory and Control Registry IDs differ")
    if set(packages) != set(controls):
        error(errors, "PACKAGE_CONTROL", "registry and Roadmap Package IDs differ")

    authority_locks: list[str] = []
    mvp_extension_ids = {
        package_id
        for package_id, control in controls.items()
        if control.get("releaseClass") == "MVP_EXTENSION"
    }
    package_edges: dict[str, set[str]] = {}
    for package_id in sorted(set(packages) | set(controls) | set(inventory)):
        package = packages.get(package_id)
        control = controls.get(package_id)
        source_package = inventory.get(package_id)
        if not package or not control or not source_package:
            continue
        release_class = control["releaseClass"]
        expected_start = package_references(source_package["startText"])
        expected_exit = package_references(source_package["exitText"])
        expected_migration_refs = (
            ["WI-MIG-01-08:authorization"]
            if package_id == "WP-S1-01" and re.search(r"\bMIG\s+gate\b", source_package["exitText"])
            else []
        )
        expected_package = {
            "authorityLock": control["authorityLock"],
            "decision": "NO_GO" if release_class == "MIGRATION" else "STOP",
            "defaultExposure": control["defaultExposure"],
            "exitPackageDependencies": expected_exit,
            "id": package_id,
            "lifecycle": "PLANNED",
            "migrationGateRefs": expected_migration_refs,
            "name": source_package["name"],
            "priorityClass": priority_class(source_package["priority"]),
            "releaseClass": release_class,
            "roadmapLane": source_package["lane"],
            "selectorBand": control["selectorBand"],
            "startPackageDependencies": expected_start,
        }
        for key, expected in expected_package.items():
            if package.get(key) != expected:
                error(
                    errors,
                    "PACKAGE_MISMATCH",
                    f"{package_id}.{key} expected {expected!r}, got {package.get(key)!r}",
                )
        authority_locks.append(package.get("authorityLock"))
        for enum_key in ("releaseClass", "priorityClass", "lifecycle", "decision", "defaultExposure"):
            enum_name = enum_key
            if package.get(enum_key) not in EXPECTED_ENUMS[enum_name]:
                error(errors, "ENUM", f"{package_id}.{enum_key}={package.get(enum_key)!r}")
        start_dependencies = package.get("startPackageDependencies", [])
        exit_dependencies = package.get("exitPackageDependencies", [])
        if not isinstance(start_dependencies, list) or not isinstance(exit_dependencies, list):
            error(errors, "PACKAGE_DEPENDENCY", f"{package_id} dependencies must be lists")
            start_dependencies, exit_dependencies = [], []
        all_dependencies = start_dependencies + exit_dependencies
        if len(start_dependencies) != len(set(start_dependencies)) or len(exit_dependencies) != len(set(exit_dependencies)):
            error(errors, "PACKAGE_DEPENDENCY", f"duplicate dependency in {package_id}")
        if package_id in all_dependencies:
            error(errors, "PACKAGE_DEPENDENCY", f"self dependency in {package_id}")
        for dependency in all_dependencies:
            if dependency not in packages:
                error(errors, "PACKAGE_DEPENDENCY", f"{package_id} references {dependency}")
        if release_class == "CORE" and set(start_dependencies) & mvp_extension_ids:
            error(errors, "CORE_OPTIONAL", f"{package_id} starts from MVP extension {sorted(set(start_dependencies) & mvp_extension_ids)}")
        if release_class in {"MVP_EXTENSION", "MIGRATION"} and package.get("defaultExposure") != "DEFAULT_OFF":
            error(errors, "ENUM", f"{package_id} must remain DEFAULT_OFF")
        if release_class == "MIGRATION" and package.get("authorityLock") != "MIGRATION_EVIDENCE":
            error(errors, "MIG_AUTHORITY", f"{package_id} owns {package.get('authorityLock')}")
        start_node = f"{package_id}:START"
        exit_node = f"{package_id}:EXIT"
        package_edges[start_node] = {f"{dep}:START" for dep in start_dependencies}
        package_edges[exit_node] = {start_node} | {f"{dep}:EXIT" for dep in exit_dependencies}

    if len(authority_locks) != len(set(authority_locks)) or set(authority_locks) != set(EXPECTED_ENUMS["authorityLock"]):
        error(errors, "ENUM", "Package authority locks must be the 13 unique finite locks")
    package_cycle = cycle_path(package_edges)
    if package_cycle:
        error(errors, "DAG_CYCLE", f"Package milestone {' -> '.join(package_cycle)}")
    s1_owner = packages.get("WP-S1-01", {})
    if "WP-MIG-01" in s1_owner.get("exitPackageDependencies", []):
        error(errors, "MIG_AUTHORITY", "WP-S1-01 cannot depend on the whole Migration Package")
    if s1_owner.get("migrationGateRefs") != ["WI-MIG-01-08:authorization"]:
        error(errors, "MIG_AUTHORITY", "WP-S1-01 requires only WI-MIG-01-08:authorization")
    for default_off_id in ("WP-S3-01", "WP-V0-01", "WP-MIG-01"):
        if packages.get(default_off_id, {}).get("defaultExposure") != "DEFAULT_OFF":
            error(errors, "ENUM", f"{default_off_id} must remain DEFAULT_OFF")
    migration_package = packages.get("WP-MIG-01", {})
    if (
        migration_package.get("releaseClass") != "MIGRATION"
        or migration_package.get("authorityLock") != "MIGRATION_EVIDENCE"
    ):
        error(errors, "MIG_AUTHORITY", "WP-MIG-01 is evidence-only MIGRATION authority")

    work_items: dict[str, dict[str, Any]] = {}
    ranks: list[Any] = []
    for item in raw_work_items:
        if not isinstance(item, dict) or not isinstance(item.get("id"), str):
            error(errors, "WI_SCHEMA", f"invalid Work Item entry {item!r}")
            continue
        work_item_id = item["id"]
        if work_item_id in work_items:
            error(errors, "WI_SCHEMA", f"duplicate Work Item {work_item_id}")
            continue
        if set(item) != WORK_ITEM_KEYS:
            error(errors, "WI_SCHEMA", f"{work_item_id} keys differ: {sorted(set(item) ^ WORK_ITEM_KEYS)}")
        work_items[work_item_id] = item
        ranks.append(item.get("stableRank"))
    if len(work_items) != 115:
        error(errors, "COUNT", f"registry expected 115 unique Work Items, got {len(work_items)}")
    if len(ranks) != len(set(map(repr, ranks))):
        error(errors, "WI_MISMATCH", "stableRank values must be unique")

    work_item_edges: dict[str, set[str]] = {}
    expected_order: list[str] = []
    for work_item_id, fields in work_item_fields.items():
        work_item = work_items.get(work_item_id)
        if not work_item:
            error(errors, "WI_MISMATCH", f"missing registry item {work_item_id}")
            continue
        parent_id = package_id_for(work_item_id)
        package = packages.get(parent_id)
        control = controls.get(parent_id)
        if not package or not control:
            error(errors, "WI_MISMATCH", f"unknown parent {parent_id} for {work_item_id}")
            continue
        dependencies_text = fields.get("Dependencies", "")
        gates = applicable_gates(fields.get("Verification", "") + " " + fields.get("External gates", ""))
        expected = {
            "authorityLock": control["authorityLock"],
            "decision": "NO_GO" if control["releaseClass"] == "MIGRATION" else "STOP",
            "dependencyNotesHash": dependency_notes_hash(dependencies_text),
            "directDependencies": expand_work_item_dependencies(dependencies_text),
            "executionOwner": "UNASSIGNED",
            "gateEvidence": {gate: "MISSING" for gate in gates},
            "id": work_item_id,
            "lifecycle": "PLANNED",
            "packageId": parent_id,
            "priorityClass": priority_class(fields.get("Priority / lane", "")),
            "releaseClass": control["releaseClass"],
            "requiredGates": gates,
            "sourceFieldCount": len(fields),
            "stableRank": expected_stable_rank(work_item_id, control["selectorBand"]),
        }
        for key, expected_value in expected.items():
            if work_item.get(key) != expected_value:
                prefix = "WI_DEPENDENCY" if key in {"directDependencies", "dependencyNotesHash"} else "WI_MISMATCH"
                error(
                    errors,
                    prefix,
                    f"{work_item_id}.{key} expected {expected_value!r}, got {work_item.get(key)!r}",
                )
        for enum_key in ("releaseClass", "priorityClass", "lifecycle", "decision"):
            if work_item.get(enum_key) not in EXPECTED_ENUMS[enum_key]:
                error(errors, "ENUM", f"{work_item_id}.{enum_key}={work_item.get(enum_key)!r}")
        if (
            work_item.get("decision") == "GO"
            and work_item.get("executionOwner") != "UNASSIGNED"
        ):
            lease = registry.get("baseline", {}).get("authorityLeases", {}).get(
                work_item.get("authorityLock")
            )
            expected_lease = {
                "owner": work_item.get("executionOwner"),
                "state": "HELD",
            }
            if lease != expected_lease:
                error(
                    errors,
                    "AUTHORITY_LOCK",
                    f"{work_item_id} requires lease {expected_lease!r}, got {lease!r}",
                )
        required_gates = work_item.get("requiredGates", [])
        gate_evidence = work_item.get("gateEvidence", {})
        if not isinstance(required_gates, list) or not required_gates:
            error(errors, "ENUM", f"{work_item_id}.requiredGates must be non-empty list")
            required_gates = []
        if not isinstance(gate_evidence, dict):
            error(errors, "ENUM", f"{work_item_id}.gateEvidence must be an object")
            gate_evidence = {}
        for gate in required_gates:
            if gate not in EXPECTED_ENUMS["gate"]:
                error(errors, "ENUM", f"{work_item_id} invalid gate {gate}")
        for gate, state in gate_evidence.items():
            if gate not in EXPECTED_ENUMS["gate"] or state not in EXPECTED_ENUMS["gateEvidence"]:
                error(errors, "ENUM", f"{work_item_id}.gateEvidence[{gate}]={state!r}")
        dependencies = work_item.get("directDependencies", [])
        if not isinstance(dependencies, list):
            error(errors, "WI_DEPENDENCY", f"{work_item_id}.directDependencies must be a list")
            dependencies = []
        if len(dependencies) != len(set(dependencies)):
            error(errors, "WI_DEPENDENCY", f"duplicate direct dependency in {work_item_id}")
        if work_item_id in dependencies:
            error(errors, "WI_DEPENDENCY", f"self dependency in {work_item_id}")
        for dependency in dependencies:
            if dependency not in work_items:
                error(errors, "WI_DEPENDENCY", f"{work_item_id} references {dependency}")
        work_item_edges[work_item_id] = set(dep for dep in dependencies if dep in work_items)
        if work_item.get("lifecycle") == "VERIFIED" and evidence_blocks_verified(work_item):
            error(errors, "EVIDENCE_CEILING", f"{work_item_id} is VERIFIED with missing/failed external evidence")
        expected_order.append(work_item_id)

    registry_order = [item.get("id") for item in raw_work_items if isinstance(item, dict)]
    expected_order.sort(key=lambda item: (work_items.get(item, {}).get("stableRank", 999999), item))
    if registry_order != expected_order:
        error(errors, "WI_MISMATCH", "registry Work Item order differs from stableRank order")
    wi_cycle = cycle_path(work_item_edges)
    if wi_cycle:
        error(errors, "DAG_CYCLE", f"Work Item {' -> '.join(wi_cycle)}")

    if set(trace_items) != set(work_items):
        missing = sorted(set(work_items) - set(trace_items))
        extra = sorted(set(trace_items) - set(work_items))
        error(errors, "TRACE_MATRIX", f"Work Item set mismatch missing={missing} extra={extra}")
    for work_item_id in sorted(set(trace_items) & set(work_items)):
        trace = trace_items[work_item_id]
        work_item = work_items[work_item_id]
        trace_gates = sorted(set(GATE_PATTERN.findall(trace["gates"])))
        comparisons = {
            "packageId": work_item.get("packageId"),
            "lifecycle": work_item.get("lifecycle"),
            "decision": work_item.get("decision"),
            "executionOwner": work_item.get("executionOwner"),
        }
        for key, expected_value in comparisons.items():
            if trace.get(key) != expected_value:
                error(errors, "TRACE_MATRIX", f"{work_item_id}.{key} expected {expected_value!r}, got {trace.get(key)!r}")
        if trace_gates != work_item.get("requiredGates"):
            error(errors, "TRACE_MATRIX", f"{work_item_id}.gates expected {work_item.get('requiredGates')!r}, got {trace_gates!r}")
        expected_ceiling = expected_matrix_ceiling(work_item.get("requiredGates", []))
        if trace.get("ceiling") != expected_ceiling:
            error(errors, "TRACE_MATRIX", f"{work_item_id}.ceiling expected {expected_ceiling}, got {trace.get('ceiling')}")

    current_action, secondary = recompute_selector(registry, source_fresh)
    declared_action = selector.get("currentAction")
    if declared_action != current_action:
        error(errors, "SELECTOR_MISMATCH", f"expected {current_action}, got {declared_action!r}")
    if selector.get("currentActionAuthorizesImplementation") != current_action.startswith("EXECUTE:"):
        error(errors, "SELECTOR_MISMATCH", "currentActionAuthorizesImplementation disagrees with action type")
    if selector.get("secondaryReadOnlyCandidate") != secondary:
        error(errors, "SELECTOR_MISMATCH", f"secondary expected {secondary!r}, got {selector.get('secondaryReadOnlyCandidate')!r}")
    if selector.get("secondaryCandidateSelected") is not False:
        error(errors, "SELECTOR_CARDINALITY", "secondary read-only candidate must not be selected")
    if selector.get("openIncidents") != []:
        error(errors, "SELECTOR_MISMATCH", "baseline must declare no recorded open incident")
    if selector.get("authorityLeaseState") != "ALL_UNHELD":
        error(errors, "AUTHORITY_LOCK", "baseline must declare all authority leases unheld")
    if current_action != "PLAN_ASSIGN_OWNER:WI-S0-03-01" and source_fresh:
        error(errors, "SELECTOR_MISMATCH", f"baseline unique action changed to {current_action}")
    if secondary != "WI-MIG-01-01" and source_fresh:
        error(errors, "SELECTOR_MISMATCH", f"baseline secondary changed to {secondary}")
    if isinstance(declared_action, str) and declared_action.startswith("EXECUTE:"):
        target_id = declared_action.split(":", 1)[1]
        target = work_items.get(target_id)
        if target and evidence_fails_execution(target):
            error(errors, "EVIDENCE_CEILING", f"{target_id} remains EXECUTE with FAIL/EXPIRED evidence")

    return sorted(set(errors))


def error_prefixes(errors: Iterable[str]) -> set[str]:
    return {item.split(":", 1)[0] for item in errors}


def fixture_requires_new_prefix(
    name: str,
    expected_prefix: str,
    baseline_errors: list[str],
    fixture_errors: list[str],
) -> None:
    added = error_prefixes(fixture_errors) - error_prefixes(baseline_errors)
    if expected_prefix not in added:
        raise AssertionError(
            f"fixture {name} expected new {expected_prefix}, added={sorted(added)}, errors={fixture_errors}"
        )


def run_self_test(roadmap_bytes: bytes, registry: dict[str, Any], matrix_text: str) -> None:
    baseline_errors = validate_inputs(roadmap_bytes, registry, matrix_text)
    if baseline_errors:
        raise AssertionError("baseline must be clean before negative fixtures:\n" + "\n".join(baseline_errors))

    gate_cases = {
        "G4产品 / G2真实 / G1 UIQA": ["G1", "G2", "G4"],
        "无G2/G3/G4；Xcode review": ["G0"],
        "G0 fixture；无G3真实调用；G4产品": ["G0", "G4"],
        "G0 fixture；G3不适用；不依赖G2；无需G4；G3不发真实effect": ["G0"],
    }
    for source, expected in gate_cases.items():
        actual = applicable_gates(source)
        if actual != expected:
            raise AssertionError(f"gate parser {source!r}: expected {expected}, got {actual}")
    dependency_cases = {
        "WI-S1-02-01/02": ["WI-S1-02-01", "WI-S1-02-02"],
        "WI-S1-02-01..04": [
            "WI-S1-02-01",
            "WI-S1-02-02",
            "WI-S1-02-03",
            "WI-S1-02-04",
        ],
        "start依赖WI-S1-01-01/02；exit依赖WI-S1-02-11": [
            "WI-S1-01-01",
            "WI-S1-01-02",
        ],
    }
    for source, expected in dependency_cases.items():
        actual = expand_work_item_dependencies(source)
        if actual != expected:
            raise AssertionError(f"dependency parser {source!r}: expected {expected}, got {actual}")

    roadmap_text = roadmap_bytes.decode("utf-8")
    fixtures: list[tuple[str, str, bytes, dict[str, Any], str]] = []

    missing_field_text = roadmap_text.replace(
        "- **Non-goals**：本项不实现 AccountLease、不迁移 store、不删除 legacy 数据。\n",
        "",
        1,
    )
    fixtures.append(("missing_wi_field", "WI_FIELDS", missing_field_text.encode(), copy.deepcopy(registry), matrix_text))

    dangling = copy.deepcopy(registry)
    dangling["workItems"][0]["directDependencies"].append("WI-UNKNOWN-99-99")
    fixtures.append(("dangling_dependency", "WI_DEPENDENCY", roadmap_bytes, dangling, matrix_text))

    wi_cycle = copy.deepcopy(registry)
    wi_by_id = {item["id"]: item for item in wi_cycle["workItems"]}
    wi_by_id["WI-S0-03-01"]["directDependencies"] = ["WI-S0-04-01"]
    wi_by_id["WI-S0-04-01"]["directDependencies"] = ["WI-S0-03-01"]
    fixtures.append(("work_item_cycle", "DAG_CYCLE", roadmap_bytes, wi_cycle, matrix_text))

    package_cycle = copy.deepcopy(registry)
    package_by_id = {item["id"]: item for item in package_cycle["packages"]}
    package_by_id["WP-S0-03"]["startPackageDependencies"] = ["WP-S0-04"]
    package_by_id["WP-S0-04"]["startPackageDependencies"] = ["WP-S0-03"]
    fixtures.append(("package_milestone_cycle", "DAG_CYCLE", roadmap_bytes, package_cycle, matrix_text))

    bad_enum = copy.deepcopy(registry)
    bad_enum["workItems"][0]["lifecycle"] = "DONE"
    fixtures.append(("invalid_enum", "ENUM", roadmap_bytes, bad_enum, matrix_text))

    core_optional = copy.deepcopy(registry)
    package_by_id = {item["id"]: item for item in core_optional["packages"]}
    package_by_id["WP-S0-03"]["startPackageDependencies"] = ["WP-S3-01"]
    fixtures.append(("optional_in_core_start", "CORE_OPTIONAL", roadmap_bytes, core_optional, matrix_text))

    migration_authority = copy.deepcopy(registry)
    package_by_id = {item["id"]: item for item in migration_authority["packages"]}
    package_by_id["WP-MIG-01"]["authorityLock"] = "OWNER_TRUTH"
    fixtures.append(("migration_business_authority", "MIG_AUTHORITY", roadmap_bytes, migration_authority, matrix_text))

    double_action_text = roadmap_text.replace(
        '"currentAction": "PLAN_ASSIGN_OWNER:WI-S0-03-01"',
        '"currentAction": ["PLAN_ASSIGN_OWNER:WI-S0-03-01", "PLAN_ASSIGN_OWNER:WI-S0-04-01"]',
        1,
    )
    fixtures.append(("double_current_action", "SELECTOR_CARDINALITY", double_action_text.encode(), copy.deepcopy(registry), matrix_text))

    expired_verified = copy.deepcopy(registry)
    wi_by_id = {item["id"]: item for item in expired_verified["workItems"]}
    target = wi_by_id["WI-V0-01-01"]
    target["lifecycle"] = "VERIFIED"
    target["gateEvidence"]["G4"] = "EXPIRED"
    fixtures.append(("expired_gate_verified", "EVIDENCE_CEILING", roadmap_bytes, expired_verified, matrix_text))

    failed_execute = copy.deepcopy(registry)
    wi_by_id = {item["id"]: item for item in failed_execute["workItems"]}
    target = wi_by_id["WI-S0-06-01"]
    target["decision"] = "GO"
    target["executionOwner"] = "qa-owner"
    target["gateEvidence"]["G4"] = "FAIL"
    execute_text = roadmap_text.replace(
        '"currentAction": "PLAN_ASSIGN_OWNER:WI-S0-03-01"',
        '"currentAction": "EXECUTE:WI-S0-06-01"',
        1,
    ).replace('"currentActionAuthorizesImplementation": false', '"currentActionAuthorizesImplementation": true', 1)
    fixtures.append(("failed_gate_execute", "EVIDENCE_CEILING", execute_text.encode(), failed_execute, matrix_text))

    missing_authority_lock = copy.deepcopy(registry)
    wi_by_id = {item["id"]: item for item in missing_authority_lock["workItems"]}
    target = wi_by_id["WI-S0-03-01"]
    target["decision"] = "GO"
    target["executionOwner"] = "qa-owner"
    fixtures.append(("go_without_authority_lock", "AUTHORITY_LOCK", roadmap_bytes, missing_authority_lock, matrix_text))

    stale_source = copy.deepcopy(registry)
    stale_source["source"]["sha256"] = "0" * 64
    fixtures.append(("stale_source_hash", "SOURCE_HASH", roadmap_bytes, stale_source, matrix_text))

    for name, expected_prefix, fixture_roadmap, fixture_registry, fixture_matrix in fixtures:
        fixture_errors = validate_inputs(fixture_roadmap, fixture_registry, fixture_matrix)
        fixture_requires_new_prefix(name, expected_prefix, baseline_errors, fixture_errors)

    print(
        "Product V4 roadmap checker self-test passed: "
        f"fixtures={len(fixtures)}, packages=13, work_items=115, fields=1840"
    )


def load_registry(errors: list[str]) -> dict[str, Any]:
    try:
        payload = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        error(errors, "REGISTRY_PARSE", str(exc))
        return {}
    if not isinstance(payload, dict):
        error(errors, "REGISTRY_PARSE", "root must be an object")
        return {}
    return payload


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Validate the real baseline, then run independent negative fixtures.",
    )
    args = parser.parse_args()

    load_errors: list[str] = []
    try:
        roadmap_bytes = ROADMAP.read_bytes()
    except OSError as exc:
        error(load_errors, "ROADMAP_PARSE", str(exc))
        roadmap_bytes = b""
    registry = load_registry(load_errors)
    try:
        matrix_text = TRACE_MATRIX.read_text(encoding="utf-8")
    except OSError as exc:
        error(load_errors, "TRACE_MATRIX", str(exc))
        matrix_text = ""
    if load_errors:
        for item in sorted(set(load_errors)):
            print(item, file=sys.stderr)
        return 1

    if args.self_test:
        try:
            run_self_test(roadmap_bytes, registry, matrix_text)
        except AssertionError as exc:
            print(f"SELF_TEST: {exc}", file=sys.stderr)
            return 1
        return 0

    errors = validate_inputs(roadmap_bytes, registry, matrix_text)
    if errors:
        for item in errors:
            print(item, file=sys.stderr)
        print(f"Product V4 roadmap check failed: errors={len(errors)}", file=sys.stderr)
        return 1
    selector = parse_selector_baseline(roadmap_bytes.decode("utf-8"), [])
    print(
        "Product V4 roadmap check passed: "
        "packages=13, work_items=115, fields=1840, trace_rows=115, "
        f"current_action={selector.get('currentAction')}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
