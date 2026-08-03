# Round 4C：Owner Truth Loop 与 iOS Runtime 工作包

## Problem

`WP-S1-01`、`WP-S1-02`、`WP-S1-03` 承担 Source 到 Memory、异步 effect 和 iOS composition/runtime 的核心迁移，但当前只有目标合同，没有按 shadow、cohort、cutover 分解的开发顺序。

## Success Criteria

- 为三个 Stage 1 package 建立稳定 atomic work items，覆盖 Source/Candidate/DecisionReceipt/MemoryVersion/Projection/Conversation、Outbox/Job/Inbox 和 iOS application/runtime ports。
- 每项绑定 Stage 0 前置、authorityEpoch、legacy facade、shadow compare、feature flag、迁移与 rollback 边界。
- 明确 Owner 文字核心在 Voice/DH、Publication、Family/Care/TimeLetter 全部关闭时可完成 Capture→Review→QA→Correction→Rights 闭环。
- 将 Echo/Voice/DH runtime 解耦限制在渐进抽取，不进行 UIKit/Stitch UI 或 EchoViewController 一次性重写。
- 每项具备非真机测试、真实 Postgres/部署门和需要时的模拟器/真机门分类。
