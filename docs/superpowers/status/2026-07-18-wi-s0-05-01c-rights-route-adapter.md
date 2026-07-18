# WI-S0-05-01C Legacy Account Delete Rights Adapter

Date: 2026-07-18

## Status

- Work item: `WI-S0-05-01`
- Sub-slice: `WI-S0-05-01C`
- Authority lock: `RIGHTS_DELETION`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / G0_G2_VERIFIED / BACKEND_DEPLOYED`
- G2: `PASS` (the deployed API container ran the Postgres rights lifecycle smoke against a temporary database through migration head `0007`)
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

## Commits

- `36265f8 feat(WI-S0-05-01): adapt account delete rights contract`
- `31d4e86 test(rights): add deployed deletion lifecycle smoke`

Backend baseline: `main@31d4e86`, pushed to `origin/main` and deployed on the production-like server. The API container was force-recreated after the deployment and `/ready` was healthy.

## Verification

```text
STORE_BACKEND=memory ... unittest tests.test_account_deletion_rights tests.test_core_services.AccountDeletionAPITests
4 tests passed

PYTHONPATH=. ... unittest tests.test_data_rights_contract tests.test_data_rights_store tests.test_db_migrator
21 tests passed

PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
554 tests passed; credential boundary, FastAPI, knowledge, backup contract and diff checks passed
```

## Deployed G2 Evidence

The deployed smoke runs **inside the deployed API container** and creates/drops a temporary `dj_rights_smoke_*` Postgres database. It does not mutate production business data.

```json
{
  "appliedMigrationCount": 7,
  "commandConflictRejected": true,
  "concurrentSameCommandDeduplicated": true,
  "crossAccountDenied": true,
  "deployedContainer": true,
  "deployedReadiness": true,
  "migrationHead": "0007",
  "productionBusinessDataMutated": false,
  "rollbackRestoredActiveState": true,
  "schemaVersion": 1,
  "status": "passed",
  "storeReconstructionPersistence": true,
  "temporaryDatabase": true
}
```

The smoke verifies the following without treating an external policy decision as closed:

- same-command concurrent deletion attempts deduplicate;
- a reused command with a different rights scope is rejected;
- a route-level injected failure rolls back the account deletion and leaves the token valid;
- an unrelated actor is denied cross-account access;
- the persisted state survives service-store reconstruction;
- the API remains ready after the deployed container is recreated.

## Gate / next action

`WI-S0-05-01` now has its required deployed G2 evidence. G4 remains explicitly external: identity proof, final legal deletion scope, and provider/backup deletion receipts are not inferred from this smoke. The execution planner may select `WI-S0-05-02` only as the next additive implementation slice and must preserve this open G4 boundary.
