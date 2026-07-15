# Backend Build Config QA

Date: 2026-06-17

Scope:

```text
DreamJourney/Resources/Info.plist
DreamJourney.xcodeproj/project.pbxproj
DreamJourney/Config/Backend.example.xcconfig
DreamJourney/Sources/Services/DreamJourneyBackendClient.swift
tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift
```

## Result

Backend environment values are now build-setting driven:

- `DreamJourneyBackendBaseURL` resolves from `$(DREAMJOURNEY_BACKEND_BASE_URL)`.
- `DreamJourneyBackendAPIToken` resolves from `$(DREAMJOURNEY_BACKEND_API_TOKEN)`.
- Debug and Release target build settings default to local `http://127.0.0.1:3100` and placeholder token.
- `Backend.example.xcconfig` documents local/default keys.
- `Backend.local.xcconfig` is ignored so real local secrets are not committed.
- `DreamJourneyBackendClient` ignores empty, placeholder, and unexpanded `$(...)` token/base URL values.

## Build Evidence

Default build:

```text
tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current/build-default-debug.log
```

Default built plist values:

```text
DreamJourneyBackendBaseURL = http://127.0.0.1:3100
DreamJourneyBackendAPIToken = REDACTED
```

Override build:

```text
tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current/build-override-debug.log
```

Override built plist values:

```text
DreamJourneyBackendBaseURL = https://staging.example.invalid
DreamJourneyBackendAPIToken = REDACTED
```

`qa-build-token` is a dummy local QA value, not a real secret.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendBuildConfigDefault build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -destination 'generic/platform=iOS Simulator' -configuration Debug -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendBuildConfigOverride DREAMJOURNEY_BACKEND_BASE_URL=https://staging.example.invalid DREAMJOURNEY_BACKEND_API_TOKEN=REDACTED build
plutil -lint DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj
```

Result: passed.
