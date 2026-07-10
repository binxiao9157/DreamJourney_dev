# 2026-07-03 数字人与音色复刻链路说明

本文整理当前 DreamJourney 工程里“腾讯数智人 + 火山/豆包音色复刻”的实际调用关系、角色切换规则、服务端音色槽部署方式和排查入口。结论先放前面：当前 Echo 数字人链路不是单一供应商，数字人渲染/口型/播放由腾讯数智人负责，音色复刻训练和复刻 TTS 合成由火山引擎负责，DreamJourney 后端负责把两者桥接起来。

> 2026-07-10 更新：新建 profile 已改用 provider 无关的 `vp_...` 逻辑 ID。真实火山 `S_...` 只保存在后端 `voice_clone_slots/providerSpeakerId` 中，并以独占槽方式绑定；旧的 `voiceProfileId=S_...` 仅作为迁移兼容。

## 当前架构结论

| 模块 | 当前职责 | 不负责什么 |
| --- | --- | --- |
| iOS App | Echo UI、角色切换、麦克风状态、腾讯 SDK 会话、PCM audio-drive 投喂、QA 证据包 | 不保存火山/腾讯服务密钥，不直接调用火山训练/合成 API |
| DreamJourneyBackend | 保存音色 profile、管理火山音色槽池、代理训练/查询/合成、签发腾讯数智人 session、把复刻音频转成腾讯 audio-drive PCM | 不渲染数字人画面，不直接占用 iOS 音频播放 |
| 火山/豆包语音 | 声音复刻训练、复刻音色 TTS 合成 | 不渲染数字人，不负责口型同步画面 |
| 腾讯云数智人 | 云渲染数字人、接管 Echo 数字人模式下的播放和口型、支持 text-drive / audio-drive | 不训练我们的火山复刻音色 |

当前核心原则：

1. **Echo 数字人模式只能有一个音频 owner**：腾讯数智人负责播放和口型时，iOS 本地播放器不能同时播放火山音频。
2. **复刻音色进入 Echo 的正确方式是 `火山合成 -> 后端转 PCM -> iOS 投喂腾讯 audio-drive`**，不是 iOS 本地播放火山 TTS。
3. **AI 助手默认不使用复刻音色**；本人或家人角色只有存在已验收的 `voiceProfileId` 时才使用复刻音色。
4. **音色槽位池部署在服务端 `.env`**；iOS 不写死真实 S_ 音色槽，只消费逻辑 `voiceProfileId`。后端负责独占分配 `providerSpeakerId`，删除后将槽退休而不是自动复用。

## 关键供应商边界

### 火山/豆包语音

火山侧现在承担两件事：

1. 音色复刻训练/查询：后端 `/voice/profiles`、`/voice/profiles/{user_id}/{voice_profile_id}/refresh` 代理调用火山声音复刻接口。
2. 复刻音色 TTS：iOS 向 `/voice/synthesis` 提交逻辑 `voiceProfileId`，后端校验 owner/状态后解析内部 `providerSpeakerId`，再把它作为火山 `voice_type`。

后端使用 `VOLCENGINE_VOICE_CLONE_SPEAKER_ID_MODE` 决定训练时走哪种音色模式：

| 模式 | 训练参数 | 适用场景 |
| --- | --- | --- |
| `customSpeakerId` | `speaker_id=custom_speaker_id` + `custom_speaker_id=<voice_profile_id>` | 后付费自定义音色 |
| `consoleSpeakerId` / `trialSpeakerIdPool` | `speaker_id=<S_...>` | 控制台预创建/免费试用音色槽 |

当前服务器已切到试用音色槽池模式：

```text
VOLCENGINE_VOICE_CLONE_SPEAKER_ID_MODE=trialSpeakerIdPool
VOLCENGINE_VOICE_CLONE_SPEAKER_ID=
VOLCENGINE_VOICE_CLONE_SPEAKER_IDS=S_URAKGqB52,S_TRAKGqB52,S_SRAKGqB52
```

