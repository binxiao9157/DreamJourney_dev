# 2026-06-20 声音复刻训练失败根因记录

## 现象

真机音色复刻提交样本后提示：

- `声音复刻训练失败: 音色训练失败`

## 线上证据

从真机 App container 读取到本地状态：

- `dj.voiceclone.speakerId=S_6A71D8D5`
- `dj.voiceclone.sampleStatus=failed`
- 当前用户：`user_9157`

查询部署后端 `/voice/profiles/user_9157` 后，后端已持久化失败 profile：

- `sampleStatus=failed`
- `providerMode=volcengineVoiceCloneV3`
- `providerStatus=failed`
- `providerMessage=voice clone provider error: voice clone provider HTTP 401: {"code":45000010,"message":"Invalid X-Api-Key"}`

结论：这不是 iOS 本地读取失败，也不是后端未部署；当前服务器可达且 `/config/runtime` 返回 `voiceClone.realProviderReady=true`。训练失败的直接原因是服务器侧火山声音复刻 provider 鉴权失败。

## 已修复

1. 后端声音复刻训练请求合同修正：
   - `speaker_id` 固定传 `custom_speaker_id`
   - 自定义音色 ID 传 `custom_speaker_id=<voiceProfileId>`

2. 后端测试补强：
   - 固定 provider 失败时必须持久化 `sampleStatus=failed`
   - 固定 provider 失败时必须持久化 `providerMessage`

3. iOS 展示收敛：
   - `VoiceCloneProfileContract` 解析 `providerStatus/providerMessage`
   - 失败态页面展示友好错误：`服务器火山音色复刻 API Key 无效，请更新后端配置后重试。`

## 仍需服务器处理

服务器 `.env` 需要确认 `VOLCENGINE_VOICE_CLONE_API_KEY` 配置的是火山声音复刻 V3 接口要求的 API Key，而不是普通 Secret Key、App Token 或 SDK App Key。

更新后需要重新部署后端，再用真机重新提交一段合规音频样本验收。

## 2026-06-20 后续处理

- 已将服务器 `VOLCENGINE_VOICE_CLONE_API_KEY` 更新为用户提供的声音复刻 V3 API Key。
- 后端已推送并部署：
  - `27470eb fix: send voice clone resource id header`
  - `26b1f9c fix: align voice clone resource id`
- 服务器容器已重新 build，确认加载：
  - `voice_clone_resource_id=seed-icl-2.0`
  - `voice_clone_tts_resource_id=seed-icl-2.0`
- 部署 smoke 证明 `Invalid X-Api-Key` 已消失。
- 旧真机 profile `S_6A71D8D5` 仍返回 `resource ID is mismatched with speaker related resource`，判断为旧失败 speakerId 已污染或不属于当前资源，不应继续复用。
- iOS 已改为失败/删除/禁用状态下重新提交样本时生成新的 speakerId，避免重试持续命中旧失败音色。

## 验证项

- `STORE_BACKEND=memory PYTHONPATH=. .venv/bin/python -m unittest tests.test_core_services.VoiceCloneProfileAPITests`
- `swift Scripts/QA/prd-stitch-ui/voice-clone-backend-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `swift Scripts/QA/prd-stitch-ui/voice-clone-shell-contract-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev`
- `git diff --check`
