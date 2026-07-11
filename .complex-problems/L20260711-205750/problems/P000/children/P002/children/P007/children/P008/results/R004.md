# 脏 Compact 与扫描完整性修复结果

## Summary

已关闭独立审查发现的维护隐私阻断：所有 receipt 统一 canonical compare，脏 compact 不再被跳过；operation 与用户扫描均改为完整、有界的 keyset 分页。

## Done

- 每行先调用统一转换 helper，仅当转换结果与原 result 完全一致才计为 alreadyCompact/skipped。
- 带 envelope 版本但夹带 graph、mutation、重复身份或私有 summary 的行成为 candidate，apply 后清理。
- Operation 第一页使用无下界查询，后续页才使用 `operation_id > last`，空字符串 ID 不再漏扫。
- 用户发现按 userId keyset 和 batch-size 分页，每页独立只读事务，不再一次 fetchall 全部用户。
- 新增脏 compact apply/二次幂等、空 operation ID fail-visible、多页用户发现无漏重测试。
- 组合 smoke 已纳入这些回归。

## Verification

- Receipt/privacy/change-feed 专项测试 29 项通过。
- Receipt maintenance 组合 smoke 34 项通过。
- 后端全量 verify：304 项测试、FastAPI/knowledge smokes、py_compile 与 diff check 全部通过。

## Gaps

- 真实 Postgres 专有锁/MVCC/JSONB 行为仍需 P003 在线 dry-run/apply 验收。
- `created_at` 运维索引需基于线上规模单独评估，不在 startup schema 中直接创建。

## Artifacts

- `app/services/postgres_store.py`
- `tests/test_knowledge_receipt_postgres_maintenance.py`
- `scripts/run-backend-knowledge-receipt-maintenance-smoke.sh`
