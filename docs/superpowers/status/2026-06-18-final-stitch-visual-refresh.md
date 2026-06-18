# Final Stitch Visual Refresh

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Scope

Refresh final visual QA against the current Stitch project and local app screenshots.

Visual authority remains:

1. current Stitch canvas;
2. downloaded `htmlCode`;
3. MCP screenshot/runtime screenshots as auxiliary evidence only.

## Current Stitch Source

Project: `projects/2650033127117292960`

Project update time from MCP: `2026-06-17T16:11:21.576280Z`

Downloaded local source cache:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/stitch/
```

Current Stitch screen set observed in this pass:

| Area | Stitch title | Screen ID | Note |
| --- | --- | --- | --- |
| Login | `登录入口 - 往日与回响` | `3fcfe3aa2489492d82f56bd7efd55b11` | Still the light login target. |
| Archive | `记忆档案 - 悬浮导航版` | `6c38acaae2ce4d579331480ab678ed64` | Still aligns with archive release/hidden split. |
| Echo | `时空对话 - 活力少年版` | `3a713e9254f742fe8b6df81d9e400e9f` | New/alternate Echo direction. |
| Echo | `时空对话 - 沉浸阅读版` | `8f0966443829472fa16ed5cd974b7fdd` | Used as the compatibility `echo.html` source in this QA cache. |
| Echo | `时空对话 - 温馨家中版` | `f1d7279042ed4fd3a1d13d918c552f7f` | New/alternate Echo direction. |
| Care | `长辈关怀 - 子女看板 (子页面逻辑)` | `22c439c698074c468b4b2f75d100148e` | PRD care dashboard direction. |
| Care/Profile-like | `长辈关怀 - 悬浮导航版` | `174fe3acf33443ee9229b4230b36c6b7` | Hidden instance label was `我的 - 悬浮导航版`, but screen title is now care-focused. |

## App Evidence

App screenshots:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/app/
```

Captured files:

- `01-login.png`
- `02-echo-default.png`
- `03-archive-default.png`
- `04-profile-default.png`
- `05-echo-stitch-qa.png`
- `06-archive-stitch-qa-hidden-branches.png`
- `07-profile-stitch-qa-hidden-branches.png`
- `08-profile-stitch-qa-hidden-branches-scrolled-bottom.png`

## Findings

| Area | Result | Notes |
| --- | --- | --- |
| Login | Pass | Current app remains light/cream, not black. |
| Archive default release | Pass for current MVP | Default release still exposes text/photo only and hides audio/time-letter/persona branches. |
| Archive hidden QA | Pass | `DJEnableArchiveHiddenBranches` exposes `语音档案`, `人格设定`, and `文字、图片、声音、时间信件`. |
| Profile default release | Pass for current MVP | Default release keeps `个人资料设置`, `法律法规`, and `退出登录`; hidden PRD branches remain non-public. |
| Profile hidden QA | Pass | `立即通话`, `家人管理`, and `注销账户` remain available only under `DJEnableProfileHiddenBranches`; bottom tabbar does not cover `注销账户`. |
| Echo | Needs product/design decision | Stitch now has multiple Echo variants and no single `时空对话 - 悬浮导航版` public screen in `list_screens`. Current app still uses the previous scenic voice-first Echo. |
| Profile/Care IA | Needs product/design decision | Current Stitch title for the profile-like hidden instance is `长辈关怀 - 悬浮导航版`, while the app public tab remains `我的`. Do not rename or restructure without product confirmation. |

## Verification

Commands run:

```bash
swift tmp/visual-qa/prd-stitch-ui/final-visual-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-release-regression.sh
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/DerivedDataStandard CODE_SIGNING_ALLOWED=NO build
```

Result:

- Final visual QA package guard passed.
- Release QA package guard passed.
- One-command release regression passed.
- Standard iOS Debug simulator build passed.

## Decision

No app UI code was changed in this pass.

The current implementation remains acceptable for the current MVP release shell, but the newest Stitch canvas introduces a product/design decision point:

- Whether Echo should stay as the existing scenic voice-first screen or move toward one of the new Stitch variants.
- Whether `我的` should remain the third public tab or shift toward a public `长辈关怀` tab/surface.

Until that decision is made, keep the current PRD release gating intact.
