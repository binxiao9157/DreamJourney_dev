#!/usr/bin/env python3
"""Build a value-free, source-only C00 current-state inventory report."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_BACKEND_ROOT = ROOT.parent / "DreamJourneyBackend"
MANIFEST = ROOT / "Scripts/QA/product-v4/current-state-inventory-v1.json"

MANIFEST_SCHEMA = "dreamjourney.current-state-inventory.v1"
REPORT_SCHEMA = "dreamjourney.current-state-inventory-report.v1"
REQUIRED_SURFACE_FIELDS = {
    "surfaceId",
    "plane",
    "packageId",
    "owner",
    "version",
    "reader",
    "writer",
    "effect",
    "credentialClass",
    "runtimeCount",
    "status",
    "sources",
}
EXPECTED_BACKEND_STATIC_FIELDS = {
    "migrationManifestCount",
    "migrationHead",
    "migrationHeadSha256",
    "routeAuditExpectedCount",
}
ALLOWED_REPOSITORIES = {"ios", "backend"}
ALLOWED_STATUSES = {
    "SOURCE_INVENTORIED",
    "HOST_UNVERIFIED_G2_REQUIRED",
    "EXTERNAL_G3_REQUIRED",
    "EXTERNAL_G4_REQUIRED",
    "EXTERNAL_G3_G4_REQUIRED",
}
FORBIDDEN_VALUE_KEYS = {
    "accessToken",
    "apiKey",
    "authorization",
    "credentialValue",
    "password",
    "privateKey",
    "rawCredential",
    "secret",
    "secretKey",
    "tokenValue",
}


class InventoryError(ValueError):
    """The static inventory cannot safely serve as a C00 freeze baseline."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise InventoryError(message)


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def value_free(value: Any, *, path: str = "$") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            require(isinstance(key, str), f"inventory key must be text at {path}")
            require(key not in FORBIDDEN_VALUE_KEYS, f"forbidden value field at {path}.{key}")
            value_free(child, path=f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            value_free(child, path=f"{path}[{index}]")


def source_file(repository_root: Path, relative_path: str) -> Path:
    path = Path(relative_path)
    require(not path.is_absolute(), f"inventory path must be repository-relative: {relative_path}")
    require(".." not in path.parts, f"inventory path may not escape repository: {relative_path}")
    resolved = repository_root / path
    require(resolved.is_file(), f"missing inventory source: {relative_path}")
    return resolved


def git_baseline(repository_root: Path) -> dict[str, object]:
    def command(*args: str) -> str:
        result = subprocess.run(
            ["git", *args],
            cwd=repository_root,
            text=True,
            capture_output=True,
            check=False,
        )
        require(result.returncode == 0, f"git baseline inspection failed for {repository_root.name}")
        return result.stdout.strip()

    return {
        "revision": command("rev-parse", "HEAD"),
        "dirty": bool(command("status", "--porcelain")),
    }


def load_manifest(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"missing inventory manifest: {path}")
    payload = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(payload, dict), "inventory manifest must be an object")
    value_free(payload)
    require(payload.get("schemaVersion") == MANIFEST_SCHEMA, "unsupported inventory manifest schema")
    require(payload.get("workItem") == "WI-MIG-01-01", "inventory must remain bound to WI-MIG-01-01")
    expected_backend_static = payload.get("expectedBackendStatic")
    require(isinstance(expected_backend_static, Mapping), "expected backend static baseline is missing")
    require(
        set(expected_backend_static) == EXPECTED_BACKEND_STATIC_FIELDS,
        "expected backend static baseline fields drifted",
    )
    require(
        isinstance(expected_backend_static["migrationManifestCount"], int)
        and expected_backend_static["migrationManifestCount"] > 0,
        "expected migration manifest count must be positive",
    )
    require(
        isinstance(expected_backend_static["routeAuditExpectedCount"], int)
        and expected_backend_static["routeAuditExpectedCount"] > 0,
        "expected route audit count must be positive",
    )
    require(
        isinstance(expected_backend_static["migrationHead"], str)
        and expected_backend_static["migrationHead"].endswith(".json"),
        "expected migration head must be a manifest name",
    )
    require(
        isinstance(expected_backend_static["migrationHeadSha256"], str)
        and re.fullmatch(r"[0-9a-f]{64}", expected_backend_static["migrationHeadSha256"]) is not None,
        "expected migration head hash must be sha256",
    )
    return payload