后端会在 Postgres `voice_clone_slots` 中原子分配独占 `S_...` 音色槽，不再根据逻辑 ID 做 hash。分配使用 `FOR UPDATE SKIP LOCKED`，同一个逻辑 profile 重试时复用原槽，不同 profile 不会共享槽。这意味着：

1. 已经训练过并保存到数据库的旧 `voiceProfileId` 不会自动迁移。
2. 新槽位只影响后续新训练。
3. `S_PhXlHqB52` 训练次数耗尽后，不能继续作为默认新训练槽。
4. 三个试用槽最多承载三个未退休 profile；容量用尽会返回明确的 HTTP 409。
5. 删除 profile 后槽位进入 `retired`，不会自动分给另一名用户，避免残留声音数据串用。

### 腾讯云数智人

腾讯侧现在承担 Echo 数字人体验：

1. 后端 `/digital-human/sessions` 签发腾讯云渲染会话信息。
2. iOS 用腾讯 SDK 建立云渲染 session。
3. 数字人画面、远端播放、口型同步由腾讯 SDK 负责。
4. 复刻声音场景下，iOS 把后端返回的 PCM 投喂给腾讯 audio-drive，由腾讯负责播放和口型。

腾讯数智人受云渲染并发配额限制。如果同一资产/项目只有 1 路并发，一台手机占用会话时，另一台手机可能显示：

```text
腾讯数智人并发配额已满，请稍后重试
```

这不是火山音色问题，也不是 iOS 本地编译问题。需要释放腾讯会话等待 TTL，或购买/激活更多并发配额。

## 服务端音色槽部署逻辑

服务端真实 `.env` 不提交到仓库。音色槽池只应该配置在服务器：

```text
VOLCENGINE_VOICE_CLONE_API_KEY=<声音复刻训练/查询 key>
VOLCENGINE_VOICE_CLONE_TTS_API_KEY=<复刻音色 TTS 合成 key>
VOLCENGINE_VOICE_CLONE_TTS_RESOURCE_ID=seed-icl-2.0
VOLCENGINE_VOICE_CLONE_MODEL_TYPE=5
VOLCENGINE_VOICE_CLONE_SPEAKER_ID_MODE=trialSpeakerIdPool
VOLCENGINE_VOICE_CLONE_SPEAKER_IDS=S_URAKGqB52,S_TRAKGqB52,S_SRAKGqB52
```

注意：仅执行 `docker compose restart api` 不一定刷新容器环境变量。更新 `.env` 后需要重建容器：

```bash
cd /opt/services/dreamjourney/DreamJourneyBackend
sudo docker compose up -d --force-recreate api
```

部署后用 `/config/runtime` 核对：

```text
voiceClone.provider=volcengineVoiceCloneV3
voiceClone.synthesisProviderReady=true
voiceClone.voiceClone2TrialReady=true
voiceClone.speakerIdMode=trialSpeakerIdPool
voiceClone.speakerIdPoolCount=3
voiceClone.tencentAudioDrive.supported=true
digitalHuman.provider=tencent
digitalHuman.providerMode=cloudRender
```

## Echo 角色到音色的切换规则

iOS 入口在 `EchoViewController.resolveEchoRoleVoiceProfileSelection()`。

| 当前回响对象 | roleVoiceSource | voiceProfileId 来源 | Echo 声音策略 |
| --- | --- | --- | --- |
| AI 助手 / selfAssistant | `selfAssistantDefault` | `nil` | 用腾讯数智人默认声音 / text-drive，不走复刻 |
| 本人数字人 | `personalOwner` | `VoiceCloneService.shared.currentUsableSpeakerId` | 有 ready/accepted 音色时走火山复刻 + 腾讯 audio-drive |
| 本人但未启用复刻 | `personalOwnerVoiceProfileMissing` | `nil` | 显示“本人暂未启用复刻音色”，不伪装成复刻 |
| 已加入家人 | `familyMember` | `FamilyMember.voiceProfileId`，且 `voiceEnabled=true`、`voiceSampleStatus=ready/accepted` | 用对应家人的复刻音色 |
| 家人未配置音色 | `familyVoiceProfileMissing` | `nil` | 显示“该家人暂未配置复刻音色” |
| 家人邀请未接受/不可用 | `familyMemberUnavailable` | `nil` | 不使用家人音色 |
| 家人资料未同步 | `familyMemberMissing` | `nil` | 不使用家人音色 |

