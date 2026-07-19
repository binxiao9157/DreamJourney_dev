# WI-S1-03-06 Echo Runtime Session Coordinator

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-06`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / FIRST_G0_RUNTIME_LEASE_AND_SESSION_CALLBACK_FENCE_VERIFIED / G1_G3_G4_OPEN`
- 本切片：`WI-S1-03-06-RUNTIME_LEASE_AND_SESSION_CREATE_CALLBACK_FENCE_G0_COMPLETE`
- 范围：先为 Echo 数字人建立本地 RuntimeLease 和 session 创建回包围栏；不改变全屏 UI、
  音频 owner、腾讯 Provider 合同或公开发布范围。

## 已实现

`EchoRuntimeSessionCoordinator` 作为纯本地运行时边界，持有一个 `EchoRuntimeLease`：

- lease 同时携带 `AccountLease`、角色 context、session/request、lifecycle/interaction generation、
  provider asset、过期时间和状态；Provider session 仍由后端签发和释放；
- 任何 session 或 interaction callback 都会先验证账户、角色 context、runtime generation、
  lifecycle generation、interaction generation、request 和 session；
- 新角色 session request 会递增 runtime generation，旧角色回包即使晚到也不能激活或绑定新的 UIKit runtime；
- RuntimeLease 模型定义“停止当前回合只递增 interaction generation、保留已建立 session”的目标语义；
  Controller 已在 interaction 失效时通知该模型，但 Provider 文本/PCM callback 对 interaction token 的逐个消费
  仍留在后续切片；
- 页面退出、完整 runtime 释放或 pending session lifecycle 失效会撤销本地 lease，所有迟到 callback
  只能被拒绝；
- `EchoViewController` 的 `/digital-human/sessions` capability 与 session 创建 callback 已接入该围栏。
  stale contract 继续走已有的后端 release 清理，不能重绑旧角色、旧 asset 或旧 runtime。

本轮保留现有 `DigitalHumanLifecycleCoordinator` 和 `DigitalHumanConversationCoordinator`。这是刻意的
渐进迁移：session 创建回包先由新的 RuntimeLease 把关，heartbeat、Provider state callback、恢复策略
和完整生命周期收敛将在同一 Work Item 的后续切片迁移，避免旧/new coordinator 同时创建 Provider session。

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
  保留 session 但拒绝旧 interaction callback、页面释放后拒绝所有迟到 session callback；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功，App 和
  `DreamJourneyTests` bundle 均已编译；
- `git diff --check` 通过。

构建仍会输出既有第三方地图静态库的缺失 object-file warning；本轮没有新增该类 warning，且测试构建结果为
`TEST BUILD SUCCEEDED`。

## 未完成边界

- heartbeat、release callback、Provider runtime state callback 仍由 `EchoViewController` 的既有路径处理，
  尚未完全移动到 coordinator；
- `beginInteraction`/`finishInteraction` 已有纯模型和本地 lifecycle 对齐，但 Provider 文本/PCM callback 的
  逐个 token 消费属于后续子切片；本轮不把该模型测试误报为已完成的真实 Provider interaction 验收；
- G1 仍受当前 scheme 没有 runnable simulator destination 阻断；G3 的腾讯配额、session cleanup 和
  Provider runtime；G4 的真机渲染/生命周期都没有因本次 G0 而关闭；
- 不涉及 `WI-S1-03-07` 的 AVAudioSession/AudioOwnerLease 仲裁，也不触及声音复刻质量。

## 下一步

继续 `WI-S1-03-06`：将 heartbeat、session release 和 provider state callback 逐步改为消费同一个
RuntimeLease callback token，并为 account/role switch、background grace、quota failure 和普通 Echo fallback
补 G0 模型验证。只有该 coordinator 成为唯一 session creator 后，才能进入 `WI-S1-03-07` 的音频 owner 仲裁。