def validate_manifest(payload: Mapping[str, Any]) -> list[dict[str, Any]]:
    required_planes = payload.get("requiredPlanes")
    required_packages = payload.get("requiredPackageIds")
    surfaces = payload.get("surfaces")
    require(isinstance(required_planes, list) and required_planes, "required planes are missing")
    require(isinstance(required_packages, list) and required_packages, "required package IDs are missing")
    require(isinstance(surfaces, list) and surfaces, "inventory surfaces are missing")

    required_plane_set = set(required_planes)
    required_package_set = set(required_packages)
    require(len(required_plane_set) == len(required_planes), "required planes must be unique")
    require(len(required_package_set) == len(required_packages), "required packages must be unique")

    actual_surface_ids: set[str] = set()
    actual_packages: set[str] = set()
    actual_planes: set[str] = set()
    normalized: list[dict[str, Any]] = []
    for index, raw_surface in enumerate(surfaces):
        require(isinstance(raw_surface, dict), f"surface {index} must be an object")
        missing = REQUIRED_SURFACE_FIELDS - set(raw_surface)
        require(not missing, f"surface {index} is missing fields: {sorted(missing)}")
        surface = dict(raw_surface)
        surface_id = surface["surfaceId"]
        require(isinstance(surface_id, str) and surface_id.strip(), f"surface {index} needs a surfaceId")
        require(surface_id not in actual_surface_ids, f"duplicate surfaceId: {surface_id}")
        actual_surface_ids.add(surface_id)
        for field in REQUIRED_SURFACE_FIELDS - {"sources"}:
            require(isinstance(surface[field], str) and surface[field].strip(), f"{surface_id}.{field} must be text")
        require(surface["status"] in ALLOWED_STATUSES, f"{surface_id} has unsupported status")
        actual_packages.add(surface["packageId"])
        actual_planes.add(surface["plane"])

        sources = surface["sources"]
        require(isinstance(sources, list) and sources, f"{surface_id}.sources must be non-empty")
        for source_index, source in enumerate(sources):
            require(isinstance(source, dict), f"{surface_id}.sources[{source_index}] must be an object")
            repository = source.get("repository")
            path = source.get("path")
            markers = source.get("markers")
            require(repository in ALLOWED_REPOSITORIES, f"{surface_id} has unsupported source repository")
            require(isinstance(path, str) and path, f"{surface_id} source path is missing")
            require(isinstance(markers, list) and markers and all(isinstance(marker, str) and marker for marker in markers), f"{surface_id} source markers are missing")
        normalized.append(surface)

    require(actual_packages == required_package_set, "inventory must include exactly one owned surface for every V4 package")
    require(required_plane_set <= actual_planes, "inventory does not cover every required W/I/P/Q/O/V plane")
    return normalized


def source_descriptors(
    surfaces: list[dict[str, Any]],
    *,
    backend_root: Path,
) -> dict[str, list[dict[str, str]]]:
    roots = {"ios": ROOT, "backend": backend_root}
    output: dict[str, list[dict[str, str]]] = {}
    for surface in surfaces:
        descriptors: list[dict[str, str]] = []
        for source in surface["sources"]:
            repository = str(source["repository"])
            relative_path = str(source["path"])
            path = source_file(roots[repository], relative_path)
            text = path.read_text(encoding="utf-8")
            for marker in source["markers"]:
                require(marker in text, f"inventory marker drifted: {surface['surfaceId']} -> {relative_path} -> {marker}")
            descriptors.append(
                {
                    "repository": repository,
                    "path": relative_path,
                    "sha256": sha256(path.read_bytes()),
                }
            )
        output[str(surface["surfaceId"])] = descriptors
    return output


