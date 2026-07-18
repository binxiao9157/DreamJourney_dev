# WI-S0-05-01C Legacy Account Delete Rights Adapter

Date: 2026-07-18

## Status

- Work item: `WI-S0-05-01`
- Sub-slice: `WI-S0-05-01C`
- Authority lock: `RIGHTS_DELETION`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / G0_VERIFIED / BACKEND_PUSHED`
- G2: `MISSING` (server deployment, migration, restart persistence, concurrent idempotency, and rollback smoke still require deployed Postgres)
- G4: `MISSING` (identity, legal deletion scope, backup/provider deletion evidence remain external)

## Delivered

The existing `POST /auth/delete` flow now records a redacted rights lifecycle without changing its product behavior:

- explicit `commandId` or `Idempotency-Key` is command-scoped per subject;
- legacy callers without a command id receive a compatibility-generated request id and are not falsely treated as idempotent;
- repeated explicit commands deduplicate after a completed deletion;
- reusing a command with a different `rightsScope` returns a 409 conflict;
- restore count is part of the lifecycle marker, so an old command cannot silently delete a restored account;
- account soft-delete completion records a module execution and append-only resource deletion receipt;
- responses expose only request id, status, contract version, and counts, while phone, command text, and payload remain out of the rights summary.

The existing two confirmations, 30-day restore window, one-time restore limit, session revocation, delegated grant revocation, and purge behavior remain in place.

## Commit

- `36265f8 feat(WI-S0-05-01): adapt account delete rights contract`

Backend baseline: `main@36265f8`, pushed to `origin/main`.

## Verification

```text
STORE_BACKEND=memory ... unittest tests.test_account_deletion_rights tests.test_core_services.AccountDeletionAPITests
4 tests passed

PYTHONPATH=. ... unittest tests.test_data_rights_contract tests.test_data_rights_store tests.test_db_migrator
21 tests passed

PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
538 tests passed; credential boundary, FastAPI, knowledge, backup contract and diff checks passed
```

## Gate / next action

Do not advance to `WI-S0-05-02` until G2 is closed. The next action is to deploy `main@36265f8` with migration `0006_rights_requests`, restart the backend, and run the Postgres rights lifecycle smoke including concurrent same-command requests, command conflict, rollback, restart persistence, and cross-account denial.
