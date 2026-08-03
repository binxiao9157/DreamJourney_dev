# Round 3C1A Legacy 数据目录与确定性 Backfill 结果

## Summary

已形成覆盖当前后端 18 张表、iOS 12 类本地状态和 V4 38 组目标对象的迁移目录与确定性 backfill 合同。方案以 claim-pending identity alias、migration-only UUID v5、外层 owner authority、checkpoint-after-commit、snapshot/tail catch-up、canonical checksum 和 quarantine 为核心，明确只迁移 current state + retained revisions，不伪造已经丢失的历史、决策 actor 或 Provider 完成状态。

## Done

- Product Spec 新增第 27 节，明确当前启动建表、JSONB、跨 owner upsert、历史压缩和本地 store 事实。
- 定义 `migrate/derive/project/quarantine/do-not-migrate/external-reconcile` 六类迁移动作。
- 定义 migration ledger、batch、link、quarantine 和 verification 临时控制对象。
- 固定新资源 UUID v4、migration target UUID v5、legacy identity alias、claim-pending subject/vault 和强身份 claim 规则。
- 编制 B01–B18 后端表迁移目录，覆盖 owner、ID、cursor、checksum、证据、quarantine 和 verify。
- 编制 I01–I12 iOS 本地 store/runtime/cache 迁移目录，禁止 `legacy_unassigned` 或最后登录账号自动认领。
- 编制 01–38 V4 target object backfill coverage，所有目标对象均有来源或明确不迁/从零创建结论。
- 定义 backfill runner 的 preflight、keyset、snapshot boundary、tail catch-up、重跑、reconcile、history gap 和完成边界。
- 增加 18 个故障场景和实现阶段必须采集的线上 UNKNOWN inventory。
- 独立后端审查确认完整 KB 历史不可恢复、owner/payload 错配、两代 legacy user ID、时间语义和共享连接风险；结论已写回 Product Spec/findings。
- 新增 `product-v4-data-backfill-check.py`，并修复 Data/AuthZ/Job 三个旧门禁跨章节误计数的问题。

## Verification

- Data backfill check：18 backend tables、12 iOS stores、38 target groups、18 scenarios，PASS。
- Data contract check：38 logical rows、9 scenarios，PASS。
- API/AuthZ check：6 principals、36 endpoints、10 errors、13 scenarios，PASS。
- Job/Provider check：15 jobs、10 providers、15 scenarios，PASS。
- Backend evidence check：`main@4c0538b`、58 routes、18 tables、30 components、12 modules、21 migrations，PASS。
- Evidence matrix check：36 requirements，PASS。
- Product V4 docs check：36 requirements、21 conflicts、39 decisions、43 review responses、4 lifecycle banners，PASS。
- `git diff --check` 在 ledger 结果记录前通过。

## Known Gaps

- 没有创建版本化 migration schema、runner、typed V4 table 或实际 backfill 代码。
- 没有读取线上 row count、relation size、owner 冲突、JSONB 分布、对象可达率或历史 gap 数量。
- 没有执行 Postgres backup/restore、锁/并发、batch 中断和真实数据 quarantine 测试。
- legacy identity claim、强身份 binding、authorityEpoch cutover 和 schema contract 尚未实现。
- iOS split-brain session、旧 callback 跨账号写入和全局私有 cache 属 Round 3C2 blocker，本轮只记录、不宣称修复。
- 数据 wave、read fallback、authority cutover 和 rollback 由 Round 3C1B 完成。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `findings.md`
- `Scripts/QA/product-v4/product-v4-data-backfill-check.py`
- `Scripts/QA/product-v4/product-v4-data-contract-check.py`
- `Scripts/QA/product-v4/product-v4-api-authz-check.py`
- `Scripts/QA/product-v4/product-v4-jobs-provider-check.py`
- `docs/plans/task_27_round_3c1a_solution.md`
- `docs/plans/task_27_round_3c1a_result.md`
