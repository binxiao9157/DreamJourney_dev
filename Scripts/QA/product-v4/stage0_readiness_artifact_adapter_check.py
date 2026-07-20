#!/usr/bin/env python3
"""Contract checks for the Stage 0 readiness artifact adapter."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

from stage0_readiness_artifact_adapter import build_readiness_input
from stage0_strict_readiness import build_report, parse_timestamp


AS_OF = "2026-07-21T00:00:00Z"


def instant(value: str) -> datetime:
    parsed = parse_timestamp(value)
    assert parsed is not None
    return parsed


def backend_ready(*, status: str = "ready", component_status: str = "ready") -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "status": status,
        "evidenceTimestamp": "2026-07-20T23:59:00Z",
        "components": [
            {"component": "database", "status": component_status, "reason": "readWriteProbeSucceeded"},
            {"component": "schema", "status": component_status, "reason": "migrationHeadVerified"},
            {"component": "auth", "status": component_status, "reason": "requiredAuthConfigPresent"},
        ],
    }


def echo_manifest(*, status: str = "passed", expires_at: str = "2026-07-21T01:00:00Z") -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "manifestVersion": 1,
        "evidenceId": "echo_manifest_1234567890abcdef12345678",
        "manifestType": "echoQaEvidenceBundle",
        "sourceCommit": "0123456789abcdef",
        "commandId": "exportEchoQAEvidenceBundle",
        "sampleCount": 1,
        "artifactHashes": ["a" * 64],
        "ownerLeaseHash": "b" * 64,
        "issuedAt": "2026-07-20T23:59:00Z",
        "expiresAt": expires_at,
        "manifestStatus": status,
    }


class Stage0ReadinessArtifactAdapterTests(unittest.TestCase):
    def report(self, **kwargs: object) -> dict[str, object]:
        as_of = instant(AS_OF)
        payload = build_readiness_input(as_of=as_of, backend_ttl_seconds=900, **kwargs)
        return build_report(payload, as_of=as_of)

    def test_current_backend_and_echo_artifacts_can_pass_local_gate(self) -> None:
        backend = backend_ready()
        manifest = echo_manifest()
        report = self.report(
            backend_payload=backend,
            backend_artifact=json.dumps(backend).encode("utf-8"),
            echo_manifest_payload=[manifest],
            echo_manifest_artifact=json.dumps([manifest]).encode("utf-8"),
            require_backend_ready=True,
            require_echo_manifest=True,
        )
        self.assertTrue(report["completed"])
        self.assertEqual(report["status"], "passed")
        self.assertEqual(report["currentPassedRequiredGateCount"], 2)
        self.assertNotIn("0123456789abcdef", json.dumps(report))
        self.assertNotIn("b" * 64, json.dumps(report))

    def test_missing_or_expired_artifacts_fail_closed(self) -> None:
        missing = self.report(
            backend_payload=None,
            backend_artifact=None,
            echo_manifest_payload=None,
            echo_manifest_artifact=None,
            require_backend_ready=True,
            require_echo_manifest=True,
        )
        self.assertFalse(missing["completed"])
        self.assertEqual(missing["status"], "missing")

        manifest = echo_manifest(expires_at="2026-07-20T23:59:59Z")
        expired = self.report(
            backend_payload=backend_ready(),
            backend_artifact=b"backend",
            echo_manifest_payload=manifest,
            echo_manifest_artifact=b"manifest",
            require_backend_ready=True,
            require_echo_manifest=True,
        )
        self.assertFalse(expired["completed"])
        self.assertEqual(expired["status"], "expired")

    def test_unhealthy_backend_and_unverified_manifest_never_pass(self) -> None:
        backend = backend_ready(status="notReady", component_status="notReady")
        manifest = echo_manifest(status="legacyUnverified")
        report = self.report(
            backend_payload=backend,
            backend_artifact=json.dumps(backend).encode("utf-8"),
            echo_manifest_payload=manifest,
            echo_manifest_artifact=json.dumps(manifest).encode("utf-8"),
            require_backend_ready=True,
            require_echo_manifest=True,
        )
        self.assertFalse(report["completed"])
        self.assertEqual(report["status"], "failed")
        reasons = {item["reason"] for item in report["gateResults"]}
        self.assertIn("backendReadinessComponentNotReady", reasons)
        self.assertIn("echoManifestUnverified", reasons)

    def test_optional_artifacts_are_not_silently_counted_as_passed(self) -> None:
        report = self.report(
            backend_payload=None,
            backend_artifact=None,
            echo_manifest_payload=None,
            echo_manifest_artifact=None,
            require_backend_ready=False,
            require_echo_manifest=False,
        )
        self.assertFalse(report["completed"])
        self.assertEqual(report["status"], "unknown")
        self.assertEqual(report["requiredGateCount"], 0)

    def test_adapter_input_is_json_serializable_and_has_no_artifact_paths(self) -> None:
        backend = backend_ready()
        payload = build_readiness_input(
            backend_payload=backend,
            backend_artifact=b'{"secret":"do-not-export"}',
            echo_manifest_payload=None,
            echo_manifest_artifact=None,
            require_backend_ready=True,
            require_echo_manifest=False,
            as_of=instant(AS_OF),
            backend_ttl_seconds=900,
        )
        serialized = json.dumps(payload, ensure_ascii=False)
        self.assertNotIn("do-not-export", serialized)
        self.assertNotIn("path", serialized.lower())
        self.assertEqual(payload["schemaVersion"], "dreamjourney.stage0-readiness-input.v1")

    def test_shell_gate_writes_current_fixture_report(self) -> None:
        root = Path(__file__).resolve().parents[3]
        runner = root / "Scripts/QA/product-v4/run-stage0-readiness-artifact-gate.sh"
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary = Path(temporary_directory)
            backend_path = temporary / "backend-ready.json"
            manifest_path = temporary / "echo-manifest.json"
            output_root = temporary / "output"
            backend_path.write_text(json.dumps(backend_ready()), encoding="utf-8")
            manifest_path.write_text(json.dumps([echo_manifest()]), encoding="utf-8")
            environment = {
                **os.environ,
                "OUTPUT_ROOT": str(output_root),
                "RUN_ID": "fixture",
                "STAGE0_READINESS_AS_OF": AS_OF,
                "STAGE0_BACKEND_READY_FILE": str(backend_path),
                "STAGE0_ECHO_MANIFEST_PATH": str(manifest_path),
                "REQUIRE_STAGE0_BACKEND_READY": "1",
                "REQUIRE_STAGE0_ECHO_MANIFEST": "1",
                "STAGE0_READINESS_STRICT": "1",
            }
            completed = subprocess.run(
                ["bash", str(runner)],
                cwd=root,
                env=environment,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            report = json.loads((output_root / "fixture" / "readiness-report.json").read_text(encoding="utf-8"))
            self.assertTrue(report["completed"])
            self.assertEqual(report["status"], "passed")

    def test_shell_gate_fails_closed_when_required_artifacts_are_absent(self) -> None:
        root = Path(__file__).resolve().parents[3]
        runner = root / "Scripts/QA/product-v4/run-stage0-readiness-artifact-gate.sh"
        with tempfile.TemporaryDirectory() as temporary_directory:
            output_root = Path(temporary_directory) / "output"
            environment = {
                **os.environ,
                "OUTPUT_ROOT": str(output_root),
                "RUN_ID": "missing",
                "STAGE0_READINESS_AS_OF": AS_OF,
                "REQUIRE_STAGE0_BACKEND_READY": "1",
                "REQUIRE_STAGE0_ECHO_MANIFEST": "1",
                "STAGE0_READINESS_STRICT": "1",
            }
            completed = subprocess.run(
                ["bash", str(runner)],
                cwd=root,
                env=environment,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            report = json.loads((output_root / "missing" / "readiness-report.json").read_text(encoding="utf-8"))
            self.assertFalse(report["completed"])
            self.assertEqual(report["status"], "missing")


if __name__ == "__main__":
    unittest.main()
