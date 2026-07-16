#!/usr/bin/env python3
"""Guard WI-S0-04-01 connection-pool and request UoW boundaries."""

import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BACKEND = Path(
    os.environ.get("BACKEND_ROOT", str(ROOT.parent / "DreamJourneyBackend"))
).expanduser().resolve()


def read(relative_path: str) -> str:
    path = BACKEND / relative_path
    require(path.is_file(), f"backend file is missing: {relative_path}")
    return path.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    pool = read("app/db/pool.py")
    uow = read("app/db/uow.py")
    store = read("app/services/postgres_store.py")
    factory = read("app/services/store_factory.py")
    main_module = read("app/main.py")
    settings = read("app/core/config.py")
    requirements = read("requirements.txt")
    release = (ROOT / "Scripts/QA/prd-stitch-ui/run-release-regression.sh").read_text(
        encoding="utf-8"
    )

    require("class PsycopgConnectionPool" in pool, "psycopg pool adapter is missing")
    require("ConnectionPool(open=False" not in pool, "invalid positional pool contract")
    require("open=False" in pool and "check_connection" in pool, "pool open/check contract")
    require("class ConnectionPoolExhausted" in pool, "pool exhaustion contract")

    require("class DatabaseUnitOfWork" in uow, "database UoW is missing")
    for boundary in ("connection.commit()", "connection.rollback()", "pool.putconn(connection)"):
        require(boundary in uow, f"UoW boundary is missing: {boundary}")
    require("correlation_id" in uow and "command_id" in uow, "UoW trace identifiers")

    require("def _connect(" not in store, "legacy shared _connect returned")
    require("self._connection =" not in store, "legacy shared connection field returned")
    require("ContextVar" in store, "request context isolation is missing")
    require("request_unit_of_work" in store, "repository UoW adapter is missing")
    require("poolExhausted" in store or "pool_exhausted" in store, "pool failure metric")

    require("DB_POOL_MIN_SIZE" in settings, "pool min setting")
    require("DB_POOL_MAX_SIZE" in settings, "pool max setting")
    require("DB_POOL_TIMEOUT_SECONDS" in settings, "pool timeout setting")
    require("psycopg_pool==" in requirements, "psycopg_pool must be pinned")
    require("open_store(store, wait=True)" in factory, "startup must open the pool")
    require("def close_store" in factory, "pool shutdown helper")

    require("async def database_request_unit_of_work" in main_module, "HTTP UoW middleware")
    require("httpErrorResponse" in main_module, "HTTP error rollback contract")
    require("database_pool_exhausted" in main_module, "stable pool exhaustion response")
    require("X-DreamJourney-Correlation-Id" in main_module, "request correlation response")
    require("def shutdown()" in main_module and "close_store(store)" in main_module, "pool shutdown")
    require("databaseUnitOfWork" in main_module, "system-only UoW metrics")

    for script in (
        "scripts/backend-db-uow-postgres-smoke.py",
        "scripts/backend-db-uow-deployed-smoke.py",
        "scripts/run-backend-db-uow-postgres-smoke.sh",
        "scripts/run-backend-db-uow-deployed-smoke.sh",
    ):
        require((BACKEND / script).is_file(), f"database UoW smoke is missing: {script}")

    require("RUN_BACKEND_DB_UOW_SMOKE" in release, "release UoW gate switch")
    require("run-backend-db-uow-deployed-smoke.sh" in release, "release UoW gate command")

    print(
        "Product V4 database UoW check passed: pooled request transactions, "
        "fail-closed exhaustion, metrics, and deployed G2 scripts are guarded"
    )


if __name__ == "__main__":
    main()
