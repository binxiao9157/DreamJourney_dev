#!/usr/bin/env python3
"""Guard WI-S0-04-03 liveness and schema/auth readiness contracts."""

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
    main_module = read(BACKEND / "app/main.py")
    readiness = read(BACKEND / "app/services/readiness.py")
    database_probe = read(BACKEND / "app/db/readiness.py")
    migrator = read(BACKEND / "app/db/migrator.py")
    store = read(BACKEND / "app/services/postgres_store.py")
    routes = read(BACKEND / "app/services/route_ownership.py")
    route_authentication = read(BACKEND / "app/services/route_authentication.py")
    compose = read(BACKEND / "docker-compose.yml")
    tests = read(BACKEND / "tests/test_readiness.py")
    verify = read(BACKEND / "scripts/verify_backend.sh")
    release = read(ROOT / "Scripts/QA/prd-stitch-ui/run-release-regression.sh")

    for endpoint in ('@app.get("/live")', '@app.get("/ready")', '"deprecated": True'):
        require(endpoint in main_module, f"infrastructure endpoint contract: {endpoint}")
    require(
        'INFRASTRUCTURE_PATHS = frozenset({"/health", "/live", "/ready"})'
        in main_module,
        "infrastructure bypass inventory",
    )
    require(
        "ROUTE_AUTHENTICATION_POLICY.evaluate(" in main_module,
        "infrastructure probes must pass through the typed route-authentication policy",
    )
    require(
        "validate_route_authentication_startup(" in main_module,
        "route-authentication inventory must be validated before readiness is served",
    )
    require(
        "routeNotClassified" in route_authentication,
        "unclassified routes must fail closed",
    )
    require(
        "request.url.path in DATABASE_TRANSACTION_BYPASS_PATHS" in main_module,
        "business UoW must use the explicit transaction bypass inventory",
    )
    require("status_code=200 if payload[\"status\"] == \"ready\" else 503" in main_module, "readiness HTTP gate")

    for component in ('"database"', '"schema"', '"auth"'):
        require(component in readiness, f"required readiness component: {component}")
    for reason in (
        "databasePoolExhausted",
        "databaseProbeFailed",
        "migrationChecksumMismatch",
        "requiredAuthConfigMissing",
        "requiredAuthConfigInvalid",
    ):
        require(reason in readiness or reason in database_probe, f"machine-safe failure reason: {reason}")
    for provider in ("deepseek", "volcengine", "tencent"):
        require(provider not in readiness.lower(), f"optional provider must not gate base readiness: {provider}")

    for boundary in (
        "CREATE TEMP TABLE dreamjourney_readiness_probe",
        "ON COMMIT DROP",
        "self._rollback(connection)",
        "set_config('statement_timeout'",
        "pool.putconn(connection)",
    ):
        require(boundary in database_probe, f"rollback-only database probe boundary: {boundary}")
    require("def verify_connection" in migrator, "pooled migration verifier")
    require("def readiness_probe" in store, "PostgresStore readiness adapter")
    require("schema_verifier=migrator.verify_connection" in store, "shared migration verifier")

    require('"/health", public, "publicHealth"' in routes, "public health route inventory")
    require('"/live", public, "publicLiveness"' in routes, "public liveness route inventory")
    require('"/ready", public, "publicReadiness"' in routes, "public readiness route inventory")
    require("127.0.0.1:8080/ready" in compose, "Docker readiness healthcheck")
    require("backend-readiness-postgres-smoke.py" in verify, "backend verification script inventory")
    for script in (
        "scripts/backend-readiness-postgres-smoke.py",
        "scripts/backend-readiness-deployed-smoke.py",
        "scripts/run-backend-readiness-postgres-smoke.sh",
        "scripts/run-backend-readiness-deployed-smoke.sh",
    ):
        require((BACKEND / script).is_file(), f"readiness smoke is missing: {script}")

    for scenario in (
        "test_missing_required_auth_config_fails_closed_but_optional_providers_do_not",
        "test_pool_and_schema_failures_are_machine_safe_and_fail_closed",
        "test_every_evaluation_uses_a_fresh_evidence_timestamp",
        "test_read_only_and_checksum_mismatch_are_typed_failures",
        "test_not_ready_returns_503_without_business_uow_or_credentials",
    ):
        require(scenario in tests, f"readiness test scenario: {scenario}")

    require("RUN_BACKEND_READINESS_SMOKE" in release, "release readiness switch")
    require("run-backend-readiness-deployed-smoke.sh" in release, "release readiness command")
    print(
        "Product V4 readiness check passed: /live, /ready, rollback-only DB probe, "
        "migration/auth fail-closed behavior, Docker gate, and G2 smokes are guarded"
    )


if __name__ == "__main__":
    main()
