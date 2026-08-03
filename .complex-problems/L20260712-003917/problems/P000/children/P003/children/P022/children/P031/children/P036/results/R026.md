# Round 3C1B 数据 Migration Waves、Authority Cutover 与 Rollback 结果

## Summary

已将 3C1A 的逐对象 catalog 组织为 W00–W11 可执行 migration waves，并固定 vault 级 `authorityEpoch` fencing、single-authority、canonical shadow compare、promotion gate、分阶段 rollback 和 legacy retirement 合同。方案明确 epoch 提升后不得恢复 legacy 写 Authority；rollback 只能冻结新命令、关闭 exposure 或使用由 V4 Authority 生成的兼容 projection，不能删除已经产生的新事实。

## Done

- Product Spec 新增第 28 节，明确当前没有 migration/cutover 系统的事实边界。
- 定义 migration run 与 cohort 状态机、稳定 HMAC vault cohort 和不可入 cohort 条件。
- 固定 `authorityEpoch` 单调 CAS、request/job/cache/callback fencing 和 stale write 处理。
- 编制 W00–W11：inventory、DB/UoW、migrator、identity bridge、snapshot、tail、shadow、command dry-run、authority cutover、projection cutover、legacy read-only 和 schema contract。
- 每个 wave 具备前置条件、变更、verify/auto-pause、rollback/compensation 和退出证据。
- 定义 M01–M08 canonical mismatch 分级；owner/identity/visibility/terminal version 为零容忍 blocker。
- 定义 R01–R05 pre-cutover、cutover transaction、post-cutover、projection 和 post-contract rollback。
- 定义 D01–D07 客户端、route、timer、projection、schema、credential 和 migration evidence 退役门。
- 固定 go/no-go evidence record 与跨角色批准要求。
- 增加 18 个 migration/cutover/rollback 故障场景。
- 新增 DR-040，将 minClientVersion、cohort、观察窗、M08 预算、RPO/RTO/maxRecoveryTime 等参数纳入实测和批准，不留给实现人员自行假设。
- 新增 `product-v4-data-cutover-check.py` 并将决策连续性门禁扩展到 DR-040。

## Verification

- Data cutover check：12 waves、8 mismatch classes、5 rollback classes、7 retirement items、18 scenarios，PASS。
- Data backfill check：18 backend tables、12 iOS stores、38 target groups、18 scenarios，PASS。
- Data contract check：38 logical rows、9 scenarios，PASS。
- API/AuthZ check：6 principals、36 endpoints、10 errors、13 scenarios，PASS。
- Job/Provider check：15 jobs、10 providers、15 scenarios，PASS。
- Backend evidence check：`main@4c0538b`、58 routes、18 tables，PASS。
- Evidence matrix check：36 requirements，PASS。
- Product V4 docs check：36 requirements、21 conflicts、40 decisions、43 review responses、4 lifecycle banners，PASS。
- 专门的 3C1B reviewer 未在限定时间返回结果，已停止；本轮不把其状态作为成功证据，组合独立复审仍由 Round 3D 执行。

## Known Gaps

- 没有实现 migration runner、authorityEpoch schema/client contract、canonical comparator 或 cohort controller。
- 没有运行真实 Postgres DDL、backup restore、tail/shadow/canary 或 rollback drill。
- minClientVersion、cohort 百分比、观察窗、锁/批次预算和 RPO/RTO 尚未按 DR-040 实测/批准。
- iOS/API/Auth 具体兼容与账号 generation 由 3C2 完成。
- Job/Object/Provider 副作用迁移和跨域总 runbook 分别由 3C3/3C4 完成。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `docs/product/DreamJourney_V4_产品决策登记册_V1.0.md`
- `Scripts/QA/product-v4/product-v4-data-cutover-check.py`
- `Scripts/QA/product-v4/product-v4-docs-check.py`
- `docs/plans/task_27_round_3c1b_solution.md`
- `docs/plans/task_27_round_3c1b_result.md`
