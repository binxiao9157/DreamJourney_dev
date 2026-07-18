# WI-S0-05-02 Access-First Suspend and Session/Grant Revocation

Date: 2026-07-18

## Status

- Work item: `WI-S0-05-02`
- Authority lock: `RIGHTS_DELETION`
- Execution owner: `codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- Result: `INTERNAL_READY / G0_G2_VERIFIED / BACKEND_DEPLOYED / IOS_LOCAL_COMMITTED`
- G0: `PASS` (backend unit/contract coverage, iOS receipt-boundary static checks and workspace build)
- G2: `PASS` (backend `main@1eca47a` deployed; migration `0008` applied and verified; isolated Postgres smoke passed)
- G4: `EXTERNAL_OPEN` (strong identity scope, legal deletion scope, Provider execution/revocation receipts and backup-retention evidence are not closed by this work item)

## Delivered

Account deletion is now access-first rather than merely a delayed data lifecycle marker:

- `soft_delete_user` atomically writes `deletionState=softDeleted`, `accessState=suspended_restorable`, increments `authEpoch`, and marks `providerCapabilityState=revoked`.
- Access and refresh credentials carry the account epoch. Old credentials are rejected even if a token-family revoke has not yet propagated.
- New session issuance and refresh rotation re-check the account state under the same user operation lock, preventing a successor token after suspension.
- `POST /auth/delete` keeps its existing all-device session and delegated-grant revocation, then appends one immutable `RightsAccessRevoked` record to `rights_access_revocation_outbox`.
- Migration `0008_access_first_suspend` enforces one outbox event per `request_id + event_type`.
- Repeating a completed deletion command is idempotent: the soft-deleted state and epoch remain stable, and the existing outbox event is returned.
- iOS accepts a deletion response only after it validates the full receipt: soft-delete, suspended access, revoked Provider capability, all-device session scope, positive epoch, and a durable `RightsAccessRevoked` event. Local deletion cleanup will not start from an incomplete `200` response.

The outbox is deliberately a durable intent boundary. This work item does not claim that an external Voice/Digital Human Provider has already executed or returned a deletion/revocation receipt; that remains a later Provider consumer and G3/G4 concern.

## Commits

- Backend: `1eca47a feat(rights): suspend account access before deletion cleanup`
- iOS: this status evidence is committed with the receipt-boundary client change on `feature/prd-stitch-ui-adaptation`.

Backend was pushed to `origin/main`, deployed from `/opt/services/dreamjourney/DreamJourneyBackend`, and rebuilt as the API container image. The production-like schema migration was explicitly applied outside API startup and verified at head `0008`.

## Verification

```text
PYTHON_BIN=.venv/bin/python scripts/verify_backend.sh
557 tests passed; credential boundary, FastAPI, knowledge, backup contract and diff checks passed

python3 scripts/QA/product-v4/account-deletion-lifecycle-static-check.py
PASS

swift scripts/QA/prd-stitch-ui/profile-safety-flow-check.swift .
PASS

swift scripts/QA/prd-stitch-ui/profile-family-account-lifecycle-check.swift .
PASS

xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
BUILD SUCCEEDED
```

The project must be built through `DreamJourney.xcworkspace`; using the bare `.xcodeproj` skips Pods and is not a valid dependency-resolved build invocation.

## Deployed G2 Evidence

`scripts/run-backend-access-first-suspend-deployed-smoke.sh` ran inside the deployed API container. It first checked public readiness, then created and deleted a disposable `dj_access_first_smoke_*` database. Production business data was not mutated.

```json
{
  "accessRevocationEvent": "RightsAccessRevoked",
  "accessState": "suspended_restorable",
  "appliedMigrationCount": 8,
  "authEpoch": 1,
  "deployedContainer": true,
  "deployedReadiness": true,
  "duplicateCommandOutboxCount": 1,
  "migrationHead": "0008",
  "oldAccessRejected": true,
  "oldRefreshRejected": true,
  "productionBusinessDataMutated": false,
  "providerCapabilityState": "revoked",
  "schemaVersion": 1,
  "status": "passed",
  "temporaryDatabase": true
}
```

## Next Boundary

`WI-S0-05-03` remains the next rights/deletion candidate, but it requires the already-open strong-identity and legal-scope boundary. The executor must assess it without treating this G0/G2 evidence as a substitute for G4, then move to the highest-priority unblocked work item if it remains externally blocked.
