# WI-S1-03-07 AudioOwnerLease

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-07`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / TWO_G0_OBSERVE_ONLY_SLICES_VERIFIED / G1_G4_OPEN`
- 已完成切片：`WI-S1-03-07-AUDIO_OWNER_INVENTORY_AND_MODEL_G0`、
  `WI-S1-03-07-ECHO_DH_OBSERVE_ONLY_ADAPTER_G0`
- 范围：先建立纯 AudioOwnerLease 合同、直接 `AVAudioSession` 写入清单，以及 Echo/DH 的 observe-only
  adapter；不迁移运行时播放/录音行为，不修改 Echo 全屏 UI、Provider、声音复刻或公开发布范围。

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
- 新增进程级 `AudioOwnerLeaseCoordinator`。它只包装纯模型、记录 acquire/preempt/release/stale-release
  证据，不导入或调用 `AVFoundation`；实际 AudioSession 的配置权仍保留在既有业务代码中；
- Echo 的 `setEchoAudioOwner` 现在会观察并记录 Tencent audio-drive、本地 Echo TTS 与静音切换。每次
  切换都持有具体 lease token；迟到的旧 release 只能得到 `ignoredStaleRelease`，不能清空后来的 owner；
- 新增 `echoLocalPlayback` / `echoLocalTTSPlayback`，使现有普通 Echo 本地 TTS 不再被错误归类为
  Profile 或 Archive 播放；
- 页面退出会释放该页面持有的 observation lease。这个释放不触碰腾讯 runtime、DialogEngine 或
  `AVAudioSession`，只避免诊断层遗留旧 owner。

本切片仍是 observe-only：以上 7 个业务写入点尚未迁移到统一 runtime coordinator，`echoCapture`
也尚未由实际 DialogEngine start/stop 事件接管。不能把模型/扫描通过误报为已解决真机无声、双播、
蓝牙或音画同步。

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
  stale capture resume 拒绝、owner route/purpose 默认值，以及 observe-only Tencent/local transition 的
  stale release 拒绝；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功；
- `git diff --check` 通过。

额外尝试了同测试文件的 Simulator `xcodebuild test`。当前 scheme 只暴露 iOS 真机和通用 Simulator
placeholder，未暴露本机已启动的具体 Simulator destination，因此该命令在 destination selection 阶段退出，
没有执行任何测试，也不是代码失败。无真机约束下，本切片以独立 Swift smoke、静态 gate 和
`build-for-testing` 作为 G0 证据。

构建仍会输出既有第三方地图静态库的缺失 object-file warning；本切片未新增该类 warning，结果为
`TEST BUILD SUCCEEDED`。

## 未完成边界

- 尚未实现唯一、强制的运行时 `AudioSessionCoordinator`，也未让任何业务面通过 lease 实际配置/释放 AVAudioSession；
- Echo/Digital Human 已有 observe-only lease adapter，但实际 Echo capture、AudioSession 配置仍各自存在；
  Archive/Profile/Memoir 也仍有直接调用；
- 系统 audio interruption、route change、蓝牙、听筒/扬声器、真正打断与麦克风恢复尚未进行 G4 真机验证；
- 不涉及 ASR/TTS 质量、腾讯/火山 Provider 行为或媒体功能公开策略。

## 下一步

继续 `WI-S1-03-07`：先把 Echo 的实际 capture/playback 关键事件与 observation lease 对齐，并补
interruption/route-change 的 model-level guard；仍不改变实际 `AVAudioSession` 配置。确认单 Echo cohort
的 event ordering、stale release 与 fallback 后，再考虑把它升级为强制仲裁；Archive/Profile/Memoir
保持在 inventory 中，不能在同一批次一起迁移。
