# Owner Truth：整理状态到候选确认交接（M0-A）

日期：2026-07-31

## 状态

`VERIFIED_LOCAL / DEFAULT_OFF / BACKEND_CONTRACT_ALREADY_DEPLOYED`

本轮完成正式访谈链路中 admission 之后的只读状态消费：

`ended -> acknowledged -> admitted -> status -> reviewReady -> focused confirmation inbox`

它不启用候选提取 worker，不创建或确认 Candidate，也不激活 Memory。

## 已落实的边界

1. admission 成功后，iOS 使用同一 `AccountLease` 和精确 `reviewBatchID` 调用既有 Candidate Proposal Status 合同。
2. 状态只消费值最小化字段：批次、准入、Source、提取、effect、候选审核状态；不读取 Source、Candidate、Memory 或 provider 内容。
3. `requested/notReady` 仅显示“这段分享正在整理”，不会出现候选确认入口。
4. 只有同时满足以下条件，才显示“查看待确认内容”：
   - 当前状态为 `reviewReady`；
   - 回包已绑定当前 `AccountLease`；
   - 回包批次等于 admission receipt 的当前批次；
   - `ownerTruthCandidateReview` 本地 flag 与 release policy 仍允许；
   - 当前自然输入 Sheet 仍是已结束的 `reviewPending` 状态。
5. 该操作只打开已有的候选确认 inbox，并传入 `focusedReviewBatchID`。inbox 仅显示该批次且仅 `reviewReady` 的条目，其他访谈批次不会混入。
6. 用户仍需在 inbox 中显式选择该批次，之后才进入既有确认页。没有自动确认、修正、MemoryVersion 激活或任何后台写入。

## 状态展示

| 后端候选审核状态 | Sheet 展示 | 用户操作 |
| --- | --- | --- |
| `notReady` | 这段分享正在整理 | 查看整理进度 |
| `reviewReady` | 整理完成，等待你确认 | 查看待确认内容 |
| `noCandidates` | 本次暂未形成记忆建议 | 查看整理进度 |
| `extractionFailed` | 整理暂未完成 | 重新查看整理状态 |
| `extractionQuarantined` | 本次整理需要进一步核验 | 查看整理进度 |

## 验证证据

- iOS XCTest：`OwnerTruthContractsTests`，151 项通过。
- 新增静态守卫：
  `Scripts/QA/product-v4/owner-truth-candidate-proposal-status-handoff-check.swift`。
- 既有 admission / confirmation 静态守卫继续通过，并且新的守卫已编排进
  `Scripts/QA/prd-stitch-ui/run-release-regression.sh`。
- 模拟器 UIQA：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh`
  已覆盖 admission 后 `requested/notReady`，确认不提前开放候选确认；没有网络、持久化写入、语音或数字人启动。
- 截图：
  `tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-214909/01-owner-truth-interview-natural-input-product-surface.png`

## 未声明的范围

- 当前 worker 仍为默认关闭；本轮不证明生产环境能形成 `reviewReady`。
- 不证明真实 Candidate 内容质量、正式数据库 worker 执行、公开发布或真机体验。
- 后端合同已存在，本轮没有后端源码、迁移或部署变更。
