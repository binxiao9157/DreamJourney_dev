# WI-S1-03-08 Voice / TTS / Digital Human Cross-Path G0 集成审查

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-08`
- Authority lock：`IOS_COMPOSITION`
- 当前结果：`INTERNAL_READY / G0_CROSSPATH_VERIFIED / IOS_LOCAL_COMMITTED / G1_G3_G4_OPEN`
- 本地 G0 六个切片均已完成：typed client ports、owner-keyed Memoir cache identity、VoiceClone
  training runtime binding、runtime capability/lease expiry fail-closed、普通 Echo DialogEngine scoped selection、
  Memoir author-scoped selection。

本结论只代表本地组合边界可以被静态/模型 Gate 与无签名 iOS 构建证明；不代表火山或腾讯 Provider、真实音频、
腾讯会话、音色听感、设备麦克风、删除回执或公开 M1/M2 已验收。

## 三条播放路径审查

| 路径 | 音色选择来源 | 账户/角色边界 | capability 行为 |
| --- | --- | --- | --- |
| 普通 Echo 本地 SpeechEngine | 当前 `DialogEngineBindingHandle` 的 scoped selection | `bindingID + AccountLease + lifecycleGeneration`；低代际与旧账户不能覆盖 | 不可合成或能力未知时显式写入空 profile，使用默认普通音色 |
| 回忆录试听 | `MemoirModel.speakerId`，或作者自己的 personal profile | 仅 `memoir.authorId` 对应的当前 AccountLease；不读取当前 Echo 家人角色 | 无明确可用作者 profile 时不走复刻合成，UI 保留系统朗读降级 |
| 腾讯数智人 PCM audio-drive | `EchoRoleVoiceProfileSelection` 的显式当前角色选择 | Echo lifecycle/context token、数字人 session lease 与 runtime interaction token | capability 未知/不支持或 contract 不可用时 fail-closed；腾讯 route 关闭本地 SpeechEngine 播放 |

## 已消除的跨路径风险

1. `DialogEngineManager` 不再直接读取 process-global `currentUsableSpeakerId`，角色切换后不会由旧异步状态覆盖普通 Echo。
2. `MemoirTTSService` 和回忆录详情不再将“当前页面选中的家人”当作作者音色 fallback；首次合成在请求前冻结作者
   对应的 profile，成功后只保存该次已选择的 profile。
3. 腾讯数智人 audio-drive 与本地 SpeechEngine 仍然是互斥 audio owner；本审查没有重新打开旧的本地播放旁路。
4. capability、credential 与 lease 的未知、过期或不完整状态不会隐式走默认复刻音色或真实腾讯 session。

## 验证

```bash
python3 Scripts/QA/product-v4/voice-tts-account-lease-check.py
python3 Scripts/QA/product-v4/memoir-tts-cache-owner-scope-check.py
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-dh-account-lifecycle-gate.sh
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- 静态检查确认 `DialogEngineManager` 和 `MemoirTTSService` 均不再按当前 UI persona 读取全局可用复刻 profile；
- owner-scope 和 account-lifecycle 组合 Gate 覆盖缓存、数字人 context、runtime capability、session lease 与新的
  Memoir/普通 Echo selection 边界；
- `build-for-testing` 在 `generic/platform=iOS` 与 `CODE_SIGNING_ALLOWED=NO` 下成功；既有第三方地图库
  warning 未由本 Work Item 引入；
- `git diff --check` 通过。

## 未关闭 Gate

- G1：模拟器 UIQA 与发布态暴露检查；
- G3：Provider 凭据、配额、合成质量、数据处理与删除/退出 receipt；
- G4：真机会话、有声、口型、打断、麦克风恢复以及产品/隐私/法律验收。

## 后续交接

下一 Work Item 为 `WI-S1-03-09`：通知与 deeplink runtime owner routing。它只能消费已经 owner-scoped 的
payload，不能因提醒点击、延迟 callback 或账户切换重新激活旧的 Voice/Digital Human runtime，也不能扩大公开发布范围。
