# Final Stitch Visual QA

Date: 2026-06-17

Branch: `feature/prd-stitch-ui-adaptation`

Goal: compare the current UIKit implementation against the current Stitch canvas and downloaded `htmlCode`, while keeping release-gated PRD behavior separate from visual mismatch findings.

## Source Evidence

Stitch project:

```text
projects/2650033127117292960
```

Stitch update time:

```text
2026-06-16T15:15:17.747640Z
```

Downloaded Stitch sources:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-current/stitch/
```

App screenshots:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-current/app/
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
| `07-profile-stitch-qa-hidden-branches.png` | Internal Stitch QA with `DJEnableProfileHiddenBranches` | Profile full visual structure |

## Screen Findings

| Area | Result | Notes |
| --- | --- | --- |
| Login | Pass | Background, centered title, subtitle, pill fields, forgot password, primary CTA, and register prompt match the Stitch composition. Device status bar / Dynamic Island creates more top visual chrome than the Stitch export; this is expected for real simulator screenshots. |
| Echo | Pass | Uses the same scenic background direction, quote bubble, microphone-first CTA, and floating 3-tab navigation. App screenshot is taller than the Stitch 390-wide canvas export, so more background image is visible. |
| Archive default release | Pass for MVP release | Default surface intentionally hides `语音档案`, `人格设定`, and time-letter/audio creation. Public CTA correctly reads `文字、图片`. This differs from the full Stitch visual canvas by release-gating policy, not by accidental UI drift. |
| Archive internal Stitch QA | Pass | With `DJEnableArchiveHiddenBranches`, archive restores the full Stitch structure: `相册影像`, `语音档案`, `人格设定`, and `文字、图片、声音、时间信件`. |
| Profile default release | Pass for MVP release | Default surface intentionally hides `立即通话`, `家人管理`, and `注销账户`; visible rows are `个人资料设置`, `法律法规`, and `退出登录`, matching the release feature matrix. |
| Profile internal Stitch QA | Pass with minor non-release note | With `DJEnableProfileHiddenBranches`, the full Stitch list is available. On iPhone 17 at top scroll position, the last `注销账户` row sits close to / partly behind the floating tabbar. This affects internal full-list QA only; the default release profile screenshot is not affected. |

## Release-Gated Differences

These are expected differences between current public app behavior and the full Stitch canvas:

- Archive hides `语音档案`, `人格设定`, `录入语音`, and `录入时间信件` by default.
- Profile hides `立即通话`, `家人管理`, and `注销账户` by default.
- Echo remains voice-first and does not expose text/image input controls.

The corresponding hidden visual branches are still available through explicit internal QA launch arguments:

```text
DJEnableArchiveHiddenBranches
DJEnableProfileHiddenBranches
```

## Verdict

The implementation remains visually aligned enough for the current MVP release target. The primary remaining visual risk is not default release UI drift; it is future Stitch updates changing the full-canvas hidden branches faster than the UIKit implementation is refreshed.

Before branch closure, keep this report paired with the release feature matrix so reviewers can distinguish intentional hidden-release differences from accidental visual mismatch.

## Verification

Static release checks:

```bash
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

Result: passed.

Whitespace / plist:

```bash
git diff --check
plutil -lint DreamJourney/Resources/Info.plist DreamJourney.xcodeproj/project.pbxproj
```

Result: passed.

iOS build:

```text
tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260617-current/build-final.log
```

Result: passed. Remaining warnings are from Kingfisher dependency whitespace in Swift 6 mode.

Core archive-to-echo smoke:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260617-final-visual-package/
```

Result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```
