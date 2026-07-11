# Postgres Receipt 维护与 CLI 实现结果

## Summary

已实现默认 dry-run 的 Postgres receipt 历史瘦身维护、用户级锁/事务隔离、结构化无正文报告和命令行入口；专用测试与后端全量回归通过。

## Done

- `PostgresStore.maintain_knowledge_operation_receipts` 支持 keep-days、batch-size、apply、lock timeout 和 statement timeout。
- 先只读列出候选用户，再按用户独立连接/事务获取 `knowledge:{userId}` advisory xact lock。
- Dry-run 与 apply 使用同一锁边界；dry-run 不执行 UPDATE 并 rollback 只读事务。
- Apply 使用 `FOR UPDATE` 分页读取并批量只更新 result；kind/schema/payload hash/created_at/identity 不变。
- 单用户锁超时、语句超时或转换失败回滚该用户并继续其他用户。
- 报告包含 scanned/candidate/updated/skipped/alreadyCompact/failed、用户计数、失败原因、按 kind 计数和估算 bytes before/after/saved，不输出 receipt 正文。
- `keep_days=0` 可立即盘点；其他 batch/timeout 参数严格验证。
- 新增默认 dry-run CLI，非 Postgres store 明确拒绝。

## Verification

- Receipt maintenance 专项测试 13 项通过。
- Receipt/privacy 组合测试 19 项通过。
- 完整 `STORE_BACKEND=memory scripts/verify_backend.sh`：302 项测试及全部 FastAPI/知识 smoke 通过。
- `py_compile`、CLI `--help` 与 `git diff --check` 通过。

## Gaps

- 尚未执行真实 Postgres dry-run/apply；由 P003 部署阶段先 dry-run、审阅报告后再 apply。
- 组合 smoke、release gate 和运维说明由 P007/P003 收口。

## Artifacts

- `app/services/postgres_store.py`
- `scripts/maintain_knowledge_operation_receipts.py`
- `tests/test_knowledge_receipt_postgres_maintenance.py`
