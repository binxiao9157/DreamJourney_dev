# Voice Clone Tencent PCM Release Gate

日期：2026-06-29

## 本轮目标

继续推进声音复刻合成与腾讯数智人 audio-drive 链路：

- 复核 iOS 已能从部署后端获取 `tencentAudioDrive` PCM 合同。
- 尝试真机 `后端复刻 TTS -> PCM -> 腾讯数智人 sendPCMChunk` QA smoke。
- 确保公开 MVP release gate 不被数字人/后端配置缺失污染。

## 已完成

### 1. iOS 声音复刻合成 runtime gate

已接入并跑通：

```bash
RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

结果：

- `/config/runtime.voiceClone` 可读。
- `/voice/synthesis` 可返回 `outputMode=tencentAudioDrive`。
- 返回音频合同：
  - `audioFormat=pcm16kMono`
  - `sampleRate=16000`
  - `bitsPerSample=16`
  - `channelCount=1`
- `pcmCompatible=true`。
- `audioDataOmitted=true`，报告不保存原始音频数据。

### 2. 公开 MVP smoke 的数字人配置边界

发现 release gate 中 `archive-to-echo-smoke` 在无显式后端配置时会尝试请求：

```text
http://127.0.0.1:3100/config/runtime
```

这会导致公开 smoke 出现“无法连接服务器 / 同步失败”噪声。

已修复：

- `DreamJourneyBackendClient` 新增 `isDigitalHumanSessionConfigured`。
- `EchoViewController.prepareCloudDigitalHumanRuntimeIfNeeded()` 在没有显式后端配置时直接安静降级：
  - 不请求 `/config/runtime`
  - 不连接 localhost
  - 不影响普通 Echo 主链路

### 3. Release gate 复验

复验命令：

```bash
RUN_ID=20260629-voice-clone-release-gate-after-dh-config-fix \
RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

结果：通过。

通过范围：

- 静态合同检查。
- iOS Debug simulator build。
- `archive-to-echo-smoke`。
- `echo-delayed-reply-notification-smoke`。
- `voice-clone-synthesis-runtime-smoke`。

证据目录：

```text
tmp/visual-qa/prd-stitch-ui/release-regression/20260629-voice-clone-release-gate-after-dh-config-fix/
```

关键结果：

- `archive-to-echo-smoke-result.json`
- `echo-delayed-reply-notification-smoke-result.json`
- `voice-clone-synthesis-runtime-smoke-result.json`
- `report.md`
- `commands.log`

## 真机状态

尝试运行：

```bash
RUN_ID=20260629-true-device-tencent-backend-pcm-drive-offline-check \
Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh
```

结果：阻塞。

原因：

```text
No online physical iPhone/iPad detected.
```

当前 `xctrace` 枚举显示物理 iPhone 在 `Devices Offline`，因此无法安装、启动或验证腾讯数智人真机 audio-drive 播放。

## 当前结论

非真机部分已经闭环：

- 后端复刻合成可返回腾讯 audio-drive 兼容 PCM。
- iOS 能读取 runtime 能力并验证 PCM 合同。
- Echo 侧已有 QA-only 的后端 PCM-drive 入口。
- 公开 MVP release gate 不再被未配置后端的数字人 runtime 请求污染。

仍未完成：

- 真机验证复刻 PCM 喂给腾讯数智人后是否有声音。
- 真机验证腾讯数智人口型是否随 PCM 音频驱动。
- 真机验证 stop 可打断。
- 真机验证结束后麦克风能恢复继续对话。

## 下一步

设备恢复在线后，运行：

```bash
DJ_TENCENT_BACKEND_PCM_VOICE_PROFILE_ID=S_PhXlHqB52 \
Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh
```

验收信号：

- `backend PCM-drive smoke synthesis ready`
- `sent PCM-drive signal`
- `sent PCM chunk`
- `AudioStart`
- `AudioOver`

如果 `AudioStart` 未出现，则继续查腾讯 SDK `sendPCM` 参数和项目是否支持音频驱动输入；如果 `AudioStart` 出现但无声或口型不动，则查腾讯资源包/项目的 audio-drive 能力与远端音频策略。
