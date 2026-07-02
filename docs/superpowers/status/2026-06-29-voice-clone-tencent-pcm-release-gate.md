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

## 2026-07-02 非真机发布前置 Gate 更新

为避免上真机前仍然分散运行多个脚本，本轮新增两条可选 release regression gate：

### 1. iPhoneOS generic build

脚本：

```bash
Scripts/QA/prd-stitch-ui/run-iphoneos-generic-build.sh
```

Release regression 开关：

```bash
RUN_IPHONEOS_GENERIC_BUILD=1
```

验证目标：

- 不依赖在线真机。
- 编译 `iphoneos/arm64` Debug 包。
- 验证腾讯 SDK、Pods 和 app target 在真机架构下可链接。
- 验证本地 QA Bundle ID 覆盖为 `com.yxj.dreamjourney.app`，不回退到共享默认 Bundle ID。

本轮验证结果：

```text
Status: passed
iPhoneOS generic build: passed
Bundle ID: com.yxj.dreamjourney.app
```

证据：

```text
tmp/visual-qa/prd-stitch-ui/release-regression/20260702-175411-release-regression/iphoneos-generic-build/20260702-175411-release-regression/report.md
```

### 2. Digital human + voice clone combo gate

脚本：

```bash
Scripts/QA/prd-stitch-ui/run-digital-human-voice-clone-combo-gate.sh
```

Release regression 开关：

```bash
RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE=1
```

该组合 gate 会在同一个 run id 下串起四条非真机验证：

1. `run-backend-digital-human-session-smoke.sh`
   - 验证后端 `/config/runtime.digitalHuman` 和 `/digital-human/sessions`。
   - 确认腾讯 `cloudRender`、后端签发 credential、asset/project 身份可用。
2. `run-backend-voice-clone-deployed-smoke.sh`
   - 验证部署后端声音复刻 ready 音色。
   - 确认 `/voice/synthesis` 可返回 `tencentAudioDrive` / `pcm16kMono`。
3. `run-voice-clone-synthesis-runtime-smoke.sh`
   - 验证 iOS 读取 runtime 能力并请求 `/voice/synthesis`。
   - 确认使用本地 QA Bundle ID：`com.yxj.dreamjourney.app`。
4. `run-tencent-backend-pcm-drive-mock-smoke.sh`
   - 验证后端 PCM 可被切成连续 chunk 喂给 fake Tencent runtime。
   - 验证 final chunk、stop/interruption cleanup。

本轮验证结果：

```text
Status: passed
Digital human + voice clone combo gate: passed
voiceProfileId: S_PhXlHqB52
outputMode: tencentAudioDrive
audioFormat: pcm16kMono
finalChunkObserved: true
interruptProbeCompleted: true
```

证据：

```text
tmp/visual-qa/prd-stitch-ui/release-regression/20260702-175411-release-regression/digital-human-voice-clone-combo-gate/20260702-175411-release-regression/report.md
```

### 推荐上线前非真机命令

如果只是想在上真机前压住数字人/复刻链路，可运行：

```bash
RUN_STANDARD_BUILD=0 \
RUN_SIMULATOR_SMOKE=0 \
RUN_ECHO_DELAYED_REPLY_NOTIFICATION_SMOKE=0 \
RUN_IPHONEOS_GENERIC_BUILD=1 \
RUN_DIGITAL_HUMAN_VOICE_CLONE_COMBO_GATE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

这条命令不替代真机听感验收。它只能证明：

- iPhoneOS 编译/链接没有破。
- 后端数字人 session 合同可用。
- 后端复刻音色可返回腾讯 audio-drive PCM。
- iOS 可消费该 PCM 合同。
- PCM chunk / stop cleanup 的 mock runtime 合同可用。

## 当前结论

非真机部分已经闭环：

- 后端复刻合成可返回腾讯 audio-drive 兼容 PCM。
- iOS 能读取 runtime 能力并验证 PCM 合同。
- Echo 侧已有 QA-only 的后端 PCM-drive 入口。
- 公开 MVP release gate 不再被未配置后端的数字人 runtime 请求污染。
- iPhoneOS generic build 和数字人/复刻组合 gate 已接入 release regression，可一键复验。

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
