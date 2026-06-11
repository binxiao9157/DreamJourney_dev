# 真机验证 API 配置清单

本文档列出真机验证或路演联调时需要配置的真实 key、endpoint 与本地演示开关。不要把真实密钥提交到仓库；建议只在本机 Xcode Scheme、未提交的本地配置或临时签名构建中注入。

## 必配项

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `AMapAPIKey` | `Info.plist` | 足迹地图、高德 SDK 初始化 | 仅展示地图链路时需要；未配置会跳过 SDK key 注入并导致地图不可用。 |
| `DeepSeekAPIKey` | `Info.plist` | 回忆录生成、知识抽取、图片分析、DeepSeek chat | 远端生成主线需要。 |
| `DeepSeekAPIBaseURL` | `Info.plist` | DeepSeek chat completions endpoint | 默认 `https://api.deepseek.com/v1/chat/completions`；如走代理或兼容服务再替换。 |
| `VolcEngineAppID` | `Info.plist` | 火山语音/对话 SDK app id | 真实语音陪伴链路需要。 |
| `VolcEngineAppKey` | `Info.plist` | 火山语音/对话 SDK app key | 真实语音陪伴链路需要。 |
| `VolcEngineAppToken` | `Info.plist` | 火山语音/对话 SDK token | 真实语音陪伴链路需要。 |
| `VoiceCloneAPIKey` | `Info.plist` | 声音克隆、个性化 TTS | 只验证普通 mock/离线路演时可不配。 |

## Safety Guard

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `SafetyGuardBaseURL` | `Info.plist` | 真实 Safety Guard 服务地址 | 也可用环境变量 `DREAMJOURNEY_SAFETY_GUARD_BASE_URL` 覆盖；HTTP client 会归一化到 `/v1/safety/evaluate`。 |
| `SafetyGuardAPIKey` | `Info.plist` | Safety Guard 鉴权 token | 也可用环境变量 `DREAMJOURNEY_SAFETY_GUARD_API_KEY` 覆盖；为空时不会发送 Authorization。 |

## 可选后端

| 配置项 | 读取位置 | 用途 | 备注 |
| --- | --- | --- | --- |
| `OpenAvatarChatBaseURL` | `Info.plist` | OpenAvatar chat 后端地址 | 默认 `http://localhost:8283`；真机不能访问 Mac 自己的 `localhost`，需要改成同局域网可访问 IP 或公网/内网域名。 |

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

