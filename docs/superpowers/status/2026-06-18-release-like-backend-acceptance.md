# Release-like Backend Acceptance

Date: 2026-06-18

App branch: `feature/prd-stitch-ui-adaptation`

Backend branch: `main`

## Status

Status: not accepted

The acceptance harness is now defined, but this machine cannot execute the Postgres run yet because Docker/Postgres runtime is not available on this machine.

Confirmed local environment facts:

- `docker`: not installed.
- `psql`: not installed.
- `postgres`: not installed.
- local TCP `5432`: not listening.
- local FastAPI memory-store smoke remains accepted from phase 0.

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

## Acceptance Boundary

- 本地 FastAPI memory-store smoke：accepted
- release-like FastAPI/Postgres 后端验收：not accepted
- 线上/公网后端验收：not accepted
- 真机验收：not accepted

Do not mark the PRD backend target complete until `run-release-like-backend-acceptance.sh` passes against a Postgres-backed FastAPI environment.

## Next Step

Provide one of the two runtime options:

1. install/start Docker so the local `DreamJourneyBackend` compose stack can run, or
2. provide a deployed FastAPI/Postgres `BACKEND_BASE_URL` and matching `BACKEND_API_TOKEN`.

After that, run the primary command above and attach the generated `report.md`, `postgres-persistence-verify.json`, and iOS smoke screenshot.
