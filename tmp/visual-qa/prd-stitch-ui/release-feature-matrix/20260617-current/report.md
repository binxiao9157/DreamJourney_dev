# Release Feature Matrix QA

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Goal: make the current public/hidden PRD surface explicit and guard it with a repeatable source-level check.

## Source

- Matrix: `docs/superpowers/status/2026-06-17-release-feature-matrix.md`
- Guard: `tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift`
- Gap audit update: `docs/superpowers/status/2026-06-17-prd-stitch-ui-gap-audit.md`

## Verification

Static checks:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-settings-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-legal-center-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.

Whitespace / plist checks:

```bash
git diff --check
plutil -lint DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj
```

Result: passed.

iOS build:

```text
tmp/visual-qa/prd-stitch-ui/release-feature-matrix/20260617-current/build-final.log
```

Result: passed. Remaining warning is from Kingfisher dependency whitespace in Swift 6 mode.

Core PRD smoke:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-111540/
```

Result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-111540/01-archive-to-echo-completed.png
```

## Finding

The release feature matrix is now durable and checkable. The default public surface stays limited to archive text/photo creation, voice-first echo, profile settings, legal center, logout, and the care dashboard. Higher-risk or unfinished flows remain hidden behind `FeatureFlagService` or explicit UIQA hidden-branch launch arguments.
