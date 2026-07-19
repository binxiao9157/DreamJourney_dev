# WI-S1-03-05 Echo Turn Intent Reducer

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-05`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / G0_STATIC_AND_BUILD_FOR_TESTING_VERIFIED / G1_G2_G3_OPEN`
- 本切片：`WI-S1-03-05-TURN_INTENT_REDUCER_G0_COMPLETE`
- 范围：先将 Echo 的 provider-independent 回合状态收敛为纯 reducer，阻止旧回调在写入记忆或转录前越过回合边界；不改公开页面、不接管现有数字人或语音 Provider。

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

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-echo-turn-reducer-gate.sh
```

结果：`PASS`。

- `product-v4-ios-echo-turn-reducer-check.py` 验证 reducer 类型、全部 intent、用户/AI 写入前的
  reducer fence、唯一普通状态写入路径和五条回归测试声明；
- `generic/platform=iOS`、Debug、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功，App 与
  `DreamJourneyTests` bundle 均已编译；
- `git diff --check` 通过；
- 新增 XCTest 覆盖正常回合、空闲态旧回复、延迟回信、App 重开后的到期回信和失败重试。

曾尝试在已启动的 `iPhone 17 Pro` 模拟器执行这五条 XCTest，但当前 `DreamJourney` scheme 的
`xcodebuild -showdestinations` 只提供 `Any iOS Simulator Device` placeholder，未提供可运行的
simulator destination。因此测试未在 simulator runtime 实际执行；这不是测试失败，也不能记为 G1。

## 未完成边界

本切片不是 `WI-S1-03-05` 的完整完成声明：

- `EchoApplicationCoordinator` 尚未承接 context build、transport、延迟策略、reply dispatch 和 diagnostics；
- `EchoViewController` 仍持有现有 Provider 调度，尚未完成“ViewController 只发 Intent/渲染 ViewState”的
  完整迁移；
- 没有修改 `/context/build`、数字人、声音复刻、KBLite Authority、后端合同或公开 UI；
- G1 需要修复 scheme 的 simulator destination 后执行可运行 XCTest/UIQA；G2/G3 仍取决于后端与 Provider
  runtime 的独立证据。

## 下一步

在同一 Work Item 内新增最小 `EchoApplicationCoordinator`，先将 context build request、文本 reply
dispatch 和 delayed-reply policy 从 ViewController 的业务编排中移出；保留现有文字 fallback，并用 lease/
generation fence 防止旧角色或旧账户请求回写当前回合。
