# WI-S1-03-04 Owner Truth Candidate Typed Client

日期：2026-07-19

## 当前状态

- Work Item：`WI-S1-03-04`
- Authority lock：`IOS_COMPOSITION`
- Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
- 当前结果：`IN_PROGRESS / G0_TYPED_CLIENT_VERIFIED / IOS_LOCAL_COMMITTED / G1_G2_G4_OPEN`
- 本切片：`WI-S1-03-04-OWNER_TRUTH_CANDIDATE_CLIENT_G0_COMPLETE`
- 范围：为 Archive 内未来的 hidden Candidate Inbox 提供 typed client、命令合同和 fail-closed 解析；本切片不新增页面、公开入口或 Authority writer。

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

## 验证

执行：

```bash
bash Scripts/QA/product-v4/run-ios-owner-truth-candidate-client-gate.sh
```

结果：`PASS`。

- `product-v4-ios-owner-truth-candidate-client-check.py` 验证 QA-only compile/launch guard、
  user session、header、请求 purpose、固定 routes 和 terminal decision/MemoryVersion 边界；
- `swift test --package-path . --scratch-path .build/product-v4-owner-truth-candidate-client`：
  16 个测试全部通过，其中包含 vault mismatch、更正 payload、reject 无 MemoryVersion 与
  accept 缺少 activation 等负例；
- `generic/platform=iOS`、Debug、`CODE_SIGNING_ALLOWED=NO` 的 `build-for-testing` 成功；
- 本轮目标文件 `git diff --check` 通过。

## 未完成边界

本切片不是 `WI-S1-03-04` 的完整完成声明：

- 尚未接入 Archive 的 hidden Candidate Inbox/ViewState/Intent；
- 尚未运行 QA server flag 开启后的真实路由 smoke，因此 G2 仍开放；
- 尚未做 Archive 交互 UIQA，因此 G1 仍开放；
- 不能把 Candidate 审核能力公开，也不能切换 legacy writer；
- 没有改变 KBLite、Archive 现有事实写入、三 Tab 或 Stitch 已对齐视觉；
- G4 的审核体验、隐私与公开策略保持外部开放。

## 下一步

在同一 `WI-S1-03-04` 内，先实现 Archive 内 hidden/QA Candidate Inbox 的
`Intent -> ViewState` 组合层。界面必须复用现有 Archive 卡片风格，只在 QA Gate 打开时
可达；页面不能直接拼 transport payload、信任 ownerId、调用 KBLite authority 或产生
未经 receipt 的写入。完成后分别补 G0 ViewState reducer、G1 simulator UIQA 与可选 G2
已部署路由 smoke。