也就是说，“切换到本人/父亲/母亲”等角色后，Echo 是否用复刻音色取决于角色上是否绑定了可用 `voiceProfileId`，不是全局固定某一个音色。

## 完整 Echo 数字人调用链路

### 1. 页面进入 Echo

1. iOS 判断是否展示数字人面板。
2. iOS 加载 `/config/runtime`，获得：
   - 声音复刻是否可合成；
   - `tencentAudioDrive` 是否支持；
   - 腾讯数智人是否 ready。
3. iOS 根据当前角色调用 `/digital-human/sessions`。
4. 后端返回腾讯会话合同：
   - `sessionId`
   - `provider=tencent`
   - `providerMode=cloudRender`
   - `assetKey/providerAssetId`
   - `providerProjectId`
   - `credential.appkey`
   - `credential.accesstoken`
5. iOS 用腾讯 SDK 创建云渲染 session。

### 2. 用户说话

1. iOS 麦克风采集用户输入。
2. Echo 生成回复文本。
3. iOS 记录 `/context/build` trace，包含本轮用了哪些档案/KBLite/persona/care 线索。

### 3. Echo 准备让数字人说话

iOS 先解析当前角色音色：

```text
AI 助手 -> voiceProfileId=nil -> 腾讯 text-drive 默认音色
本人 -> currentUsableSpeakerId -> 如果 ready 则复刻音色
家人 -> family.voiceProfileId -> 如果 ready/accepted 且 enabled 则复刻音色
```

如果有可用 `voiceProfileId`，iOS 调用：

```http
POST /voice/synthesis
{
  "userId": "<current user>",
  "voiceProfileId": "vp_...",
  "text": "<Echo reply>",
  "format": "wav",
  "sampleRate": 16000,
  "speechRate": -10,
  "loudnessRate": 10,
  "outputMode": "tencentAudioDrive"
}
```

后端处理：

1. 用火山 TTS 合成复刻音色。
2. 从火山响应读取 `providerLogId/providerRequestId`，便于查供应商日志。
3. 如果 `outputMode=tencentAudioDrive`，把 WAV/PCM 转成：

```text
format=pcm16kMono
sampleRate=16000
bitsPerSample=16
channelCount=1
encoding=base64
```

4. 返回给 iOS。

iOS 校验响应必须满足：

```text
outputMode=tencentAudioDrive
audio.format=pcm16kMono
sampleRate=16000
bitsPerSample=16
channelCount=1
byteCount>0
```

校验通过后，iOS 调腾讯 SDK 的 audio-drive 路径，把 PCM chunk 投喂给腾讯数智人。此时：

```text
audioOwner=tencentDigitalHuman
```

腾讯负责“声音播放 + 口型同步 + 数字人画面”。

### 4. 没有复刻音色或 provider 失败

当前策略是不静默伪装：

| 场景 | 行为 |
| --- | --- |
| 当前角色没有 ready/accepted `voiceProfileId` | UI 明确提示“暂未启用复刻音色” |
| `/voice/synthesis` 未配置 | UI 提示“复刻声音服务暂不可用” |
| 火山合成失败 | UI 提示“复刻声音生成失败，请稍后重试” |
| 返回音频不是腾讯兼容 PCM | 记录 `incompatibleAudioFormat`，不切默认复刻 |
| 腾讯 session 不可用/配额满 | 回落普通 Echo 或提示腾讯数智人不可用 |

这里的关键是：如果用户正在测“复刻声音是否进入 Echo”，不能在失败时悄悄换成腾讯默认音色，否则听感会误判。

## 音频 owner 规则

iOS 当前用 `EchoDigitalHumanAudioOwner` 记录音频归属：

