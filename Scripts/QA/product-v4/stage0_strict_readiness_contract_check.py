#!/usr/bin/env python3
"""Contract tests for the fail-closed Stage 0 readiness evaluator."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from stage0_strict_readiness import INPUT_SCHEMA_VERSION, build_report, parse_timestamp


ROOT = Path(__file__).resolve().parents[3]
EVALUATOR = ROOT / "Scripts/QA/product-v4/stage0_strict_readiness.py"
RUNNER = ROOT / "Scripts/QA/product-v4/run-stage0-strict-readiness-gate.sh"
RELEASE = ROOT / "Scripts/QA/prd-stitch-ui/run-release-regression.sh"
RELEASE_PACKAGE = ROOT / "Scripts/QA/prd-stitch-ui/release-qa-package-check.swift"
AS_OF = "2026-07-21T00:00:00Z"


def gate(
    gate_id: str,
    *,
    status: str = "passed",
    evidence_id: str | None = "evidence.g0.current",
    checked_at: str | None = "2026-07-20T23:59:00Z",
    expires_at: str | None = "2026-07-21T01:00:00Z",
    required: bool = True,
    applicability: str = "applicable",
    reason: str = "localContractPassed",
) -> dict[str, object]:
    return {
        "gate": gate_id,
        "applicability": applicability,
        "required": required,
        "status": status,
        "evidenceId": evidence_id,
        "reason": reason,
        "checkedAt": checked_at,
        "expiresAt": expires_at,
    }


def report_for(*items: dict[str, object]) -> dict[str, object]:
    as_of = parse_timestamp(AS_OF)
    assert as_of is not None
    return build_report(
        {"schemaVersion": INPUT_SCHEMA_VERSION, "gateResults": list(items)},
        as_of=as_of,
    )


class Stage0StrictReadinessContractTests(unittest.TestCase):
    def test_all_current_required_gates_complete(self) -> None:
        report = report_for(gate("stage0.g0"), gate("stage0.g2", evidence_id="evidence.g2.current"))
        self.assertTrue(report["completed"])
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["currentPassedRequiredGateCount"], 2)
        self.assertIsNone(report["nextAction"])

    def test_skipped_is_not_run_and_never_passes(self) -> None:
        report = report_for(gate("stage0.g2", status="skipped"))
        self.assertFalse(report["completed"])
        self.assertEqual(report["status"], "notRun")
        result = report["gateResults"][0]
        self.assertEqual(result["status"], "notRun")
        self.assertEqual(result["reason"], "skippedIsNotPass")
        self.assertEqual(report["nextAction"]["actionCode"], "runRequiredGate")

    def test_missing_or_expired_evidence_is_not_current(self) -> None:
        missing = report_for(gate("stage0.g2", evidence_id=None))
        self.assertFalse(missing["completed"])
        self.assertEqual(missing["status"], "missing")
        self.assertEqual(missing["nextAction"]["actionCode"], "attachRequiredEvidence")

        expired = report_for(gate("stage0.g2", expires_at="2026-07-20T23:59:59Z"))
        self.assertFalse(expired["completed"])
        self.assertEqual(expired["status"], "expired")
        self.assertEqual(expired["nextAction"]["actionCode"], "reissueEvidence")

    def test_not_applicable_gate_does_not_hide_a_required_failure(self) -> None:
        report = report_for(
            gate("stage0.g0"),
            gate(
                "stage0.external",
                status="notApplicable",
                applicability="notApplicable",
                evidence_id=None,
                checked_at=None,
                expires_at=None,
                reason="notApplicable",
            ),
            gate("stage0.g2", status="blocked", reason="externalProviderReceiptMissing"),
        )
        self.assertFalse(report["completed"])
        self.assertEqual(report["status"], "blocked")
        self.assertEqual(report["requiredGateCount"], 2)
        self.assertEqual(report["nextAction"]["gate"], "stage0.g2")

    def test_duplicate_and_unstructured_input_fail_closed_without_echoing_text(self) -> None:
        duplicate = report_for(gate("stage0.g0"), gate("stage0.g0", evidence_id="evidence.g0.second"))
        self.assertFalse(duplicate["completed"])
        self.assertEqual(duplicate["status"], "unknown")
        self.assertTrue(all(item["reason"] == "duplicateGateResult" for item in duplicate["gateResults"]))

        invalid_reason = report_for(gate("stage0.g1", reason="raw user text is not permitted"))
        self.assertFalse(invalid_reason["completed"])
        serialized = json.dumps(invalid_reason, ensure_ascii=False)
        self.assertNotIn("raw user text is not permitted", serialized)
        self.assertEqual(invalid_reason["status"], "unknown")

    def test_schema_or_shape_mismatch_cannot_pass(self) -> None:
        as_of = parse_timestamp(AS_OF)
        assert as_of is not None
        malformed = build_report(
            {
                "schemaVersion": "untrusted schema value with spaces",
                "gateResults": [gate("stage0.g0")],
            },
            as_of=as_of,
        )
        self.assertFalse(malformed["completed"])
        self.assertEqual(malformed["status"], "unknown")
        self.assertEqual(malformed["inputSchemaVersion"], "unknown")
        self.assertNotIn("untrusted schema value with spaces", json.dumps(malformed, ensure_ascii=False))

        missing_shape = build_report({"schemaVersion": INPUT_SCHEMA_VERSION}, as_of=as_of)
        self.assertFalse(missing_shape["completed"])
        self.assertEqual(missing_shape["status"], "missing")
        self.assertEqual(missing_shape["nextAction"]["gate"], "stage0.inputShape")

    def test_cli_strict_exit_and_release_wiring(self) -> None:
        with tempfile.TemporaryDirectory(prefix="dj-stage0-readiness-") as directory:
            root = Path(directory)
            input_path = root / "input.json"
            output_path = root / "result.json"
            input_path.write_text(
                json.dumps(
                    {"schemaVersion": INPUT_SCHEMA_VERSION, "gateResults": [gate("stage0.g2", status="skipped")]},
                    ensure_ascii=False,
                ),
                encoding="utf-8",
            )
            completed = subprocess.run(
                [
                    sys.executable,
                    str(EVALUATOR),
                    "--input",
                    str(input_path),
                    "--output",
                    str(output_path),
                    "--as-of",
                    AS_OF,
                    "--strict",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertTrue(output_path.is_file())
            self.assertEqual(json.loads(output_path.read_text(encoding="utf-8"))["status"], "notRun")

        self.assertTrue(RUNNER.is_file())
        self.assertIn("RUN_STAGE0_STRICT_READINESS_GATE", RELEASE.read_text(encoding="utf-8"))
        self.assertIn("run-stage0-strict-readiness-gate.sh", RELEASE.read_text(encoding="utf-8"))
        package = RELEASE_PACKAGE.read_text(encoding="utf-8")
        self.assertIn("stage0_strict_readiness.py", package)
        self.assertIn("stage0_strict_readiness_contract_check.py", package)


if __name__ == "__main__":
    unittest.main(verbosity=2)
