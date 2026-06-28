# Submit Slice Inventory

Date: 2026-06-17

Purpose:

- Convert the current large dirty tree into explicit review/commit slices.
- Catch unclassified files before staging.
- Keep source changes, durable docs, selected QA evidence, and local generated artifacts separate.

## Guard

Run:

```bash
swift Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected output starts with:

```text
Submit slice inventory checks passed
```

The guard expands `git status --porcelain=v1 -uall`, classifies every dirty path, and fails if any path is outside the known submit slices.

## Submit Slices

1. `1-project-scaffolding-release-gates`
   - `.gitignore`
   - Xcode project / plist / Podfile changes
   - `FeatureFlagService`
   - `AppDelegate` UIQA, backend config support, and backend client auth wiring
   - shared `DesignSystem` tokens and component helpers

2. `2-shell-login-echo-prompt`
   - custom tabbar
   - login
   - echo screen/view model
   - dialog prompt context
   - microphone and profile update support used by the MVP shell

3. `3-archive-core-creation`
   - archive model, metadata, repository, overview, detail page
   - text/photo creation
   - hidden audio/time-letter branches

4. `4-profile-care-settings-legal`
   - profile/care dashboard
   - settings page
   - legal center
   - release gating for family/account/doctor contact entries

5. `5-map-future-route-compatibility`
   - map files kept build-compatible
   - legacy recording screen kept hidden and source-warning clean
   - old memoir banner no longer assumes tab index `1` is footprint
   - legacy voice/memoir service compatibility warnings are guarded

6. `5-source-warning-cleanup`
   - low-risk app source warning cleanup
   - UIKit button padding moved away from deprecated edge inset APIs
   - key-window lookup moved away from deprecated `UIApplication.shared.windows`
   - unused source locals removed

7. `6-durable-docs`
   - development plan
   - status reviews
   - PRD/Stitch gap audit
   - release matrix
   - pre-submit inventory

8. `6-optional-qa-evidence`
   - selected reusable QA scripts
   - selected reports
   - smoke result JSON
   - Stitch reference screenshots

## Local Only

The guard classifies but does not recommend staging:

- `local-only-generated-qa`: build logs, runtime logs, OS logs, screenshots, video, xcresult, DerivedData.
- `local-only-stitch-cache`: cached Stitch exports.

These are useful locally but should not be staged unless there is a specific review need.

## Current Rule

Do not run broad commands like `git add tmp/` or `git add .` on this branch. Stage by submit slice.

## Latest Classification

Latest run:

```text
Submit slice inventory checks passed
- 1-project-scaffolding-release-gates: 10
- 2-shell-login-echo-prompt: 7
- 3-archive-core-creation: 11
- 4-profile-care-settings-legal: 4
- 5-source-warning-cleanup: 7
- 5-map-future-route-compatibility: 7
- 6-durable-docs: 12
- 6-optional-qa-evidence: 98
- local-only-generated-qa: 403
- local-only-stitch-cache: 4
```

The high `local-only-generated-qa` count is expected because prior simulator runs produced screenshots, build logs, app path files, cached HTML, and temporary compiled check binaries. These remain classified so they do not get mistaken for source work.

## Verification

- Submit slice inventory guard passed.
- Release QA package guard passed with latest smoke `20260617-backend-build-config`.
- `git diff --check` passed.
- `plutil -lint DreamJourney/Resources/Info.plist` passed.
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj` passed.
- iOS Simulator Debug build passed:
  `tmp/visual-qa/prd-stitch-ui/backend-build-config/20260617-current/build-default-debug.log`.
