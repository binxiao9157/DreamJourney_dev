# Release QA Handoff

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

Base remote commit: `0f64248 feat: adapt PRD Stitch UI flows`

Current HEAD before this handoff commit: `d360799 feat: add profile safety flow shells`

## Current Branch Delta

Commits ahead of `origin/feature/prd-stitch-ui-adaptation`:

```text
d360799 feat: add profile safety flow shells
f656d02 feat: add hidden family persona switcher
7b173ea docs: add device backend readiness package
d3e5e4a feat: scope archive context by persona
560165d docs: add PRD continuation ledger
```

## Release QA Result

Status: simulator and static QA passed.

This does not mean true-device or real-backend acceptance has passed. Those still require user-provided backend URL/token, signing, and device operation.

## Commands Run

```bash
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-family-persona-switcher-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/profile-safety-flow-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/group4-profile-care-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/persona-scoped-archive-context-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/device-backend-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-build-config-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-env-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/submit-slice-inventory-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260618-release-qa-handoff tmp/visual-qa/prd-stitch-ui/run-archive-to-echo-smoke.sh
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/release-qa-handoff/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Core Smoke Result

Result file:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260618-release-qa-handoff/archive-to-echo-smoke-result.json
```

Result:

```json
{"availableItemCount":1,"completed":true,"containsArchiveContext":true,"entries":"相册影像（相册）"}
```

Screenshot:

```text
tmp/visual-qa/prd-stitch-ui/archive-to-echo-smoke/20260618-release-qa-handoff/01-archive-to-echo-completed.png
```

Build log:

```text
tmp/visual-qa/prd-stitch-ui/release-qa-handoff/20260618-current/build-debug.log
```

## Implemented PRD Surface

- `记忆档案 -> 回响` simulator core loop passes.
- Persona-scoped archive/echo context is implemented.
- Hidden family persona switcher writes `DigitalHumanContextStore`.
- Profile safety shells exist for account deletion and doctor contact without executing destructive or external actions.
- Care visibility is centralized through a selected-context helper.
- Real-device/backend readiness runbook exists.

## Still Hidden

These remain hidden by default:

- Family management / family space public release.
- Account deletion execution.
- Doctor call / intervention execution.
- Audio archive, time letters, remote fetch, local analysis debug controls.
- Full sunlight/star/silent mode management.
- Digital inheritance lifecycle.

## External Acceptance Still Needed

Real backend:

- User provides `DREAMJOURNEY_BACKEND_BASE_URL`.
- User provides `DREAMJOURNEY_BACKEND_API_TOKEN`.
- Run `tmp/visual-qa/prd-stitch-ui/run-backend-env-smoke.sh`.

True device:

- User provides signing/device operation.
- Validate microphone, photo library, speech recognition, camera/privacy prompts.
- Validate real voice/photo flows and background/foreground recovery.

## Known Residual Risks

- Third-party/asset warnings remain in Xcode build logs, but Debug builds passed.
- Public family management and safety-critical execution flows still need product/legal/backend decisions before release.
- Stitch UI can still change; rerun final visual QA and the archive-to-echo smoke after each Stitch update.

## Next Recommended Step

Use this handoff as the baseline for any push/PR. If continuing development before handoff, the next highest-value task is true backend smoke once real URL/token are provided, otherwise final visual QA against the newest Stitch canvas/htmlCode.
