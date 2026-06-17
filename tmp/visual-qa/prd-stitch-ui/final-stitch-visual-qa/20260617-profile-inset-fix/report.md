# Final Stitch Visual QA Refresh

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Purpose: refresh the Stitch visual QA package after app-source warning cleanup and the Profile floating-tabbar bottom inset fix.

## Source Evidence

Stitch project:

```text
projects/2650033127117292960
```

Visual authority:

```text
current Stitch canvas and downloaded `htmlCode`
```

Downloaded Stitch sources:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-profile-inset-fix/stitch/
```

App screenshots:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-profile-inset-fix/app/
```

## Captured App Screens

| File | Mode | Screen |
| --- | --- | --- |
| `01-login.png` | Default logged-out | Login |
| `02-echo-default.png` | Default public release surface | Echo |
| `03-archive-default.png` | Default public release surface | Archive |
| `04-profile-default.png` | Default public release surface | Profile |
| `05-echo-stitch-qa.png` | Internal Stitch QA | Echo |
| `06-archive-stitch-qa-hidden-branches.png` | Internal Stitch QA with `DJEnableArchiveHiddenBranches` | Archive full visual structure |
| `07-profile-stitch-qa-hidden-branches.png` | Internal Stitch QA with `DJEnableProfileHiddenBranches` | Profile full visual structure at top position |
| `08-profile-stitch-qa-hidden-branches-scrolled-bottom.png` | Internal Stitch QA with `DJEnableProfileHiddenBranches` | Profile full visual structure after scrolling to bottom |

## Screen Findings

| Area | Result | Notes |
| --- | --- | --- |
| Login | Pass | Login remains light/cream, not black; title, subtitle, fields, CTA, and register prompt remain aligned to the Stitch composition. |
| Echo | Pass | Scenic background, quote bubble, microphone-first CTA, and single floating 3-tab navigation remain intact. |
| Archive default release | Pass for MVP release | Default surface still hides audio/persona/time-letter branches; CTA remains `文字、图片`. |
| Archive internal Stitch QA | Pass | With `DJEnableArchiveHiddenBranches`, `相册影像`, `语音档案`, `人格设定`, and `文字、图片、声音、时间信件` are visible. |
| Profile default release | Pass for MVP release | Default surface still exposes only `个人资料设置`, `法律法规`, and `退出登录`; hidden PRD branches are not public. |
| Profile internal Stitch QA | Pass | Full list remains available under `DJEnableProfileHiddenBranches`. The bottom inset fix lets `注销账户` scroll fully above the floating tabbar; `08-profile-stitch-qa-hidden-branches-scrolled-bottom.png` is the proof screenshot. |

## Release-Gated Differences

These are expected differences between current public app behavior and the full Stitch canvas:

- Archive hides `语音档案`, `人格设定`, `录入语音`, and `录入时间信件` by default.
- Profile hides `立即通话`, `家人管理`, and `注销账户` by default.
- Echo remains voice-first and does not expose text/image input controls.

Hidden visual branches remain available only through explicit internal QA launch arguments:

```text
DJEnableArchiveHiddenBranches
DJEnableProfileHiddenBranches
```

## Verification

Core archive-to-echo smoke:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-profile-inset-fix/
```

Result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

iOS build:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-profile-inset-fix/build-final.log
```

Result: passed.

Profile scroll inset guard:

```bash
swift tmp/visual-qa/prd-stitch-ui/profile-scroll-inset-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.

## Verdict

The current UIKit implementation remains aligned enough for the MVP release target. The prior internal Profile full-list bottom readability issue is resolved by explicit floating-tabbar scroll insets.
