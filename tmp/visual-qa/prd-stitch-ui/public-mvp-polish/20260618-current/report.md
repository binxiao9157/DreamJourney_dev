# Public MVP UI Polish

Run ID: `20260618-current`

## Source Evidence

- App baseline screenshots copied from `tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/app/`.
- Stitch references copied from `tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/stitch/`.
- Visual authority remains current Stitch canvas + downloaded `htmlCode`; MCP metadata is auxiliary only.

## Accepted Release-Gated Differences

- Archive default release intentionally exposes only `相册影像` plus `封存新记忆` for `文字、图片`; `语音档案`, `人格设定`, and `时间信件` remain hidden.
- Profile default release intentionally keeps hidden `家人管理`, `立即通话`, and `注销账户` out of the public surface.
- Echo remains the current scenic voice-first public surface; newer Stitch Echo variants are candidates only until explicitly selected.

## Public UI Issues To Fix

- Fixed in this slice: archive header typography was too hero-scale compared with the current Stitch archive screen, pushing the public timeline lower on first load.
- Change made: centralized archive header stack spacing and title/subtitle font sizes in `ArchiveLayout`, reducing the archive title from `40` to `32` and subtitle from `16` to `14`.
- Not changed in this slice: archive bento height, primary CTA height, tab labels, release feature flags, and hidden archive/profile entries.

## Hidden Features Not Exposed

- Archive hidden branches remain behind `DJEnableArchiveHiddenBranches` or explicit feature flags.
- Profile hidden branches remain behind `DJEnableProfileHiddenBranches` or explicit feature flags.
- No new tab, button, or route was exposed in default release mode.

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-compact-stitch-layout-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-public-mvp-polish tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/public-mvp-polish/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO build
```

All checks passed. The release regression's Archive -> Echo smoke completed with `containsArchiveContext=true`.

## Screenshot Evidence

- Baseline Echo: `01-echo-default.png`
- Baseline Archive: `02-archive-default.png`
- Baseline Profile: `03-profile-default.png`
- Post-polish Archive: `04-archive-post-polish.png`
- Post-polish Echo seed state: `04-echo-seed-state.png`
