# PRD Stitch UI Adaptation Pre-Submit Inventory

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Goal: split the current dirty worktree into reviewable groups before any commit, and distinguish source changes from QA evidence and local generated artifacts.

## Current Worktree Shape

Tracked source/doc changes:

- 27 tracked files changed, excluding `tmp`.
- Diff size: 2422 insertions, 342 deletions.
- `.gitignore` now ignores `tmp/**/DerivedData*/` so Xcode build caches do not flood status output.

Untracked source files:

- `DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchivePhotoEntryViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift`

Untracked status docs:

- `docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md`
- `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- `docs/superpowers/status/2026-06-17-pre-submit-inventory.md`
- `docs/superpowers/status/2026-06-17-group1-scaffolding-review.md`
- `docs/superpowers/status/2026-06-17-group2-shell-echo-review.md`
- `docs/superpowers/status/2026-06-17-group3-archive-core-review.md`
- `docs/superpowers/status/2026-06-17-group4-profile-care-review.md`

## Commit Candidate Groups

### Group 1: Project Scaffolding And Release Gates

Status: ready for staged review, should be committed with source after signing/backend config decision.

Files:

- `.gitignore`
- `DreamJourney.xcodeproj/project.pbxproj`
- `DreamJourney/Resources/Info.plist`
- `DreamJourney/Sources/App/FeatureFlagService.swift`
- `DreamJourney/Sources/AppDelegate.swift`
- `DreamJourney/Sources/DesignSystem/DJComponentFactory.swift`
- `DreamJourney/Sources/DesignSystem/DJDesignTokens.swift`
- `Podfile`
- `Podfile.lock`

Purpose:

- Adds backend base URL config.
- Adds release feature flag defaults and hidden feature gates.
- Adds shared Stitch/UIKit design tokens and component helpers.
- Adds versioned feature-flag storage so stale local/dev defaults cannot re-expose hidden branches.
- Adds UIQA simulator harness / smoke seed support.
- Adds simulator build compatibility for device-only SDK pods.
- Syncs `Podfile.lock` after the Podfile checksum changed; pod versions are unchanged.
- Ensures new Swift files are part of the app target.

Review notes:

- `DreamJourneyBackendBaseURL` currently points at `http://127.0.0.1:3100`; this is acceptable for dev, but must become environment-specific before real release.
- UIQA harness is compile-gated by `UI_QA_SIMULATOR`.
- `Podfile.lock` changed only by `PODFILE CHECKSUM`, with no dependency version changes.
- Detailed review: `docs/superpowers/status/2026-06-17-group1-scaffolding-review.md`.
- Guard script: `tmp/visual-qa/prd-stitch-ui/group1-scaffolding-check.swift`.
- Source review guard: `tmp/visual-qa/prd-stitch-ui/group1-source-review-check.swift`.

### Group 2: Shell, Login, Echo, And Prompt Context

Status: ready for staged review, should be committed with source.

Files:

- `DreamJourney/Sources/TabBar/WarmTabBarController.swift`
- `DreamJourney/Sources/Modules/Auth/LoginViewController.swift`
- `DreamJourney/Sources/Modules/Echo/EchoViewController.swift`
- `DreamJourney/Sources/Modules/Echo/EchoViewModel.swift`
- `DreamJourney/Sources/Services/DialogEngineManager.swift`
- `DreamJourney/Sources/Services/MicrophonePermissionManager.swift`
- `DreamJourney/Sources/Services/UserManager.swift`

Purpose:

- Aligns login and `回响` visuals to Stitch.
- Fixes the bottom navigation overlap by suppressing the residual system `UITabBar` and keeping the custom tabbar single-layer.
- Keeps `回响` voice-first.
- Injects archive context into prompt/debug capture.
- Adds profile update and simulator microphone handling needed by the MVP loop.

Review notes:

- Real voice SDK/device behavior still needs device-level verification.
- Text/image echo inputs remain hidden by design.
- Detailed review: `docs/superpowers/status/2026-06-17-group2-shell-echo-review.md`.
- Guard scripts: `tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift`, `tmp/visual-qa/prd-stitch-ui/warm-tabbar-single-layer-check.swift`.

