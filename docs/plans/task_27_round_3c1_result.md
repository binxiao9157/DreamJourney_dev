# Round 3C1 数据 Schema、Backfill 与 Authority 切换结果

## Summary

Round 3C1 已形成从当前 18 表/本地 store 到 V4 typed Authority 的完整数据迁移设计：先按 deterministic catalog 识别、回填和隔离，再通过 W00–W11、authorityEpoch fencing、canonical compare 和 single-authority 逐 Vault 切流。方案明确完整旧历史不可恢复、线上参数未知和 post-cutover 不可恢复 legacy 写 Authority等真实边界。

## Done

- P035 / R025：18 backend tables、12 iOS stores、38 target groups 的 migration/backfill catalog。
- 定义 identity alias、claim-pending subject/vault、migration UUID v5、checkpoint/checksum/tail/quarantine。
- 明确 current state + retained revisions，不伪造 KB 历史、decision actor、对象或 Provider 完成。
- P036 / R026：W00–W11 数据 migration waves、M01–M08 compare、R01–R05 rollback、D01–D07 retirement。
- 定义 authorityEpoch 单调 fencing、single Authority、旧 route facade 和 compatibility projection。
- 新增 DR-040，冻结 cutover/rollback/retirement 参数的实测与批准责任。
- 新增 data-backfill/data-cutover checks，并修复旧 V4 门禁章节越界。

## Verification

- R025/C025 与 R026/C026 均成功。
- Data backfill：18/12/38/18，PASS。
- Data cutover：12 waves、8 mismatches、5 rollbacks、7 retirements、18 scenarios，PASS。
- Data/API/Job/Backend/Evidence/Docs 全部门禁通过；决策登记连续至 DR-040。
- `git diff --check` 在父结果记录前通过。

## Known Gaps

- 本轮是目标迁移合同，不是 migration 代码、生产 DDL、线上 inventory、canary 或恢复演练完成。
- iOS/API/Auth 的 account generation、typed client、旧路由和强身份切流尚未由 3C2 固定。
- Job/Object/Provider 外部副作用与全域退役 runbook 仍由 3C3/3C4 完成。
- 专项 3C1B reviewer 未返回；Round 3D 必须进行新的独立组合审查。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `docs/product/DreamJourney_V4_产品决策登记册_V1.0.md`
- `Scripts/QA/product-v4/product-v4-data-backfill-check.py`
- `Scripts/QA/product-v4/product-v4-data-cutover-check.py`
- `docs/plans/task_27_round_3c1a_result.md`
- `docs/plans/task_27_round_3c1b_result.md`
- `docs/plans/task_27_round_3c1_result.md`
