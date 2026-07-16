#!/usr/bin/env python3
"""Guard WI-S0-04-02 versioned migrator and startup-DDL retirement."""

import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = Path(
    os.environ.get("BACKEND_ROOT", str(ROOT.parent / "DreamJourneyBackend"))
).expanduser().resolve()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def read(relative_path: str) -> str:
    path = BACKEND / relative_path
    require(path.is_file(), f"backend file is missing: {relative_path}")
    return path.read_text(encoding="utf-8")


def main() -> None:
    migrator = read("app/db/migrator.py")
    store = read("app/services/postgres_store.py")
    factory = read("app/services/store_factory.py")
    main_module = read("app/main.py")
    cli = read("scripts/migrate_db.py")
    baseline_sql = read("db/migrations/0001_existing_schema_baseline.sql")
    baseline_manifest = json.loads(
        read("db/migrations/0001_existing_schema_baseline.json")
    )
    dockerfile = read("Dockerfile")
    readme = read("README.md")

    for source_name, source in (
        ("PostgresStore", store),
        ("store_factory", factory),
        ("FastAPI main", main_module),
    ):
        require("def init_schema" not in source, f"{source_name} restored startup schema DDL")
        for ddl in ("CREATE TABLE", "ALTER TABLE", "CREATE INDEX", "CREATE TRIGGER"):
            require(ddl not in source, f"{source_name} contains implicit DDL: {ddl}")

    for contract in (
        "class PostgresMigrator",
        "schema_migrations",
        "checksum",
        "pg_advisory_lock",
        "MigrationChecksumMismatch",
        "MigrationHeadAhead",
        "ExistingSchemaRequiresAdoption",
        "ExistingSchemaMismatch",
        "execution_mode",
        "build_id",
    ):
        require(contract in migrator, f"migrator contract is missing: {contract}")
    require(
        migrator.index("set_config('statement_timeout'")
        < migrator.index("pg_advisory_lock"),
        "statement timeout must be configured before advisory lock acquisition",
    )

    require("--dry-run" in cli, "migration dry-run CLI")
    require("--apply" in cli, "migration apply CLI")
    require("--verify" in cli, "migration verify CLI")
    require("--adopt-existing-baseline" in cli, "explicit baseline adoption CLI")
    require("COPY db ./db" in dockerfile, "migration files must be packaged")

    require(baseline_manifest.get("version") == "0001", "baseline version")
    baseline = baseline_manifest.get("baseline") or {}
    require(len(baseline.get("columns") or {}) == 19, "baseline table inventory")
    require(
        "evidence_events_no_update" in (baseline.get("triggers") or []),
        "append-only trigger baseline",
    )
    require("-- migration:existing_schema_baseline" in baseline_sql, "baseline marker")
    sql_upper = baseline_sql.upper()
    for destructive in ("DROP TABLE", "TRUNCATE ", "ALTER TABLE", "DELETE FROM"):
        require(destructive not in sql_upper, f"destructive baseline SQL: {destructive}")

    for script in (
        "scripts/backend-db-migration-postgres-smoke.py",
        "scripts/run-backend-db-migration-postgres-smoke.sh",
    ):
        require((BACKEND / script).is_file(), f"migration G2 smoke is missing: {script}")
    require("API startup does not create or alter" in readme, "migration runbook")

    print(
        "Product V4 database migration check passed: startup DDL is zero and "
        "version/checksum/lock/ledger/baseline/G2 contracts are guarded"
    )


if __name__ == "__main__":
    main()
