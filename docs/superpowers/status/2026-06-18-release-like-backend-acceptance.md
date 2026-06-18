# Release-like Backend Acceptance

Date: 2026-06-18

App branch: `feature/prd-stitch-ui-adaptation`

Backend branch: `main`

## Status

Status: accepted for the latest selected deployed simulator release-like scope.

The deployed FastAPI/Postgres environment is accepted for the simulator release-like backend path after deploying and restarting the backend with the Postgres rollback-on-exception fix.

The latest selected backend rerun on 2026-06-18 passed after deploying the backend contract branch through `1ff8b78 feat: add password change backend contract`.
The earlier password-contract drift run is retained below as superseded diagnostic evidence.

Confirmed local environment facts:

- Docker/Postgres runtime is not available on this machine.
- `docker`: not installed.
- `psql`: not installed.
- `postgres`: not installed.
- local TCP `5432`: not listening.
- local FastAPI memory-store smoke remains accepted from phase 0.

Confirmed deployed environment facts:

- deployed FastAPI/Postgres health check is reachable.
- `/health`: reachable at `https://dreamjourney-api.liftora.cn/health`.
- `/health` store: `postgres`.
- `POST /archive/items`: accepted in release-like persistence and iOS smoke.
- `POST /auth/login`: accepted in backend token/integration contract.
- `POST /auth/password`: accepted in release-like persistence.
- `POST /profile` and `GET /profile/{user_id}`: accepted in release-like persistence.
- `POST /kb/sync`: accepted in release-like persistence and iOS smoke.
- `POST /care/snapshots` and `GET /care/snapshots/latest/{user_id}`: accepted for active / empty / stale / failed fixture evidence.
- Backend token document found locally with token configured; token value is intentionally omitted from reports.

Profile contract update after the accepted deployed run:

- `POST /profile`: now covered by the release-like persistence runner in local code.
- `GET /profile/{user_id}`: now covered by the release-like persistence runner in local code.
- The latest selected backend run `20260618-selected-backend-latest-contracts-after-deploy-r2` accepts and persists nickname, gender, region, and avatar metadata.

Password change contract update after the accepted deployed run:

- `POST /auth/password`: now covered by the release-like persistence runner in local code.
- `POST /auth/login`: now covered for password credential initialization, old-password rejection after change, and new-password login after change.
- The runner now emits `passwordChangeStatus`, `passwordOldLoginStatus`, and `passwordNewLoginConfigured` in `postgres-persistence-verify.json`.
- The latest selected backend run `20260618-selected-backend-latest-contracts-after-deploy-r2` verified `passwordChangeStatus=changed`, `passwordOldLoginStatus=invalid password`, and `passwordNewLoginConfigured=true`.
- The iOS password change entry remains hidden until auth/security review, true-device acceptance, and explicit public-release promotion are complete.

Care snapshot state fixture update after the accepted deployed run:

- `careActiveRiskLevel`: now covered by the release-like persistence runner in local code.
- `careMissingStatus`: now covered by the release-like persistence runner in local code and maps a missing user to the public empty state boundary.
- `careInvalidStatus`: now covered by the release-like persistence runner in local code and maps rejected malformed payloads to the public failed-state boundary.
- `careStaleWindowEnd`: now covered by the release-like persistence runner in local code and preserves an old care window for stale-state handling.
- The latest selected backend run `20260618-selected-backend-latest-contracts-after-deploy-r2` verified these care-state fields against the deployed Postgres backend.

Root cause narrowed during the deployed retry:

- An earlier deployed run reached `postgres-persistence-verify.json` with `completed=true` for marker `20260618-deployed-postgres-acceptance`.
- A later repeated run reused the same marker and triggered a duplicate write path.
- After that failure, deployed JSONB write endpoints returned HTTP 500 for unrelated fresh requests.
- Local `PostgresStore` did not rollback failed DB operations before this pass, which can leave a long-lived psycopg connection in an aborted transaction state, effectively an aborted DB connection for later requests.
- Local backend now has a regression test and fix for rollback-on-exception.
- After deploying/restarting that backend update, the release-like backend acceptance run passed.

