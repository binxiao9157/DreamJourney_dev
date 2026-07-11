# Compact Receipt 标记与最小 envelope 修复结果

## Summary

已移除 compact envelope 中与 receipt 表重复的身份字段，并统一所有 compact duplicate 重放响应的 `receiptCompacted` 与 `originalRevision` 语义；历史 full/compact 双读和现有 API 兼容保持不变。

## Done

- Compact envelope 仅保留版本、原始 revision、mutation schema、可选更新时间、兼容 no-op 标记和 ID-only governance summary。
- 移除 `userId`、`operationId`、`operationKind`、`operationSchemaVersion` 重复字段，身份以 receipt 表列与 fingerprint 为唯一权威来源。
- Change 仍存在和已压缩后的 snapshot fallback 两条重放路径均返回 `receiptCompacted=true` 与 envelope 的 `originalRevision`。
- Reader 继续容忍历史 compact envelope 的额外字段，legacy full result 继续直接双读。
- 更新内存、Postgres、同步与治理回归测试，显式校验最小 envelope 和两条 compact replay 路径。

## Verification

- `STORE_BACKEND=memory .venv/bin/python -m unittest tests.test_core_services tests.test_postgres_store tests.test_knowledge_governance`：218 项通过。
- `STORE_BACKEND=memory scripts/verify_backend.sh`：289 项测试、FastAPI smoke、知识库 delta/V2/evidence smoke 和 diff check 全部通过。
- `py_compile` 与 `git diff --check` 通过。

## Gaps

- 历史 full receipt 的批量最小化仍由 P002 实现，不属于本修复范围。
- 真实 Postgres dry-run/apply 与线上部署验收仍待 P002/P003 完成。

## Artifacts

- `app/services/knowledge_store.py`
- `app/services/in_memory_store.py`
- `app/services/postgres_store.py`
- `tests/test_core_services.py`
- `tests/test_postgres_store.py`
- `tests/test_knowledge_governance.py`
