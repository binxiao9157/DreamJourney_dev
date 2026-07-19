# WI-S1-01-04 Candidate Inbox Action UIQA 证据

日期：2026-07-19

## 结论

- Work Item：`WI-S1-01-04`
- Authority lock：`OWNER_TRUTH`
- 结果：`INTERNAL_READY / G0_G2_SCOPED_EVIDENCE_PRESENT / IOS_QA_ACTION_UIQA_VERIFIED`
- 发布边界：hidden / QA-only；默认公开版本没有 Candidate Inbox 入口。

## 本次收敛范围

此前 Candidate Inbox UIQA 只验证候选卡片能够渲染。现在 QA-only runner 会沿用页面的
typed review use case，执行一条 `accept` 命令并验证完整的结果状态：

```text
pending Candidate
  -> accept review command
  -> accepted DecisionReceipt consumed
  -> MemoryVersion created
  -> candidate leaves pending Inbox
```

`accept`/`correct` 同时激活 `MemoryVersion` 是已完成的 `WI-S1-01-05` 事务合同；
`reject` 不创建 memory。本 smoke 不伪造公开业务入口，也不请求真实后端或 Provider，
只覆盖 iOS 组合层与 typed 回执消费语义。

## 安全边界

- 仅在 `UI_QA_SIMULATOR` 且带 `DJEnableOwnerTruthCandidateReviewQA` 和
  `DJRunOwnerTruthCandidateInboxSmoke` 时编译、运行。
- 默认 Release、普通 Debug 启动和公开 Archive UI 都不显示此入口。
- QA mock 只暴露一条 owner-scoped pending Candidate；不注入 service token、不跳过
  AccountLease，也不写真实后端数据。
- 正式后端 Owner-only、CAS、跨 vault 拒绝、不可变 receipt 与 Postgres 并发单写证据
  仍以原 `WI-S1-01-04` 后端 smoke 为准。

## 验证

```bash
bash Scripts/QA/prd-stitch-ui/run-owner-truth-candidate-inbox-smoke.sh
bash Scripts/QA/product-v4/run-ios-owner-truth-candidate-client-gate.sh
git diff --check
```

结果：通过。

最近一次 UIQA 产物：

```text
tmp/visual-qa/product-v4/owner-truth-candidate-inbox-smoke/20260719-141022/
```

`owner-truth-candidate-inbox-uiqa-result.json` 断言：

- `candidateVisible=true`
- `reviewActionsAvailable=true`
- `reviewSubmitted=true`
- `reviewAction=accept`
- `terminalDecision=accepted`
- `receiptConsumed=true`
- `memoryVersionCreated=true`
- `candidateRemovedAfterReview=true`

## 后续

`WI-S1-01-04` 不再作为当前执行阻塞。下一项是 `WI-S1-01-06`：将已确认的
MemoryVersion/rights event 收敛为可重建的 KBLite compatibility Projection；在它形成
明确 read envelope 前，不能把 legacy KBLite 当作 confirmed-fact Authority。