## Accepted Run

Run ID:

```text
20260618-deployed-postgres-acceptance-after-deploy
```

Evidence directory:

```text
tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-deployed-postgres-acceptance-after-deploy/
```

Result highlights:

- `postgres-persistence-seed.json`: `completed=true`, `store=postgres`, `mode=seed`.
- `postgres-persistence-verify.json`: `completed=true`, `store=postgres`, `mode=verify`.
- `backend-env-smoke-result.json`: `completed=true`.
- App-side backend smoke confirmed:
  - `archiveRefreshSucceeded=true`
  - `containsBackendContractPhoto=true`
  - `careMoodStatus=需关注`
  - `familyRefreshSucceeded=true`
  - `containsBackendFamilyMember=true`
- Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-deployed-postgres-acceptance-after-deploy/ios-backend-env-smoke/20260618-deployed-postgres-acceptance-after-deploy/01-backend-env-profile.png
```

## Superseded Selected Backend Drift Run

Run ID:

```text
20260618-selected-backend-latest-contracts
```

Status:

```text
blocked
```

Evidence directory:

```text
tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-selected-backend-latest-contracts/
```

Observed result:

- Local backend verification passed first: backend unittest reported `Ran 66 tests` and `OK`, backend py_compile passed, deployment-file checks passed, FastAPI smoke passed, and backend diff check passed.
- The deployed backend health endpoint still reported `store=postgres`.
- The release-like seed stopped at the password credential check because deployed `POST /auth/login` returned a `user` without `passwordConfigured`.
- A focused deployed probe showed `POST /auth/password` returns HTTP `404`.

Root cause:

- Local backend branch `feature/archive-persona-visibility-contract` contains `1ff8b78 feat: add password change backend contract`.
- The selected deployed backend still behaves like an older route set: `POST /auth/login` has only `id`, `nickname`, `phone`, and `updatedAt` in `user`, and the `/auth/password` route is absent.
- This is deployment drift, not an iOS implementation failure.

Required recovery:

1. Deploy the latest backend contract branch, including commits through `1ff8b78`.
2. Rerun `run-release-like-backend-acceptance.sh` with the private deployed backend URL/token.
3. Treat the password fields as selected-environment evidence only after `postgres-persistence-verify.json` includes `passwordChangeStatus`, `passwordOldLoginStatus`, and `passwordNewLoginConfigured`.

Recovery status: completed by `20260618-selected-backend-latest-contracts-after-deploy-r2`.

## Latest Selected Backend Accepted Run

Run ID:

```text
20260618-selected-backend-latest-contracts-after-deploy-r2
```

Evidence directory:

```text
tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-selected-backend-latest-contracts-after-deploy-r2/
```

Result highlights:

- Local backend verification passed first: backend unittest reported `Ran 66 tests` and `OK`, backend py_compile passed, deployment-file checks passed, FastAPI smoke passed, and backend diff check passed.
- `postgres-persistence-seed.json`: `completed=true`, `store=postgres`, `mode=seed`.
- `postgres-persistence-verify.json`: `completed=true`, `store=postgres`, `mode=verify`.
- `passwordChangeStatus=changed`.
- `passwordOldLoginStatus=invalid password`.
- `passwordNewLoginConfigured=true`.
- `profileNickname=RL Profile er-deploy-r2`.
- `profileRegion=RL Region er-deploy-r2`.
- `archivePersonaScope=family`.
- `archiveDigitalHumanId=family_default`.
- `careActiveRiskLevel=watch`.
- `careMissingStatus=care snapshot not found`.
- `careStaleWindowEnd=2026-05-01T00:00:00Z`.
- App-side backend smoke confirmed `completed=true`, `archiveRefreshSucceeded=true`, `containsBackendContractPhoto=true`, `familyRefreshSucceeded=true`, `containsBackendFamilyMember=true`, and `careMoodStatus=需关注`.

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-selected-backend-latest-contracts-after-deploy-r2/ios-backend-env-smoke/20260618-selected-backend-latest-contracts-after-deploy-r2/01-backend-env-profile.png
```

## Target

The release-like backend pass uses the existing `DreamJourneyBackend` repo. It does not create or replace the backend.

