# V4 M0-A 待确认记忆入口（已被正式整理确认流程替代）

日期：2026-07-31

## 本轮范围

本文件记录的是早期实现尝试，已由
`2026-07-31-v4-owner-truth-pending-review-batch-acknowledgement.md` 替代。

现在的正式流程为：访谈正常结束后先“确认本次分享”，再由用户明确选择“开始整理”。第二步仅在独立的 `ownerTruthCandidateReview` 策略允许时，把已确认的 review batch 准入私有 Source / effect 整理队列；它不返回候选内容、不创建 Candidate 或 Memory。服务端后续形成正式候选确认 inbox 后，才由 Archive 中独立的候选确认入口读取该 inbox。自然输入 Sheet 的 `reviewPending` 状态不再直接展示或跳转“查看待确认记忆”。

## 默认关闭与授权边界

- 自然输入 Sheet 只在 `.product`、当前 `AccountLease` 有效、自然输入策略允许、会话结束且 continuation 为 `reviewPending` 时提供“确认进入整理”。
- “开始整理”与候选确认均受 `ownerTruthCandidateReview` 的独立 feature flag 与发布策略控制，默认发布态不开放；确认分享不继承这项权限。
- 候选确认入口继续传递同一份 `AccountLease`、runtime 和正式 client 给 `OwnerTruthInterviewCandidateConfirmationInboxViewController`；该页面自行读取服务端确认 inbox 并执行请求/提交阶段的租约与策略校验。
- 两段流程均不使用 `OwnerTruthCandidateReviewQAGate`，不把候选原文带回自然输入 Sheet，也不由整理确认直接触发 MemoryVersion 激活。

## 验证

- 静态守卫：`Scripts/QA/product-v4/owner-truth-candidate-confirmation-presentation-check.swift`，确认自然输入 Sheet 不会在 `reviewPending` 直接进入候选确认。
- 整理准入守卫：`Scripts/QA/product-v4/owner-truth-candidate-proposal-admission-check.swift`，确认独立策略、最小化 payload/receipt 与确认后的显式操作顺序。
- 默认关闭合同：`Scripts/QA/product-v4/owner-truth-candidate-confirmation-default-off-check.swift`
- UIKit 单测：
  - `testNaturalInputProductPendingConfirmationEntryUsesDedicatedPolicyAndInbox`
  - `testNaturalInputProductPendingConfirmationEntryStaysHiddenWithoutPolicy`
- 模拟器 UIQA：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh`

本轮 UIQA 产物：

`tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-212745/`

## 部署

仅 iOS 本地界面和 QA 变更；没有后端合同或迁移变更，因此不需要部署后端。
