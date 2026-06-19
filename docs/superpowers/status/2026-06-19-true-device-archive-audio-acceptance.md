# 语音档案真机前置验收

日期：2026-06-19

## 本轮目标

把语音档案从“模拟器 lifecycle smoke 已证明数据链路”推进到“可执行的真机前置验收包”，但不默认公开 `录入语音`。

验收重点：

- 真实麦克风授权。
- 拒绝麦克风权限后的恢复态。
- 从系统设置重新授权后的恢复录音。
- 录音质量人工记录。
- 详情播放路由。
- 前后台切换后文件不丢。

## 新增入口

真机前置脚本：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-archive-audio-true-device-preflight \
tmp/visual-qa/prd-stitch-ui/run-true-device-archive-audio-preflight.sh
```

脚本会：

- 读取 `DreamJourney/Config/VoiceSDK.local.xcconfig` 和后端本地配置，但语音档案录音本身不强依赖语音 SDK。
- 检查 `NSMicrophoneUsageDescription` 和 `NSSpeechRecognitionUsageDescription`。
- 保存 `xcodebuild-destinations.txt`、`devicectl-devices.txt`、`xctrace-devices.txt`。
- 在线真机可用时执行 Debug device build。
- 生成 `report.md`，并列出需要人工采集的截图名。

## 人工验收截图

真机人工验收通过前，以下截图和记录必须放入对应 run 目录：

- `01-audio-permission-allow.png`
- `02-audio-permission-deny.png`
- `03-audio-permission-recover.png`
- `04-audio-created.png`
- `05-audio-detail-playback.png`
- `06-audio-after-background-foreground.png`

需要同步记录：

- 设备型号、iOS 版本、构建配置。
- 录音质量：清晰度、音量、噪声、截断、播放失败。
- 详情播放路由是否稳定。
- 前后台切换后列表、详情、本地音频文件是否仍存在。

## 与模拟器 smoke 的边界

已有模拟器脚本：

```bash
tmp/visual-qa/prd-stitch-ui/run-archive-audio-lifecycle-smoke.sh
```

它证明：

- hidden QA 下 `DJEnableArchiveHiddenBranches` 可进入语音档案。
- 权限拒绝恢复逻辑可调用。
- 本地音频文件可生成。
- `MemoryArchiveRepository` 可持久化并恢复语音档案。
- 详情页可加载本地音频播放结构。

但模拟器 smoke 不能替代真机麦克风验收，因为它不能证明真实麦克风权限弹窗、系统设置重新授权、真实录音质量、真机音频路由和设备前后台行为。

## 当前状态

- `录入语音` 仍是 hidden QA 功能，只能通过 `DJEnableArchiveHiddenBranches` 或对应 feature flag 打开。
- 公开 MVP 默认不能暴露该入口。
- 如果设备离线、未解锁、未信任，或 Xcode 无法发现物理 iPhone/iPad，脚本会写出 blocked report，并且不声明验收通过。

当前运行：

- Run: `20260619-archive-audio-true-device-preflight`
- Report: `tmp/visual-qa/prd-stitch-ui/true-device-acceptance/20260619-archive-audio-true-device-preflight/report.md`
- 结果：blocked。
- 原因：`xcodebuild -showdestinations` 只返回 iOS placeholder；`devicectl` 显示 iPhone `unavailable`；`xctrace` 将 iPhone 列在 `Devices Offline`。
- 配置状态：后端配置和 VolcEngine 语音 SDK build settings 均已能从本地配置读取为 `set`；隐私声明已存在。

## 验收结论规则

可以声明“语音档案真机前置验收通过”的最低条件：

1. `run-true-device-archive-audio-preflight.sh` 在在线真机上通过。
2. 上述 6 张截图齐全。
3. 录音质量记录无 P0/P1 阻塞问题。
4. 前后台切换后文件不丢，详情播放仍可进入。
5. release hidden guard 仍确认公开 MVP 不暴露 `录入语音`。

未满足这些条件前，只能写为：真机前置脚本已准备，真机人工验收待执行或 blocked。
