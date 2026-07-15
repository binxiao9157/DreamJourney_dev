#!/usr/bin/env python3
"""Verify WI-S0-03-01 credential inventory without persisting secret values."""

from __future__ import annotations

import json
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SCANNER = ROOT / "Scripts/QA/product-v4/credential-inventory-scanner.py"
POLICY = ROOT / "Scripts/QA/product-v4/credential-inventory-policy.json"
RUNNER = ROOT / "Scripts/QA/prd-stitch-ui/run-credential-inventory-scan.sh"
RELEASE = ROOT / "Scripts/QA/prd-stitch-ui/run-release-regression.sh"
PACKAGE_CHECK = ROOT / "Scripts/QA/prd-stitch-ui/release-qa-package-check.swift"

REQUIRED_FINDING_FIELDS = {
    "credentialId",
    "type",
    "owner",
    "scope",
    "locationCategory",
    "path",
    "line",
    "fingerprint",
    "version",
    "status",
    "lastObserved",
    "evidenceId",
    "containment",
    "replacementPath",
    "rotationAction",
    "rotationStatus",
}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def run_scanner(root: Path, output: Path, *, enforce: bool) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable,
        str(SCANNER),
        "--policy",
        str(POLICY),
        "--surface",
        f"SOURCE={root}",
        "--output",
        str(output),
        "--observed-at",
        "2026-07-15T00:00:00Z",
    ]
    if enforce:
        command.append("--enforce")
    return subprocess.run(command, text=True, capture_output=True, check=False)


