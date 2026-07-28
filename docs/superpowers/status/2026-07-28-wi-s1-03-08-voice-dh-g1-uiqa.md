# WI-S1-03-08 G1：角色音色与数字人降级模拟器 UIQA

日期：2026-07-28
Work Item：`WI-S1-03-08`
Authority lock：`IOS_COMPOSITION`

## 结论

`G1 = SCOPED_VERIFIED`。

本轮验证 Voice / Digital Human client port、角色音色选择和 Echo 页面降级状态在模拟器 QA 路径中一致：

1. 家庭成员角色的页面身份徽标与 runtime diagnostics 使用同一角色上下文。
2. 角色音色诊断仍为 `familyMember`，音频归属仍为 `tencentDigitalHuman`，且导出的证据包不包含明文私有值。
3. 当数智人 session 因缺少可撤销 scoped credential 被后端拒绝时，页面明确显示“数字人暂不可用，已回到普通回响”。
4. 该拒绝不会保留腾讯数智人 audio owner，也不会创建真实 Tencent runtime。

这只是 G1 模拟器状态和 UIQA 证据，不等同于 Provider、真机音频、口型、打断、麦克风恢复或公开 Voice/Digital Human 功能完成。

## 本轮实现

所有行为都位于 `UI_QA_SIMULATOR` 测试编排路径，未改变公开 Echo 视觉、真实 Provider 路由或发布态能力。

- `runUIQAEchoTraceEvidencePackagePanelExportSmoke` 在注入 QA 家庭角色后刷新身份徽标，并将徽标与 runtime role voice diagnostics 的一致性写入结果。
- `runUIQADigitalHumanRuntimeStubSmoke` 在预期的 scoped broker 拒绝时调用现有 fail-closed 路径，再断言普通 Echo 的可见降级文案和非腾讯 audio owner。
- 两个 smoke runner 增加 JSON 断言，防止以后仅有后台字段正确、页面仍显示旧角色或“连接中”状态。

## 验证

```bash
bash Scripts/QA/prd-stitch-ui/run-echo-trace-evidence-package-panel-export-smoke.sh
bash Scripts/QA/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
swift Scripts/QA/prd-stitch-ui/echo-role-voice-profile-selection-check.swift .
swift Scripts/QA/prd-stitch-ui/digital-human-runtime-abstraction-check.swift .
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
git diff --check
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath tmp/visual-qa/product-v4/DerivedDataWIS10308G1 \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  DREAMJOURNEY_PRODUCT_BUNDLE_IDENTIFIER=com.yxj.dreamjourney.app \
  DREAMJOURNEY_DEVELOPMENT_TEAM=2BTR77V3R8
```

结果：全部通过；`generic/platform=iOS` 输出 `TEST BUILD SUCCEEDED`。`release-qa-package-check.swift` 对缺失的历史视觉证据目录只做既有 skip，不影响本轮检查结果。

本轮模拟器证据：

```text
tmp/visual-qa/prd-stitch-ui/echo-trace-evidence-package-panel-export-smoke/20260728-100835/
tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260728-100835/
```

关键结果：

- `personaBadgeMatchesFamily=true`
- `personaBadgeName=UIQA 家人音色 · AI 数字分身`
- `latestRuntimeRoleVoiceSource=familyMember`
- `latestRuntimeAudioOwner=tencentDigitalHuman`
- `fallbackMode=textOnly`
- `visibleFallback=true`
- `visibleFallbackDetail=数字人暂不可用，已回到普通回响`
- `audioOwner=volcengineLocalTTS`

## 未关闭 Gate

- `G3`：真实 Provider credential、配额、质量、删除/退出 receipt 和成本边界。
- `G4`：真实腾讯数智人 session、PCM 有声/口型、打断、蓝牙、前后台和麦克风恢复。
- 角色切换后的真实 Profile 听感一致性，以及真机上“试听音色 = Echo 数字人音色”。

因此本轮不部署后端、不提升 Registry 生命周期，也不将 Voice/Digital Human 作为公开完成能力。
