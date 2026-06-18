# Elder Care Dashboard

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Scope

This slice promotes the PRD 5.4 `长辈关怀` child-facing dashboard from a profile card summary into a navigable aggregate-results page.

## What Changed

- Added `ProfileElderCareDashboardViewController`.
- The Profile `心境追踪` card is now tappable and pushes the dashboard.
- The dashboard reuses the existing `ProfileCareSnapshot` model and selected `DigitalHumanContext`.
- The page shows aggregate fields only:
  - `情绪指数`
  - `认知指数`
  - `睡眠状态`
  - `孤独指数`
  - `风险提醒`
- The page states the privacy boundary:
  - `仅查看结果`
  - `不查看聊天内容`

## Release Boundary

- This is part of the default `careDashboard` public surface.
- It does not expose raw chat history or message transcripts.
- It does not add new backend requirements; real backend acceptance still uses the existing care snapshot endpoint and `run-backend-env-smoke.sh`.
- It does not replace true-device acceptance.

## Verification

Simulator screenshot:

```text
tmp/visual-qa/prd-stitch-ui/elder-care-dashboard/20260618-current/01-elder-care-dashboard.jpg
```

Run:

```bash
swift tmp/visual-qa/prd-stitch-ui/elder-care-dashboard-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
