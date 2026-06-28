# 语音档案 hidden QA 生命周期

日期：2026-06-19

## 本轮目标

推进语音档案 hidden QA 录音链路，但不默认公开 `录入语音`：

- 权限拒绝后录音页回到可恢复状态。
- 本地生成/保存音频文件。
- 通过生产 `MemoryArchiveItemFactory.makeAudioItem` 和 `MemoryArchiveRepository.add` 保存。
- 重新从仓库读取后仍能恢复语音档案。
- 详情页可加载音频播放结构。
- 语音档案可进入 Archive context。

## 实现内容

- 新增 `DJRunArchiveAudioLifecycleSmoke` UIQA harness。
- 新增 `run-archive-audio-lifecycle-smoke.sh`：
  - 构建 `DEBUG UI_QA_SIMULATOR` 版本。
  - 以 `DJEnableArchiveHiddenBranches` 启动隐藏分支。
  - 轮询 `archive-audio-lifecycle-smoke-result.json`。
  - 保存模拟器截图和日志。
- 新增 `archive-audio-lifecycle-smoke-check.swift` 静态 guard，并接入 release regression / release QA package。
- `MemoryArchiveAudioRecorderViewController` 新增统一的 `handleMicrophonePermissionDenied`：
  - 停止录音。
  - 保存按钮保持不可用。
  - 状态文案变为 `录音需要麦克风权限，可在系统设置开启后再试`。
  - 真实路径仍弹出系统设置引导。
  - UIQA 可调用同一恢复逻辑但不弹窗。
- UIQA smoke 使用 `AVAudioFile` + `AVAudioPCMBuffer` 生成本地 m4a，避免模拟器依赖真实麦克风。

## 验证

已通过：

```bash
swift Scripts/QA/prd-stitch-ui/archive-audio-lifecycle-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/archive-audio-ia-release-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/archive-media-entries-smoke-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift Scripts/QA/prd-stitch-ui/release-like-hidden-entries-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-archive-audio-lifecycle Scripts/QA/prd-stitch-ui/run-archive-audio-lifecycle-smoke.sh
git diff --check
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataArchiveAudioLifecycleBuild build
```

Smoke JSON 关键字段：

- `completed`: `true`
- `permissionDeniedRecoveryReady`: `true`
- `releaseAudioCreationVisible`: `false`
- `hiddenAudioCreationVisible`: `true`
- `audioFileExists`: `true`
- `restoredAudioItem`: `true`
- `restoredAudioItemCount`: `1`
- `summaryAudioCount`: `1`
- `contextIncludesAudio`: `true`
- `detailViewLoaded`: `true`
- `detailPlaybackLoadable`: `true`

证据路径：

- 结果 JSON：`tmp/visual-qa/prd-stitch-ui/archive-audio-lifecycle-smoke/20260619-archive-audio-lifecycle/archive-audio-lifecycle-smoke-result.json`
- 截图：`tmp/visual-qa/prd-stitch-ui/archive-audio-lifecycle-smoke/20260619-archive-audio-lifecycle/01-archive-audio-lifecycle.png`
- build log：`tmp/visual-qa/prd-stitch-ui/archive-audio-lifecycle-build.log`

## 已知限制

- 本轮证明的是模拟器内的数据链路和本地播放可加载性，不等于真机麦克风权限、真实录音质量、系统音频路由和后台恢复已验收。
- `release-qa-package-check.swift` 仍因本地 final visual QA 截图证据缺失失败，缺少如 `tmp/visual-qa/prd-stitch-ui/final-stitch-visual-qa/20260618-current/app/01-login.png`；本轮未伪造视觉证据。
- `录入语音` 仍是 hidden QA 功能，公开 MVP 默认不暴露。

## 下一步

建议继续做语音档案真机前置验收清单：真实麦克风授权/拒绝/重新授权、录音质量、详情播放路由、前后台切换后录音文件不丢失。通过后再决定是否从 hidden QA 推进到公开发布候选。
