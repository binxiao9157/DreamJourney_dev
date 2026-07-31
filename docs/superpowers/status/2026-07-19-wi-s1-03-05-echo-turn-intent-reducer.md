# WI-S1-03-05 Echo Turn Intent And Context Coordination

日期：2026-07-19；更新：2026-07-31

## 当前状态

- Work Item：`WI-S1-03-05`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`INTERNAL_READY / G0_STATIC_AND_BUILD_FOR_TESTING_VERIFIED / G1_HOSTED_XCTEST_AND_ECHO_CONTINUOUS_UIQA_VERIFIED / G2_POSTGRES_RUNTIME_VERIFIED / G3_EXTERNAL_DEFERRED`
- 本切片：`WI-S1-03-05-TURN_INTENT_CONTEXT_LEASE_TRANSPORT_AND_IDENTITY_G0_COMPLETE`
- 范围：先将 Echo 的 provider-independent 回合状态收敛为纯 reducer，并让 context build 使用独立
  generation lease；不改公开页面、不接管现有数字人、语音 Provider 或后端 transport。

## 已实现

`EchoViewModel` 增加 `EchoTurnIntentReducer`、`EchoTurnPhase`、`EchoTurnIntent` 和
`EchoTurnTransition`。它只描述回合生命周期，不携带 transcript、context、音频或数字人运行时：

- 正常路径：`starting -> listening -> thinking -> speaking -> replied`；
- 延迟回信：`waitingReply` 阻止另一个采集回合开启；
- 恢复到期回信：使用专用 `restoredDelayedReplyDelivered`，允许已持久化、已验证的回信在 App 重开后的
  `idle` 状态落到 `replied`，但普通 `replyDelivered` 和 `replyStarted` 仍不能从 `idle` 复活旧回调；
- 失败/重试：只有 `failed` 可进入 retry，reset 始终回到 `idle`。

`finishUserVoice` 和 `receiveAIReply` 分别在 `recordUserTurn` / `recordAITurn` 前检查 reducer，
因此无效状态的旧异步回调不会写入记忆、转录或 UI state。显式的安全中性态仍是唯一允许绕过普通
view-state 更新的安全覆盖层。

QA/POC 的腾讯数智人文本、PCM 与复刻 PCM 驱动入口会先发出 `prepareVoiceInteraction`，再注入
模拟回复；这使测试入口遵守同一回合边界，而不是放宽 production reply 的 `idle` 状态规则。

### Context Build Lease And Transport 增量

新增 `EchoApplicationCoordinator`、`EchoContextBuildLease` 和 `EchoContextBuildTransport`。本轮 coordinator
的职责被刻意限制为：

- 每次 `/context/build` 分配单调递增的 generation lease；
- 新回合、账户/角色生命周期失效或页面退出时作废旧 lease；
- 由 `EchoContextBuildTransport` 发起 `/context/build`，并在将 success/failure 回调交给 Controller 前先验证
  当前 lease；
- 成功包必须在 coordinator 内匹配 lease 的 `owner/persona/digitalHuman` 身份；不匹配的包被分类为
  typed `identityMismatch`，不会进入 Controller 的成功、trace 持久化或 DialogEngine 提交路径；
- 后端未配置时不创建 lease，Controller 沿用既有本地 KBLite fallback。

