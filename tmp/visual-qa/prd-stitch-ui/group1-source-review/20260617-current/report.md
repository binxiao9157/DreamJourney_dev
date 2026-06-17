# Group 1 Source Review Report

Date: 2026-06-17

Scope:

- `.gitignore`
- `DreamJourney.xcodeproj/project.pbxproj`
- `DreamJourney/Resources/Info.plist`
- `DreamJourney/Sources/App/FeatureFlagService.swift`
- `DreamJourney/Sources/AppDelegate.swift`
- `DreamJourney/Sources/DesignSystem/DJComponentFactory.swift`
- `Podfile`
- `Podfile.lock`

Focus:

- release feature flag defaults and migration;
- placeholder API keys;
- local backend base URL visibility;
- UIQA simulator gating;
- device-only SDK simulator workaround;
- target membership for newly split source files.
- design-system button helpers avoiding deprecated UIKit inset APIs.

## Finding Fixed

`FeatureFlagService` now versions its stored flag set through `dj.featureFlags.schemaVersion`.

Why:

- the PRD release surface now hides `familyManagement`, `accountDeletion`, `careDoctorContact`, audio upload, time letters, and similar branches by default;
- older development builds or QA sessions could have persisted a broader `dj.featureFlags.enabled` array;
- trusting that old storage could re-expose hidden rows after an upgrade.

Fix:

- `FeatureFlagService` only trusts stored flags when the stored schema version matches `currentStorageVersion`;
- otherwise it resets to the current release defaults and persists the versioned defaults.

## Additional Warning Triage

`DJComponentFactory` now uses `UIButton.Configuration` and `configuration.contentInsets` for shared primary/icon buttons instead of deprecated `contentEdgeInsets`.

Why:

- `DJComponentFactory` is used by the current login and archive creation UI;
- iOS 15+ deprecates `UIButton.contentEdgeInsets` when modern button configuration is active;
- keeping the design-system helper warning-free makes future Stitch UI work easier to review.

## Guard

```bash
swift tmp/visual-qa/prd-stitch-ui/group1-source-review-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected:

```text
Group 1 source review checks passed
```

## Review Notes

- `DreamJourneyBackendBaseURL` remains `http://127.0.0.1:3100`; this is acceptable for local/dev QA and still must be made environment-specific before release.
- API keys remain placeholders in `Info.plist`.
- UIQA smoke harness remains simulator-gated through `UI_QA_SIMULATOR`.
- `Podfile` simulator xcconfig override remains intentionally idempotent.

## Verification

- Group 1 source review guard passed.
- Group 1 scaffolding guard passed.
- Release feature matrix guard passed.
- Release QA package guard passed with latest smoke `20260617-final-visual-package`.
- Submit slice inventory guard passed.
- `git diff --check` passed.
- `plutil -lint DreamJourney/Resources/Info.plist` passed.
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj` passed.
- iOS Simulator Debug build passed:
  `tmp/visual-qa/prd-stitch-ui/group1-source-review/20260617-current/build-component-factory-insets.log`.
- arm64 simulator login screenshot passed visual inspection:
  `tmp/visual-qa/prd-stitch-ui/group1-source-review/20260617-current/01-login-component-factory-insets.png`.
