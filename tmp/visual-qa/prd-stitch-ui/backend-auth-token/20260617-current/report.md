# Backend Auth Token QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Resources/Info.plist
DreamJourney/Sources/Services/DreamJourneyBackendClient.swift
tmp/visual-qa/prd-stitch-ui/backend-auth-token-check.swift
tmp/visual-qa/prd-stitch-ui/backend-auth-token-contract-check.py
```

## Result

The iOS backend client now supports an optional backend API token:

- Source `Info.plist` contains only the placeholder `YOUR_DREAMJOURNEY_BACKEND_API_TOKEN`.
- `DreamJourneyBackendClient` ignores empty/placeholder token values.
- When a real token is present in the built app config, requests include `Authorization: Bearer <token>`.

The local FastAPI backend was started with token enforcement:

```bash
STORE_BACKEND=memory APP_ENV=local BACKEND_API_TOKEN=dj-local-test-token PYTHONPATH=. .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 3100
```

Contract evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-auth-token-contract-result.json
tmp/visual-qa/prd-stitch-ui/backend-integration-token-result.json
tmp/visual-qa/prd-stitch-ui/backend-integration-token-user9999-result.json
```

Simulator evidence:

```text
tmp/visual-qa/prd-stitch-ui/backend-auth-token/20260617-current/01-archive-auth-token-fetch.jpg
tmp/visual-qa/prd-stitch-ui/backend-auth-token/20260617-current/02-profile-auth-token-care.jpg
tmp/visual-qa/prd-stitch-ui/backend-auth-token/20260617-current/app-archive-store-summary.json
```

Observed app behavior:

- `GET /config/runtime` without token returned `401`.
- Authorized contract calls to `/archive`, `/kb`, `/family`, and `/care` returned `200`.
- UIQA app with token injected only into the built app bundle fetched backend archive data and rendered `Backend Contract Photo`.
- Profile care fetched backend data and rendered `需关注` with `Call today.`.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/backend-auth-token-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
python3 tmp/visual-qa/prd-stitch-ui/backend-auth-token-contract-check.py http://127.0.0.1:3100 dj-local-test-token
python3 tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py http://127.0.0.1:3100 auth_user_9999 dj-local-test-token
python3 tmp/visual-qa/prd-stitch-ui/backend-integration-contract-check.py http://127.0.0.1:3100 user_9999 dj-local-test-token
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest discover tests
STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m compileall -q app tests
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendAuthToken CODE_SIGNING_ALLOWED=NO 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

Result: passed.

## Boundary

The real token used in this QA pass was injected only into the built simulator app bundle and was not committed to source. Postgres/Docker persistence is still unverified in this environment because Docker is unavailable.
