# 真机验证 API 配置清单

本文档列出真机验证或路演联调时需要配置的真实 key、endpoint 与本地演示开关。不要把真实密钥提交到仓库；当前仓库内 `Info.plist` 只保留占位符，真机本地值建议放到未提交的 `DreamJourney/Resources/LocalConfig.plist`，或通过 Xcode Scheme 环境变量注入。

## 推荐配置方式

读取优先级：

1. Xcode Scheme 环境变量：支持原始 key，例如 `VolcEngineAPIKey`，也支持 `DREAMJOURNEY_` 前缀蛇形命名，例如 `DREAMJOURNEY_VOLC_ENGINE_API_KEY`。
2. 本机未提交文件：`DreamJourney/Resources/LocalConfig.plist`。该文件已加入 `.gitignore`，构建时会复制到 app bundle。
3. `DreamJourney/Resources/Info.plist`：只作为占位符或 CI build setting fallback，不应写入真实密钥。

提交前会由 `Scripts/SecretConfigVerify/main.py` 检查：敏感 key 不能以真实值出现在 `Info.plist`，`LocalConfig.plist` 必须被 git ignore，且仓库文本不能出现明显 token 形态。

## 必配项

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `AMapAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 足迹地图、高德 SDK 初始化 | 仅展示地图链路时需要；未配置会跳过 SDK key 注入并导致地图不可用。 |
| `DeepSeekAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 回忆录生成、知识抽取、图片分析、DeepSeek chat | 远端生成主线需要。 |
| `DeepSeekAPIBaseURL` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | DeepSeek chat completions endpoint | 默认 `https://api.deepseek.com/v1/chat/completions`；如走代理或兼容服务再替换。 |
| `VolcEngineAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 新版豆包语音 API Key，用于声音复刻、回忆录 TTS、数字人 WAV TTS 等 HTTP API Key 接入链路 | 新版控制台优先配置这一项；HTTP TTS 使用 `/api/v1/tts` + `x-api-key`。实时 Dialog 若未配置专用凭证，会把它作为实验性 `X-Api-Key` 兜底。 |
| `VolcEngineRealtimeAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 新版实时对话 SDK 专用 API Key | 可选；仅在控制台/文档明确给出实时 Dialog API Key 时配置。当前端到端实时对话官方文档仍出现 `X-Api-App-ID`、`X-Api-Access-Key` 与固定 `X-Api-App-Key`，所以真机联调时更建议优先补齐下方旧式三件套。 |
| `VolcEngineRealtimeResourceID` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 实时对话 SDK resource id | 默认 `volc.speech.dialog`；如控制台给出不同资源 ID，以控制台为准。 |
| `VolcEngineRealtimeAddress` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 实时对话 SDK websocket address | 默认 `wss://openspeech.bytedance.com`。 |
| `VolcEngineRealtimeURI` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 实时对话 SDK URI | 默认 `/api/v3/realtime/dialogue`。 |
| `VolcEngineVoiceType` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 新版豆包语音 TTS 的 voice/speaker id | 对应 `/api/v1/tts` 请求体中的 `audio.voice_type`；当前真机配置为 `zh_female_cancan_mars_bigtts`。如果 app 内声音复刻已有 `speakerId`，会优先使用回忆录/本地训练音色。 |
| `VoiceCloneAPIKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 声音克隆、个性化 TTS 的旧兜底 key | 兼容旧配置；配置了 `VolcEngineAPIKey` 时优先使用新版 key。 |
| `VolcEngineAppID` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 火山端到端实时 Dialog 的 App ID | 官方实时对话链路对应 `X-Api-App-ID`；完整配置旧式三件套后，会优先于通用 `VolcEngineAPIKey`。 |
| `VolcEngineAppKey` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 火山端到端实时 Dialog 的 App Key | 官方实时对话链路对应 `X-Api-App-Key`；部分文档示例为固定值，实际以控制台/开通资源为准，不要填新版 API Key。 |
| `VolcEngineAppToken` | Scheme env / `LocalConfig.plist` / `Info.plist` placeholder | 火山端到端实时 Dialog 的 Access Key/Token | 官方实时对话链路对应 `X-Api-Access-Key`；不要填新版 API Key。 |

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
