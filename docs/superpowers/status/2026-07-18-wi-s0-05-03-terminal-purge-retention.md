# WI-S0-05-03 Restore, Terminal Purge and Retention-Hold Semantics

Date: 2026-07-18

## Status

- Work item: `WI-S0-05-03`
- Authority lock: `RIGHTS_DELETION`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / BACKEND_DEPLOYED / G0_G2_POSTGRES_VERIFIED / G4_EXTERNAL_OPEN`
- G0: `PASS` for deterministic lifecycle state, route contract, migration contract and negative coverage.
- G2: `PASS` for backend `main@1e743a1`, migration `0009` and isolated deployed Postgres smoke.
- G4: `EXTERNAL_OPEN`. This work does not claim that strong identity proof, legal retention policy, provider deletion or backup physical deletion have been approved or completed.

## Delivered

- Shared fail-closed state rules now govern both memory and Postgres stores:
  - generic upsert cannot reactivate `softDeleted` or `purged` accounts;
  - restore is allowed at the exact `restoreDeadline`, denied after it, and limited by persisted `restoreCount` / `restoreLimit`;
  - malformed retention metadata blocks physical purge;
  - active retention holds block purge, while explicitly `released` holds permit it.
- `POST /auth/purge-expired-deletions` is machine-only and no longer accepts a client-provided cutoff. It uses the server clock, returns only count/status metadata, and does not return tombstone items.
- Account deletion stores the rights request identifier only until final purge. Final purge clears the `users.phone` column and payload phone/nickname, preserves only a minimal tombstone, and prevents generic reactivation.
- Migration `0009_account_purge_receipts` adds an append-only, redacted terminal receipt table. The receipt retains subject/request hashes, lifecycle timestamps, restore count and receipt hash; it does not store the phone or raw user ID.
- A new deployed smoke runs inside the API container against a disposable `dj_terminal_purge_smoke_*` database. It verifies the full state-machine boundary without mutating production business data.

## Commit and Deployment

- Backend: `1e743a1 feat(rights): harden terminal account purge lifecycle`
- Remote: pushed to `origin/main`.
- Server: `/opt/services/dreamjourney/DreamJourneyBackend` fast-forwarded to `1e743a1`; API image rebuilt and recreated.
- Schema: explicit production migration application advanced the deployed schema from `0008` to `0009`. API readiness became `database=ready`, `schema=ready`, `auth=ready`.

## Verification

```text
./scripts/verify_backend.sh
565 tests passed
credential boundary, FastAPI, knowledge, backup contract and diff checks passed

STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest \
  tests.test_account_deletion_state \
  tests.test_account_purge_api \
  tests.test_db_migrator \
  tests.test_postgres_store \
  tests.test_auth_sessions
118 tests passed
```

The deployed smoke was executed inside the API container after migration:

```text
scripts/run-backend-account-terminal-purge-deployed-smoke.sh

status=passed
migrationHead=0009
deployedContainer=true
deployedReadiness=true
temporaryDatabase=true
productionBusinessDataMutated=false
serverClockEnforced=true
exactDeadlineRestoreAllowed=true
restoreLimitPersisted=true
retentionHoldBlocked=true
releasedHoldPurged=true
terminalReceiptRedacted=true
terminalReceiptAppendOnly=true
purgedAccountCannotReactivate=true
repeatPurgeNoop=true
```

## External Boundary

`retentionHolds` is intentionally a fail-closed data contract, not a self-declared legal decision. The product still needs the appropriate owner to define legal hold creation/release authority, and the later module executors must produce provider/object/backup cleanup receipts. This work does not expose restore or weaken the existing strong-identity boundary.

## Next Boundary

Proceed to `WI-S0-05-04` only as a scoped inventory and contract design for module-owned export/erase executors. Keep external provider, retention and legal decisions explicitly open; do not mark those effects as complete based on the terminal-account receipt alone.