### Group 3: Archive Core And Creation Branches

Status: ready for staged review, should be committed with source.

Files:

- `DreamJourney/Sources/Modules/Archive/MemoryArchiveItem.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveDisplayMetadata.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveItemFactory.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveRepository.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveDetailViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationOption.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveCreationSheetViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveTextEntryViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchivePhotoEntryViewController.swift`
- `DreamJourney/Sources/Modules/Archive/MemoryArchiveAudioRecorderViewController.swift`

Purpose:

- Implements the PRD archive model, repository persistence, metadata, detail page, text/photo creation, hidden audio/time-letter branches, local analysis, and archive-to-echo context bridge.

Review notes:

- Default public creation is text/photo only.
- Audio/time-letter/persona-style branches are compiled but hidden behind flags or explicit UIQA arguments.
- Backend archive roundtrip and real photo-library behavior still need integration/device verification.
- Detailed review: `docs/superpowers/status/2026-06-17-group3-archive-core-review.md`.
- Guard script: `tmp/visual-qa/prd-stitch-ui/group3-archive-core-check.swift`.

### Group 4: Profile, Care, Settings, And Legal

Status: ready for staged review, should be committed with source.

Files:

- `DreamJourney/Sources/Modules/Profile/ProfileViewController.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileSettingsViewController.swift`
- `DreamJourney/Sources/Modules/Profile/ProfileLegalViewController.swift`

Purpose:

- Aligns `我的` / care dashboard with Stitch.
- Promotes `个人资料设置` and `法律法规` to real release-visible pages.
- Keeps `家人管理`, `注销账户`, and `立即通话` hidden by default.
- Hides the floating tabbar on profile second-level pages.

Review notes:

- Hidden full-list internal QA mode has a minor non-release visual note: `注销账户` can sit close to the floating tabbar on iPhone 17.
- Family management, doctor contact, and account deletion should not be publicly promoted until product contracts and confirmation/safety copy exist.
- Detailed review: `docs/superpowers/status/2026-06-17-group4-profile-care-review.md`.
- Guard script: `tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift`.

### Group 5: Map / Future Route Compatibility

Status: release-compatible as a hidden/future route.

Files:

- `DreamJourney/Sources/Modules/Map/MapFootprintViewController.swift`
- `DreamJourney/Sources/Modules/Map/MemoryAnnotation.swift`
- `DreamJourney/Sources/Modules/Map/MemoryAnnotationView.swift`

Purpose:

- Keeps map-related code compiling under simulator/UIQA while old top-level routes are removed from the PRD shell.
- Keeps old memoir completion navigation from assuming tab index `1` is still the footprint map.

Review notes:

- This should remain a future/hidden route unless the PRD explicitly brings time-letter/map footprint back into MVP.
- Detailed review: `docs/superpowers/status/2026-06-17-group5-map-compatibility-review.md`.
- Guard script: `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility-check.swift`.

### Group 6: Planning And Durable QA Docs

Status: should be committed if the branch keeps process evidence.

Files:

- `docs/superpowers/plans/2026-06-16-prd-stitch-ui-adaptation.md`
- `docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md`
- `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- `docs/superpowers/status/2026-06-17-pre-submit-inventory.md`

Purpose:

- Records source-of-truth policy, release matrix, current gaps, visual QA evidence, and this submit grouping.

## QA Artifacts

### Keep As Optional Branch Evidence

Status: useful for review, but consider committing only selected reports/scripts, not every screenshot/log.

High-value scripts:

- `tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh`
- `tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift`
- `tmp/visual-qa/prd-stitch-ui/group1-scaffolding-check.swift`
- `tmp/visual-qa/prd-stitch-ui/group1-source-review-check.swift`
- `tmp/visual-qa/prd-stitch-ui/group2-shell-echo-check.swift`
- `tmp/visual-qa/prd-stitch-ui/group3-archive-core-check.swift`
- `tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift`
- `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility-check.swift`
- `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`
- `tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift`
- `tmp/visual-qa/prd-stitch-ui/warm-tabbar-single-layer-check.swift`
- `tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift`
- `tmp/visual-qa/prd-stitch-ui/release-like-hidden-entries-check.swift`
- `tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift`
- `tmp/visual-qa/prd-stitch-ui/profile-settings-check.swift`
- `tmp/visual-qa/prd-stitch-ui/profile-legal-center-check.swift`

High-value latest reports:

- `tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/release-state-overview/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/release-feature-matrix/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group1-scaffolding/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group1-source-review/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group2-shell-echo/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group3-archive-core/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group4-profile-care/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group5-map-compatibility/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/group6-release-qa-package/20260617-current/report.md`
- `tmp/visual-qa/prd-stitch-ui/submit-slice-inventory/20260617-current/report.md`
- `docs/superpowers/status/2026-06-17-submit-slice-inventory.md`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-121902/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-124045/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-125207/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-130030/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-132339/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-133201/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-archive-remote-fetch/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-profile-care-fallback/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-integration-clean2/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-auth-token/archive-to-echo-smoke-result.json`
- `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-fallback-ui/archive-to-echo-smoke-result.json`

