# iOS Voice Clone Synthesis Runtime Smoke

日期：2026-06-29

## 背景

声音复刻链路已经迁到后端：iOS 不直连火山/豆包接口，后端负责 `/voice/synthesis`，并可按腾讯数智人 audio-drive 需要返回 `pcm16kMono`。

本轮补齐 iOS 侧 QA-only runtime smoke，验证 App 能读取部署后端 `/config/runtime.voiceClone` 能力，并调用 `/voice/synthesis?outputMode=tencentAudioDrive` 得到可喂给腾讯数智人的 PCM 合同。

## 已实现

- 新增 `run-voice-clone-synthesis-runtime-smoke.sh`。
- 新增 `voice-clone-synthesis-runtime-smoke-check.swift` 静态守卫。
- AppDelegate 新增 `DJRunVoiceCloneSynthesisRuntimeSmoke` UIQA harness。
- runner 会读取 `DreamJourney/Config/Backend.local.xcconfig` 或私密 `deployed-backend-access.md`，构建时注入：
  - `DREAMJOURNEY_BACKEND_BASE_URL`
  - `DREAMJOURNEY_BACKEND_API_TOKEN`
- 构建日志对后端 token 做脱敏，不输出原始 token。
- smoke 结果只保存合成合同元数据，不保存原始音频数据。
- 已接入 `run-release-regression.sh` 可选 gate：
  - `RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE=1`
- 已接入 `release-qa-package-check.swift`。

## 验证范围

- `/config/runtime.voiceClone` 可读。
- `voiceClone.canSynthesize == true`。
- `voiceClone.tencentAudioDrive.supported == true`。
- `/voice/synthesis` 支持 `outputMode=tencentAudioDrive`。
- 返回格式为：
  - `audioFormat=pcm16kMono`
  - `sampleRate=16000`
  - `bitsPerSample=16`
  - `channelCount=1`
- `decodedByteCount == byteCount`。
- PCM 非空，且不是 WAV/RIFF 容器。
- `audioDataOmitted=true`，报告不落原始音频内容。

## 本轮证据

运行命令：

```bash
RUN_ID=20260629-voice-clone-synthesis-runtime-smoke-2 \
Scripts/QA/prd-stitch-ui/run-voice-clone-synthesis-runtime-smoke.sh
```

结果：

- `completed=true`
- `provider=volcengineVoiceCloneV3`
- `providerMode=volcengineVoiceCloneV1TTS`
- `outputMode=tencentAudioDrive`
- `audioFormat=pcm16kMono`
- `byteCount=36398`
- `decodedByteCount=36398`
- `pcmCompatible=true`
- `audioDataOmitted=true`

证据目录：

```text
tmp/visual-qa/prd-stitch-ui/voice-clone-synthesis-runtime-smoke/20260629-voice-clone-synthesis-runtime-smoke-2/
```

关键文件：

- `voice-clone-synthesis-runtime-smoke-result.json`
- `runtime.log`
- `oslog.log`
- `01-voice-clone-synthesis-runtime.png`

## 使用方式

单独运行：

```bash
Scripts/QA/prd-stitch-ui/run-voice-clone-synthesis-runtime-smoke.sh
```

指定音色：

```bash
VOICE_CLONE_READY_PROFILE_ID=S_PhXlHqB52 \
Scripts/QA/prd-stitch-ui/run-voice-clone-synthesis-runtime-smoke.sh
```

接入 release regression：

```bash
RUN_VOICE_CLONE_SYNTHESIS_RUNTIME_SMOKE=1 \
Scripts/QA/prd-stitch-ui/run-release-regression.sh
```

## 注意事项

- 该 smoke 依赖部署后端已经配置声音复刻合成 provider。
- 该 smoke 不验证腾讯数智人真机播放，只验证 iOS 能从部署后端拿到腾讯 audio-drive 兼容 PCM。
- 真机上的“复刻声音驱动腾讯数智人有声、口型动、stop 可打断、结束恢复麦克风”仍需独立真机验收。
