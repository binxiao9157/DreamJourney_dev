# Release-like Backend Acceptance

Date: 2026-06-18

App branch: `feature/prd-stitch-ui-adaptation`

Backend branch: `main`

## Status

Status: not accepted

The acceptance harness is defined, and the deployed FastAPI/Postgres environment has now been located through the private backend access document. The deployed FastAPI/Postgres health check is reachable and reports `store=postgres`, but the release-like write path is not accepted because deployed JSONB write endpoints currently return HTTP 500.

Confirmed local environment facts:

- Docker/Postgres runtime is not available on this machine.
- `docker`: not installed.
- `psql`: not installed.
- `postgres`: not installed.
- local TCP `5432`: not listening.
- local FastAPI memory-store smoke remains accepted from phase 0.

Confirmed deployed environment facts:

- `/health`: reachable at `https://dreamjourney-api.liftora.cn/health`.
- `/health` store: `postgres`.
- `POST /archive/items`: HTTP 500.
- `POST /auth/login`: HTTP 500.
- `POST /kb/sync`: HTTP 500.
- Backend token document found locally with token configured; token value is intentionally omitted from reports.

Root cause narrowed during the deployed retry:

- An earlier deployed run reached `postgres-persistence-verify.json` with `completed=true` for marker `20260618-deployed-postgres-acceptance`.
- A later repeated run reused the same marker and triggered a duplicate write path.
- After that failure, deployed JSONB write endpoints returned HTTP 500 for unrelated fresh requests.
- Local `PostgresStore` did not rollback failed DB operations before this pass, which can leave a long-lived psycopg connection in an aborted transaction state.
- Local backend now has a regression test and fix for rollback-on-exception; the deployed service still needs that backend update and a process restart before release-like acceptance can pass.

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

- Archive item creation/listing and local path stripping;
- KB sync/snapshot persistence;
- Family invite/accept/list persistence;
- Care snapshot latest persistence with metadata-only/content-redacted guarantees.

The runner also keeps the two user scopes separate:

- Postgres persistence contract uses a unique `release_like_*` user ID per run.
- iOS backend environment smoke uses `user_9999`, matching the UIQA app harness seeded by `DJRunBackendEnvSmoke`.

Local backend verification is run with `BACKEND_API_TOKEN` cleared so deployed credentials do not force local memory-store TestClient requests through token authentication.

## Acceptance Boundary

- 本地 FastAPI memory-store smoke：accepted
- release-like FastAPI/Postgres 后端验收：not accepted; deployed write endpoints return HTTP 500 until backend rollback fix is deployed/restarted
- 线上/公网后端验收：not accepted; health passes, JSONB write path currently fails
- 真机验收：not accepted

Do not mark the PRD backend target complete until `run-release-like-backend-acceptance.sh` passes against a Postgres-backed FastAPI environment.

## Next Step

Deploy or restart the public backend with the current `DreamJourneyBackend` code, including the Postgres rollback-on-exception fix, then rerun:

```bash
BACKEND_BASE_URL=https://dreamjourney-api.liftora.cn \
BACKEND_API_TOKEN='<server token from private access doc>' \
tmp/visual-qa/prd-stitch-ui/run-release-like-backend-acceptance.sh
```

If the latest backend is already deployed, inspect the server logs for the HTTP 500 raised by:

- `POST /auth/login`
- `POST /kb/sync`
- `POST /archive/items`

The local current backend code contains Postgres `Jsonb` parameter adaptation, rolls back failed DB operations, and passes the backend verification suite. The next check is whether the deployed service is running this backend revision and has been restarted to clear any aborted DB connection.
