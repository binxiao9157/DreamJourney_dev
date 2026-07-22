#!/usr/bin/env python3
"""Verify the WI-MIG-01-01 source-only current-state inventory freeze."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parents[3]
BACKEND_ROOT = ROOT.parent / "DreamJourneyBackend"
FREEZE = ROOT / "Scripts/QA/product-v4/current-state-inventory-freeze.py"
MANIFEST = ROOT / "Scripts/QA/product-v4/current-state-inventory-v1.json"
RUNNER = ROOT / "Scripts/QA/product-v4/run-current-state-inventory-freeze-gate.sh"

REQUIRED_PLANES = {"W", "I", "P", "Q", "O", "V"}
REQUIRED_PACKAGES = {
    "WP-S0-01", "WP-S0-02", "WP-S0-03", "WP-S0-04", "WP-S0-05", "WP-S0-06", "WP-S0-07",
    "WP-S1-01", "WP-S1-02", "WP-S1-03", "WP-S3-01", "WP-V0-01", "WP-MIG-01",
}
FORBIDDEN_VALUE_KEYS = {
    "accessToken", "apiKey", "authorization", "credentialValue", "password", "privateKey", "rawCredential", "secret", "secretKey", "tokenValue",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def assert_value_free(value: Any, *, path: str = "$") -> None:
    if isinstance(value, Mapping):
        for key, child in value.items():
            require(key not in FORBIDDEN_VALUE_KEYS, f"forbidden report field at {path}.{key}")
            assert_value_free(child, path=f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_value_free(child, path=f"{path}[{index}]")


def freeze(output: Path, *, manifest: Path = MANIFEST) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            str(FREEZE),
            "--manifest", str(manifest),
            "--backend-root", str(BACKEND_ROOT),
            "--output", str(output),
            "--observed-at", "2026-07-22T00:00:00Z",
        ],
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> None:
    for path in (FREEZE, MANIFEST, RUNNER):
        require(path.is_file(), f"missing current-state inventory artifact: {path.relative_to(ROOT)}")

    with tempfile.TemporaryDirectory(prefix="dj-current-state-inventory-") as temporary:
        temp = Path(temporary)
        first_path = temp / "first.json"
        second_path = temp / "second.json"
        first = freeze(first_path)
        second = freeze(second_path)
        require(first.returncode == 0, f"first freeze failed: {first.stderr}")
        require(second.returncode == 0, f"second freeze failed: {second.stderr}")
        require(first_path.read_bytes() == second_path.read_bytes(), "freeze output must be deterministic for one source baseline")

        report = json.loads(first_path.read_text(encoding="utf-8"))
        require(report.get("schemaVersion") == "dreamjourney.current-state-inventory-report.v1", "report schema drift")
        require(report.get("workItem") == "WI-MIG-01-01", "report work item drift")
        require(report.get("sourceOnly") is True, "C00 report must remain source-only")
        assert_value_free(report)
        serialized = first_path.read_text(encoding="utf-8")
        require(str(ROOT) not in serialized and str(BACKEND_ROOT) not in serialized, "report must not expose local absolute paths")

        summary = report.get("summary") or {}
        require(summary.get("surfaceCount") == 13, "C00 must inventory all 13 package surfaces")
        require(summary.get("packageCount") == 13, "C00 package coverage drifted")
        require(summary.get("unknownSourceSurfaceCount") == 0, "source inventory must not leave unknown surfaces")
        require(REQUIRED_PLANES <= set((summary.get("planeCounts") or {}).keys()), "C00 plane coverage is incomplete")
        surfaces = report.get("surfaces") or []
        require({surface.get("packageId") for surface in surfaces} == REQUIRED_PACKAGES, "package inventory set drifted")
        require(all(len(str(surface.get("evidenceHash") or "")) == 64 for surface in surfaces), "surface evidence hashes are incomplete")
        require(all(surface.get("sourceFiles") for surface in surfaces), "every surface needs source evidence")
        require(report.get("baselines", {}).get("backendStatic", {}).get("routeAuditExpectedCount") == 104, "route audit baseline drifted")
        require(report.get("baselines", {}).get("backendStatic", {}).get("migrationHead") == "0037_owner_truth_interview_confirmation_feature_constraint.json", "migration freeze head drifted")

        broken_manifest = temp / "broken.json"
        payload = json.loads(MANIFEST.read_text(encoding="utf-8"))
        payload["surfaces"][0]["sources"][0]["markers"] = ["missing-c00-marker"]
        broken_manifest.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
        broken = freeze(temp / "broken-report.json", manifest=broken_manifest)
        require(broken.returncode != 0, "marker drift must block a freeze report")
        require("missing-c00-marker" in broken.stderr, "marker drift must be actionable")

    runner = RUNNER.read_text(encoding="utf-8")
    require("current-state-inventory-freeze.py" in runner, "C00 runner must call the freeze generator")
    require("product-v4-current-state-inventory-check.py" in runner, "C00 runner must call the static check")
    print("Product V4 C00 current-state inventory check passed: 13 packages, W/I/P/Q/O/V covered")


if __name__ == "__main__":
    main()