The target environment must be one of:

1. sibling `DreamJourneyBackend` started through Docker Compose with `STORE_BACKEND=postgres`, or
2. deployed FastAPI backend with `STORE_BACKEND=postgres`.

## Script

Primary command:

```bash
tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh
```

External backend command:

```bash
BACKEND_BASE_URL=https://example.com/dreamjourney-api \
BACKEND_API_TOKEN='<server token>' \
tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh
```

Local compose command:

```bash
BACKEND_ROOT=/Users/yxj/Documents/Codex/Video/DreamJourneyBackend \
tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh
```

If an external backend can be restarted from the local shell, add:

```bash
RELEASE_LIKE_RESTART_COMMAND='<restart command>'
```

## Coverage

`run-release-like-backend-acceptance.sh` performs:

- `/health` check requiring `store=postgres`;
- backend unit/FastAPI smoke through `DreamJourneyBackend/scripts/verify_backend.sh` when the backend repo is present;
- Postgres persistence seed through `backend-postgres-persistence-check.py`;
- API restart boundary when local compose or `RELEASE_LIKE_RESTART_COMMAND` is available;
- Postgres persistence verify through `backend-postgres-persistence-check.py`;
- iOS `run-backend-env-smoke.sh` against the same backend URL/token.

The persistence contract covers:

- Profile save/read persistence for nickname, gender, region, and avatar metadata;
- Password credential initialization and password change persistence through `passwordChangeStatus`, `passwordOldLoginStatus`, and `passwordNewLoginConfigured`;
- Archive item creation/listing and local path stripping;
- Archive persona visibility fields: `personaScope=family` and `digitalHumanId=family_default`;
- KB sync/snapshot persistence;
- Family invite/accept/list persistence;
- Care snapshot latest persistence with metadata-only/content-redacted guarantees;
- Care snapshot active / empty / stale / failed fixture evidence through `careActiveRiskLevel`, `careMissingStatus`, `careInvalidStatus`, and `careStaleWindowEnd`.

The runner also keeps the two user scopes separate:

- Postgres persistence contract uses a unique `release_like_*` user ID per run.
- iOS backend environment smoke uses `user_9999`, matching the UIQA app harness seeded by `DJRunBackendEnvSmoke`.

Local backend verification is run with `BACKEND_API_TOKEN` cleared so deployed credentials do not force local memory-store TestClient requests through token authentication.

## Acceptance Boundary

- 本地 FastAPI memory-store smoke：accepted
- release-like FastAPI/Postgres 后端验收：accepted
- 线上/公网后端验收：accepted for simulator release-like scope
- 真机验收：not accepted

Do not mark the PRD fully complete until true-device acceptance also passes. The backend release-like simulator gate is accepted.

## Latest Archive Visibility Contract Run

Run ID: `20260618-archive-persona-contract`

Evidence:

- `tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-archive-persona-contract/postgres-persistence-verify.json`
- `tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-archive-persona-contract/ios-backend-env-smoke/20260618-archive-persona-contract/backend-env-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/release-like-backend-acceptance/20260618-archive-persona-contract/ios-backend-env-smoke/20260618-archive-persona-contract/01-backend-env-profile.png`

Verified:

- `/archive/items` accepts the archive visibility payload.
- Postgres persistence verify returns `archivePersonaScope=family`.
- Postgres persistence verify returns `archiveDigitalHumanId=family_default`.
- The same deployed backend still passes the iOS backend environment smoke.

## Next Step

For backend regressions, rerun:

```bash
BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn \
BACKEND_API_TOKEN='<server token from private access doc>' \
tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh
```

The local current backend code contains Postgres `Jsonb` parameter adaptation, rolls back failed DB operations, and passes the backend verification suite.

The latest selected backend acceptance run `20260618-selected-backend-latest-contracts-after-deploy-r2` verified `passwordChangeStatus`, `passwordOldLoginStatus`, `passwordNewLoginConfigured`, `careActiveRiskLevel`, `careMissingStatus`, `careInvalidStatus`, and `careStaleWindowEnd` in `postgres-persistence-verify.json`.
