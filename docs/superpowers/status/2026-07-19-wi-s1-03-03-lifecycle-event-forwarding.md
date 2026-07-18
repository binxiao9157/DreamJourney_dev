# WI-S1-03-03 App/Scene 生命周期事件转发接缝

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-03`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / G0_ROOT_AND_ECHO_EVENT_FORWARDING_VERIFIED / G1_SIMULATOR_LIFECYCLE_UIQA_VERIFIED / IOS_LOCAL_COMMITTED / G2_G4_OPEN`
- 本切片：`WI-S1-03-03-ECHO_LIFECYCLE_MIGRATION`
- 范围：统一 Scene 生命周期事件向根协调器的转发，并将 Echo 的前后台事件来源迁移到 root forwarding；不改变 Echo 的音频、腾讯数字人、通知或定时器行为。

## 已实现

- 在纯 Foundation 的租约模型中增加 value-minimized `AppLifecycleEvent` 与 `AppLifecycleEventReceipt`：
  - 记录事件类型、递增序号、是否存在有效 private runtime、generation 与是否具备 policy authority；
  - 不记录 subject、vault、session、policy 值或 provider 状态。
- `SceneDelegate` 只转发以下 UIKit 事件：连接、活跃、失活、进入前台、进入后台、断开。
- `AppCoordinator` 统一捕获已有 `AppFeatureRuntimeContext`，并通过 `AppLifecycleEventForwarder` 决定是否允许私有副作用。
- 原有 `foregroundAfterFamilyRefresh` 流程迁到 forwarding seam：
  1. 进入前台时要求 active `AccountLease` 和匹配的 ReleasePolicy authority epoch；
  2. 发起 Family refresh 前执行 runtime lease 校验；
  3. Family 回调后再次执行 commit lease 校验；
  4. 仅在同一代租约仍有效时同步 Knowledge。
- `AppLifecycleEventForwarder` 发布仅含事件、序号、runtime disposition 和可选 lifecycle generation 的 root 通知；不携带 subject、vault、session 或 policy authority 值。
- Echo 只订阅 `djAppLifecycleEventForwarded`，再调用既有 `echoAppWillResignActive`、`echoAppDidEnterBackground`、`echoAppWillEnterForeground` 与 `echoAppDidBecomeActive`。因此暂停、8 秒后台释放、音频恢复、腾讯 runtime 保护和既有 lease/lifecycle token fence 均保持原路径，且不会和 UIKit observer 双触发。
- 这不会改变三 Tab、Echo 全屏、登录路由或任何后端 API。

## 验证证据

1. `python3 Scripts/QA/product-v4/product-v4-ios-lifecycle-event-forwarding-check.py`。
   - 确认 SceneDelegate 仅转发事件；
   - 确认 private foreground effect 位于 AppCoordinator，并具有 runtime 与 commit 两个 lease checkpoint；
   - 确认六个 Scene 回调均未丢失。
2. `swift test --package-path . --scratch-path .build/product-v4-echo-lifecycle` 通过：11 条 XCTest。
   - 新增 receipt 测试，确认活跃 runtime 只暴露 generation/policy presence，非活跃 runtime 不允许触发私有前台刷新。
3. `Scripts/QA/product-v4/run-ios-echo-lifecycle-forwarding-gate.sh` 通过。
   - 静态 Guard；
   - Echo root-event / consumer inventory / 原有 Phase 2 stability Guard；
   - unhosted XCTest；
   - `generic/platform=iOS` 的无签名 `build-for-testing`。
4. `Scripts/QA/prd-stitch-ui/run-echo-digital-human-lifecycle-smoke.sh` 通过。
   - 使用 `com.yxj.dreamjourney.app` 的本地 QA simulator build；
   - UIQA 通过 root event 发布 `.willResignActive -> .didEnterBackground -> .willEnterForeground -> .didBecomeActive`；
   - `lifecycleSuspended`、`lifecycleRestored`、`providerViewPreserved`、`backgroundLeaseScheduled`、`backgroundLeaseCancelled`、`backgroundLeaseExpired`、`runtimeReleasedAfterGrace` 为 `true`；
   - `microphoneAutoStart=false`，暂停文案保持“已暂停，轻点话筒继续”；
   - 截图：`tmp/visual-qa/prd-stitch-ui/echo-digital-human-lifecycle-smoke/20260719-071454/01-echo-digital-human-lifecycle-smoke.png`。
5. `git diff --check` 通过。

## 未完成边界

- 这不是完整的跨模块生命周期迁移：AIRecording 仍直接监听 UIKit；Echo、音频、腾讯数字人、通知、Archive 与 Knowledge 的具体 timer/callback fence 仍保留既有实现，后续必须按模块迁移并记录 stale callback 证据。
- 已有模拟器 root-event 生命周期 smoke，但还没有真机前后台、真实腾讯 Provider 或真实音频路由验收。
- 不将本切片作为任何 Voice/Digital Human、真实后台保活或公开发布放行依据。

## Lifecycle Consumer Inventory v1

来源：`Scripts/QA/product-v4/app-lifecycle-consumer-inventory-v1.json`。

| 消费者 | 当前事件/异步入口 | 现有 fence | 后续迁移顺序 |
| --- | --- | --- | --- |
| App/Scene root | 6 个 Scene 事件、前台 Family/Knowledge refresh | `AppFeatureRuntimeContext`，runtime + commit lease check | 已完成 forwarding seam |
| Echo | root lifecycle event -> 前后台、云端数字人 8 秒释放、音频/回调恢复 | `echoAccountLease`、`DigitalHumanLifecycleToken`、background release lease | 已迁移，不再直接订阅 UIKit |
| AIRecording | 后台停止录音、前台重绑 DialogEngine/检查训练 | `dialogAccountLease`、DialogEngine binding | 2 |
| FamilyRepository | startup work item、后端 bootstrap | `AccountLeaseRuntime` checkpoint | 维持，迁移时只接事件 intent |
| KnowledgeSync | debounce、pull/governance callback | `KnowledgeSyncLeaseContext` | 维持，迁移时只接事件 intent |
| DialogEngine | silence timer、provider callback、local TTS | binding + `AccountLeaseRuntime` | 由 Echo/AIRecording consumer 迁移带入 |
| 延迟回信通知 | 授权/通知 request callback | `EchoDelayedReplyOperationScope` | 独立 notification-entry slice |

账户登出、切号、私有访问冻结和注销仍由 `AccountLifecycleTransitionController` 的 13 个 module teardown registration 串行处理。Scene 生命周期不得复制或抢占该路径。

## 下一步

`WI-S1-03-03` 保持进行中，下一子切片迁移 AIRecording 的后台/前台 observer；必须保留现有录音停止、DialogEngine 重绑和训练检查行为，改为消费 root forwarding event，不能同时保留两个会实际触发副作用的 observer。