| audioOwner | 含义 |
| --- | --- |
| `tencentDigitalHuman` | Echo 数字人模式下，腾讯 SDK 接管播放和口型 |
| `fallbackMuted` | 腾讯远端音频已静音，准备恢复用户麦克风采集 |
| `localPreview` | 音色复刻试听，不进入 Echo 主链路 |
| `volcengineLocalTTS` | 普通 Echo fallback 或非数字人路径 |

稳定性原则：

1. Echo 数字人说话时不能同时启动 iOS 本地 TTS 播放器。
2. 音色试听可以本地播放，但不能与腾讯数智人主链路混用。
3. 停止按钮只应该停止麦克风/当前说话，不应该销毁腾讯数字人 session。
4. 页面退出或 provider 真失败时才释放/关闭数字人 session。

之前出现过的“前几个字没声音”“说完后还有一段声音”“口型和声音错位”，本质上都和 audio owner 不唯一或音频 session 抢占有关。

## 数字人生命周期

| 时机 | 应该做什么 |
| --- | --- |
| 进入 Echo 页面 | 创建或恢复腾讯 session |
| 切换本人/家人角色 | 取消旧上下文请求，按新 context 创建/恢复 session |
| 数字人说话中 | 暂停用户麦克风采集，腾讯负责播放/口型 |
| 数字人说完 | 静音腾讯远端音频并恢复麦克风 |
| 用户主动打断 | 停止当前 provider speech，恢复麦克风 |
| 用户点击停止本轮对话 | 停止麦克风和当前播放，但不销毁数字人 |
| 页面退出/销毁 | 释放腾讯 session，避免占用并发配额 |
| 腾讯配额满/连接失败 | 明确提示并 fallback 普通 Echo |

## 后端关键接口

| 接口 | 用途 |
| --- | --- |
| `GET /config/runtime` | 返回火山复刻、腾讯数智人、audio-drive 能力 |
| `POST /digital-human/sessions` | 后端签发腾讯数智人云渲染 session 合同 |
| `POST /voice/profiles` | 保存/提交音色训练合同，后端代理火山训练 |
| `GET /voice/profiles/{user_id}` | 拉取用户音色 profile 列表 |
| `POST /voice/profiles/{user_id}/{voice_profile_id}/refresh` | 查询/刷新火山训练状态 |
| `POST /voice/profiles/{user_id}/{voice_profile_id}/quality-acceptance` | 用户确认试听效果，允许进入 Echo |
| `POST /voice/profiles/{user_id}/{voice_profile_id}/disable` | 禁用音色 |
| `DELETE /voice/profiles/{user_id}/{voice_profile_id}` | 删除/停用音色合同 |
| `POST /voice/synthesis` | 用指定 `voiceProfileId` 合成复刻音频，支持 `outputMode=tencentAudioDrive` |
| `POST /context/build` | 构建本轮 Echo 上下文 trace，辅助排查是否混入错误数据 |

## 关键本地代码位置

### iOS

| 文件 | 关键职责 |
| --- | --- |
| `DreamJourney/Sources/Modules/Echo/EchoViewController.swift` | Echo 数字人 UI、角色音色选择、audio owner、腾讯 text-drive/audio-drive 调用 |
| `DreamJourney/Sources/Services/DreamJourneyBackendClient.swift` | `/config/runtime`、`/digital-human/sessions`、`/voice/synthesis` 合同解析 |
| `DreamJourney/Sources/Memoir/VoiceCloneService.swift` | 本人/当前 persona 音色 profile 保存、验收、可用音色判断 |
| `DreamJourney/Sources/Services/MemoryModel.swift` | 家人 `voiceProfileId`、`voiceSampleStatus`、`voiceEnabled` 和 Echo 可用判断 |

### 后端

