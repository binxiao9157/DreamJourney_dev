#!/usr/bin/env python3
"""Static guard for the inert Owner Truth V1 foundation."""

from __future__ import annotations

import json
import sys
from pathlib import Path


IOS_ROOT = Path(__file__).resolve().parents[3]
BACKEND_ROOT = IOS_ROOT.parent / "DreamJourneyBackend"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    migration_sql = BACKEND_ROOT / "db/migrations/0011_owner_truth_core.sql"
    migration_manifest = migration_sql.with_suffix(".json")
    contracts = IOS_ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthContracts.swift"
    repository = IOS_ROOT / "DreamJourney/Sources/Domain/OwnerTruth/OwnerTruthRepository.swift"

    for path in (migration_sql, migration_manifest, contracts, repository):
        require(path.is_file(), f"missing required Owner Truth artifact: {path}")

    metadata = json.loads(migration_manifest.read_text(encoding="utf-8"))
    require(metadata["phase"] == "expand", "owner truth migration must remain expand")
    require(metadata["compatibility"] == "additive", "owner truth migration must remain additive")
    require(metadata["releaseFlags"] == {"ownerTruthV1Read": False, "ownerTruthV1Write": False}, "owner truth flags must default off")

    sql = migration_sql.read_text(encoding="utf-8")
    require("CREATE SCHEMA IF NOT EXISTS owner_truth" in sql, "owner truth must remain namespaced")
    require("ALTER TABLE memories" not in sql, "legacy public memories must not be mutated")
    require("owner_truth_memory_versions_one_current" in sql, "current version guard missing")
    require("owner_truth_memory_relations_no_cycle" in sql, "relation cycle guard missing")

    contracts_source = contracts.read_text(encoding="utf-8")
    for value in ("case experience", "case knowledge", "case emotion"):
        require(value in contracts_source, f"missing memory kind: {value}")
    require("protocol OwnerTruthReadRepository" in repository.read_text(encoding="utf-8"), "read repository port missing")

    print("Owner Truth V1 static contract check passed")


if __name__ == "__main__":
    try:
        main()
    except AssertionError as exc:
        print(f"Owner Truth V1 static contract check failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
