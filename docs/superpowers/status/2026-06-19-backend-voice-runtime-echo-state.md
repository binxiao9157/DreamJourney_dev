# 后端语音配置合同与回响状态机

日期：2026-06-19

## 范围

本轮只处理两个不依赖真机的闭环：

1. 后端语音运行配置合同：
   - `GET /config/runtime`
   - `POST /voice/realtime-token`
   - token TTL、绝对过期时间、客户端 fallback 元数据
   - iOS 优先消费后端 runtime，失败时回落本地 build settings
2. 回响状态机：
   - 聆听中
   - 思考中
   - 等待回信
   - 已回信
   - 失败/重试

未处理真机麦克风、生产语音质量、APNs provider 投递。

## 后端合同

`/config/runtime` 的 `voice` 节点现在公开：

- `runtimeConfigEndpoint=/voice/realtime-token`
- `fallback.enabled=true`
- `fallback.mode=localBuildSettings`

`/voice/realtime-token` 现在返回：

- `expiresInSeconds=3600`
- `expiresAt`
- `fallback.mode=localBuildSettings`

后端仍保持原有认证方式：如果部署环境配置了 `BACKEND_API_TOKEN`，接口需要 Bearer token；`/health` 保持公开。

## iOS 接入

`DreamJourneyBackendClient` 新增：

- `BackendRuntimeConfig`
- `RealtimeVoiceRuntimeConfig`
- `fetchRuntimeConfig`
- `fetchRealtimeVoiceConfig`
- `isRealtimeVoiceConfigConfigured`

Echo 启动语音时现在执行：

1. 已配置后端 base URL：优先请求 `/voice/realtime-token`。
2. 后端返回未过期且 `authMode=legacy`：注入 `DialogEngineManager`。
3. 后端失败、过期、非 legacy 或字段不完整：回落本地 `VolcEngineAppID/AppKey/AppToken` build settings。

当前 `SpeechEngineToB` 封装只接收 legacy `appID/appKey/appToken`，`api_key` 模式保留为后续 SDK 适配。

## 回响状态机

新增状态机防回退检查：

- `tmp/visual-qa/prd-stitch-ui/echo-state-machine-runtime-check.swift`

本轮补齐两个缺口：

- `retryAfterError()`：错误状态下再次点击麦克风前先明确回到 idle，再进入新一轮启动。
- `markStoredDelayedReplyArrived(_:)`：App 恢复时如果等待回信已到期，不再静默清空为 idle，而是进入 `replied`。

## 回归接入

新增/更新：

- `tmp/visual-qa/prd-stitch-ui/backend-voice-runtime-contract-check.swift`
- `tmp/visual-qa/prd-stitch-ui/echo-state-machine-runtime-check.swift`
- `tmp/visual-qa/prd-stitch-ui/run-release-regression.sh`
- `tmp/visual-qa/prd-stitch-ui/release-qa-package-check.swift`

后续 release regression 会覆盖这两个 guard。

## 验证

已通过：

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
./scripts/verify_backend.sh
```

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
swift tmp/visual-qa/prd-stitch-ui/backend-voice-runtime-contract-check.swift .
swift tmp/visual-qa/prd-stitch-ui/echo-state-machine-runtime-check.swift .
swift tmp/visual-qa/prd-stitch-ui/echo-waiting-reply-policy-check.swift .
swift tmp/visual-qa/prd-stitch-ui/echo-voice-state-visual-check.swift .
```

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
xcodebuild -workspace DreamJourney.xcworkspace -scheme DreamJourney -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath tmp/visual-qa/prd-stitch-ui/DerivedDataBackendVoiceRuntimeEchoState build
```

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
RUN_ID=20260619-backend-voice-runtime-echo-state DERIVED_DATA_PATH=tmp/visual-qa/prd-stitch-ui/DerivedDataBackendVoiceRuntimeEchoStateSmoke tmp/visual-qa/prd-stitch-ui/run-echo-delayed-reply-notification-smoke.sh
```

模拟器 smoke 证据：

- 结果：`tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke/20260619-backend-voice-runtime-echo-state/echo-delayed-reply-notification-smoke-result.json`
- 截图：`tmp/visual-qa/prd-stitch-ui/echo-delayed-reply-notification-smoke/20260619-backend-voice-runtime-echo-state/01-echo-delayed-reply-notification-smoke.png`

已知非阻塞 warning：

- Kingfisher 第三方源码在 Swift 6 语言模式下提示 `private (set)` 空格 warning；本轮未改第三方依赖。

## 剩余边界

- 真机麦克风、ASR/TTS 质量、前后台切换仍需真机验收。
- APNs provider delivery 和真机通知到达仍未验收。
- `api_key` 模式尚未接入当前 iOS `SpeechEngineToB` wrapper。