| 文件 | 关键职责 |
| --- | --- |
| `app/main.py` | `/digital-human/sessions`、`/voice/profiles`、`/voice/synthesis` 路由 |
| `app/services/voice_clone.py` | 火山训练/查询 provider、`S_` 槽池选择 |
| `app/services/tts.py` | 火山 TTS provider、腾讯 audio-drive PCM 适配 |
| `app/services/runtime_config.py` | `/config/runtime` 能力输出 |
| `app/core/config.py` | 火山/腾讯环境变量读取 |

## QA 与排查入口

### Runtime 能力检查

部署后先看 `/config/runtime`：

```text
voiceClone.synthesisProviderReady
voiceClone.voiceClone2TrialReady
voiceClone.speakerIdMode
voiceClone.speakerIdPoolCount
voiceClone.tencentAudioDrive.supported
digitalHuman.realProviderReady
digitalHuman.providerMode
```

### Echo evidence / QA 面板重点字段

真机问题复现后，导出的 Echo evidence 需要优先看：

```text
roleVoiceSource
voiceProfileId
audioOwner
outputMode
providerLogId
providerRequestId
digitalHumanRuntimeState
digitalHumanSessionReady
digitalHumanProviderMode
fallbackReason
contextOwnerId
```

### 常见问题判断

| 现象 | 优先判断 |
| --- | --- |
| 提示腾讯数智人配额满 | 腾讯云渲染并发 quota，占用会话未释放或额度不足 |
| AI 助手一直是默认音色 | 这是预期，AI 助手 `voiceProfileId=nil` |
| 切家人后还是上一个人的声音 | 检查家人 `voiceProfileId` 是否同步、context 是否切换成功、旧请求是否被忽略 |
| 显示可用但 Echo 不是复刻声音 | 检查 `roleVoiceSource`、`voiceProfileId`、`outputMode=tencentAudioDrive`、`audioOwner=tencentDigitalHuman` |
| 试听是复刻声音，Echo 不是 | 试听走本地 preview，Echo 必须走 `/voice/synthesis + tencentAudioDrive`；看 evidence 是否进入 PCM-drive |
| 说话前有异常响声 | 优先检查是否存在本地播放器和腾讯 SDK 抢 AVAudioSession |
| 前几个字无声/只有尾音 | 优先检查 audio owner 切换、麦克风恢复、腾讯远端静音时机 |
| 火山客服要 logid | 看 `/voice/synthesis` 返回或 Echo evidence 中的 `providerLogId` |

## 当前已知约束

1. 腾讯数智人并发配额是外部资源限制；后端重启不能增加配额。
2. 火山试用音色槽每个槽有训练次数限制，用完需要换新的 `S_...` 槽或购买/开通正式资源。
3. 服务端更新 `.env` 后必须 `docker compose up -d --force-recreate api`，否则容器可能仍使用旧环境变量。
4. 旧的已训练 `voiceProfileId` 不会因为更换槽池自动迁移。
5. 家人音色进入 Echo 依赖家人资料里持久化 `voiceProfileId + voiceSampleStatus + voiceEnabled`。
6. 真机上要确认“复刻音色进入 Echo”，不能只听试听按钮，必须看 Echo evidence 的 `voiceProfileId/outputMode/audioOwner/providerLogId`。

## 建议验收顺序

1. 后端：
   - `/health` 正常；
   - `/config/runtime` 显示火山复刻和腾讯 audio-drive ready；
   - `/digital-human/sessions` 可签发腾讯 session；
   - `/voice/synthesis` 对 ready `voiceProfileId` 返回 `pcm16kMono`。
2. iOS 非真机：
   - 跑 voice clone synthesis runtime smoke；
   - 跑 Tencent backend PCM-drive mock smoke；
   - 跑 Echo evidence bundle 导出 smoke。
3. 真机：
   - AI 助手：默认音色，数字人稳定显示；
   - 本人：选择已验收本人音色，Echo evidence 显示 `roleVoiceSource=personalOwner`；
   - 家人：切换家人后，Echo evidence 显示 `roleVoiceSource=familyMember` 和该家人的 `voiceProfileId`；
   - 验证有声、口型动、可打断、结束后麦克风恢复；
   - 第二台手机同时测试时，单独记录腾讯并发配额表现。
