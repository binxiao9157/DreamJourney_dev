# WI-S1-03-10 数字人 Lifecycle Runner Parity G0 子切片

日期：2026-07-19

## 结论

- Work Item：`WI-S1-03-10`
- Authority lock：`IOS_COMPOSITION`
- 本子切片结果：`G0_PARTIAL / DIGITAL_HUMAN_LIFECYCLE_ROUTE_PARITY_VERIFIED`
- 原 `QAEchoExportRunner` 更名为 `QAEchoScenarioRunner`，因为它现在承载一般 Echo UIQA 路由，而非仅 export。
- `EchoDigitalHumanLifecycleSmoke` 已迁移到共享 runner；真实数字人 session、生命周期协调器、音频 owner 与业务行为均未改动。

## 本次范围

1. 共享 runner 继续只负责 key-window/root、Echo route、Tab 选择、重试和结果中的 `selectedTabIndex`。
2. lifecycle 场景保留原有 operation、writer、日志字段和 failure contract：
   - `lifecycleSuspended`
   - `lifecycleRestored`
   - `providerViewPreserved`
   - `backgroundLeaseScheduled` / `backgroundLeaseCancelled` / `backgroundLeaseExpired`
   - `runtimeReleasedAfterGrace`
   - `microphoneAutoStart`
   - `audioOwner`
3. 静态 guard 同步改为从集中式 `QALaunchConfiguration` 读取启动参数，禁止要求 raw argument 回流 `AppDelegate`。

## 边界

- 仅影响 `UI_QA_SIMULATOR && targetEnvironment(simulator)` 下的 QA route。
- 不触及 Tencent session 创建、后台 grace 策略、真实 Provider、麦克风、AVAudioSession、公开 Echo UI 或产品功能。
- 不能将该模拟器 smoke 作为 G3 Provider 或 G4 真机证据。

## 验证

```bash
bash Scripts/QA/product-v4/run-qa-launch-configuration-gate.sh
swift Scripts/QA/prd-stitch-ui/echo-digital-human-lifecycle-uiqa-smoke-check.swift "$PWD"
bash Scripts/QA/prd-stitch-ui/run-echo-digital-human-lifecycle-smoke.sh
```

结果：`PASS`。

- 真实模拟器产物：
  `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/prd-stitch-ui/echo-digital-human-lifecycle-smoke/20260719-115624/`
- 结果包含：`completed=true`、`lifecycleSuspended=true`、`lifecycleRestored=true`、
  `providerViewPreserved=true`、`backgroundLeaseScheduled=true`、
  `backgroundLeaseCancelled=true`、`backgroundLeaseExpired=true`、
  `runtimeReleasedAfterGrace=true`、`microphoneAutoStart=false`、`selectedTabIndex=1`。
- 截图显示暂停态与“轻点话筒继续”文案，符合预期 lifecycle 收敛状态。
- Release iPhoneOS 无签名编译通过；未覆盖本机签名、Team、Bundle ID 或 provisioning profile。

## 后续

下一子切片：`WI-S1-03-10-G0-QA-DIGITAL-HUMAN-RUNTIME-STUB-RUNNER-PARITY`。

仅迁移已有 runtime stub smoke 的 root/Echo 路由，并运行相应静态检查和模拟器 smoke；不改变真实数字人会话或音频路径。
