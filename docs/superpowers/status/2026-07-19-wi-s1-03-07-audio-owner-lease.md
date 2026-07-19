# WI-S1-03-07 AudioOwnerLease

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-07`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / FIRST_G0_MODEL_AND_INVENTORY_VERIFIED / G1_G4_OPEN`
- 本切片：`WI-S1-03-07-AUDIO_OWNER_INVENTORY_AND_MODEL_G0`
- 范围：先建立纯 AudioOwnerLease 合同和直接 `AVAudioSession` 写入清单；不迁移运行时播放/录音行为，
  不修改 Echo 全屏 UI、Provider、声音复刻或公开发布范围。

## 已实现

`AudioOwnerLeaseModel` 是既有的纯仲裁基础，本切片将它补齐为可描述、可验证的 lease 合同：

- lease 现在显式携带 owner、purpose、route、account/runtime generation、priority、state 与 issuedAt；
- owner 的默认 purpose/route 固定为：Echo capture/Tencent audio-drive 使用 `playAndRecordVoiceChat`，
  Archive recorder 使用 `recordAndSpeaker`，Archive/Memoir playback 使用 `playback`，Profile 试听使用
  `spokenAudioPreview`；
- 新增 `active`/`interrupted` 状态和 interruption/resume 结果。系统中断后只有当前 active lease 能恢复；
  已被抢占的旧 capture lease 不能在腾讯数字人播放结束后重新抢回音频；
- 既有 generation/priority/stale-release 规则仍保留：旧 runtime generation 不能抢占，旧 lease 不能清除新 owner；
- 新增静态 inventory gate。当前真正配置或激活 `AVAudioSession` 的业务写入点为 7 个：
  `DialogEngineManager`、`EchoViewController`、Archive recorder、Archive detail、Memory detail、
  Profile voice preview、`MemoirAudioPlayer`。`MicrophonePermissionManager` 只读/请求权限，不属于
  audio owner configurator；
- inventory gate 会阻止新增未登记的直接 `AVAudioSession.setCategory` / `setActive` 写入点。

本切片是 observe-only：`setEchoAudioOwner` 仍然只是 Echo 诊断状态，以上 7 个业务写入点尚未迁移到
统一 runtime coordinator。不能把模型/扫描通过误报为已解决真机无声、双播、蓝牙或音画同步。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-audio-owner-lease-gate.sh
git diff --check
```

结果：`PASS`。

- `product-v4-ios-audio-owner-lease-check.py` 校验 lease 字段、interruption/resume XCTest 声明及 7 个
  直接 AVAudioSession configurator 的完整清单；
- `audio-owner-lease-model-smoke.swift` 实际编译运行，覆盖数字人播放抢占 Echo capture、系统中断、
  stale capture resume 拒绝和 owner route/purpose 默认值；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功；
- `git diff --check` 通过。

构建仍会输出既有第三方地图静态库的缺失 object-file warning；本切片未新增该类 warning，结果为
`TEST BUILD SUCCEEDED`。

## 未完成边界

- 尚未实现唯一运行时 `AudioSessionCoordinator`，也未让任何业务面通过 lease 实际配置/释放 AVAudioSession；
- Echo/Digital Human 仍有自己的 `setEchoAudioOwner` 与 AudioSession 配置，Archive/Profile/Memoir 也仍有直接调用；
- 系统 audio interruption、route change、蓝牙、听筒/扬声器、真正打断与麦克风恢复尚未进行 G4 真机验证；
- 不涉及 ASR/TTS 质量、腾讯/火山 Provider 行为或媒体功能公开策略。

## 下一步

继续 `WI-S1-03-07`：只先为 Echo/Digital Human 建立 observe-only runtime adapter，将现有
`setEchoAudioOwner` 映射为 lease acquire/release 诊断并记录冲突，不改变实际 AVAudioSession 配置。确认
单 Echo cohort 的事件和 stale release 行为后，再考虑把它升级为强制仲裁；Archive/Profile/Memoir 保持在
inventory 中，不能在同一批次一起迁移。
