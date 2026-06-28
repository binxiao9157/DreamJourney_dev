# Group 6 Release QA Package Review

Date: 2026-06-17

Scope:

- `docs/superpowers/plans/2026-06-16-prd-stitch-ui-adaptation.md`
- `docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md`
- `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- `docs/superpowers/status/2026-06-17-pre-submit-inventory.md`
- `Scripts/QA/prd-stitch-ui/release-qa-package-check.swift`
- `Scripts/QA/prd-stitch-ui/final-visual-qa-package-check.swift`
- `Scripts/QA/prd-stitch-ui/submit-slice-inventory-check.swift`
- selected Group 1-5 QA reports/build logs
- latest archive-to-echo smoke result and screenshot

## Result

Group 6 now has a reusable QA package guard.

The new guard verifies that:

- Stitch/htmlCode remains the documented visual source of truth and MCP screenshots stay auxiliary;
- Group 1-5 review documents exist;
- Group 1-5 current reports and build logs exist and contain successful builds;
- release feature matrix and hidden-branch policy are documented;
- pre-submit inventory includes the submit grouping and avoids staging all of `tmp/`;
- the latest archive-to-echo smoke result exists, completed successfully, and contains archive context;
- the latest smoke screenshot exists;
- final Stitch/htmlCode visual QA evidence and release-state screenshots exist;
- generated DerivedData remains ignored.
- every dirty path is classified into a submit slice or explicit local-only generated-artifact bucket.

## Verification

- Group 1-6 guard scripts passed.
- `release-feature-matrix-check.swift` passed.
- `release-like-hidden-entries-check.swift` passed.
- `final-visual-qa-package-check.swift` passed.
- `profile-release-gating-check.swift` passed.
- `submit-slice-inventory-check.swift` passed.
- `group1-source-review-check.swift` passed.
- Submit slice inventory build passed:
  `tmp/visual-qa/prd-stitch-ui/submit-slice-inventory/20260617-current/build-final.log`.
- `git diff --check` passed.
- `plutil -lint DreamJourney/Resources/Info.plist` passed.
- `plutil -lint DreamJourney.xcodeproj/project.pbxproj` passed.
- iOS Simulator Debug build passed:
  `tmp/visual-qa/prd-stitch-ui/group6-release-qa-package/20260617-current/build-final.log`.
- Core archive-to-echo smoke passed with `completed=true` and `containsArchiveContext=true`:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/archive-to-echo-smoke-result.json`.
- Smoke screenshot:
  `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/01-archive-to-echo-completed.png`.

## Guard

Run:

```bash
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Expected output:

```text
Release QA package checks passed with latest smoke <run-id>
```

## Commit Hygiene

Keep source changes, durable docs, selected QA scripts, and generated artifacts separate during staging.

Recommended commit/review slices:

1. Project scaffolding and release gates.
2. Shell/login/echo/prompt context.
3. Archive core and creation branches.
4. Profile settings/legal/care gating.
5. Map simulator compatibility.
6. Docs and selected QA scripts/reports.

Do not stage `tmp/visual-qa/prd-stitch-ui/DerivedData*`, full build logs, runtime logs, OS logs, or obsolete intermediate screenshots unless there is an explicit review reason.

## Remaining Boundary

This package proves that the local QA evidence is coherent. It does not replace final product review against the current Stitch canvas/htmlCode, real backend verification, or device-level microphone/photo-library/voice-SDK checks.
