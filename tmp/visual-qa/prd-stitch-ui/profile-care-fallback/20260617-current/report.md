# Profile Care Fallback QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift
DreamJourney/Sources/Modules/Profile/ProfileViewController.swift
tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift
```

## Result

The Profile care dashboard now has a safe fallback state for backend-unavailable or malformed backend responses.

- `ProfileCareSnapshot.offlineFallback()` returns a bounded local state.
- The fallback pill reads `待同步`.
- The card caption reads `关怀数据暂未同步，当前显示本地安全状态。`.
- Backend snapshots remain parsed only into bounded signal fields.
- Raw transcript or raw message fields are not exposed by the care model or Profile UI.

This is a UI/contract fallback only. It does not replace real backend integration verification.

Simulator evidence:

```text
tmp/visual-qa/prd-stitch-ui/profile-care-fallback/20260617-current/01-profile-care-fallback.png
```

Build evidence:

```text
tmp/visual-qa/prd-stitch-ui/profile-care-fallback/20260617-current/build-standard-debug.log
```

Core archive-to-echo smoke evidence:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-profile-care-fallback/
```

## Verification

```bash
swiftc DreamJourney/Sources/Modules/Profile/ProfileCareModels.swift tmp/visual-qa/prd-stitch-ui/profile-care-snapshot-check.swift -o /tmp/profile-care-snapshot-check
/tmp/profile-care-snapshot-check /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareFallback build
RUN_ID=20260617-profile-care-fallback DERIVED_DATA_PATH=tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCareFallbackSmoke LOG_WAIT_TIMEOUT=60 tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
```

Result: passed.
