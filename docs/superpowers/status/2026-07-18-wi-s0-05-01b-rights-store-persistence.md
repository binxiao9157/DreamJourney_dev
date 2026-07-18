# WI-S0-05-01B Rights Store Persistence

Date: 2026-07-18

## Status

- Work item: `WI-S0-05-01`
- Sub-slice: `WI-S0-05-01B`
- Authority lock: `RIGHTS_DELETION`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / G0_VERIFIED`
- G2: `MISSING` (the backend commit is pushed, but migration/restart/concurrency/rollback smoke has not run against deployed Postgres)
- G4: `MISSING` (identity, legal deletion scope, backup/provider deletion evidence remain external)

## Delivered

Backend `main` now contains the persistence boundary for the rights contract:

- `InMemoryStore`
  - request creation and command-scoped idempotency
  - per-module execution attempts and aggregate status
  - append-only deletion receipt deduplication/conflict handling
  - redacted request summary
- `PostgresStore`
  - request/execution/receipt methods wrapped in the existing unit-of-work boundary
  - `FOR UPDATE` locking for request and execution updates
  - unique command/request and receipt conflict boundaries
  - append-only receipt verification
- `0006_rights_requests` includes the three additive tables and the execution evidence hash
- store contract tests cover in-memory behavior and source-level Postgres safety assertions

The legacy `/auth/delete`, `/auth/restore`, and purge route behavior is intentionally unchanged. Route/service adaptation is the next sub-slice.

## Commits

- `4d37450 test(WI-S0-05-01): add data rights contract G0`
- `aa949e8 feat(WI-S0-05-01): add rights request storage contract`
- `27ffd59 feat(WI-S0-05-01): persist rights execution receipts`

Backend baseline after this sub-slice: `main@27ffd59`, pushed to `origin/main`.

## Verification

```text
PYTHONPATH=. .venv/bin/python -m unittest tests.test_data_rights_contract tests.test_data_rights_store tests.test_db_migrator
21 tests passed

STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest discover tests
536 tests passed

PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
PASS: full backend suite, credential boundary smoke, py_compile, voice clone smoke,
      FastAPI smoke, knowledge smokes, backup contract smoke, git diff --check
```

## Next slice

`WI-S0-05-01C` should add a narrow internal/service adapter and integrate the legacy `/auth/delete` path without changing its existing confirmation, error, session revocation, delegated-access revocation, restore, or purge behavior. It must preserve redacted responses and add route-level idempotency/conflict tests before any claim of G2.
