# Phase 0 Backend Alignment

Date: 2026-06-18

App branch: `feature/prd-stitch-ui-adaptation`

Backend branch: `main`

## Decision

DreamJourneyBackend exists.

Backend repository:

```text
/Users/yxj/Documents/Codex/Video/DreamJourneyBackend
```

The stage 0 backend task is not to create a new backend. It is to align the existing FastAPI backend with the current iOS `DreamJourneyBackendClient` and the first-stage MVP acceptance path.

## Scope

User-confirmed stage 0 boundary:

- Product target: first-stage MVP complete acceptance.
- Backend: existing `DreamJourneyBackend` should be used and aligned.
- True device: deferred.
- 真机验收：not accepted
- 线上/公网后端验收：not accepted
- 本地 FastAPI 后端 smoke：accepted

## Contract Alignment

iOS client currently calls:

| iOS client method | Path | Backend status |
| --- | --- | --- |
| `postArchiveItem` | `POST /archive/items` | implemented |
| `listArchiveItems` | `GET /archive/items/{userId}` | implemented |
| `syncKnowledge` | `POST /kb/sync` | implemented |
| `listFamilyMembers` | `GET /family/members/{userId}` | implemented |
| `latestCareSnapshot` | `GET /care/snapshots/latest/{userId}` | implemented |

iOS backend smoke also seeds and verifies:

| Smoke dependency | Path | Backend status |
| --- | --- | --- |
| health | `GET /health` | implemented |
| runtime token guard | `GET /config/runtime` | implemented and token-protected when configured |
| family invite | `POST /family/invite` | implemented |
| family accept | `POST /family/members/{userId}/{memberId}/accept` | implemented |
| care save | `POST /care/snapshots` | implemented |

No iOS client route mismatch was found in this phase 0 pass.

## Backend Fix Applied

`DreamJourneyBackend/scripts/verify_backend.sh` now:

- prefers `DreamJourneyBackend/.venv/bin/python` when available,
- allows override through `PYTHON_BIN`,
- runs backend unittests with `STORE_BACKEND=memory`,
- keeps FastAPI TestClient smoke in memory mode.

Root cause:

- The script previously used system `python3`, which missed local dependencies such as FastAPI and psycopg.
- After switching to `.venv`, tests then hit the default Postgres DSN because unittest did not force memory mode.
- The backend app and route contract were not the failure; the verification script environment was.

## Commands Run

Backend unit tests:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
PYTHONPATH=. STORE_BACKEND=memory .venv/bin/python -m unittest discover tests
```

Result:

```text
Ran 52 tests in 0.116s
OK
```

Backend verification:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
./scripts/verify_backend.sh
```

Result:

```text
Backend unittest: OK
Backend py_compile: OK
Backend deployment files: OK
Backend FastAPI smoke: FastAPI smoke verification passed
Backend diff --check: OK
```

Local backend start:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
STORE_BACKEND=memory BACKEND_API_TOKEN=YOUR_BACKEND_API_TOKEN PYTHONPATH=. .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 3100
```

HTTP contract checks:

```bash
python3 /Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/backend-auth-token-contract-check.py http://127.0.0.1:3100 dj-local-test-token
python3 /Users/yxj/Documents/Codex/Video/DreamJourney_dev/Scripts/QA/prd-stitch-ui/backend-integration-contract-check.py http://127.0.0.1:3100 phase0_contract_user dj-local-test-token
```

Result:

- token contract completed with unauthorized runtime returning `401`;
- archive, KB, family, and care contract completed;
- care snapshot remains metadata-only and content-redacted;
- archive payload strips local path.

iOS backend smoke:

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
BACKEND_BASE_URL=http://127.0.0.1:3100 BACKEND_API_TOKEN=YOUR_BACKEND_API_TOKEN RUN_ID=20260618-phase0-backend-alignment Scripts/QA/prd-stitch-ui/run-backend-env-smoke.sh
```

Result JSON:

```json
{"archiveItemCount":2,"archiveRefreshSucceeded":true,"availableArchiveItemCount":2,"backendFamilyMemberCount":1,"careMoodStatus":"需关注","careSyncCaption":"Call today.","completed":true,"containsBackendContractPhoto":true,"containsBackendFamilyMember":true,"containsCareSuggestion":true,"familyRefreshSucceeded":true}
```

## Evidence

iOS backend smoke artifacts:

```text
tmp/visual-qa/prd-stitch-ui/backend-env-smoke/20260618-phase0-backend-alignment/backend-env-smoke-result.json
tmp/visual-qa/prd-stitch-ui/backend-env-smoke/20260618-phase0-backend-alignment/app-archive-store-summary.json
tmp/visual-qa/prd-stitch-ui/backend-env-smoke/20260618-phase0-backend-alignment/01-backend-env-profile.png
tmp/visual-qa/prd-stitch-ui/backend-env-smoke/20260618-phase0-backend-alignment/build-uiqa.log
tmp/visual-qa/prd-stitch-ui/backend-env-smoke/20260618-phase0-backend-alignment/report.md
```

## Remaining Boundaries

- This pass validates local FastAPI backend with memory store. It does not validate a deployed public backend.
- This pass validates simulator UIQA integration. It does not validate true-device microphone, photo, speech, camera, or signing.
- The first-stage MVP can now treat backend existence as confirmed, but final acceptance still needs the release environment chosen and run.

## Next Step

Proceed with first-stage MVP backend acceptance planning against either:

1. local FastAPI + memory store for fast development, or
2. deployed FastAPI + Postgres for release-like acceptance.

Do not create a new backend unless the existing `DreamJourneyBackend` is explicitly replaced by a product or infrastructure decision.
