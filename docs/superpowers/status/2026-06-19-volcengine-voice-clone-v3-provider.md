# 火山声音复刻 V3 后端 Provider 接入

## 本轮目标

把声音复刻正式 provider 放到 DreamJourneyBackend，iOS 不再直连火山声音复刻训练、查询或复刻音色 TTS 合成 API，也不在客户端保存声音复刻 API Key。

## API 决策

- 正式训练 API：`POST https://openspeech.bytedance.com/api/v3/tts/voice_clone`
- 正式查询 API：`POST https://openspeech.bytedance.com/api/v3/tts/get_voice`
- 正式复刻音色 TTS 合成 API：`POST https://openspeech.bytedance.com/api/v3/tts/unidirectional`
- 鉴权位置：仅后端 `.env`
- iOS 行为：提交授权后的声音样本到 `/voice/profiles`，通过 `/voice/profiles/{user_id}/{voice_profile_id}/refresh` 查询状态；回忆录朗读通过 `/voice/synthesis` 请求后端合成音频

## 后端实现

- 新增 `app/services/voice_clone.py`
  - `VolcEngineVoiceCloneV3Provider`
  - `VoiceCloneProviderFactory`
  - `MockVoiceCloneProvider`
- `app/core/config.py` 新增：
  - `VOLCENGINE_VOICE_CLONE_API_KEY`
  - `VOLCENGINE_VOICE_CLONE_TRAIN_URL`
  - `VOLCENGINE_VOICE_CLONE_QUERY_URL`
  - `VOLCENGINE_VOICE_CLONE_TTS_URL`
  - `VOLCENGINE_VOICE_CLONE_TTS_RESOURCE_ID`
- `/config/runtime` 新增 `voiceClone` 能力公告：
  - provider
  - realProviderReady
  - trainEndpoint
  - queryEndpoint
  - synthesisEndpoint
  - synthesisProviderReady
  - fallbackMode
- `/voice/profiles`
  - provider 已配置且 payload 带 `audioBase64` 时，由后端提交火山 V3 训练
  - 不持久化 `audioBase64`、`rawSampleURL`、`sampleLocalPath`
  - 上游失败收敛为 `sampleStatus=failed` / `providerStatus=failed`
- 新增 `/voice/profiles/{user_id}/{voice_profile_id}/refresh`
  - 查询 provider 训练状态并回写 profile
- 新增 `/voice/synthesis`
  - 使用后端 `.env` 中的火山声音复刻 API Key 和资源 ID 调用 V3 HTTP Chunked/SSE 合成接口
  - 响应只返回 base64 音频、格式、字节数和 `providerMode`
  - 不向 iOS 返回 `X-Api-Key`、上游请求头或火山密钥

## iOS 实现

- `VoiceCloneService.trainVoice` 改为调用 `DreamJourneyBackendClient.saveVoiceCloneProfile`
- `VoiceCloneService.queryStatus` 改为调用 `DreamJourneyBackendClient.refreshVoiceCloneProfile`
- `MemoirTTSService` 改为调用 `DreamJourneyBackendClient.requestVoiceCloneSynthesis`
- `VoiceCloneService` 和 `MemoirTTSService` 不再包含火山复刻训练/查询/合成 URL，也不再发送 `X-Api-Key`
- `DreamJourneyBackendClient` 新增 `refreshVoiceCloneProfile` 和 `requestVoiceCloneSynthesis`

## 部署配置

服务器 `.env` 需要补：

```env
VOLCENGINE_VOICE_CLONE_API_KEY=<火山声音复刻 V3 API Key>
VOLCENGINE_VOICE_CLONE_TRAIN_URL=https://openspeech.bytedance.com/api/v3/tts/voice_clone
VOLCENGINE_VOICE_CLONE_QUERY_URL=https://openspeech.bytedance.com/api/v3/tts/get_voice
VOLCENGINE_VOICE_CLONE_TTS_URL=https://openspeech.bytedance.com/api/v3/tts/unidirectional
VOLCENGINE_VOICE_CLONE_TTS_RESOURCE_ID=seed-icl-1.0
```

真实 key 不写入仓库，不写入状态文档。

## 验证

- `STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_core_services.VoiceCloneProfileAPITests`
- `STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest discover tests`
- `swift Scripts/QA/prd-stitch-ui/voice-clone-backend-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift Scripts/QA/prd-stitch-ui/release-qa-package-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `git diff --check` in `DreamJourneyBackend`
- `git diff --check` in `DreamJourney_dev`
- iOS simulator generic Debug build with local xcconfig

## 剩余风险

- 真实复刻音色合成仍需用已训练成功的 `voiceProfileId` 跑线上验收；当前自动测试只证明后端合同、密钥隔离和 base64 音频返回形态。
- 声音复刻真实样本采集、授权 UI、训练质量、合成质量、播放路由和合规验收仍需真机与产品验收。
