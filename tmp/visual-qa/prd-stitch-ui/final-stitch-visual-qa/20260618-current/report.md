# Final Stitch Visual QA Refresh

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Goal: refresh the local visual QA package against the current Stitch canvas and downloaded `htmlCode`, while keeping MCP/runtime screenshots auxiliary only.

## Source Evidence

Stitch project:

```text
projects/2650033127117292960
```

Stitch project update time:

```text
2026-06-17T16:11:21.576280Z
```

Visual authority:

```text
current Stitch canvas and downloaded `htmlCode`
```

Downloaded Stitch sources:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/stitch/
```

App screenshots:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/app/
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
| Login | Pass | Login remains light/cream, not black; title, subtitle, pill fields, CTA, and register prompt remain aligned to the Stitch composition. |
| Echo | Pass for current MVP, pending design decision | Current app keeps the scenic voice-first Echo. Stitch now exposes multiple Echo variants rather than a single prior floating-nav reference. |
| Archive default release | Pass for MVP release | Default surface still hides audio/persona/time-letter branches; CTA remains `文字、图片`. |
| Archive internal Stitch QA | Pass | With `DJEnableArchiveHiddenBranches`, `相册影像`, `语音档案`, `人格设定`, and `文字、图片、声音、时间信件` are visible. |
| Profile default release | Pass for MVP release | Default surface still exposes only `个人资料设置`, `法律法规`, and `退出登录`; hidden PRD branches are not public. |
| Profile internal Stitch QA | Pass | Full list remains available under `DJEnableProfileHiddenBranches`. The bottom inset keeps `注销账户` above the floating tabbar. |

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

## New Stitch Drift / Product Decision Points

- `list_screens` now returns three Echo variants: `时空对话 - 活力少年版`, `时空对话 - 沉浸阅读版`, and `时空对话 - 温馨家中版`.
- The profile-like hidden instance label was `我的 - 悬浮导航版`, but the current screen title is `长辈关怀 - 悬浮导航版`.
- The app still uses the PRD MVP tab shell `记忆档案 / 回响 / 我的`.

Do not rename the public `我的` tab or rework Echo toward one of the new variants without product confirmation.

## Verification

Final visual QA guard:

```bash
swift tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Release QA guard:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

One-command release regression:

```bash
RUN_ID=20260618-one-command-release-regression tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
```

iOS standard build:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/build-final.log
```

Result: passed.

## Verdict

The current UIKit implementation remains aligned enough for the existing MVP release target. The main open item is not a local visual bug; it is a product/design decision about whether the newest Stitch Echo variants and care-focused profile surface should replace the current release shell.
