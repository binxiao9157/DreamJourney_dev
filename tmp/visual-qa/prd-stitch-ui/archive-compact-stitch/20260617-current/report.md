# Archive Compact Stitch Alignment

Date: 2026-06-17

Visual source of truth:
- Current Stitch canvas and downloaded `htmlCode` remain the primary reference.
- MCP/runtime screenshots are auxiliary evidence only.

Scope:
- Centralized Archive root layout constants for top spacing, stack rhythm, bento grid, CTA, and timeline rows.
- Centralized Archive creation Sheet layout constants and tightened title/option-row density while keeping tappable row height.
- Kept release gating unchanged: default release mode exposes text/photo creation only; audio, time-letter, and persona branches require `DJEnableArchiveHiddenBranches`.

Evidence:
- `01-archive-compact-default.png`: default Archive release-like page; CTA reads `文字、图片`.
- `02-archive-create-sheet-default.png`: default creation Sheet; only text/photo options are visible.
- `03-archive-compact-hidden-branches.png`: internal UIQA Archive page; bento/CTA restore audio/persona/time-letter comparison branches.
- `04-archive-create-sheet-hidden-branches.png`: internal UIQA creation Sheet; all four creation options are visible.

Validation:
- `swift tmp/visual-qa/prd-stitch-ui/archive-compact-stitch-layout-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/group3-archive-core-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveCompactStitch CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build`

Result:
- Source guards passed.
- iOS Debug simulator build succeeded.
- Simulator smoke confirmed both default release-like state and hidden-branch UIQA state.
