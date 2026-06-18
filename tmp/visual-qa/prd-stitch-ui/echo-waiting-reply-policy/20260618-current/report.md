# Echo Waiting Reply Policy QA

Run ID: `20260618-current`

## Scope

- Verify the public Echo default policy for waiting reply.
- Keep Echo voice-first.
- Do not expose text/image input controls.
- Do not switch to any candidate Stitch Echo variant.

## Result

- The UIQA preview now drives three final user voice turns.
- The first two turns can receive immediate replies.
- The third turn enters waiting reply state.
- The visible waiting copy is `约 5 分钟后再听`.

## Evidence

- Screenshot: `01-echo-waiting-reply-third-turn.jpg`
- UI text observed by simulator automation:
  - `第三次想起这件事`
  - `约 5 分钟后再听`

## Commands

```bash
swift tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy/20260618-current/DerivedData CODE_SIGNING_ALLOWED=NO SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG UI_QA_SIMULATOR' EXCLUDED_ARCHS='' ARCHS=arm64 ONLY_ACTIVE_ARCH=NO build
```
