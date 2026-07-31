# Owner Truth：候选提案 ReviewReady 定向确认收件箱 UIQA

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / QA_ONLY / DEFAULT_OFF / NOT_DEPLOYED`

## 本轮闭环

在既有自然输入 Sheet 的候选提案状态入口上，新增并验证 `reviewReady` 的正向交互回归：

- 内存夹具绑定当前 `AccountLease` 与唯一的当前 `reviewBatchId`。
- 点击真实的“查看待确认内容”按钮后，只打开该批次的既有确认收件箱。
- 夹具同时提供另一条 `reviewReady` 批次，证明它不会混入当前定向收件箱。
- 不会自动打开确认详情、自动确认候选提案、修正内容或激活 Memory。
- 不启动后端网络、持久化写入、语音回合或数字人会话。
- 既有 `notReady` 烟测复跑后仍保持确认收件箱关闭。

该闭环只验证 iOS 模拟器内存夹具和现有页面行为；不改变公开 Echo，不新增后端代码，不构成部署、Provider 或真机证据。

## 验证证据

- `owner-truth-candidate-proposal-status-handoff-check.swift`：通过。
- `owner-truth-candidate-confirmation-presentation-check.swift`：通过。
- `DreamJourneyTests/OwnerTruthContractsTests`：151/151 通过。
- `run-owner-truth-interview-candidate-proposal-review-ready-smoke.sh`：通过。
- `run-owner-truth-interview-natural-input-product-surface-smoke.sh`：通过。
- 通用未签名 iPhoneOS Debug 编译：通过。
- 可选发布回归开关：`RUN_OWNER_TRUTH_CANDIDATE_PROPOSAL_REVIEW_READY_SMOKE=1`。

全量 `run-release-regression.sh` 已调用到既有必经的 C00 当前状态库存冻结门，但该门因全局后端基线过期而停止，尚未执行到本轮可选烟测。冻结清单记录的是 38 个迁移、106 条路由；当前干净后端基线已经是 70 个迁移、148 条路由。此偏差早于且独立于本轮 iOS 改动，不在本小闭环中刷新 C00 清单，以免把迁移库存重建混入确认收件箱 UIQA。

正向烟测截图：

`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-candidate-proposal-review-ready-smoke/20260731-222003/01-owner-truth-interview-candidate-proposal-review-ready-smoke.png`

负向复测截图：

`/Users/yxj/Documents/Codex/Video/DreamJourney_dev/tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-222110/01-owner-truth-interview-natural-input-product-surface-smoke.png`

## 下一边界

下一项 P0 只应在这一交接已经提交后推进：用受控本地/隔离后端证明“候选提案状态读取到 `reviewReady`”与现有确认收件箱之间的端到端 lease、批次和权限边界。它不能绕过确认动作，也不能直接写入或公开 Memory。
