# WI-S1-03-04 Owner Truth Candidate Typed Client

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-04`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / G0_G1_HIDDEN_QA_VERIFIED / IOS_LOCAL_COMMITTED / G2_G4_OPEN`
- 本切片：`WI-S1-03-04-ARCHIVE_CANDIDATE_INBOX_UIQA_G1_COMPLETE`
- 范围：为 Archive 内 hidden Candidate Inbox 提供 typed client、命令合同、lease-fenced Intent/ViewState 用例和 QA-only 页面；本切片不新增公开入口或 Authority writer。

## 已实现

### iOS typed 合同

`OwnerTruthContracts.swift` 新增候选审核所需的 value type：

- `OwnerTruthCandidateInbox`、`OwnerTruthCandidateInboxItem`、提议值与证据引用；
- `OwnerTruthCandidateReviewCommand`，固定 `accept`、`correct`、`reject` 三种终态动作；
- typed `DecisionReceipt`、`MemoryActivation` 和 command outcome；
- 递归 JSON value，仅限承载 server proposal，不把 `[String: Any]` 或 transport DTO 传给未来 ViewState；
- `OwnerTruthCandidateReviewQAGate`，仅在 Debug 或 `UI_QA_SIMULATOR` 构建中接受 launch argument `DJEnableOwnerTruthCandidateReviewQA`。Release 构建始终关闭。

解析和命令合同均 fail-closed：

- inbox 的 `vaultId` 必须与发起请求的 vault 完全一致；
- Candidate 的 `sourceId` 必须有对应 evidence reference；
- `correct` 必须带非空更正值和 schema version，`accept/reject` 不得夹带更正值；
- `accept/correct` 的成功结果必须带 MemoryVersion activation；
- `reject` 或 invalidated 结果必须是 `notApplicable`，且不得伪造 MemoryVersion 标识；
- 非空但格式错误的 memory ID、hash 或 result 结构不会被静默降级为 `nil`。

### Backend client 边界

`DreamJourneyBackendClient` 仅在 QA Gate 打开时调用已部署的 Owner Truth 路由：

```text
GET  /v2/vaults/{vaultId}/candidates
POST /v2/vaults/{vaultId}/candidates/{candidateId}/decisions
```

两条请求都要求现有 user session，使用 `ownerTruth` request purpose，并附加
`X-DreamJourney-QA-Owner-Truth: 1`。QA Gate 未开启时返回
`featurePolicyDenied(ownerTruthCandidateReview, qaOnlyDisabled)`，不尝试请求、不回退到
legacy writer，也不暴露公共功能。

后端 `WI-S1-01-03..05` 的 Candidate/Decision/MemoryVersion 合同已经兼容部署；本轮没有
修改后端、没有部署，也没有打开服务端 QA flag。

### Intent / ViewState 审核用例

新增 `OwnerTruthCandidateReviewUseCase`，把未来 Archive QA 界面的四个操作收敛为：

- `refresh`；
- `accept(candidateID:)`；
- `correct(candidateID:correctedSummary:)`；
- `reject(candidateID:)`。

该用例在发起请求和提交结果时都校验捕获的 `AccountLease`，并以 operation generation 忽略
旧账户、旧 vault 或旧操作的异步回调。它只把审核所需的预览、记忆类型、视角、证据数量、
敏感级别和审核状态投影为 `OwnerTruthCandidateInboxViewState`；UI 不接触 owner ID、原始
transport payload、KBLite 或 legacy writer。

命令结果还会核验 Candidate ID 和终态 action 是否与本次 Intent 一致。只有验证过的
`accept` receipt 才会从 ViewState 移除对应候选项；更正操作保留原 Candidate content，
仅覆盖可审核的摘要字段。发生 lease 变化、回执不匹配或网络失败时全部 fail-closed，保留
现有列表并返回可重试失败态。

### Archive Hidden Candidate Inbox

Archive 自传页增加了 `审核候选记忆（QA）` 入口，但该入口满足以下全部条件才会存在：

- 当前为本人自传；
- `OwnerTruthCandidateReviewQAGate` 已由 launch argument
  `DJEnableOwnerTruthCandidateReviewQA` 打开；
- 已捕获并验证当前用户的 `AccountLease` 与非空 vault。

默认公开构建、家人只读上下文和未带 launch argument 的 Debug 构建均不会显示该入口。页面
只展示审核预览、记忆类型、视角、认知状态、敏感级别和证据数量；不会向 UI 暴露 owner ID、
source ID、原始 transport payload、KBLite 或 legacy writer。

页面提供刷新、确认、更正后确认和拒绝操作。所有动作继续通过
`OwnerTruthCandidateReviewUseCase` 发出 Intent，只有收到匹配的 typed terminal receipt 才改变
ViewState。UI 失败态保留重新载入入口，且不把服务端失败转成旧 Archive 写入。

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-owner-truth-candidate-client-gate.sh
```

结果：`PASS`。

- `product-v4-ios-owner-truth-candidate-client-check.py` 验证 QA-only compile/launch guard、
  user session、header、请求 purpose、固定 routes 和 terminal decision/MemoryVersion 边界；
- `swift test --package-path . --scratch-path .build/product-v4-owner-truth-candidate-client`：
  20 个测试全部通过，其中包含 vault mismatch、更正 payload、reject 无 MemoryVersion、
  accept 缺少 activation、stale AccountLease 回调和回执终态不匹配等负例；
- `generic/platform=iOS`、Debug、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功；
- 本轮目标文件 `git diff --check` 通过。
- `bash Scripts/QA/prd-stitch-ui/run-owner-truth-candidate-inbox-smoke.sh`：`PASS`。
  该 smoke 以 QA 假候选启动隐藏审核页，不访问部署后端，验证 gate、候选卡片、摘要和审核动作
  可用性；结果与截图保存在：
  `tmp/visual-qa/product-v4/owner-truth-candidate-inbox-smoke/20260719-075600/`。

## 未完成边界

本切片不是 `WI-S1-03-04` 的完整完成声明：

- 尚未运行 QA server flag 开启后的真实路由 smoke，因此 G2 仍开放；
- 不能把 Candidate 审核能力公开，也不能切换 legacy writer；
- 没有改变 KBLite、Archive 现有事实写入、三 Tab 或 Stitch 已对齐视觉；
- G4 的审核体验、隐私与公开策略保持外部开放。

## 下一步

在同一 `WI-S1-03-04` 内，执行可选 G2：在服务端 QA flag 受控开启的环境运行真实
Candidate inbox/decision route smoke，并保留部署证据。该操作不能开启公开 release 路由、
不能改动 legacy writer，也不应绕过 AccountLease 或 owner authorization。
