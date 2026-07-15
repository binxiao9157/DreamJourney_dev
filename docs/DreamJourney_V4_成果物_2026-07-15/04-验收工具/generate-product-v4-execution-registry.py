#!/usr/bin/env python3
"""Generate the deterministic DreamJourney V4 execution registry."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
ROADMAP = (
    ROOT
    / "docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md"
)
OUTPUT = ROOT / "docs/product/DreamJourney_V4_路线执行注册表_V1.0.json"
SOURCE_PATH = ROADMAP.relative_to(ROOT).as_posix()

FIELDS = (
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

RELEASE_CLASSES = ("CORE", "MVP_EXTENSION", "MIGRATION")
PRIORITY_CLASSES = ("P0", "P1", "P2")
LIFECYCLES = (
    "PLANNED",
    "IN_PROGRESS",
    "INTERNAL_READY",
    "EXTERNAL_BLOCKED",
    "DEPLOYED_UNVERIFIED",
    "VERIFIED",
    "PAUSED",
    "RETIRED",
)
DECISIONS = ("STOP", "NO_GO", "GO")
DEFAULT_EXPOSURES = ("DEFAULT_OFF", "EXISTING_PUBLIC_SHELL")
GATES = ("G0", "G1", "G2", "G3", "G4")
GATE_EVIDENCE_STATES = ("MISSING", "PASS", "FAIL", "EXPIRED")
AUTHORITY_LEASE_STATES = ("UNHELD", "HELD", "EXPIRED", "REVOKED")

AUTHORITY_LOCKS = (
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
)

GATE_PATTERN = re.compile(r"(?<![A-Z0-9])G[0-4](?![A-Z0-9])")
GATE_ATOM = r"`?G[0-4]`?"
NEGATED_GATE_SPANS = (
    re.compile(rf"(?:无|不依赖|无需)\s*{GATE_ATOM}(?:\s*/\s*{GATE_ATOM})*"),
    re.compile(rf"{GATE_ATOM}\s*(?:不适用|不发(?:送)?|不调用)"),
)

WORK_ITEM_DEPENDENCY_PATTERN = re.compile(
    r"(?<![A-Z0-9-])WI-([A-Z0-9]+)-(\d{2})-(\d{2})"
    r"(?:(\.\.)(\d{2})|((?:/\d{2})+))?"
    r"(?![A-Z0-9-])"
)


@dataclass(frozen=True)
class PackageControl:
    release_class: str
    authority_lock: str
    selector_band: int
    default_exposure: str
    start_dependencies: tuple[str, ...] = ()
    exit_dependencies: tuple[str, ...] = ()
    migration_gate_refs: tuple[str, ...] = ()


# Package-level dependencies describe whole-package readiness only. Partial
# contracts remain Work Item dependencies so the registry does not invent a
# package cycle that the roadmap does not require.
PACKAGE_CONTROLS: dict[str, PackageControl] = {
    "WP-S0-03": PackageControl(
        "CORE", "CREDENTIAL_CONTROL", 0, "EXISTING_PUBLIC_SHELL"
    ),
    "WP-S0-04": PackageControl(
        "CORE", "DB_RECOVERY", 1, "EXISTING_PUBLIC_SHELL"
    ),
    "WP-S0-06": PackageControl(
        "CORE", "RELEASE_POLICY", 2, "EXISTING_PUBLIC_SHELL"
    ),
    "WP-S0-07": PackageControl(
        "CORE", "OPERATIONS_EVIDENCE", 3, "EXISTING_PUBLIC_SHELL"
    ),
    "WP-S0-02": PackageControl(
        "CORE",
        "IDENTITY_AUTHZ",
        10,
        "EXISTING_PUBLIC_SHELL",
        start_dependencies=("WP-S0-03", "WP-S0-04"),
    ),
    "WP-S0-01": PackageControl(
        "CORE",
        "ACCOUNT_LOCAL_STATE",
        20,
        "EXISTING_PUBLIC_SHELL",
        start_dependencies=("WP-S0-02",),
        exit_dependencies=("WP-S0-02",),
    ),
    "WP-S1-01": PackageControl(
        "CORE",
        "OWNER_TRUTH",
        30,
        "EXISTING_PUBLIC_SHELL",
        start_dependencies=("WP-S0-01", "WP-S0-02", "WP-S0-04", "WP-S0-06"),
        exit_dependencies=("WP-S1-02", "WP-S1-03"),
        migration_gate_refs=("WI-MIG-01-08:authorization",),
    ),
    "WP-S1-02": PackageControl(
        "CORE",
        "ASYNC_EFFECT",
        40,
        "EXISTING_PUBLIC_SHELL",
        start_dependencies=("WP-S0-02", "WP-S0-04", "WP-S0-07", "WP-S1-01"),
    ),
    "WP-S1-03": PackageControl(
        "CORE",
        "IOS_COMPOSITION",
        41,
        "EXISTING_PUBLIC_SHELL",
        start_dependencies=("WP-S0-01", "WP-S0-02", "WP-S0-06", "WP-S1-01"),
    ),
    "WP-S0-05": PackageControl(
        "CORE",
        "RIGHTS_DELETION",
        42,
        "EXISTING_PUBLIC_SHELL",
        start_dependencies=("WP-S0-02", "WP-S0-04"),
        exit_dependencies=("WP-S1-02",),
    ),
    "WP-S3-01": PackageControl(
        "MVP_EXTENSION",
        "PUBLICATION",
        80,
        "DEFAULT_OFF",
        start_dependencies=(
            "WP-S0-02",
            "WP-S0-05",
            "WP-S0-06",
            "WP-S0-07",
            "WP-S1-01",
            "WP-S1-02",
        ),
    ),
    "WP-V0-01": PackageControl(
        "MVP_EXTENSION",
        "VOICE_DH_GOVERNANCE",
        81,
        "DEFAULT_OFF",
        start_dependencies=(
            "WP-S0-02",
            "WP-S0-03",
            "WP-S0-05",
            "WP-S0-06",
            "WP-S0-07",
        ),
    ),
    "WP-MIG-01": PackageControl(
        "MIGRATION", "MIGRATION_EVIDENCE", 90, "DEFAULT_OFF"
    ),
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def cells(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def strip_ticks(value: str) -> str:
    return value.replace("`", "").strip()


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def normalized_text(value: str) -> str:
    return " ".join(value.split())


def applicable_gates(text: str) -> tuple[str, ...]:
    """Return positive gate declarations, excluding explicit negations."""
    normalized = text
    for pattern in NEGATED_GATE_SPANS:
        normalized = pattern.sub(" ", normalized)
    gates = set(GATE_PATTERN.findall(normalized))
    if not gates:
        gates.add("G0")
    return tuple(sorted(gates))


def start_dependency_text(text: str) -> str:
    """Exclude explicitly labelled exit-only clauses from the start DAG."""
    markers = ("exit依赖", "退出依赖", "退出前", "exit dependency")
    offsets = [text.index(marker) for marker in markers if marker in text]
    return text[: min(offsets)] if offsets else text


def expand_work_item_dependencies(text: str) -> tuple[str, ...]:
    """Expand explicit WI compact and range references into canonical IDs."""
    dependencies: list[str] = []
    for match in WORK_ITEM_DEPENDENCY_PATTERN.finditer(start_dependency_text(text)):
        lane, package, first = match.group(1), match.group(2), int(match.group(3))
        numbers = [first]
        if match.group(4):
            last = int(match.group(5))
            require(last >= first, f"descending Work Item dependency range: {match.group(0)}")
            numbers = list(range(first, last + 1))
        elif match.group(6):
            numbers.extend(int(part) for part in match.group(6).split("/") if part)
        dependencies.extend(
            f"WI-{lane}-{package}-{number:02d}" for number in numbers
        )
    return tuple(dict.fromkeys(dependencies))


def dependency_notes_hash(text: str) -> str:
    notes = WORK_ITEM_DEPENDENCY_PATTERN.sub("<WI_DEPENDENCY>", text)
    return sha256_bytes(normalized_text(notes).encode("utf-8"))


def parse_package_inventory(text: str) -> dict[str, dict[str, str]]:
    try:
        inventory = text.split("### 2.1 Package Inventory", 1)[1].split(
            "### 2.2", 1
        )[0]
    except IndexError as error:
        raise ValueError("roadmap Package Inventory section is missing") from error

    result: dict[str, dict[str, str]] = {}
    for line in inventory.splitlines():
        if not line.startswith("| `WP-"):
            continue
        row = cells(line)
        require(len(row) == 9, f"invalid Package Inventory row: {line}")
        package_id = strip_ticks(row[0])
        result[package_id] = {
            "name": row[1],
            "priority": row[3],
            "lane": row[4],
        }
    return result


def parse_work_items(text: str) -> dict[str, dict[str, str]]:
    matches = list(re.finditer(r"^### `(WI-[A-Z0-9-]+)`", text, re.MULTILINE))
    result: dict[str, dict[str, str]] = {}
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[match.start() : end]
        field_pairs = re.findall(r"^- \*\*([^*]+)\*\*：(.*)$", block, re.MULTILINE)
        field_names = tuple(name for name, _ in field_pairs)
        require(
            field_names == FIELDS,
            f"{match.group(1)} must contain the exact 16 Work Item fields",
        )
        work_item_id = match.group(1)
        require(work_item_id not in result, f"duplicate Work Item: {work_item_id}")
        result[work_item_id] = dict(field_pairs)
    return result


def priority_class(value: str) -> str:
    priorities = set(re.findall(r"(?<![A-Z0-9])P[0-2](?![A-Z0-9])", value))
    require(priorities, f"missing priority class: {value}")
    return min(priorities, key=lambda item: int(item[1]))


def package_id_for(work_item_id: str) -> str:
    return "WP-" + "-".join(work_item_id.split("-")[1:-1])


def stable_rank(work_item_id: str, selector_band: int) -> int:
    item_number = int(work_item_id.rsplit("-", 1)[1])
    require(0 < item_number < 100, f"invalid Work Item sequence: {work_item_id}")
    return selector_band * 100 + item_number


def canonical_bytes(payload: dict[str, Any]) -> bytes:
    return (
        json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    ).encode("utf-8")


def build_registry() -> dict[str, Any]:
    roadmap_bytes = ROADMAP.read_bytes()
    roadmap_text = roadmap_bytes.decode("utf-8")
    package_inventory = parse_package_inventory(roadmap_text)
    work_item_fields = parse_work_items(roadmap_text)

    require(
        set(package_inventory) == set(PACKAGE_CONTROLS),
        "Package Inventory and typed Package controls must match exactly",
    )
    require(len(work_item_fields) == 115, "registry requires exactly 115 Work Items")

    packages: list[dict[str, Any]] = []
    for package_id, control in sorted(
        PACKAGE_CONTROLS.items(), key=lambda item: (item[1].selector_band, item[0])
    ):
        inventory = package_inventory[package_id]
        packages.append(
            {
                "authorityLock": control.authority_lock,
                "decision": "NO_GO" if control.release_class == "MIGRATION" else "STOP",
                "defaultExposure": control.default_exposure,
                "exitPackageDependencies": list(control.exit_dependencies),
                "id": package_id,
                "lifecycle": "PLANNED",
                "migrationGateRefs": list(control.migration_gate_refs),
                "name": inventory["name"],
                "priorityClass": priority_class(inventory["priority"]),
                "releaseClass": control.release_class,
                "roadmapLane": inventory["lane"],
                "selectorBand": control.selector_band,
                "startPackageDependencies": list(control.start_dependencies),
            }
        )

    work_items: list[dict[str, Any]] = []
    for work_item_id, fields in work_item_fields.items():
        package_id = package_id_for(work_item_id)
        require(package_id in PACKAGE_CONTROLS, f"unknown parent Package: {work_item_id}")
        control = PACKAGE_CONTROLS[package_id]
        dependencies = expand_work_item_dependencies(fields["Dependencies"])
        gates = applicable_gates(fields["Verification"] + " " + fields["External gates"])
        work_items.append(
            {
                "authorityLock": control.authority_lock,
                "decision": "NO_GO" if control.release_class == "MIGRATION" else "STOP",
                "dependencyNotesHash": dependency_notes_hash(fields["Dependencies"]),
                "directDependencies": list(dependencies),
                "executionOwner": "UNASSIGNED",
                "gateEvidence": {gate: "MISSING" for gate in gates},
                "id": work_item_id,
                "lifecycle": "PLANNED",
                "packageId": package_id,
                "priorityClass": priority_class(fields["Priority / lane"]),
                "releaseClass": control.release_class,
                "requiredGates": list(gates),
                "sourceFieldCount": len(fields),
                "stableRank": stable_rank(work_item_id, control.selector_band),
            }
        )
    work_items.sort(key=lambda item: (item["stableRank"], item["id"]))

    registry: dict[str, Any] = {
        "baseline": {
            "authorityLeases": {
                authority_lock: {"owner": "UNASSIGNED", "state": "UNHELD"}
                for authority_lock in AUTHORITY_LOCKS
            },
            "decision": {"coreAndMvpExtension": "STOP", "migration": "NO_GO"},
            "executionOwner": "UNASSIGNED",
            "gateEvidence": "MISSING",
            "implementationClaim": "NONE",
            "lifecycle": "PLANNED",
            "openIncidents": [],
        },
        "counts": {
            "packages": len(packages),
            "sourceFields": sum(item["sourceFieldCount"] for item in work_items),
            "workItems": len(work_items),
        },
        "enums": {
            "authorityLeaseState": list(AUTHORITY_LEASE_STATES),
            "authorityLock": list(AUTHORITY_LOCKS),
            "decision": list(DECISIONS),
            "defaultExposure": list(DEFAULT_EXPOSURES),
            "gate": list(GATES),
            "gateEvidence": list(GATE_EVIDENCE_STATES),
            "lifecycle": list(LIFECYCLES),
            "priorityClass": list(PRIORITY_CLASSES),
            "releaseClass": list(RELEASE_CLASSES),
        },
        "packages": packages,
        "schemaVersion": "dreamjourney.execution-registry.v1.1",
        "source": {
            "authority": "ROADMAP_WORK_ITEMS_PLUS_TYPED_PACKAGE_CONTROLS",
            "path": SOURCE_PATH,
            "sha256": sha256_bytes(roadmap_bytes),
        },
        "workItems": work_items,
    }
    validate_registry(registry)
    return registry


def assert_acyclic(edges: dict[str, set[str]], label: str) -> None:
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(node: str, path: tuple[str, ...]) -> None:
        if node in visiting:
            raise AssertionError(f"{label} cycle: {' -> '.join(path + (node,))}")
        if node in visited:
            return
        visiting.add(node)
        for dependency in sorted(edges.get(node, set())):
            visit(dependency, path + (node,))
        visiting.remove(node)
        visited.add(node)

    for node in sorted(edges):
        visit(node, ())


def package_milestone_edges(packages: list[dict[str, Any]]) -> dict[str, set[str]]:
    """Separate package start and exit milestones before checking the DAG."""
    edges: dict[str, set[str]] = {}
    for package in packages:
        package_id = package["id"]
        start_node = f"{package_id}:START"
        exit_node = f"{package_id}:EXIT"
        edges[start_node] = {
            f"{dependency}:START"
            for dependency in package["startPackageDependencies"]
        }
        edges[exit_node] = {start_node} | {
            f"{dependency}:EXIT"
            for dependency in package["exitPackageDependencies"]
        }
    return edges


def validate_registry(registry: dict[str, Any]) -> None:
    packages = registry["packages"]
    work_items = registry["workItems"]
    package_ids = [item["id"] for item in packages]
    work_item_ids = [item["id"] for item in work_items]

    require(len(package_ids) == len(set(package_ids)) == 13, "Package IDs must be unique")
    require(len(work_item_ids) == len(set(work_item_ids)) == 115, "Work Item IDs must be unique")
    require(registry["counts"] == {"packages": 13, "sourceFields": 1840, "workItems": 115}, "registry counts must be 13/115/1840")

    authority_locks = [item["authorityLock"] for item in packages]
    require(
        len(authority_locks) == len(set(authority_locks)) == len(AUTHORITY_LOCKS),
        "each Package must own one unique authority lock",
    )
    require(set(authority_locks) == set(AUTHORITY_LOCKS), "authority lock enum mismatch")

    mvp_extension_ids = {
        item["id"] for item in packages if item["releaseClass"] == "MVP_EXTENSION"
    }
    for package in packages:
        require(package["releaseClass"] in RELEASE_CLASSES, f"invalid releaseClass: {package['id']}")
        require(package["priorityClass"] in PRIORITY_CLASSES, f"invalid priorityClass: {package['id']}")
        require(package["lifecycle"] == "PLANNED", f"Package cannot claim implementation: {package['id']}")
        expected_decision = "NO_GO" if package["releaseClass"] == "MIGRATION" else "STOP"
        require(package["decision"] == expected_decision, f"unsafe Package decision: {package['id']}")
        start_dependencies = package["startPackageDependencies"]
        exit_dependencies = package["exitPackageDependencies"]
        require(
            len(start_dependencies) == len(set(start_dependencies)),
            f"duplicate Package start dependency: {package['id']}",
        )
        require(
            len(exit_dependencies) == len(set(exit_dependencies)),
            f"duplicate Package exit dependency: {package['id']}",
        )
        dependencies = start_dependencies + exit_dependencies
        require(package["id"] not in dependencies, f"self Package dependency: {package['id']}")
        require(set(dependencies) <= set(package_ids), f"unknown Package dependency: {package['id']}")
        if package["releaseClass"] == "CORE":
            require(
                not (set(package["startPackageDependencies"]) & mvp_extension_ids),
                f"Core Package cannot start from an MVP extension: {package['id']}",
            )
        if package["releaseClass"] in {"MVP_EXTENSION", "MIGRATION"}:
            require(package["defaultExposure"] == "DEFAULT_OFF", f"MVP extension/Migration must be default-off until its gates pass: {package['id']}")
        if package["releaseClass"] == "MIGRATION":
            require(package["authorityLock"] == "MIGRATION_EVIDENCE", "Migration may only own evidence")
        for gate_ref in package["migrationGateRefs"]:
            work_item_ref = gate_ref.split(":", 1)[0]
            require(work_item_ref in work_item_ids, f"unknown migration gate ref: {gate_ref}")
    assert_acyclic(package_milestone_edges(packages), "Package milestone dependency")

    s1_owner = next(item for item in packages if item["id"] == "WP-S1-01")
    require("WP-MIG-01" not in s1_owner["exitPackageDependencies"], "S1-01 cannot depend on the whole Migration Package")
    require(s1_owner["migrationGateRefs"] == ["WI-MIG-01-08:authorization"], "S1-01 migration authorization ref is required")

    ranks = [item["stableRank"] for item in work_items]
    require(len(ranks) == len(set(ranks)), "stableRank must be unique")
    work_item_edges: dict[str, set[str]] = {}
    for work_item in work_items:
        require(work_item["packageId"] in package_ids, f"unknown Work Item parent: {work_item['id']}")
        package = next(item for item in packages if item["id"] == work_item["packageId"])
        require(work_item["releaseClass"] == package["releaseClass"], f"releaseClass mismatch: {work_item['id']}")
        require(work_item["authorityLock"] == package["authorityLock"], f"authorityLock mismatch: {work_item['id']}")
        require(work_item["priorityClass"] in PRIORITY_CLASSES, f"priorityClass mismatch: {work_item['id']}")
        require(work_item["lifecycle"] == "PLANNED", f"Work Item cannot claim implementation: {work_item['id']}")
        expected_decision = "NO_GO" if work_item["releaseClass"] == "MIGRATION" else "STOP"
        require(work_item["decision"] == expected_decision, f"unsafe Work Item decision: {work_item['id']}")
        require(work_item["executionOwner"] == "UNASSIGNED", f"Work Item cannot assign itself: {work_item['id']}")
        require(work_item["sourceFieldCount"] == 16, f"source field count mismatch: {work_item['id']}")
        require(work_item["requiredGates"], f"requiredGates cannot be empty: {work_item['id']}")
        require(set(work_item["requiredGates"]) <= set(GATES), f"invalid gate: {work_item['id']}")
        require(
            work_item["gateEvidence"] == {
                gate: "MISSING" for gate in work_item["requiredGates"]
            },
            f"gate evidence must remain MISSING: {work_item['id']}",
        )
        dependencies = work_item["directDependencies"]
        require(len(dependencies) == len(set(dependencies)), f"duplicate Work Item dependency: {work_item['id']}")
        require(work_item["id"] not in dependencies, f"self Work Item dependency: {work_item['id']}")
        require(set(dependencies) <= set(work_item_ids), f"unknown Work Item dependency: {work_item['id']}")
        work_item_edges[work_item["id"]] = set(dependencies)
    assert_acyclic(work_item_edges, "Work Item dependency")


def run_self_test() -> None:
    gate_cases = {
        "G4产品 / G2真实 / G1 UIQA": ("G1", "G2", "G4"),
        "无G2/G3/G4；Xcode owner review": ("G0",),
        "G0 shadow；G2部署；无G3真实调用；G4产品": ("G0", "G2", "G4"),
        "G0 fixture；G3不适用；不依赖G2；无需G4；G3不发真实effect": ("G0",),
        "G2 schema；G3/G4尚不由schema关闭": ("G2", "G3", "G4"),
    }
    for source, expected in gate_cases.items():
        require(applicable_gates(source) == expected, f"gate parser failed: {source}")

    dependency_cases = {
        "WI-S0-01-02/03": ("WI-S0-01-02", "WI-S0-01-03"),
        "WI-S1-02-01..04": (
            "WI-S1-02-01",
            "WI-S1-02-02",
            "WI-S1-02-03",
            "WI-S1-02-04",
        ),
        "WI-S0-02-01/02、WI-S0-05-01..03": (
            "WI-S0-02-01",
            "WI-S0-02-02",
            "WI-S0-05-01",
            "WI-S0-05-02",
            "WI-S0-05-03",
        ),
        "start依赖WI-S1-01-01/02；exit依赖WI-S1-02-11": (
            "WI-S1-01-01",
            "WI-S1-01-02",
        ),
    }
    for source, expected in dependency_cases.items():
        require(
            expand_work_item_dependencies(source) == expected,
            f"dependency parser failed: {source}",
        )

    registry_a = build_registry()
    registry_b = build_registry()
    bytes_a = canonical_bytes(registry_a)
    bytes_b = canonical_bytes(registry_b)
    require(bytes_a == bytes_b, "same roadmap must produce identical canonical bytes")
    require(bytes_a.endswith(b"\n") and not bytes_a.endswith(b"\n\n"), "canonical JSON needs one trailing newline")
    decoded = json.loads(bytes_a.decode("utf-8"))
    require(canonical_bytes(decoded) == bytes_a, "JSON bytes are not canonical")
    require("generatedAt" not in registry_a, "runtime timestamps are forbidden")
    print(
        "Product V4 execution registry self-test passed: "
        "packages=13, work_items=115, fields=1840, "
        f"sha256={sha256_bytes(bytes_a)}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="Run parser, invariant, and canonical byte tests without writing output.",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Fail if the checked-in registry differs from regenerated canonical bytes.",
    )
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        return

    payload = canonical_bytes(build_registry())
    if args.check:
        require(OUTPUT.is_file(), f"missing generated registry: {OUTPUT.relative_to(ROOT)}")
        require(OUTPUT.read_bytes() == payload, "generated execution registry is stale")
        print(
            "Product V4 execution registry check passed: "
            f"sha256={sha256_bytes(payload)}"
        )
        return

    OUTPUT.write_bytes(payload)
    print(
        "Generated Product V4 execution registry: "
        f"{OUTPUT.relative_to(ROOT)} "
        f"sha256={sha256_bytes(payload)}"
    )


if __name__ == "__main__":
    main()
