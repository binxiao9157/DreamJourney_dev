#!/usr/bin/env python3
"""Guard WI-S0-04-04 verified Postgres backup contracts."""

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = Path(
    os.environ.get("BACKEND_ROOT", str(ROOT.parent / "DreamJourneyBackend"))
).resolve()


def read(path: Path) -> str:
    if not path.is_file():
        raise AssertionError(f"required file is missing: {path}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    model = read(BACKEND / "app/db/backup.py")
    backup = read(BACKEND / "scripts/db/backup_postgres.sh")
    verifier = read(BACKEND / "scripts/db/verify_backup_manifest.py")
    latest = read(BACKEND / "scripts/db/verify_latest_backup.py")
    retention = read(BACKEND / "scripts/db/audit_backup_retention.py")
    deployed = read(BACKEND / "scripts/db/backup-deployed-smoke.py")
    backup_service = read(BACKEND / "deploy/systemd/dreamjourney-db-backup.service")
    backup_timer = read(BACKEND / "deploy/systemd/dreamjourney-db-backup.timer")
    retention_service = read(
        BACKEND / "deploy/systemd/dreamjourney-db-backup-retention-audit.service"
    )
    retention_timer = read(
        BACKEND / "deploy/systemd/dreamjourney-db-backup-retention-audit.timer"
    )
    tests = read(BACKEND / "tests/test_backup_manifest.py")
    integration = read(BACKEND / "scripts/db/backup-postgres-smoke.py")
    runbook = read(BACKEND / "docs/backend/2026-07-16-postgres-backup-operations.md")
    release = read(ROOT / "Scripts/QA/prd-stitch-ui/run-release-regression.sh")

    for field in (
        '"backupId"',
        '"createdAt"',
        '"schemaHead"',
        '"lsn"',
        '"checksum"',
        '"size"',
        '"encryptionRef"',
        '"retentionClass"',
        '"status"',
    ):
        require(field in model, f"backup manifest field: {field}")
    for boundary in (
        "write_manifest_atomic",
        "artifactChecksumMismatch",
        "artifactSizeMismatch",
        "backupExpired",
        "backupStale",
        '"automaticDeletion": False',
        '"action": "auditOnly"',
    ):
        require(boundary in model, f"backup model safety boundary: {boundary}")

    for command in (
        "pg_dump",
        "--format=custom",
        "enc -aes-256-cbc -pbkdf2 -salt",
        "pg_restore --list",
        "BACKUP_MIN_FREE_BYTES",
        "backupInterrupted",
        "insufficientSpace",
        ".partial",
        ".backup.lock.d",
    ):
        require(command in backup, f"backup execution contract: {command}")
    require('BACKUP_ALLOW_UNENCRYPTED:-0' in backup, "encryption must fail closed by default")
    require("rm -rf" not in backup, "backup script must not recursively delete")
    require("--max-age-hours" in verifier, "manifest freshness option")
    require("noCurrentVerifiedBackup" in latest, "latest verified backup gate")
    require("plan_backup_retention" in retention, "retention must use the audit-only model")
    require("unlink(" not in retention and "os.remove(" not in retention, "retention CLI must not delete artifacts")

    for evidence in (
        '"verifiedCurrentBackupCount"',
        '"encryptedArtifacts"',
        '"freshnessGate"',
        '"retentionAction"',
        '"alertReceiptPresent"',
        '"timerEnabled"',
    ):
        require(evidence in deployed, f"deployed backup evidence: {evidence}")

    require("OnFailure=dreamjourney-db-backup-alert@database-backup.service" in backup_service, "backup failure owner wiring")
    require("Persistent=true" in backup_timer, "persistent daily backup timer")
    require("OnCalendar=*-*-* 03:15:00" in backup_timer, "daily backup schedule")
    require("OnFailure=dreamjourney-db-backup-alert@retention-audit.service" in retention_service, "retention failure owner wiring")
    require("Persistent=true" in retention_timer, "persistent retention audit timer")

    for scenario in (
        "test_corruption_wrong_schema_and_expiry_fail_closed",
        "test_failed_manifest_never_claims_a_verified_artifact",
        "test_retention_plan_never_removes_last_valid_backup",
        "test_manifest_rejects_missing_encryption_reference_and_unsafe_identity",
    ):
        require(scenario in tests, f"backup unit scenario: {scenario}")
    for result in (
        '"consecutiveVerifiedBackups": 2',
        '"encryptedArchiveAccess": True',
        '"checksumCorruptionFailClosed": True',
        '"insufficientSpaceReceipt": True',
        '"interruptionReceipt": True',
        '"alertReceipt": True',
        '"freshnessGate": True',
        '"retentionAuditOnly": True',
    ):
        require(result in integration, f"backup integration scenario: {result}")

    for boundary in (
        "独立于 Compose volume",
        "backup 成功不等于 restore 成功",
        "automaticDeletion=false",
        "off-host storage",
        "Privacy/Legal retention",
    ):
        require(boundary in runbook, f"backup runbook boundary: {boundary}")
    require("product-v4-db-backup-check.py" in release, "release backup static gate")

    print(
        "Product V4 database backup check passed: encrypted custom-format backups, "
        "value-free manifests, freshness, failure receipts, timers, alerts, and "
        "audit-only retention are guarded"
    )


if __name__ == "__main__":
    main()
