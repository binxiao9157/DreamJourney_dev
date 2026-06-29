# 2026-06-29 真机腾讯数智人 Backend PCM Drive POC

## 目标

验证部署后端 `/voice/synthesis` 返回的 `outputMode=tencentAudioDrive` PCM，能在真机上接入真实腾讯数智人 SDK audio-drive 入口，并覆盖：

- 后端复刻 TTS 请求成功。
- iOS 将 PCM 分片发送给腾讯 SDK。
- 腾讯 SDK 触发 `AudioStart`。
- QA stop probe 能打断播放。
- stop 后恢复麦克风/语音捕获。
- 人工确认真机有声、口型/动态跟随声音。

## 本轮实现

- `run-true-device-tencent-backend-pcm-drive-smoke.sh`
  - 默认加入 `DJRunTencentDigitalHumanPCMDriveStopProbe`。
  - 报告中区分自动化日志证据和人工视觉/听觉确认项。
  - 新增检查：
    - `PCM-drive stop probe fired`
    - `resume voice capture after provider speech reason=pcmDriveSmokeStopProbe`
    - `provider playback completed`
  - 继续过滤 `devicectl unavailable` 和 `xctrace Devices Offline` 设备。
- `EchoViewController`
  - `pcmDriveSmokeStopProbe` 下打断腾讯 provider 后，QA-only 恢复语音捕获。
  - stop probe 日志增加 `resumedVoiceCapture`。
- 新增静态守卫：
  - `Scripts/QA/prd-stitch-ui/true-device-tencent-backend-pcm-drive-smoke-check.swift`
- 接入：
  - `run-release-regression.sh`
  - `release-qa-package-check.swift`

## 自动化验证结果

已通过：

```text
swift Scripts/QA/prd-stitch-ui/true-device-tencent-backend-pcm-drive-smoke-check.swift .
swift Scripts/QA/prd-stitch-ui/tencent-digital-human-pcm-drive-poc-check.swift .
swift Scripts/QA/prd-stitch-ui/voice-synthesis-tencent-audio-drive-contract-check.swift .
swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift .
git diff --check
xcodebuild iphonesimulator Debug build
xcodebuild iphoneos Debug no-sign build
```

## 真机执行状态

本轮真机脚本已执行，但被设备状态阻断：

```text
RUN_ID=20260629-true-device-tencent-backend-pcm-drive-poc \
RUN_SECONDS=35 \
Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh
```

结果：

```text
Status: failed
Reason: No online physical iPhone/iPad detected.
```

设备检测显示：

```text
== Devices Offline ==
iPhone (27.0) (00008150-001402D60A04401C)
```

证据目录：

```text
tmp/visual-qa/prd-stitch-ui/true-device-tencent-backend-pcm-drive/20260629-true-device-tencent-backend-pcm-drive-poc/
```

## 下一步

等 iPhone 在 Xcode / `xcrun xctrace list devices` 中显示为 online 后，重新执行：

```bash
RUN_ID=20260629-true-device-tencent-backend-pcm-drive-poc-rerun \
RUN_SECONDS=55 \
Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh
```

通过标准：

- 自动化日志：
  - `backend PCM-drive smoke synthesis ready`
  - `sent PCM chunk`
  - `AudioStart`
  - `PCM-drive stop probe fired`
  - `resume voice capture after provider speech reason=pcmDriveSmokeStopProbe`
- 人工确认：
  - 真机能听到声音。
  - 腾讯数智人口型/动态跟随声音。
  - stop 后声音停止，数字人面板不关闭。
  - stop 后可以继续说话，麦克风可用。
