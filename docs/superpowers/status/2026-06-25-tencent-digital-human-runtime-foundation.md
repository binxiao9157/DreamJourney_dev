# 2026-06-25 Tencent Digital Human Runtime Foundation

## Scope

本轮只完成腾讯数智人替换的基础架构层，不接入真实腾讯 SDK，不公开数字人入口，不删除当前本地 WKWebView / WASM / MP4 预览链路。

目标是先固定两个后续迁移必需边界：

- iOS 通过 `DigitalHumanRuntime` 抽象消费数字人表现层；
- Backend 通过 `/digital-human/sessions` 下发腾讯会话 mock 合同。

## iOS

新增：

- `DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntime.swift`
- `DreamJourney/Sources/Services/DigitalHuman/AudioOnlyDigitalHumanRuntime.swift`
- `DreamJourney/Sources/Services/DigitalHuman/DigitalHumanRuntimeFactory.swift`
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanSDKRuntimeUnavailable.swift`
- `DreamJourney/Sources/Services/DigitalHuman/TencentDigitalHumanRuntimeStub.swift`
- `DreamJourneyBackendClient.DigitalHumanRuntimeCapability`
- `DreamJourneyBackendClient.DigitalHumanSessionContract`
- `DJRunDigitalHumanRuntimeStubSmoke`
- `Scripts/QA/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh`

当前状态：

- `DigitalHumanRuntime` 定义统一接口：`configure`、`open`、`sendTextChunk`、`sendPCMChunk`、`interrupt`、`close`。
- `DigitalHumanSessionState` 预留腾讯接入需要的 `connecting`、`speaking`、`reconnecting`、`degraded`、`failed` 等状态。
- `AudioOnlyDigitalHumanRuntime` 是正式降级路径，不是第二套数字人渲染器。
- `TencentDigitalHumanSDKRuntimeUnavailable` 是真实腾讯 SDK adapter 的占位实现：不引用 `Virtualman` / TRTC 符号，配置后进入 degraded，任何 open / stream 行为都会抛出 explicit unsupported error。
- `DigitalHumanRuntimeFactory` 统一选择 runtime：`mockContract` 走 `TencentDigitalHumanRuntimeStub`；未来 `tencentSDK` 在真实 adapter 未链接前走 `TencentDigitalHumanSDKRuntimeUnavailable` 并保持 `isRealSDKBacked=false`。
- `TencentDigitalHumanRuntimeStub` 只固定 provider 和状态机合同，不引用 `Virtualman` / TRTC SDK。
- `DJFeature.digitalHumanLivePanel` 仍默认隐藏。
- `DreamJourneyBackendClient` 可以解析 `/config/runtime` 的 `digitalHuman` 能力，并请求 `/digital-human/sessions`。
- Echo 的 hidden/QA smoke 会把后端 session contract 转换为 `DigitalHumanProfile`，经 `DigitalHumanRuntimeFactory` 驱动 `TencentDigitalHumanRuntimeStub`，并验证 `AudioOnlyDigitalHumanRuntime` 降级。
- smoke 结果必须包含 `runtimeIsRealSDKBacked=false`，防止把 stub / mock contract 误标为真实腾讯 SDK 接入完成。
- `RUN_DIGITAL_HUMAN_RUNTIME_STUB_GATE=1 Scripts/QA/prd-stitch-ui/run-release-regression.sh` 会把这条链路作为可选 release regression gate 执行；默认公开 MVP 回归不执行该隐藏 gate。

## Backend

新增：

- `POST /digital-human/sessions`
- `tests/test_digital_human_sessions.py`
- `scripts/run-digital-human-session-contract-smoke.sh`

`/config/runtime` 新增：

```json
{
  "capabilities": {
    "digitalHumanSession": true
  },
  "digitalHuman": {
    "enabled": true,
    "provider": "tencent",
    "providerMode": "mockContract",
    "realProviderReady": false,
    "sdkProvider": "tencent-cloud-digital-human",
    "sdkAuthMode": "appkeyAccessToken",
    "sdkAdapterLinked": false,
    "sdkReadinessMessage": "Tencent digital human appkey/accesstoken and native adapter are not linked in this build.",
    "requiredServerEnv": [
      "TENCENT_DIGITAL_HUMAN_APP_KEY",
      "TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN"
    ],
    "requiredAssetEnv": [
      "TENCENT_DIGITAL_HUMAN_ASSET_VIRTUALMAN_KEY",
      "TENCENT_DIGITAL_HUMAN_VIRTUALMAN_PROJECT_ID"
    ],
    "providerFieldAliases": [
      "asset_virtualman_key",
      "virtualman_project_id",
      "appkey",
      "accesstoken"
    ],
    "optionalASREnv": [
      "TENCENT_DIGITAL_HUMAN_APP_ID",
      "TENCENT_DIGITAL_HUMAN_SECRET_ID",
      "TENCENT_DIGITAL_HUMAN_SECRET_KEY"
    ],
    "sessionEndpoint": "/digital-human/sessions",
    "driveModes": ["streamText", "sendAudio"],
    "fallbackMode": "audioOnly",
    "defaultReleaseVisible": false,
    "requiresBackendIssuedCredential": true,
    "contractVersion": 1
  }
}
```

腾讯数智人会话/API 主链路使用官方 `appkey` 和 `accesstoken`。形象资产使用 `asset_virtualman_key`，或项目建流使用 `virtualman_project_id`，两者二选一。`TENCENT_DIGITAL_HUMAN_APP_ID`、`TENCENT_DIGITAL_HUMAN_SECRET_ID`、`TENCENT_DIGITAL_HUMAN_SECRET_KEY` 只作为 ASR-only 配置，不是当前数智人会话主链路必填项。

`/digital-human/sessions` 当前返回 mock contract：

- provider: `tencent`
- providerMode: `mockContract`
- driveMode: `streamText`
- alphaEnabled: `true`
- smartActionEnabled: `false`
- credential.mode: `backend-issued-mock`
- fallback.mode: `audioOnly`

`lifecycleMode=silent` 会返回 `409`，因为静默态不得创建数字人建流会话。

## Validation

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourney_dev
Scripts/QA/prd-stitch-ui/run-digital-human-runtime-abstraction-check.sh
Scripts/QA/prd-stitch-ui/run-digital-human-session-client-check.sh
Scripts/QA/prd-stitch-ui/run-digital-human-runtime-stub-smoke.sh
```

