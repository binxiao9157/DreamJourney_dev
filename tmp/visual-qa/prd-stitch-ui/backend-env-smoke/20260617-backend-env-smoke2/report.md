# Backend Environment Smoke

Run ID: `20260617-backend-env-smoke2`

Backend base URL: `http://127.0.0.1:3100`
Backend API token: configured, value intentionally omitted
Simulator: `F54C960B-005F-434A-81E2-557D21AF14ED`
Bundle ID: `com.yxj.dreamjourney.app`

## Scope

- Runs `backend-auth-token-contract-check.py`.
- Runs `backend-integration-contract-check.py` for `user_9999`.
- Builds the iOS app with `DREAMJOURNEY_BACKEND_BASE_URL="$BACKEND_BASE_URL"` and `DREAMJOURNEY_BACKEND_API_TOKEN="$BACKEND_API_TOKEN"`.
- Launches `DJSeedEchoArchiveContext`, `DJEnableArchiveRemoteFetch`, and `DJRunBackendEnvSmoke`.
- Verifies app-side archive/profile backend results through `backend-env-smoke-result.json`.
- Captures merged archive store summary in `app-archive-store-summary.json`.

Expected UI identifiers covered by this route:

- `archiveRemoteSyncStatus`
- `profileCareSyncCaption`

## Evidence

- Build log: `build-uiqa.log`
- Runtime log: `runtime.log`
- OS log: `oslog.log`
- Token contract result: `backend-auth-token-contract-result.json`
- Backend integration result: `backend-integration-contract-result.json`
- App smoke result: `backend-env-smoke-result.json`
- Archive store summary: `app-archive-store-summary.json`
- Screenshot: `01-backend-env-profile.png`
