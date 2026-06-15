# 真机验证 API 配置清单

本文档列出真机验证需要配置的 endpoint、token 与本地兜底 key。不要把真实密钥提交到仓库；当前仓库内 `Info.plist` 只保留占位符，真机本地值建议放到未提交的 `DreamJourney/Resources/LocalConfig.plist`，或通过 Xcode Scheme 环境变量注入。

## 推荐配置方式

读取优先级：

1. Xcode Scheme 环境变量：支持原始 key，例如 `VolcEngineAPIKey`，也支持 `DREAMJOURNEY_` 前缀蛇形命名，例如 `DREAMJOURNEY_VOLC_ENGINE_API_KEY`。
2. 本机未提交文件：`DreamJourney/Resources/LocalConfig.plist`。该文件已加入 `.gitignore`，构建时会复制到 app bundle。
3. `DreamJourney/Resources/Info.plist`：只作为占位符或 CI build setting fallback，不应写入真实密钥。

提交前会由 `Scripts/SecretConfigVerify/main.py` 检查：敏感 key 不能以真实值出现在 `Info.plist`，`LocalConfig.plist` 必须被 git ignore，且仓库文本不能出现明显 token 形态。

## 新机真机必配项

新电脑、新真机优先走业务后端下发实时语音运行配置，不需要在每台开发机重复配置火山实时语音三件套。

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `DreamJourneyBackendBaseURL` | Scheme env / `LocalConfig.plist` / `Info.plist` fallback | DreamJourney 自有业务后端入口 | 当前可用入口为 `https://www.mmdd10.tech/dreamjourney-api`；正式域名 `https://dreamjourney-api.liftora.cn` 放行后再切换。 |
| `DreamJourneyBackendAPIToken` | Scheme env / `LocalConfig.plist` | 后端接口鉴权 | 如果服务器启用了 `BACKEND_API_TOKEN`，iOS 必须配置同值 token；实时语音配置接口 `/voice/realtime-token` 也依赖它。 |
| `AMapAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 足迹地图、高德 SDK 初始化 | 仅展示地图链路时需要；未配置会跳过 SDK key 注入并导致地图不可用。 |
| `DeepSeekAPIKey` | 后端 `.env` 优先；Scheme env / `LocalConfig.plist` 仅本地兜底 | 回忆录生成、知识抽取、图片分析、DeepSeek chat | 真实测试优先走 DreamJourney 后端代理；不要为了新机验证把 DeepSeek key 写入仓库。 |
| `DeepSeekAPIBaseURL` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | DeepSeek chat completions endpoint | 默认 `https://api.deepseek.com/v1/chat/completions`；如走代理或兼容服务再替换。 |
| `VolcEngineAPIKey` | 后端 `.env` 优先；Scheme env / `LocalConfig.plist` 仅本地兜底 | 新版豆包语音 API Key，用于声音复刻、回忆录 TTS、数字人 WAV TTS 等 HTTP API Key 接入链路 | 真实测试优先放在后端；本地配置仅用于后端不可用时的开发兜底。 |
| `VolcEngineVoiceType` | 后端 `.env` 优先；Scheme env / `LocalConfig.plist` 仅本地兜底 | 新版豆包语音 TTS 的 voice/speaker id | 对应 `/api/v1/tts` 请求体中的 `audio.voice_type`；当前真机配置为 `zh_female_cancan_mars_bigtts`。如果 app 内声音复刻已有 `speakerId`，会优先使用回忆录/本地训练音色。 |

## 本地兜底项

以下项不是新机真机必配。只有当 `DreamJourneyBackendBaseURL` 不可用、后端未部署 `/voice/realtime-token`，或需要离线开发排障时，才需要在本机 `LocalConfig.plist` / Scheme env 配置。

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `VolcEngineRealtimeAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 新版实时对话 SDK 专用 API Key | 可选；仅在控制台/文档明确给出实时 Dialog API Key 时配置。 |
| `VolcEngineRealtimeResourceID` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 实时对话 SDK resource id | 默认 `volc.speech.dialog`；后端下发成功时以后端为准。 |
| `VolcEngineRealtimeAddress` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 实时对话 SDK websocket address | 默认 `wss://openspeech.bytedance.com`；后端下发成功时以后端为准。 |
| `VolcEngineRealtimeURI` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 实时对话 SDK URI | 默认 `/api/v3/realtime/dialogue`；后端下发成功时以后端为准。 |
| `VoiceCloneAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 声音克隆、个性化 TTS 的旧兜底 key | 兼容旧配置；配置了 `VolcEngineAPIKey` 时优先使用新版 key。 |
| `VolcEngineAppID` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 火山端到端实时 Dialog 的 App ID | 官方实时对话链路对应 `X-Api-App-ID`；后端下发成功时无需本地配置。 |
| `VolcEngineAppKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 火山端到端实时 Dialog 的 App Key | 当前实时 Dialog 固定值为 `PlgvMymc7f3tQnJ6`；后端下发成功时无需本地配置。 |
| `VolcEngineAppToken` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 火山端到端实时 Dialog 的 Access Key/Token | 官方实时对话链路对应 `X-Api-Access-Key`；后端下发成功时无需本地配置。 |

## Safety Guard

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `SafetyGuardBaseURL` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 真实 Safety Guard 服务地址 | 也可用环境变量 `DREAMJOURNEY_SAFETY_GUARD_BASE_URL` 覆盖；HTTP client 会归一化到 `/v1/safety/evaluate`。 |
| `SafetyGuardAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | Safety Guard 鉴权 token | 也可用环境变量 `DREAMJOURNEY_SAFETY_GUARD_API_KEY` 覆盖；为空时不会发送 Authorization。 |

## 可选后端

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `OpenAvatarChatBaseURL` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | OpenAvatar chat 后端地址 | 默认 `http://localhost:8283`；真机不能访问 Mac 自己的 `localhost`，需要改成同局域网可访问 IP 或公网/内网域名。 |

## 路演/离线真机开关

这些不是密钥，用于构造稳定演示态：

| 启动参数或环境变量 | 用途 |
| --- | --- |
| `--seed-roadshow-demo` 或 `DREAMJOURNEY_SEED=roadshow_demo` | 灌入路演 mock 数据。 |
| `--reset-roadshow-demo` 或 `DREAMJOURNEY_RESET_DEMO=1` | 清空旧 demo 状态并重新播种。 |
| `--roadshow-offline-mode` 或 `DREAMJOURNEY_ROADSHOW_OFFLINE=1` | 路演离线模式，不调用远端主线。 |
| `--use-mock-dialog-engine` 或 `DREAMJOURNEY_DIALOG_ENGINE=mock` | 使用 mock 对话引擎。 |
| `--use-mock-safety-guard` 或 `DREAMJOURNEY_SAFETY_GUARD=mock_allow` | 使用 mock allow guard。 |

## 当前真机签名上下文

| 项 | 当前值 |
| --- | --- |
| App Bundle ID | `com.yxj.dreamjourney.app` |
| Widget Bundle ID | `com.yxj.dreamjourney.app.widget` |
| Development Team | `2BTR77V3R8` |
| 已验证设备 | iPhone 17 / iOS 26.6 |
