# 生产语音 SDK Readiness 边界

日期：2026-06-19

## 本轮目标

把回响语音链路的验收口径固定下来，避免把模拟器 mock、后端 token fallback 或 SDK 初始化成功误写成“生产语音闭环完成”。

当前结论：

- mock ASR/TTS：只验证回响状态机、等待回信、UI 展示和脚本合同。
- 后端 token fallback：只验证 `/voice/realtime-token` 不可用或不兼容时可以回落本地配置，不证明生产语音质量。
- 生产 SDK readiness：必须依赖真机验收，覆盖麦克风、ASR、TTS、播放路由、前后台恢复、截图和日志。
- 只有真机证据包齐全且无 P0/P1 阻塞时，才允许声明生产语音闭环完成。

## iOS 边界实现

新增 `VoiceSDKReadinessSummary`：

- `mockASRTTS`：UIQA simulator 分支，文案为 `UIQA mock ASR/TTS，仅验证状态机`。
- `backendTokenFallback`：后端 runtime token 未配置、获取失败或不兼容，文案为 `后端 token 不可用，使用本地语音配置`。
- `productionSDKNeedsTrueDeviceQA`：配置可用但缺少真机质量证据，文案为 `生产语音待真机验收`。
- `productionSDKVerified`：仅为未来真机证据齐全后预留，当前代码不会默认进入。

Echo hidden QA 入口：

```bash
DJShowVoiceSDKReadinessPreview
```

该入口只在 UIQA simulator 下用于展示 readiness 状态，公开 release 默认不暴露。

## QA 判断

必须区分三类通过：

- 模拟器通过：可以证明 UI 状态、状态机、等待回信和 mock ASR/TTS 行为。
- 后端合同通过：可以证明 `/config/runtime`、`/voice/realtime-token`、token TTL、过期时间和 fallback 合同。
- 生产语音通过：必须在真机上完成麦克风授权/拒绝/恢复、至少一轮 ASR/TTS、播放路由、前后台恢复、截图和日志。

当前不声明生产语音闭环完成。

## 门禁

新增静态检查：

```bash
swift Scripts/QA/prd-stitch-ui/voice-sdk-readiness-boundary-check.swift /Users/yxj/Documents/Codex/Video/DreamJourney_dev
```

该检查已接入 release regression 和 release QA package，防止后续把 mock/fallback/production readiness 混成一个状态。
