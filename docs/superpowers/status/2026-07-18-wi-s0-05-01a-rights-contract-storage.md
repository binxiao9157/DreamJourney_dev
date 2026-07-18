# WI-S0-05-01A Rights Request Contract and Storage Schema

Date: 2026-07-18

## Status

- Work item: `WI-S0-05-01`
- Sub-slice: `WI-S0-05-01A`
- Authority lock: `RIGHTS_DELETION`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / G0_VERIFIED`
- G2: `MISSING` (backend commit is not pushed, deployed, or verified on Postgres)
- G4: `MISSING` (identity, legal deletion scope, backup/provider deletion evidence remain external)

## Delivered

Backend `main` now contains:

- `app/services/data_rights_contract.py`
  - scoped command idempotency
  - explicit command payload conflict
  - required identity proof presence
  - module execution outcomes: `pending`, `completed`, `partial`, `unsupported`, `failed`
  - non-boolean aggregate request state
  - redacted public receipt using hashes only
- `db/migrations/0006_rights_requests.sql`
  - additive `rights_requests`
  - additive `rights_executions`
  - append-only `resource_deletion_receipts`
  - subject/command uniqueness and request indexes
- `tests/test_data_rights_contract.py`
- migration manifest coverage in `tests/test_db_migrator.py`

The contract layer is intentionally independent from FastAPI and both stores. It does not change `/auth/delete`, `/auth/restore`, or purge behavior yet.

## Commits

- `4d37450 test(WI-S0-05-01): add data rights contract G0`
- `aa949e8 feat(WI-S0-05-01): add rights request storage contract`

Backend baseline after this sub-slice: `main@aa949e8`; `origin/main` remains `32a081f`.

## Verification

```text
PYTHONPATH=. .venv/bin/python -m unittest tests.test_data_rights_contract tests.test_db_migrator
19 tests passed

STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest discover tests
534 tests passed

git diff --check
PASS

load_migrations(default_migrations_dir())
head=0006 rights_requests
PASS
```

## Next slice

`WI-S0-05-01B` should add InMemoryStore/PostgresStore persistence methods and a narrow internal/service contract before adapting the legacy `/auth/delete` route. It must preserve existing confirmation, error, session revocation, delegated-access revocation, restore, and purge behavior. Do not claim G2 until migration, restart persistence, concurrent idempotency, rollback, and cross-account Postgres smoke pass.
