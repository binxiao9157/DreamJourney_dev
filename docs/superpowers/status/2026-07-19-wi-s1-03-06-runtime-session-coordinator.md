# WI-S1-03-06 Echo Runtime Session Coordinator

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-06`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / THIRD_G0_INTERACTION_CALLBACK_FENCE_VERIFIED / G1_G3_G4_OPEN`
- 本切片：`WI-S1-03-06-INTERACTION_CALLBACK_FENCE_G0_COMPLETE`
- 范围：为 Echo 数字人建立本地 RuntimeLease，围住 session 创建、heartbeat、Provider state 和请求级文本/PCM
  回包；不改变全屏 UI、音频 owner、腾讯 Provider 合同或公开发布范围。

## 已实现

`EchoRuntimeSessionCoordinator` 作为纯本地运行时边界，持有一个 `EchoRuntimeLease`：

- lease 同时携带 `AccountLease`、角色 context、session/request、lifecycle/interaction generation、
  provider asset、过期时间和状态；Provider session 仍由后端签发和释放；
- 任何 session 或 interaction callback 都会先验证账户、角色 context、runtime generation、
  lifecycle generation、interaction generation、request 和 session；
- 新角色 session request 会递增 runtime generation，旧角色回包即使晚到也不能激活或绑定新的 UIKit runtime；
- RuntimeLease 模型定义“停止当前回合只递增 interaction generation、保留已建立 session”的目标语义；
  新 interaction 会立即使旧 request 的 token 失效，重复完成/停止不会额外推进 generation；
- 页面退出、完整 runtime 释放或 pending session lifecycle 失效会撤销本地 lease，所有迟到 callback
  只能被拒绝；
- `EchoViewController` 的 `/digital-human/sessions` capability 与 session 创建 callback 已接入该围栏。
  stale contract 继续走已有的后端 release 清理，不能重绑旧角色、旧 asset 或旧 runtime。
- 已激活 session 的 heartbeat 定时器、heartbeat 回包和腾讯运行时 state callback 也携带同一份带 session ID 的
  RuntimeLease token；角色切换、页面释放或 session replacement 后的迟到事件不能再更新当前 runtime、触发恢复或降级；
- 复刻音色 synthesis 回包、文本会话超时、PCM start/chunk/final、PCM stop probe、异常恢复和回信结束后的
  delayed resume 已消费 interaction token。旧 request、旧角色或已停止回合的异步工作不能再把旧音频送入当前腾讯
  session，也不能在新回合后恢复旧录音状态；
- 真正的 `TencentDigitalHumanCloudRuntime` 若没有已激活 RuntimeLease interaction token，会明确降级而不是继续把
  音频送给未受围栏保护的 runtime。UIQA stub 不依赖真实腾讯 session，因此允许其使用既有 mock 路径；
- 腾讯 Provider 的 `onStateChange` 目前不携带 request ID，只能使用 session token 围栏。它不能被表述为已完成的
  request 级回调关联；请求级安全性由本地发起的 synthesis/text/PCM work 和 active request gate 提供。
- session release 回包保持为与 UIKit runtime 解耦的 backend cleanup：它只能维护对应 contract 的 deferred-cleanup
  队列与诊断，不能覆盖当前角色/当前 session 的页面状态。这条 cleanup 路径后续仍会单独补其回执审计。

本轮保留现有 `DigitalHumanLifecycleCoordinator` 和 `DigitalHumanConversationCoordinator`。这是刻意的
渐进迁移：RuntimeLease 已覆盖 session 创建、heartbeat、Provider state 以及 Controller 发起的文本/PCM interaction
callback；background grace、quota/fallback 覆盖与完整 lifecycle 收敛仍在同一 Work Item 的后续切片迁移，避免旧/new
coordinator 同时创建 Provider session。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-echo-runtime-session-coordinator-gate.sh
git diff --check
```

结果：`PASS`。

- `product-v4-ios-echo-runtime-session-coordinator-check.py` 验证 RuntimeLease 类型、Controller 接入点、
  session callback fence 和 XCTest 覆盖声明；
- `echo-runtime-session-coordinator-model-smoke.swift` 实际编译运行，覆盖：角色切换迟到回包、停止回合
  保留 session 但拒绝旧 interaction callback、页面释放后拒绝所有迟到 session callback、替换 session 的
  heartbeat/state callback 因 session ID 不一致被拒绝，以及新 request 拒绝旧 request 的 interaction callback；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功，App 和
  `DreamJourneyTests` bundle 均已编译；
- `git diff --check` 通过。

构建仍会输出既有第三方地图静态库的缺失 object-file warning；本轮没有新增该类 warning，且测试构建结果为
`TEST BUILD SUCCEEDED`。

## 未完成边界

- heartbeat、Provider runtime state 和 Controller 发起的 interaction callback 已消费 RuntimeLease token，但其调度/
  恢复流程仍留在 `EchoViewController`，尚未把所有 lifecycle policy 移为 coordinator 的唯一实现；
- session release 仍是独立 backend cleanup 回包，尚未纳入完整 receipt/audit 模型；
- Provider `onStateChange` 没有 request ID；必须在腾讯 SDK 能力允许或增加 provider event envelope 后，才能把
  provider state 本身提升为 request 级精确关联，当前不能把它误报为已关闭；
- background grace、配额满、普通 Echo fallback 的 RuntimeLease release/callback 拒绝仍缺独立 G0 模型覆盖；
- G1 仍受当前 scheme 没有 runnable simulator destination 阻断；G3 的腾讯配额、session cleanup 和
  Provider runtime；G4 的真机渲染/生命周期都没有因本次 G0 而关闭；
- 不涉及 `WI-S1-03-07` 的 AVAudioSession/AudioOwnerLease 仲裁，也不触及声音复刻质量。

## 下一步

继续 `WI-S1-03-06`：补 background grace、quota failure、普通 Echo fallback 的 RuntimeLease release/callback 拒绝
模型验证，并审计 session release receipt。只有该 coordinator 成为唯一 session creator 后，才能进入 `WI-S1-03-07`
的音频 owner 仲裁。
