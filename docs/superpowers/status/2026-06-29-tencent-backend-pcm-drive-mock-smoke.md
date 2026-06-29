# 2026-06-29 腾讯数字人后端 PCM Drive Mock Smoke

## 目标

把“部署后端声音复刻 TTS -> Tencent audio-drive PCM -> iOS 数字人 runtime chunk 发送 -> stop/interruption cleanup”固化成非真机可重复 gate。

这条链路不连接真实腾讯 SDK，也不验证真实云渲染画面；它用于提前验证后端输出的 `tencentAudioDrive` PCM 合同能被 iOS 按腾讯数字人 audio-drive 入口消费，避免等到真机时才发现音频格式、chunk 顺序或停止语义不一致。

## 本轮实现

- 新增静态守卫：
  - `Scripts/QA/prd-stitch-ui/tencent-backend-pcm-drive-mock-smoke-check.swift`
- 新增模拟器 smoke：
  - `Scripts/QA/prd-stitch-ui/run-tencent-backend-pcm-drive-mock-smoke.sh`
- 接入 release regression 可选开关：
  - `RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE=1`
- 增强 `TencentDigitalHumanRuntimeStub`：
  - 记录 `sentPCMChunks`
  - 记录 `interruptCount`
  - 验证 chunk `sequence` 连续、final chunk 存在、stop probe 能清理 active request
- 增加 App 侧 UIQA launch arg：
  - `DJRunTencentBackendPCMDriveMockSmoke`
  - `DJTencentBackendPCMDriveMockVoiceProfileId=<S_ voiceProfileId>`

## 验证方式

单独执行：

```bash
RUN_ID=20260629-tencent-backend-pcm-drive-mock-smoke \
Scripts/QA/prd-stitch-ui/run-tencent-backend-pcm-drive-mock-smoke.sh
```

接入 release regression：

```bash
RUN_ID=20260629-tencent-backend-pcm-drive-mock-gate \
RUN_STANDARD_BUILD=0 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
RUN_TENCENT_BACKEND_PCM_DRIVE_MOCK_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 本轮验证结果

单独 smoke：

- `completed=true`
- `voiceProfileId=S_PhXlHqB52`
- `outputMode=tencentAudioDrive`
- `audioFormat=pcm16kMono`
- `pcmCompatible=true`
- `byteCount=186118`
- `pcmChunkCount=60`
- `finalChunkObserved=true`
- `sequenceIsContiguous=true`
- `interruptProbeCompleted=true`
- 证据目录：
  - `tmp/visual-qa/prd-stitch-ui/tencent-backend-pcm-drive-mock-smoke/20260629-tencent-backend-pcm-drive-mock-smoke/`

Release regression gate：

- `completed=true`
- `voiceProfileId=S_PhXlHqB52`
- `outputMode=tencentAudioDrive`
- `audioFormat=pcm16kMono`
- `pcmCompatible=true`
- `byteCount=213302`
- `pcmChunkCount=68`
- `finalChunkObserved=true`
- `sequenceIsContiguous=true`
- `interruptProbeCompleted=true`
- 报告：
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260629-tencent-backend-pcm-drive-mock-gate/report.md`
- 证据目录：
  - `tmp/visual-qa/prd-stitch-ui/release-regression/20260629-tencent-backend-pcm-drive-mock-gate/tencent-backend-pcm-drive-mock-smoke/20260629-tencent-backend-pcm-drive-mock-gate/`

## 边界

- 不验证真实腾讯云渲染 SDK。
- 不验证真实口型视觉效果。
- 不播放真实声音。
- 不替代真机验收。

## 下一步

进入真机 POC：

1. 使用部署后端 `/voice/synthesis` 的 `outputMode=tencentAudioDrive`。
2. iOS 接真实腾讯 SDK 的 PCM/audio-drive 入口。
3. 验证有声音、口型动、stop 可打断、结束后恢复麦克风。
4. 若真机链路稳定，再把同一合同纳入真机验收包。