### Keep Local Only

Status: do not commit by default.

- `tmp/visual-qa/prd-stitch-ui/DerivedData*`
- `tmp/visual-qa/prd-stitch-ui/**/build*.log`
- `tmp/visual-qa/prd-stitch-ui/**/oslog.log`
- `tmp/visual-qa/prd-stitch-ui/**/runtime.log`
- Old intermediate screenshot folders before the latest final QA pass.
- `tmp/stitch/*.html` unless the team wants local cached Stitch exports in git.

## Temporarily Hidden / Not Public

These must remain hidden in release mode:

- Echo text/image input.
- Archive audio upload, remote fetch, time-letter creation, persona settings, video input, and local analysis outside debug/UIQA.
- Profile family management, family space, account deletion, doctor contact, and password change.
- Old map/footprint route.

## Remaining Before Merge / Release

1. Decide whether `tmp/visual-qa` evidence should be committed at all, or kept local with only `docs/superpowers/status` retained.
2. Run a final source review by module before staging.
3. Verify real backend environment for archive sync/fetch, care dashboard, family, and KB endpoints.
4. Verify device-level microphone, photo library, audio recording, and voice SDK behavior.
5. Keep the latest Stitch canvas and `htmlCode` as the visual authority before any final UI tweaks.

## Suggested Staging Order

Suggested review/commit slices:

1. Project scaffolding and release gates.
2. Shell/login/echo/prompt context.
3. Archive core and creation branches.
4. Profile settings/legal/care gating.
5. Map simulator compatibility.
6. Docs and selected QA scripts/reports.

Avoid staging all of `tmp/` wholesale. Before staging, run:

```bash
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Then stage by submit slice rather than with `git add .`.

## Latest Verification

QA report:

```text
tmp/visual-qa/prd-stitch-ui/pre-submit-inventory/20260617-current/report.md
```

Checks run:

- Group 1 scaffolding check: passed.
- Group 2 shell/echo check: passed.
- Group 3 archive core check: passed.
- Group 4 profile/care check: passed.
- Warm tabbar single-layer check: passed.
- Release feature matrix check: passed.
- Archive local analysis, backend sync, remote fetch, hidden-entry, context snapshot, and debug summary checks: passed.
- Release-like hidden entries check: passed.
- Profile release gating check: passed.
- Profile settings check: passed.
- Profile legal center check: passed.
- Profile pushed-page simulator smoke: passed.
- `git diff --check`: passed.
- `plutil -lint DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj`: passed.
- `pod install`: passed.
- iOS Debug simulator build: passed.
- Archive-to-echo smoke: passed with `completed=true` and `containsArchiveContext=true`.

Latest Group 1 QA report:

```text
tmp/visual-qa/prd-stitch-ui/group1-scaffolding/20260617-current/report.md
```

Latest smoke evidence:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-auth-token/
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-fallback-ui/
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-backend-build-config/
```

Latest profile QA evidence:

```text
tmp/visual-qa/prd-stitch-ui/profile-care-fallback/20260617-current/
tmp/visual-qa/prd-stitch-ui/backend-fallback-ui/20260617-current/
tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current/
```
