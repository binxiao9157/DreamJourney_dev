# WI-S1-03-08 DialogEngine 本地 TTS 角色选择边界

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-08`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`SUBSLICE_COMPLETE / FIVE_G0_SLICES_VERIFIED / FINAL_G0_INTEGRATION_REVIEW_PENDING / G1_G3_G4_OPEN`
- 新增切片：`WI-S1-03-08-DIALOG_ENGINE_SCOPED_LOCAL_TTS_G0`
- 范围：仅收敛普通 Echo 本地 SpeechEngine 的音色选择。腾讯数智人云渲染与 PCM audio-drive 路径不改用本地 TTS，也不改动现有全屏 Echo 视觉、Provider 配置或公开范围。

## 问题与修复

`DialogEngineManager` 原先在启动普通 Echo 语音引擎时直接读取
`VoiceCloneService.shared.currentUsableSpeakerId`。该服务虽然已有账户绑定，但该读取点没有携带当前
Echo 的角色上下文和生命周期代际；角色切换后，迟到的旧异步结果可能使普通 Echo 取到上一角色的复刻音色。

本切片新增 `DialogEngineScopedTTSVoiceSelection` 和单值 store：

- 选择记录必须同时匹配当前 `DialogEngineBindingHandle` 的 `bindingID` 和完整 `AccountLease` 代际；
- 同一 binding 的低生命周期代际不能覆盖更高代际的角色选择；
- 重新绑定或解绑账户时清空该 binding 的选择；
- `EchoViewController` 在绑定、数字人上下文变化和 VoiceClone runtime capability 返回时，显式写入当前角色的
  `voiceProfileId`、上下文 key 与生命周期代际；
- capability 未知或不可合成时显式写入空 profile，普通 Echo 回到默认普通音色，不把本地旧 profile 当作可用；
- 腾讯数智人路线继续关闭本地 SpeechEngine 播放，因此不会与腾讯 audio-drive 争夺音频 owner。

## 验证

执行：

```bash
python3 Scripts/QA/product-v4/voice-tts-account-lease-check.py
bash Scripts/QA/product-v4/run-voice-tts-digital-human-owner-scope-gate.sh
bash Scripts/QA/product-v4/run-voice-tts-dh-account-lifecycle-gate.sh
xcodebuild build-for-testing -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
git diff --check
```

结果：`PASS`。

- 新增模型测试覆盖：低代际角色切换不能覆盖较新的选择；不同账户 generation 不能读取或覆盖当前 binding；解绑后选择清空；
- 账户租约静态 Gate 断言 `DialogEngineManager` 不再直接读取 process-global
  `VoiceCloneService.shared.currentUsableSpeakerId`；
- Voice/TTS/Digital Human owner-scope 与 account lifecycle 组合 Gate 通过；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功；
- `git diff --check` 通过。既有第三方地图静态库 warning 未由本切片引入。

## 未完成边界

- 这是 G0 本地边界，不证明真实火山合成、腾讯数智人会话、音频播放或角色听感；G1/G3/G4 保持开放；
- `MemoirTTSService` 的 owner-scoped缓存与回忆录专属 `speakerId` 逻辑不在本切片改动范围，其现有 owner-scope Gate 仍需作为最终整合审查输入；
- 统一强制的 AVAudioSession owner 仍属于后续 runtime/audio 迁移，当前保持 observe-only 边界。

## 下一步

完成 `WI-S1-03-08` 的最终 G0 cross-path review：复核普通 Echo、Memoir TTS、腾讯 audio-drive 三条路径的
profile 选择、runtime capability 和 owner/lease 边界。通过后将该 Work Item 写入 handoff evidence，再进入
`WI-S1-03-09` 的 notification/deeplink runtime owner routing。
