# 2026-06-29 腾讯数智人 audio-drive 后端 PCM 合同

## 目标

把“声音复刻 TTS 音频驱动腾讯数智人”的第一段生产化合同固定下来：

- 后端继续持有火山/豆包声音复刻 TTS 密钥。
- iOS 不直连火山/豆包复刻 TTS API。
- 后端在 `/voice/synthesis` 支持 `outputMode=tencentAudioDrive`。
- 后端把 provider 音频转成腾讯 audio-drive 兼容的裸 PCM：16kHz / 16-bit / mono。
- iOS 继续复用现有腾讯数智人 `sendPCMChunk` 路径，不启用本地播放器播放复刻音频。

## 已实现

### 后端

- `app/services/tts.py`
  - 新增 `TencentAudioDrivePCMAdapter`。
  - 支持 WAV provider audio 转裸 `pcm16kMono`。
  - 支持采样率转换、双声道转单声道、16-bit PCM 输出。
  - 对 MP3 等不可直接转换格式返回明确错误，不伪装成功。

- `app/main.py`
  - `/voice/synthesis` 新增 `outputMode` 合同。
  - 默认模式保持原有返回格式。
  - `outputMode=tencentAudioDrive` 时强制向 provider 请求 `wav + 16k`，再转成腾讯 PCM。

- `app/services/runtime_config.py`
  - `voiceClone.tencentAudioDrive` 暴露 audio-drive 能力：
    - `requestOutputMode=tencentAudioDrive`
    - `audioFormat=pcm16kMono`
    - `sampleRate=16000`
    - `bitsPerSample=16`
    - `channelCount=1`

### iOS

- `DreamJourneyBackendClient.VoiceCloneSynthesisResult`
  - 解析 `outputMode`、`sampleRate`、`bitsPerSample`、`channelCount`。
  - 提供 `isTencentAudioDrivePCMCompatible`。
  - 提供 `tencentAudioDrivePCMData`。

- `DreamJourneyBackendClient.requestVoiceCloneSynthesis(...)`
  - 支持可选 `outputMode` 参数。

- `EchoViewController`
  - 新增后端合成结果到腾讯 PCM-drive signal 的桥接。
  - 复用已有 `scheduleTencentDigitalHumanPCMDriveChunks` 和 `sendPCMChunk`。
  - 新增 QA-only 真机链路 `DJRunTencentDigitalHumanBackendPCMDriveSmoke`：
    - 调部署后端 `/voice/synthesis`。
    - 请求 `outputMode=tencentAudioDrive`。
    - 可通过 `DJTencentBackendPCMDriveVoiceProfileId=S_xxx` 指定音色。
    - 未指定时使用本机已保存且 ready 的复刻音色。
    - 成功后把后端返回 PCM 直接喂给腾讯数智人。

### QA 参数

```text
DJRunTencentDigitalHumanBackendPCMDriveSmoke
DJTencentBackendPCMDriveVoiceProfileId=S_xxx
DJTencentBackendPCMDriveText=自定义测试文案
```

`DJTencentBackendPCMDriveVoiceProfileId` 可选；如果不提供，App 会尝试读取本机已训练完成的音色。真机验收时建议显式传入，方便复现同一条链路。

### 真机脚本

```bash
DJ_TENCENT_BACKEND_PCM_VOICE_PROFILE_ID=S_xxx \
Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh
```

脚本会：

- 查找已连接真机。
- 使用 `DreamJourney/Config/YXJ.local.xcconfig` 构建，避免把后端 token 或签名配置打印到命令行。
- 安装并启动 App。
- 传入 `DJRunTencentDigitalHumanBackendPCMDriveSmoke`。
- 记录 console 日志和报告。
- 检查是否观察到后端合成完成、PCM chunk、Tencent `AudioStart`。

## 边界

- 本轮没有把公开 Echo 默认回复切到复刻 TTS PCM drive。
- 本轮没有启用 iOS 本地播放器播放复刻 TTS。
- 本轮没有接 provider 级流式 PCM；仍是后端一次性合成后返回 base64 PCM。
- 真实延迟、打断体验和音色质量仍需后续真机验收。

## 验证

- 后端单测：
  - `tests.test_core_services.TokenAndProxyTests.test_voice_clone_synthesis_can_return_tencent_audio_drive_pcm_contract`

- iOS/后端静态合同门：
  - `Scripts/QA/prd-stitch-ui/voice-synthesis-tencent-audio-drive-contract-check.swift`

- 真机 QA 脚本：
  - `Scripts/QA/prd-stitch-ui/run-true-device-tencent-backend-pcm-drive-smoke.sh`

## 下一步

1. 用部署后的后端和真机运行 `DJRunTencentDigitalHumanBackendPCMDriveSmoke`。
2. 验证真机上“复刻声音有声、口型动、停止可打断、结束后恢复麦克风”。
3. 如果延迟不可接受，再评估 provider 流式 TTS 或腾讯 audio-drive 分片推送优化。
