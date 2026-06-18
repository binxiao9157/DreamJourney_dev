# Archive Media Release Readiness

Date: 2026-06-18

Branch: `feature/prd-stitch-ui-adaptation`

## Scope

This slice keeps the current Stitch-aligned archive UI stable while making PRD media boundaries explicit in code:

- Public archive creation remains `添加文字描述` and `选择照片`.
- Hidden QA/development archive creation remains `录入语音` and `录入时间信件`.
- Video is still not available and must not appear in creation options.

## Release Boundary

| Capability | Current State | Gate | Persistence | Notes |
| --- | --- | --- | --- | --- |
| Text archive | Public | None | `local_user_defaults` | Feeds archive timeline and Echo context. |
| Photo archive | Public | None | `local_file` | Feeds archive timeline and Echo context. |
| Audio archive | Hidden ready | `archiveAudioUpload` or `DJEnableArchiveHiddenBranches` | `local_file` | Requires microphone permission and true-device permission recovery QA before public release. |
| Time letter | Hidden ready | `timeLetters` or `DJEnableArchiveHiddenBranches` | `local_user_defaults` | Needs delivery/reminder/family visibility product rules before public release. |
| Video | Unavailable | Not exposed | `not_available` | Copy remains `视频素材录入将在后续开放`. |

## Verification

Run after changes to archive creation, media persistence, feature flags, or release QA:

```bash
swift tmp/visual-qa/prd-stitch-ui/archive-media-release-readiness-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/archive-media-entries-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-archive-media-entries-smoke.sh
swift tmp/visual-qa/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

`run-archive-media-entries-smoke.sh` builds the UIQA simulator app, resets persisted feature flags, and checks the creation option matrix:

- release mode: `添加文字描述`, `选择照片`
- hidden QA mode: `添加文字描述`, `选择照片`, `录入语音`, `录入时间信件`
- video remains unavailable
- audio keeps the microphone-permission boundary
