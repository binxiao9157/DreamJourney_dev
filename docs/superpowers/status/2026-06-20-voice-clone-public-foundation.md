# 音色复刻公开基础功能

Date: 2026-06-20

Branch: `feature/prd-stitch-ui-adaptation`

## Product Decision

用户已明确：音色复刻功能放开，不再作为默认隐藏功能处理。

本轮实现把 `DJFeature.voiceCloneShell` 加入默认启用列表，并将功能从“只读安全壳层”推进为公开基础闭环。

## Implemented Scope

- `我的` 页面公开显示 `音色复刻` 入口。
- 音色复刻页已按 Product Design pass 收敛为用户可理解的三块信息：当前音色状态、授权与样本、训练与管理。
- `voiceProfileId`、provider mode 和合同版本仍由后端合同/静态检查覆盖，但不再作为用户可见字段展示。
- 用户必须先确认本人授权，才可选择音频样本提交训练。
- iOS 通过后端代理提交训练，不直连火山音色复刻 API，也不保存火山密钥。
- 支持刷新训练状态。
- 支持通过后端合同禁用音色。
- 支持通过后端合同删除音色。
- `trainVoice` 必须由调用方显式传入 `authorizationConfirmed`，不会由 service 默认伪造授权。
- `MemoirFlowManager` 不再用普通录音自动发起音色复刻训练；只有已有授权 `voiceProfileId` 时才等待音色就绪。
- 禁用音色后不再被 `isVoiceReady` 判定为可用于 TTS。
- 后端接收 pending profile 后，UI 会立即转译为“样本已提交/训练中”状态，不等训练最终完成。
- 发布矩阵和 PRD 覆盖矩阵已更新为公开基础功能口径。

## Still Not Claimed Complete

- 真实麦克风采样质量、样本时长、噪声、说话人一致性仍需真机验收。
- 火山 provider 真实训练成功率和真实复刻音色 TTS 质量仍需外部验收。
- 授权文案、样本质量政策和 consent audit 仍需产品/合规复核。
- provider-side disable/delete 的真实后台效果仍需部署后端 smoke 和人工复核。

## Verification

```bash
swift Scripts/QA/prd-stitch-ui/voice-clone-shell-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/voice-clone-backend-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/ios-family-voice-consumer-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/ios-family-voice-hidden-uiqa-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-feature-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/prd-coverage-matrix-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/profile-release-gating-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/voice-clone-public-foundation-build build
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/voice-clone-public-foundation-arm64-build ARCHS=arm64 EXCLUDED_ARCHS= build
```

## Verification Result

- Static guards passed, including authorization-required and disabled-not-ready checks.
- Release QA package passed; historical visual evidence folders that are incomplete were skipped by the existing package script.
- `git diff --check` passed.
- Standard simulator build passed.
- Arm64 simulator build passed and was installed on the booted simulator.
- Simulator smoke confirmed `我的 -> 音色复刻` is visible and the detail page shows authorization, user-facing status, submit, refresh, disable, and delete controls.
- Screenshot: `tmp/visual-qa/prd-stitch-ui/voice-clone-public-foundation-smoke/profile-voice-clone-public-detail-rerun.jpg`.
- Backend repo had no code changes. Local backend voice-profile tests could not run in the current shell because `fastapi`, `psycopg`, and `pytest` are not installed; existing backend contract is still guarded by iOS static checks and previous backend tests.

后续如修改 `FeatureFlagService`、`ProfileViewController`、`ProfileVoiceCloneShellViewController`、`VoiceCloneService` 或 `/voice/profiles` 合同，需要重新运行上述检查，并补真机音频样本验收记录。
