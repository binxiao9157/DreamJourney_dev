# Profile Compact Stitch Alignment

Date: 2026-06-17

Scope:

```text
DreamJourney/Sources/Modules/Profile/ProfileViewController.swift
tmp/visual-qa/prd-stitch-ui/profile-compact-stitch-layout-check.swift
```

Visual source of truth:

```text
tmp/stitch/profile.html
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-profile-inset-fix/stitch/profile.png
```

## Result

The Profile root now uses centralized `ProfileLayout` constants for the Stitch-sensitive vertical rhythm:

- top content margin
- persona avatar scale
- persona title/subtitle scale
- persona-to-care spacing
- care card padding
- care signal height
- settings row minimum height

The goal was to make `我的` feel closer to the compact Stitch profile target without changing release gating or backend/care behavior.

## Evidence

Default release profile:

```text
tmp/visual-qa/prd-stitch-ui/profile-compact-stitch/20260617-current/01-profile-compact-default.png
```

Internal Stitch QA profile with hidden branches:

```text
tmp/visual-qa/prd-stitch-ui/profile-compact-stitch/20260617-current/02-profile-compact-hidden-branches.png
```

The hidden-branch screenshot keeps `立即通话`, `家人管理`, and `注销账户` available only under `DJEnableProfileHiddenBranches`; the default screenshot keeps those branches hidden.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-compact-stitch-layout-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataProfileCompactStitch CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
swift tmp/visual-qa/prd-stitch-ui/profile-scroll-inset-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.
