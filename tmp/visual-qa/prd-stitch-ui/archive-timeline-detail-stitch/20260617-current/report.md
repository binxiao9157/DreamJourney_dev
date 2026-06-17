# Archive Timeline And Detail Stitch Alignment

Date: 2026-06-17

Visual source of truth:
- Current Stitch canvas and downloaded `htmlCode` remain the primary reference.
- MCP/runtime screenshots are auxiliary evidence only.

Scope:
- Real archive items now render through Stitch-style timeline cards instead of the older compact horizontal row.
- Photo timeline cards use a large media card structure with a polished no-image placeholder state.
- Audio timeline cards use the compact rounded player pattern from Stitch.
- Text/time-letter/video items keep a compact card fallback without exposing hidden release branches.
- Archive detail layout now centralizes Stitch-sensitive spacing and uses a lighter photo placeholder state.

Evidence:
- `01-archive-timeline-card-default.png`: default release-like Archive page with real seeded photo item rendered as a large timeline card.
- `02-archive-detail-default.png`: detail page entered from the seeded item; pushed detail view keeps the floating tab bar hidden.

Validation:
- `swift tmp/visual-qa/prd-stitch-ui/archive-timeline-detail-stitch-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/archive-compact-stitch-layout-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveTimelineDetailStitch CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build`

Result:
- Source guards passed.
- iOS Debug simulator build succeeded.
- Simulator smoke confirmed default release-like Archive entry visibility and detail navigation.