def backend_static_baseline(backend_root: Path) -> dict[str, object]:
    migration_dir = backend_root / "db/migrations"
    manifests = sorted(migration_dir.glob("*.json"))
    require(manifests, "backend migration manifests are missing")
    route_test = backend_root / "tests/test_route_ownership_registry.py"
    route_text = route_test.read_text(encoding="utf-8")
    match = re.search(r"self\.assertEqual\(len\(app_routes\),\s*(\d+)\)", route_text)
    require(match is not None, "backend route audit baseline marker is missing")
    expected_count = int(match.group(1))
    head = manifests[-1]
    return {
        "migrationManifestCount": len(manifests),
        "migrationHead": head.name,
        "migrationHeadSha256": sha256(head.read_bytes()),
        "routeAuditExpectedCount": expected_count,
    }


def build_report(
    manifest: Mapping[str, Any],
    surfaces: list[dict[str, Any]],
    descriptors: Mapping[str, list[dict[str, str]]],
    *,
    backend_root: Path,
    observed_at: str,
) -> dict[str, Any]:
    actual_backend_static = backend_static_baseline(backend_root)
    expected_backend_static = dict(manifest["expectedBackendStatic"])
    require(
        actual_backend_static == expected_backend_static,
        "backend static baseline drifted; refresh expectedBackendStatic before issuing a new C00 freeze",
    )
    report_surfaces: list[dict[str, Any]] = []
    status_counts: Counter[str] = Counter()
    plane_counts: Counter[str] = Counter()
    for surface in surfaces:
        surface_id = str(surface["surfaceId"])
        source_list = descriptors[surface_id]
        evidence_hash = sha256(canonical_json({"surface": surface, "sources": source_list}))
        report_surface = {
            key: surface[key]
            for key in (
                "surfaceId",
                "plane",
                "packageId",
                "owner",
                "version",
                "reader",
                "writer",
                "effect",
                "credentialClass",
                "runtimeCount",
                "status",
            )
        }
        report_surface["evidenceHash"] = evidence_hash
        report_surface["sourceFiles"] = source_list
        report_surfaces.append(report_surface)
        status_counts[str(surface["status"])] += 1
        plane_counts[str(surface["plane"])] += 1

    report = {
        "schemaVersion": REPORT_SCHEMA,
        "workItem": manifest["workItem"],
        "sourceOnly": True,
        "observedAt": observed_at,
        "baselines": {
            "ios": git_baseline(ROOT),
            "backend": git_baseline(backend_root),
            "backendStatic": actual_backend_static,
        },
        "summary": {
            "surfaceCount": len(report_surfaces),
            "packageCount": len({surface["packageId"] for surface in report_surfaces}),
            "planeCounts": dict(sorted(plane_counts.items())),
            "statusCounts": dict(sorted(status_counts.items())),
            "unknownSourceSurfaceCount": 0,
            "hostOrExternalVerificationRequiredCount": sum(
                1 for surface in report_surfaces if surface["status"] != "SOURCE_INVENTORIED"
            ),
        },
        "surfaces": report_surfaces,
        "limitations": [
            "This report is source-only and does not prove host timer state, backup restore, object storage, Provider execution, deployed client distribution, or production data parity.",
            "Credential values, tokens, passwords, raw request bodies, local absolute paths, and production identifiers are intentionally excluded.",
            "A new report must be generated after a source baseline or manifest change; source inventory never authorizes a migration or production cutover by itself."
        ],
    }
    report["inventoryHash"] = sha256(canonical_json(report))
    return report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--backend-root", type=Path, default=DEFAULT_BACKEND_ROOT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--observed-at", default=datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    backend_root = args.backend_root.resolve()
    require(backend_root.is_dir(), f"backend root is missing: {backend_root}")
    manifest = load_manifest(args.manifest)
    surfaces = validate_manifest(manifest)
    descriptors = source_descriptors(surfaces, backend_root=backend_root)
    report = build_report(
        manifest,
        surfaces,
        descriptors,
        backend_root=backend_root,
        observed_at=str(args.observed_at),
    )
    value_free(report)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(canonical_json(report))
    print(
        "Current-state inventory freeze passed: "
        f"surfaces={report['summary']['surfaceCount']} "
        f"packages={report['summary']['packageCount']} "
        f"sourceUnknown={report['summary']['unknownSourceSurfaceCount']} "
        f"report={args.output}"
    )


if __name__ == "__main__":
    main()