```bash
cd /Users/yxj/Documents/Codex/Video/DreamJourneyBackend
scripts/run-digital-human-session-contract-smoke.sh
```

Latest evidence:

- Runtime stub smoke result: `tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260625-digital-human-sdk-boundary/digital-human-runtime-stub-smoke-result.json`
- Runtime stub screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260625-digital-human-sdk-boundary/01-digital-human-runtime-stub.png`
- Unavailable adapter smoke result: `tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260625-tencent-sdk-unavailable-adapter/digital-human-runtime-stub-smoke-result.json`
- Unavailable adapter smoke screenshot: `tmp/visual-qa/prd-stitch-ui/digital-human-runtime-stub-smoke/20260625-tencent-sdk-unavailable-adapter/01-digital-human-runtime-stub.png`

## Remaining Work

- Echo 公开主链路改为通过 `DigitalHumanRuntime` 消费数字人表现层。
- 独立腾讯 SDK PoC Target 接入 `VirtualmanStreamSDK` / 定制 TRTC，并把真实 adapter 接入 `DigitalHumanRuntimeFactory` 的 `tencentSDK` 分支。
- 腾讯真实 Project / Asset 建流真机验证。
- 后端保存 `digital_human_provider_assets`、`digital_human_render_sessions`、`provider_usage_records`。
- 腾讯商务/技术确认逝者授权、照片数字人实时交互、声音复刻和 C 端资产创建 API。
