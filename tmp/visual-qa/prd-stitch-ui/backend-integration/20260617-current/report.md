# Backend Integration QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/Services/DreamJourneyBackendClient.swift
DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift
DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift
DreamJourney/Sources/AppDelegate.swift
tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py
```

## Result

The DreamJourney backend was started locally with the real FastAPI app in memory-store mode:

```bash
STORE_BACKEND=memory APP_ENV=local PYTHONPATH=. .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 3100
```

Backend HTTP contract checks passed for:

- `GET /health`
- `GET /config/runtime`
- `POST /archive/items` and `GET /archive/items/{user_id}`
- `POST /kb/sync` and `GET /kb/snapshot/{user_id}`
- `POST /family/invite`, accept, and `GET /family/members/{user_id}`
- `POST /care/snapshots` and `GET /care/snapshots/latest/{user_id}`

The iOS UIQA app was then launched with:

```text
DJSeedEchoArchiveContext DJEnableArchiveRemoteFetch
```

Simulator evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-integration/20260617-current/01-archive-backend-fetch.jpg
tmp/visual-qa/prd-stitch-ui/backend-integration/20260617-current/02-profile-care-backend.jpg
```

Observed app behavior:

- Archive fetched and rendered the backend item `Backend Contract Photo`.
- App archive store merged backend and local seed items:
  `tmp/visual-qa/prd-stitch-ui/backend-integration/20260617-current/app-archive-store-summary.json`
- Profile care fetched backend aggregate data and rendered `需关注` with the backend suggestion `Call today.`.
- Backend logs confirmed app requests to `/archive/items/user_9999` and `/care/snapshots/latest/user_9999`.
- Core archive-to-echo smoke passed again after adding simulator-defaults cleanup:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-integration-clean2/`

## Verification

```bash
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest discover tests
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m compileall -q app tests
python3 tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py http://127.0.0.1:3100
python3 tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py http://127.0.0.1:3100 user_9999
swiftc DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift -o /tmp/profile-care-snapshot-check
/tmp/profile-care-snapshot-check /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/archive-remote-fetch-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendIntegration CODE_SIGNING_ALLOWED=NO 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendIntegrationStandard build
RUN_ID=20260617-backend-integration-clean2 DERIVED_DATA_PATH=tmp/visual-qa/prd-stitch-ui/DerivedDataBackendIntegrationSmokeClean2 LOG_WAIT_TIMEOUT=60 tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

Result: passed.

## Boundary

This validates the real backend app and real HTTP requests against the local memory store. It does not validate Postgres persistence or Docker deployment because `docker` is not available in the current environment. It also does not validate production auth-token configuration or real device microphone/photo-library behavior.
