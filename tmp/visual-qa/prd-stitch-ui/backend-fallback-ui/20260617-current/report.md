# Backend Fallback UI QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift
DreamJourney/Sources/Modules/Profile/ProfileViewController.swift
tmp/visual-qa/prd-stitch-ui/backend-fallback-ui-check.swift
```

## Result

The app now keeps backend failures visible but non-blocking:

- Archive remote fetch shows `正在同步远端档案...` while the request is in flight.
- Archive remote fetch success shows `已同步远端档案`.
- Archive remote fetch failure shows `远端暂不可用，已保留本地档案`.
- The archive fallback label has accessibility identifier `archiveRemoteSyncStatus`.
- The profile care fallback caption has accessibility identifier `profileCareSyncCaption`.

This does not change the default release first screen because `archiveRemoteFetch` remains hidden by default.

## Simulator Evidence

The simulator was launched with `DJSeedEchoArchiveContext DJEnableArchiveRemoteFetch` while no backend was listening on `127.0.0.1:3100`.

```text
tmp/visual-qa/prd-stitch-ui/backend-fallback-ui/20260617-current/01-archive-remote-fallback.jpg
tmp/visual-qa/prd-stitch-ui/backend-fallback-ui/20260617-current/02-profile-care-fallback.jpg
```

Runtime UI observations:

- Archive text: `远端暂不可用，已保留本地档案`
- Archive identifier: `archiveRemoteSyncStatus`
- Profile text: `关怀数据暂未同步，当前显示本地安全状态。`
- Profile identifier: `profileCareSyncCaption`

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/backend-fallback-ui-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendFallbackUI build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendFallbackUIQA CODE_SIGNING_ALLOWED=NO 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```

Result: passed.
