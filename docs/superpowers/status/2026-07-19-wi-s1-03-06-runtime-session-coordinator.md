# WI-S1-03-06 Echo Runtime Session Coordinator

日期：2026-07-19；更新：2026-07-20

## 当前状态

- Work Item：`WI-S1-03-06`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / G0_LIFECYCLE_FENCE_VERIFIED / G1_SIMULATOR_LIFECYCLE_UIQA_VERIFIED / G3_G4_OPEN`
- 本切片：`WI-S1-03-06-LIFECYCLE_FALLBACK_RELEASE_G0_COMPLETE`
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
- 后台宽限期在创建 timer 时额外捕获 active RuntimeLease session callback；到期时只有账户、角色、lifecycle、
  background lease 和 RuntimeLease session 都仍匹配才会释放。真实腾讯 runtime 若意外缺少 lease，则立即安全释放，
  不保留无法验证的后台 session；
- 配额满和 Provider route failure 已统一进入 `releaseDigitalHumanRuntime`，该路径撤销 RuntimeLease、取消延迟工作、
  关闭 runtime 并回到普通 Echo。因此旧 session/interaction callback 不能在 fallback 后恢复旧角色或旧声音。
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
  heartbeat/state callback 因 session ID 不一致被拒绝、新 request 拒绝旧 request 的 interaction callback，以及
  background/fallback release 同时拒绝旧 session 与 interaction callback；
- Debug、`generic/platform=iOS`、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功，App 和
  `DreamJourneyTests` bundle 均已编译；
- `git diff --check` 通过。

构建仍会输出既有第三方地图静态库的缺失 object-file warning；本轮没有新增该类 warning，且测试构建结果为
`TEST BUILD SUCCEEDED`。

### 2026-07-20 G1 生命周期 UIQA 补证

此前记录的 simulator destination 阻断已通过 hosted XCTest/Pods 配置修复。现使用
`iPhone 17 Pro` 运行：

```bash
SIMULATOR_NAME='iPhone 17 Pro' \
  bash Scripts/QA/prd-stitch-ui/run-echo-digital-human-lifecycle-smoke.sh
swift Scripts/QA/prd-stitch-ui/echo-digital-human-lifecycle-uiqa-smoke-check.swift "$PWD"
DJ_IOS_TEST_BUILD_DESTINATION='generic/platform=iOS' \
  bash Scripts/QA/product-v4/run-ios-echo-runtime-session-coordinator-gate.sh
```

结果：`PASS`。

- UIQA stub 验证 lifecycle suspend/restore、provider view preservation、后台宽限预约/取消/到期释放、
  普通 Echo fallback 与 `microphoneAutoStart=false`；
- 结果 JSON：`tmp/visual-qa/prd-stitch-ui/echo-digital-human-lifecycle-smoke/20260720-194712/echo-digital-human-lifecycle-smoke-result.json`；
- 截图：`tmp/visual-qa/prd-stitch-ui/echo-digital-human-lifecycle-smoke/20260720-194712/01-echo-digital-human-lifecycle-smoke.png`；
- Runtime coordinator static check、模型 smoke 与 generic iPhoneOS `build-for-testing` 均通过。

此处运行的是 `TencentDigitalHumanRuntimeStub`，不创建真实腾讯 session、不使用 Provider 凭据或配额；
因此只关闭 G1 本地生命周期交互证据，不关闭 G3/G4。

## 未完成边界

- G0 覆盖已完成：角色快速切换、late session/callback、stop vs exit、background grace、quota/error 与 ordinary Echo
  fallback 都有模型或静态路径证据；这只证明本地合同，不替代真实腾讯 session/音频行为验收；
- heartbeat、Provider runtime state 和 Controller 发起的 interaction callback 已消费 RuntimeLease token，但其调度/
  恢复流程仍留在 `EchoViewController`，尚未把所有 lifecycle policy 移为 coordinator 的唯一实现；
- session release 仍是独立 backend cleanup 回包，尚未纳入完整 receipt/audit 模型；
- Provider `onStateChange` 没有 request ID；必须在腾讯 SDK 能力允许或增加 provider event envelope 后，才能把
  provider state 本身提升为 request 级精确关联，当前不能把它误报为已关闭；
- G1 的本地 lifecycle UIQA 已通过；G3 的腾讯配额、session cleanup 和 Provider runtime，以及 G4 的
  真机渲染/生命周期都没有因本次 G0/G1 证据而关闭；
- 不涉及 `WI-S1-03-07` 的 AVAudioSession/AudioOwnerLease 仲裁，也不触及声音复刻质量。

## 下一步

`WI-S1-03-06` 已达到内部 G0 完成定义。下一步进入 `WI-S1-03-07`，建立进程级 AudioOwnerLease 与
AVAudioSession 仲裁；session release receipt/audit 和真实腾讯 lifecycle 继续分别保留为 G3/G4 证据，不阻塞
下一项的本地合同开发。