def main() -> None:
    for path in (SCANNER, POLICY, RUNNER):
        require(path.is_file(), f"missing WI-S0-03-01 artifact: {path.relative_to(ROOT)}")

    policy = json.loads(POLICY.read_text(encoding="utf-8"))
    require(policy.get("schemaVersion") == "dreamjourney.credential-inventory-policy.v1", "policy schema drift")
    require(len(policy.get("credentialTypes", [])) >= 8, "credential taxonomy is incomplete")
    for entry in policy.get("allowlist", []):
        reviewers = entry.get("reviewedBy", [])
        require(len(set(reviewers)) >= 2, "allowlist entries require two distinct reviewers")
        require(entry.get("expiresAt"), "allowlist entries require expiry")
        require("value" not in entry, "allowlist must not persist credential values")

    secret_value = "credential-" + "A" * 48
    private_key_body = "B" * 96
    with tempfile.TemporaryDirectory(prefix="dj-credential-inventory-") as temporary:
        fixture_root = Path(temporary) / "fixture"
        fixture_root.mkdir()
        (fixture_root / "config.txt").write_text(
            "\n".join(
                [
                    f"VOLCENGINE_ACCESS_TOKEN={secret_value}",
                    "DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY",
                    "VOLCENGINE_APP_ID=8442000000",
                    "-----BEGIN PRIVATE KEY-----",
                    private_key_body,
                    "-----END PRIVATE KEY-----",
                ]
            ),
            encoding="utf-8",
        )
        (fixture_root / "references.swift").write_text(
            "let apiKey: String\nlet accessToken = config.accessToken\n",
            encoding="utf-8",
        )
        excluded = fixture_root / ".venv"
        excluded.mkdir()
        excluded_secret = "excluded-" + "C" * 48
        (excluded / "config.txt").write_text(
            f"BACKEND_API_TOKEN={excluded_secret}\n",
            encoding="utf-8",
        )
        binary_secret = "binary-" + "D" * 48
        (fixture_root / "fixture.bin").write_bytes(
            b"\x00\x01VOLCENGINE_ACCESS_TOKEN=" + binary_secret.encode("ascii")
        )
        output = Path(temporary) / "inventory.json"
        result = run_scanner(fixture_root, output, enforce=False)
        require(result.returncode == 0, f"inventory mode failed: {result.stderr}")
        require(output.is_file(), "scanner did not write inventory JSON")
        serialized = output.read_text(encoding="utf-8")
        require(secret_value not in serialized, "inventory persisted a secret value")
        require(private_key_body not in serialized, "inventory persisted private key material")
        require(excluded_secret not in serialized, "inventory persisted excluded dependency material")
        require(binary_secret not in serialized, "inventory persisted source binary material")
        require(secret_value not in result.stdout + result.stderr, "scanner printed a secret value")
        require(private_key_body not in result.stdout + result.stderr, "scanner printed private key material")

        report = json.loads(serialized)
        require(report.get("schemaVersion") == "dreamjourney.credential-inventory.v1", "report schema drift")
        require(report.get("containsCredentialValues") is False, "report must declare value-free output")
        findings = report.get("findings", [])
        require(findings, "secret fixture produced no findings")
        require(all(REQUIRED_FINDING_FIELDS <= set(item) for item in findings), "finding fields are incomplete")
        require(any(item["type"] == "VOLCENGINE_ACCESS_TOKEN" and item["status"] == "SECRET" for item in findings), "Volcengine token was not classified")
        require(any(item["type"] == "DEEPSEEK_API_KEY" and item["status"] == "PLACEHOLDER" for item in findings), "placeholder was not classified")
        require(any(item["type"] == "VOLCENGINE_APP_ID" and item["status"] == "PUBLIC_IDENTIFIER" for item in findings), "public identifier was not classified")
        require(any(item["type"] == "PRIVATE_KEY" and item["status"] == "SECRET" for item in findings), "private key was not classified")
        secret_fingerprint = hashlib.sha256(secret_value.encode("utf-8")).hexdigest()[:16]
        require(
            not any(item["type"] == "GENERIC_SECRET" and item["fingerprint"] == secret_fingerprint for item in findings),
            "specific credential matches must not be duplicated as generic findings",
        )
        require(any(item["status"] == "REFERENCE" for item in findings), "source references were not classified")
        require(all(len(item["fingerprint"]) == 16 for item in findings), "fingerprints must be truncated SHA-256")
        require(report.get("summary", {}).get("blockingFindings", 0) >= 2, "secret findings must block release enforcement")
        require(report.get("summary", {}).get("uniqueBlockingCredentials", 0) >= 2, "unique secret inventory is incomplete")
        require(
            all(item["rotationStatus"] and item["rotationAction"] for item in findings),
            "rotation status/action must be explicit for every finding",
        )

        enforced = run_scanner(fixture_root, Path(temporary) / "enforced.json", enforce=True)
        require(enforced.returncode == 2, "release enforcement must fail on secret findings")
        require(secret_value not in enforced.stdout + enforced.stderr, "enforcement printed a secret value")

        clean_root = Path(temporary) / "clean"
        clean_root.mkdir()
        (clean_root / "config.txt").write_text(
            "DEEPSEEK_API_KEY=YOUR_DEEPSEEK_API_KEY\n"
            "VOLCENGINE_APP_ID=8442000000\n"
            "BACKEND_API_TOKEN=test-token-for-contract\n"
            "apiKey=config.apiKey\n",
            encoding="utf-8",
        )
        clean = run_scanner(clean_root, Path(temporary) / "clean.json", enforce=True)
        require(clean.returncode == 0, f"placeholder/public identifiers should not block: {clean.stderr}")

    runner = RUNNER.read_text(encoding="utf-8")
    release = RELEASE.read_text(encoding="utf-8")
    package_check = PACKAGE_CHECK.read_text(encoding="utf-8")
    for token in ("SOURCE", "HISTORY", "APP", "IPA", "DSYM", "RESPONSE", "HEADER", "RUNTIME", "OSLOG", "QA", "BACKUP", "CONTAINER"):
        require(token in runner, f"runner does not inventory {token}")
    require("RUN_CREDENTIAL_INVENTORY_SCAN" in release, "release regression switch is missing")
    require("run-credential-inventory-scan.sh" in release, "release regression does not invoke scanner")
    require("RUN_CREDENTIAL_INVENTORY_SCAN" in package_check, "release package guard does not protect scanner integration")
    require("run-credential-inventory-scan.sh" in package_check, "release package guard does not protect scanner runner")

    print("Product V4 credential inventory check passed: value-free findings, enforcement, surfaces, release integration")


if __name__ == "__main__":
    main()
