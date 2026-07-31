# V4 M0-A 待确认记忆入口

日期：2026-07-31

## 本轮范围

在既有“今天想聊点什么？”访谈 sheet 内，补充受控的“查看待确认记忆”入口。它只复用已存在的正式确认 inbox，不创建候选、不会把内容写入正式记忆，也不改变 Echo 的默认全屏页面。

## 默认关闭与授权边界

- 入口仅在 `.product` 展示、访谈 continuation 为 `reviewPending`、且 `ownerTruthCandidateReview` 的 feature flag 与发布策略同时允许时出现。
- 默认发布配置下 `ownerTruthCandidateReview` 为非持久化关闭，状态文案退回为“这段分享已经留好”，不会错误暗示用户可以打开待确认内容。
- 点击后传递同一份 `AccountLease`、runtime 和正式 client 给 `OwnerTruthInterviewCandidateConfirmationInboxViewController`；该页面继续执行请求/提交阶段的租约与策略校验。
- 不使用 `OwnerTruthCandidateReviewQAGate`，不读取或渲染候选原文，不接入 MemoryVersion 激活。

## 验证

- 静态守卫：`Scripts/QA/product-v4/owner-truth-candidate-confirmation-presentation-check.swift`
- 默认关闭合同：`Scripts/QA/product-v4/owner-truth-candidate-confirmation-default-off-check.swift`
- UIKit 单测：
  - `testNaturalInputProductPendingConfirmationEntryUsesDedicatedPolicyAndInbox`
  - `testNaturalInputProductPendingConfirmationEntryStaysHiddenWithoutPolicy`
- 模拟器 UIQA：
  `Scripts/QA/prd-stitch-ui/run-owner-truth-interview-natural-input-product-surface-smoke.sh`

本轮 UIQA 产物：

`tmp/visual-qa/product-v4/owner-truth-interview-natural-input-product-surface-smoke/20260731-135514/`

## 部署

仅 iOS 本地界面和 QA 变更；没有后端合同或迁移变更，因此不需要部署后端。