因此旧角色、旧账户或已离开页面的 context response 不会再写入当前回合的 trace。原先基于
`turnID` 字符串的 `latestEchoContextRequestTurnID` 已移除：同一个 turn ID 被重新发起时，也必须以
新的 generation 才能被接收。`EchoViewController` 不再直接组合
`DreamJourneyBackendClient.shared.buildEchoContextPacket`；它仍负责本地 KBLite fallback、
`DialogEngineManager` 提交、诊断渲染和所有数字人/音频行为。身份不匹配时 Controller 只接收拒绝原因，
保留已有的本地 fallback 与脱敏诊断输出；这些职责没有在本轮迁移。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-echo-turn-reducer-gate.sh
bash Scripts/QA/product-v4/run-ios-echo-application-coordinator-gate.sh
```

结果：`PASS`。

- `product-v4-ios-echo-turn-reducer-check.py` 验证 reducer 类型、全部 intent、用户/AI 写入前的
  reducer fence、唯一普通状态写入路径和五条回归测试声明；
- `generic/platform=iOS`、Debug、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功，App 与
  `DreamJourneyTests` bundle 均已编译；
- `git diff --check` 通过；
- 新增 XCTest 覆盖正常回合、空闲态旧回复、延迟回信、App 重开后的到期回信和失败重试。
- 新增 XCTest 覆盖 context build 新请求覆盖旧请求、显式取消拒绝迟到回调、同 turn ID 的新 generation
  拒绝旧 callback、transport callback 被后发 lease 丢弃，以及未配置 transport 时不发起请求；
  还覆盖 transport 返回身份不匹配 packet 时，coordinator 在交给 Controller 前将其分类为拒绝；静态检查
  确认 Controller 不再直接组合 context transport 或直接执行 context response identity policy。

### 2026-07-20 模拟器运行 Gate

此前的实际阻断不是腾讯数智人 SDK 缺少 simulator slice：`VirtualmanStreamSDK.xcframework` 已包含
`ios-arm64_x86_64-simulator`。根因是 CocoaPods 生成的 `Pods-DreamJourney` xcconfig 把
`EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64` 继承给 App；同时 `DreamJourneyTests` 未在
`Podfile` 中声明，后续 `pod install` 会让 test bundle 丢失 Pod 模块搜索路径。

本轮将 `DreamJourneyTests` 作为 `inherit! :search_paths` 的 Pod 子 target，并把现有
`UI_QA_SIMULATOR` 的 device-only linkage 过滤规则同时施加到 App/Test 两个聚合 target。测试 bundle
仅保留 Pod 模块搜索路径，不再重复链接生产 Speech/Map provider binary；运行时仍由宿主 App 单独拥有。

执行：

```bash
pod install
bash Scripts/QA/product-v4/run-ios-simulator-runtime-gate.sh
bash Scripts/QA/product-v4/run-ios-test-foundation-gate.sh
```

结果：

- `xcodebuild -showdestinations` 已列出具体 arm64 `iPhone 17 Pro` simulator；
- XcodeBuildMCP 在该 simulator 成功构建、安装并启动 App，正常落在登录页；
- `run-ios-simulator-runtime-gate.sh` 在 booted iPhone 17 Pro 跑完 `DreamJourneyTests`，`82 passed, 0 failed`；
- `run-ios-test-foundation-gate.sh` 的 SwiftPM `41` 个测试和 `generic/platform=iOS` 的
  `build-for-testing` 均通过；
- 新 gate 要求先执行 `pod install`，以保证 Pods test support config 已更新。

### 2026-07-20 普通 Echo 连续回合 UIQA

新增 provider-free 的 `DJRunEchoContinuousTurnSmoke`。它复用既有
`QAEchoScenarioRunner` 和普通 `EchoViewController`，不启动麦克风、本地 TTS 或数字人 Provider，覆盖：

- 连续两轮 `starting -> listening -> thinking -> speaking -> replied`；
- 使用正常 `stopVoiceCapture()` 语义回到 `idle`；
- stop 后迟到的普通 AI 回信不能重新写入 transcript 或恢复回合；
- 离开 Echo tab 后再次进入仍保持 `idle`；
- 冷启动和进程重启各跑一次；
- provider-free 场景不创建数字人 live panel，仍输出当前 `audioOwner` 诊断值。

离开再进入时，现有页面会按设计重置为一条开场引导。因此 gate 在离开前断言四条真实回合 transcript，
重进后只断言普通 idle 恢复，不将该视觉重置误判为回合丢失。

执行：

```bash
swift Scripts/QA/prd-stitch-ui/echo-continuous-turn-uiqa-smoke-check.swift "$PWD"
python3 Scripts/QA/product-v4/qa-non-echo-dispatch-inventory-check.py
bash Scripts/QA/prd-stitch-ui/run-echo-continuous-turn-uiqa-smoke.sh
```

结果：`PASS`。两次运行均完成，两份 JSON、两张截图和报告位于：

```text
tmp/visual-qa/prd-stitch-ui/echo-continuous-turn-uiqa-smoke/20260720-192714/
```

该 smoke 已接入 release regression 的可选开关：
`RUN_ECHO_CONTINUOUS_TURN_UIQA_SMOKE=1`。完整 release regression 当前仍有一个独立的 archive
static-model gate 依赖漂移，不将其归因于本 Work Item；本切片的专用 static、UIQA、宿主 XCTest 与
generic iPhoneOS build 证据均已通过。

### 2026-07-20 G2 Context/Reply 隔离 Postgres 运行时证据

后端新增 `scripts/backend-echo-context-reply-runtime-postgres-smoke.py` 与
`scripts/run-backend-echo-context-reply-runtime-postgres-smoke.sh`。该 smoke 在临时 Postgres
数据库内使用真实 FastAPI 路由和默认关闭的 delayed-reply completion service，不调用模型、语音或
数字人 Provider，也不写入线上业务库。

后端 `main@4cc7792` 已部署到服务器 API 容器。容器内 smoke 通过，value-free 结果为：

```json
{
  "answerBoundToContext": true,
  "contextIdentityMatched": true,
  "crossOwnerAnswerDenied": true,
  "crossOwnerContextDenied": true,
  "crossOwnerMailboxDenied": true,
  "mailboxBodyRedacted": true,
  "migrationHead": "0028",
  "publicV4RouteDisabled": true,
  "status": "passed"
}
```

同时，`/ready` 返回 `status=ready`，database、schema、auth 与 incident component 均为
`ready`。这只关闭本 Work Item 的 G2 Context/Reply runtime 证据，不等同于模型生成、腾讯数字人或
声音 Provider 已通过 G3。

## 未完成边界

本切片不是 `WI-S1-03-05` 的完整完成声明：

- `EchoApplicationCoordinator` 目前只承接 context build transport、lease 与 response identity 分类，尚未承接
  runtime session、延迟策略、reply dispatch 或 diagnostics；
- `EchoViewController` 仍持有现有 Provider 调度，尚未完成“ViewController 只发 Intent/渲染 ViewState”的
  完整迁移；
- 没有修改 `/context/build`、数字人、声音复刻、KBLite Authority、后端合同或公开 UI；
- 已完成的是 hosted XCTest runtime、普通 Echo 的 provider-free 连续多轮、停止、返回与重启 UIQA，
  以及 Context Packet 到默认关闭 delayed-reply Answer 的隔离 Postgres runtime 证据；
  G3 仍取决于真实 Provider runtime 的独立证据。

## 后续边界

当前 Work Item 的 G0 application-context 边界、G1 hosted XCTest/普通 Echo 连续回合 UIQA，以及
G2 `/context/build` 到 Answer 的后端运行时证据均已可复跑。G3 的真实 Provider runtime 仍必须使用独立、
可审计的 credential/quota/quality receipt，不能由本次模拟器或隔离 Postgres smoke 替代。

按终版路线的 Stage 1 规则，Voice/Digital Human 的真实 Provider 门不能阻塞 Owner 文字核心。因此本项保持
`INTERNAL_READY / G3_EXTERNAL_DEFERRED`，当前执行租约移交给 M0-A 的 Owner Truth Conversation/InterviewSession
bootstrap；不会因该移交删除或弱化 G3。

### 2026-07-30 G0 Context Build AccountLease 交付栅栏

`EchoApplicationCoordinator` 现在将发起 `/context/build` 的 `AccountLease` 绑定到对应
`EchoContextBuildLease`，并在两个检查点验证它：

- request：无效账户 lease 时不发起 transport；
- runtime：异步回调回到主线程后重新验证 lease。若 session、generation、vault 或 authority epoch
  已失效，coordinator 清除该 Context lease，并只交付 value-minimized 的
  `authorityInvalidated(checkpoint, reason)`。

`EchoViewController` 对这类拒绝只取消当前 Context turn/gate 和记录脱敏诊断；不会持久化 packet、提交
DialogEngine，也不会以本地 KBLite fallback 继续旧 owner 的回合。身份不匹配和后端失败的既有处理保持不变。

新增 XCTest 使 request 发出后切换 authority epoch，再返回同一 owner 的 packet；结果必须为
`authorityInvalidated(.runtime, .authorityEpochMismatch)`，且 coordinator 不保留 active lease。

执行：

```bash
DJ_IOS_TEST_DESTINATION='platform=iOS Simulator,id=F54C960B-005F-434A-81E2-557D21AF14ED' \
  bash Scripts/QA/product-v4/run-ios-echo-application-coordinator-gate.sh
xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

结果：静态 gate、`EchoApplicationCoordinatorTests` 和 generic simulator Debug build 均通过。
这是本地 G0 证据，不包含后端部署、Postgres、真实 Provider、公开 UI 或真机声明。

### 2026-07-31 G0 Context Completion 一次性交付栅栏

`EchoApplicationCoordinator` 现在为当前 `/context/build` lease 记录第一条已交付 completion。该
lease 在第一条 callback 后仍保持 active，因此同回合的已存在 QA parity observer 可以配对合法的
Context packet；但重复 success/failure callback 不会第二次进入 Controller。

这收敛了第三方 transport 异常重复回调的边界：不会重复写 Echo trace、诊断或后续 context handling，
也不会让一条已成功的 Context 之后被迟到失败改写。新回合或显式 invalidation 会清空一次性交付标记，
旧 generation 仍由既有 lease 栅栏拒绝。

新增 XCTest 使用会重复调用同一 completion 的 deferred transport，先交付 success，再交付 failure；
断言 completion 只执行一次且原 Context lease 仍可用于当前回合的 observation。静态 gate 同时要求
一次性交付 claim 存在。

执行：

```bash
DJ_IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17' \
  bash Scripts/QA/product-v4/run-ios-echo-application-coordinator-gate.sh
xcodebuild test -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:DreamJourneyTests/EchoApplicationCoordinatorTests \
  -only-testing:DreamJourneyTests/OwnerTruthContractsTests CODE_SIGNING_ALLOWED=NO
xcodebuild build -workspace DreamJourney.xcworkspace -scheme DreamJourney \
  -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

结果：coordinator gate 的 `20/20` XCTest、与 Owner Truth 合并的 `157/157` XCTest、静态 gate、
`git diff --check` 和 generic unsigned iPhoneOS Debug build 均通过。

该变化只涉及 iOS application composition，不修改 `/context/build` payload、后端、Echo 视觉、数字人、
音频 owner 或公开发布策略。

### 2026-07-31 G0 最终 ASR 回合接纳栅栏

`EchoViewModel.finishUserVoice(...)` 现在返回本次用户最终语音是否真的被 `EchoTurnIntentReducer`
接受。它会先依据下一条用户回合和可能的延迟回信计算目标 intent，再在写入记忆、转录、Context 或
延迟回信持久化前做一次精确的 reducer admission。

`EchoViewController.onASRResult(...)` 只在该结果为 `true` 时才继续：创建腾讯数智人用户回合、请求
`/context/build`、持久化 Context trace，以及安排延迟回信通知。重复的最终 ASR callback、迟到回调或
当前状态不接受的回合会记录 value-minimized 的
`userTurnRejectedBeforeRuntimeDispatch`，不会再触发这些运行时副作用。

新增 `EchoViewModelTurnAdmissionTests` 覆盖一条成功 final 后紧跟同内容 duplicate final：仅首条写入
用户 transcript，第二条返回拒绝，状态仍保持首条回合的 `thinking`。正式
`run-ios-echo-application-coordinator-gate.sh` 已纳入 coordinator、turn reducer 和 turn-admission 三组
测试，避免该行为只依赖一次性本地命令。

执行：

```bash
DJ_IOS_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 17' \
  bash Scripts/QA/product-v4/run-ios-echo-application-coordinator-gate.sh
python3 Scripts/QA/product-v4/product-v4-ios-echo-turn-reducer-check.py
python3 Scripts/QA/product-v4/product-v4-current-handoff-check.py
git diff --check
```

结果：`PASS`。模拟器 scoped XCTest 为 `26/26`；静态 reducer/handoff checks 与 diff check 均通过。此前
同一源码修订已完成 `generic/platform=iOS`、Debug、无签名 build。本条仍仅是本地 G0 防重入证据，不包含
后端、Provider、数字人音频、公开 UI、部署或真机结论。
