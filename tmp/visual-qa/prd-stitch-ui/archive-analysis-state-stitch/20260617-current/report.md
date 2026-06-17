# Archive Analysis State Stitch Alignment

Date: 2026-06-17

Visual source of truth:
- Current Stitch canvas and downloaded `htmlCode` remain the primary reference.
- MCP/runtime screenshots are auxiliary evidence only.

Scope:
- Reworked the archive detail analysis card into a Stitch-aligned state block.
- Added a status header for `待生成` / `已生成`.
- Moved analysis summary into a warm inset panel.
- Rendered tags and people as dedicated insight sections.
- Preserved the existing local analysis data flow: `applyLocalAnalysisResult`, repository update, and archive-to-echo prompt context.

Evidence:
- `01-analysis-pending-state.png`: detail analysis card before tapping `生成本地分析`.
- `02-analysis-generated-state.png`: detail analysis card after local analysis; status changes to `已生成`, tags include `场景线索`, and the nav action is removed.
- Latest archive-to-echo core smoke: `tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-204851/`.

Validation:
- `swift tmp/visual-qa/prd-stitch-ui/archive-analysis-state-stitch-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/archive-timeline-detail-stitch-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift tmp/visual-qa/prd-stitch-ui/archive-local-analysis-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveAnalysisStateStitch CODE_SIGNING_ALLOWED=NO EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build`
- `tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh`

Result:
- Source guards passed.
- iOS Debug simulator build succeeded.
- Simulator smoke confirmed pending and generated analysis states.
- Archive-to-echo smoke completed with `containsArchiveContext=true`.
