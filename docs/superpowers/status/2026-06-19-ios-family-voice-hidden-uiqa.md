# Hidden Family / Voice UIQA

Date: 2026-06-19

## Scope

把 family digital-human 与 voice profile 后端合同推进到 UIQA 层，证明 App 不只是静态持有字段，而是能把 backend-shaped payload 解析、注入 family 页面 / voice shell，并输出可回归的 JSON 证据。2026-06-20 起，voice clone entry has since been promoted to a public foundation；本文件保留为 family/voice 后端字段消费证据。

## Contract

- Family fixture 走 `FamilyMember.fromBackendJSON`。
- Family hidden page 通过 `FamilyRepository.refreshFromBackend` 消费 typed backend client。
- Smoke result 输出：
  - `backendFamilyDigitalHumanMode`
  - `backendFamilyPersonaContractVersion`
  - `backendFamilyContractMode`
  - `backendFamilyDefaultReleaseVisible`
  - `backendFamilyRenderedInRepository`
- Voice fixture 走 `VoiceCloneProfileContract(json:)` 和 `VoiceCloneService.voiceCloneShellSnapshot(from:)`。
- Smoke result 输出：
  - `backendVoiceProfileId`
  - `backendVoiceSampleStatus`
  - `backendVoiceProviderMode`
  - `backendVoiceDefaultReleaseVisible`
  - `backendVoiceShellRendered`

## Release Boundary

当前公开边界：

- `familyManagement`、`familySpace`、`voiceCloneShell` 已进入默认 feature flags。
- `voiceCloneShell` 公开基础能力仅覆盖授权、音频样本提交、状态刷新、禁用、删除；真实样本质量和 provider-side 复刻效果仍需外部验收。
- `family` 的高级生命周期控制仍不公开。
- `DJEnableProfileHiddenBranches` 只在 simulator UIQA 编译条件下生效。

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/ios-family-voice-hidden-uiqa-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-profile-family-persona-release-smoke.sh
```

该检查已接入 release regression 和 release QA package。
