# Hidden Family / Voice UIQA

Date: 2026-06-19

## Scope

把 family digital-human 与 voice profile 后端合同推进到隐藏 UIQA 层，证明 App 不只是静态持有字段，而是能把 backend-shaped payload 解析、注入隐藏页面/shell，并输出可回归的 JSON 证据。

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

不开放公开入口：

- `familyManagement` 不进入默认 feature flags。
- `familySpace` 不进入默认 feature flags。
- `voiceCloneShell` 不进入默认 feature flags。
- `DJEnableProfileHiddenBranches` 只在 simulator UIQA 编译条件下生效。

## Verification

```bash
swift tmp/visual-qa/prd-stitch-ui/ios-family-voice-hidden-uiqa-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
tmp/visual-qa/prd-stitch-ui/run-profile-family-persona-release-smoke.sh
```

该检查已接入 release regression 和 release QA package。
