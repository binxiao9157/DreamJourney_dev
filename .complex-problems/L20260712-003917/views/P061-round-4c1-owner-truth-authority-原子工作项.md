# P061: Round 4C1：Owner Truth Authority 原子工作项

Status: done
Parent: P053
Root: P000
Source Ticket: T057 (split)
Source Check: none
Package: problems/P000/children/P004/children/P053/children/P061
Body: problems/P000/children/P004/children/P053/children/P061/README.md
Ticket(s): T058

## Problem
当前 Archive、Memory、KBLite、Context 与 Echo 已形成可用链路，但 Source、用户确认事实、派生投影和对话引用的 Authority 仍分散。需要把 `WP-S1-01` 拆成可按 additive、shadow、cohort、cutover、retire 实施的工作项，避免以兼容字段或自动分析结果冒充 Owner 已确认记忆。

## Success Criteria
- 建立覆盖 Source/SourceObject、Candidate、Review inbox、DecisionReceipt、immutable MemoryVersion/correction lineage、Projection、Conversation/Answer/Citation 的连续原子工作项。
- 每项完整填写路线图规定的 16 个字段，绑定 Stage 0 前置、真实 iOS/backend 范围、schema/API/event、authorityEpoch、release policy、迁移、部署和 rollback。
- 明确现有 Archive/KBLite/Context/Memory 的 facade、shadow compare、backfill、cohort cutover 和 legacy writer retirement 顺序。
- failed/unreviewed analysis、草稿时间信件、未接受家庭邀请、未到期收件内容和 runtime 状态不得作为 confirmed Owner facts。
- Owner 文字核心在所有 Optional package 关闭时可完成 Capture→Review→QA→Correction→Rights，并能引用到具体 MemoryVersion/Source。
- 为每项区分 G0/G1/G2/G3/G4，真实 Postgres/cohort 与外部门未满足时不标完成。

## Subproblems
- none

## Results
- R055

## Latest Check
C056

## Bodies
- Problem: problems/P000/children/P004/children/P053/children/P061/README.md
- Ticket T058: problems/P000/children/P004/children/P053/children/P061/tickets/T058.md
- Result R055: problems/P000/children/P004/children/P053/children/P061/results/R055.md
- Check C056: problems/P000/children/P004/children/P053/children/P061/checks/C056.md

## Follow-ups
- none
