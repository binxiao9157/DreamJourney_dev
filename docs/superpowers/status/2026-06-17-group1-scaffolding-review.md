# Group 1 Scaffolding And Release Gates Review

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Scope:

- `.gitignore`
- `DreamJourney.xcodeproj/project.pbxproj`
- `DreamJourney/Resources/Info.plist`
- `DreamJourney/Sources/App/FeatureFlagService.swift`
- `DreamJourney/Sources/AppDelegate.swift`
- `Podfile`
- `Podfile.lock`

## Review Result

Status: ready for staged review. No blocking issue found in this group.

## What This Group Provides

- Keeps `tmp/**/DerivedData*/` out of git status and accidental staging.
- Adds `DreamJourneyBackendBaseURL` for backend integration work.
- Narrows default public feature flags to:
  - `careDashboard`
  - `profileSettings`
  - `legalCenter`
- Versions persisted feature-flag storage so older QA/dev defaults do not re-expose hidden branches after upgrade.
- Keeps unfinished/high-risk branches behind feature flags or explicit UIQA launch arguments.
- Compiles out device-only SpeechEngine/AMap imports for `UI_QA_SIMULATOR`.
- Adds a UIQA simulator launch harness for seeded archive/echo smoke testing.
- Adds new archive/profile Swift files into the Xcode target.
- Adds simulator-specific Pod xcconfig overrides so UIQA simulator builds can link without device-only SDK binaries.
- Syncs `Podfile.lock` after the Podfile checksum changed; pod versions are unchanged.

## Review Notes

Important:

- `DreamJourneyBackendBaseURL` is currently `http://127.0.0.1:3100`. This is acceptable for local/dev QA, but it must become environment-specific before a real App Store/TestFlight release.
- `Podfile` uses a post-install xcconfig override for simulator builds. This is pragmatic for the current SDK mix, but it means `pod install` plus an iOS simulator build should remain part of Group 1 verification.
- `Podfile.lock` currently changes only `PODFILE CHECKSUM`; no dependency version drift was introduced.
- `project.pbxproj` also changes `PRODUCT_BUNDLE_IDENTIFIER` to `com.yxj.dreamjourney.app` and sets `DEVELOPMENT_TEAM = 2BTR77V3R8`; keep this if this branch is tied to the current signing environment, otherwise move signing settings to local config before wider team handoff.

Non-blocking:

- `Info.plist` key ordering changed around `DeepSeekAPIBaseURL` / `DeepSeekAPIKey`; no semantic issue.
- `project.pbxproj` contains some indentation churn around newly inserted archive entries; build and plist parsing still pass.

Fixed during source review:

- Old local `dj.featureFlags.enabled` values are no longer trusted unless `dj.featureFlags.schemaVersion` matches the current schema. This protects release-like installs from stale hidden-branch flags.

## Guard Script

```text
tmp/visual-qa/prd-stitch-ui/group1-scaffolding-check.swift
```

Additional source review guard:

```text
tmp/visual-qa/prd-stitch-ui/group1-source-review-check.swift
```

Source review report:

```text
tmp/visual-qa/prd-stitch-ui/group1-source-review/20260617-current/report.md
```

This checks:

- DerivedData ignore rule.
- API placeholders remain placeholders.
- Dev backend URL is explicit.
- Default release flags stay narrow.
- UIQA harness and seed data stay simulator-gated.
- Shared design-system buttons use `UIButton.Configuration` instead of deprecated `contentEdgeInsets`.
- Podfile simulator override is present.
- `Podfile.lock` is synced to the current Podfile checksum.
- New source files are included in the Xcode target.

## Verification

Latest QA report:

```text
tmp/visual-qa/prd-stitch-ui/group1-scaffolding/20260617-current/report.md
```

Passed on 2026-06-17:

- Group 1 scaffolding guard.
- Release feature matrix guard.
- `git diff --check`.
- `plutil -lint` for `Info.plist` and `project.pbxproj`.
- `pod install`.
- iOS Debug simulator build with `CODE_SIGNING_ALLOWED=NO`.
- Login simulator screenshot after the design-system button inset update.
- Archive-to-echo smoke with `completed=true` and `containsArchiveContext=true`.

Latest smoke screenshot:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-121902/01-archive-to-echo-completed.png
```

Latest login screenshot:

```text
tmp/visual-qa/prd-stitch-ui/group1-source-review/20260617-current/01-login-component-factory-insets.png
```

## Recommendation

Group 1 can be the first staged slice once the user decides whether signing/bundle-id settings should be committed as branch state or moved out before handoff.
