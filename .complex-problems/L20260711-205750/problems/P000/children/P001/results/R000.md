# Compact Receipt 与安全重放实现结果

## Summary

已完成新旧 receipt 双读、compact envelope 写入、fingerprint-first 重放和四类知识操作兼容；后端相关及全量回归通过。历史数据迁移和跨仓发布门留给后续子问题处理。

## Done

- 后端新增版本化 compact receipt envelope，新写入的 operation receipt 不再保存完整知识图谱或实体正文。
- Postgres 与内存存储同时兼容 legacy full result 和 compact envelope。
- 重放前先校验 operation kind、schema version 与 payload hash；同 payload 返回 duplicate，异 payload 保持 conflict。
- 关联 change 仍存在时，使用 change 重建精确 graph/mutation；change 已压缩时，使用当前权威 snapshot 与结构合法的空 V2 mutation 重建兼容响应。
- `kb.sync`、`kb.mutation`、`kb.governance`、`archive.delete` 四类操作均接入 compact receipt 合同。
- governance/archive receipt 仅保留 ID 级摘要，不保留实体文本。
- server-generated legacy sync compatibility no-op 不再写入无意义 receipt。

## Verification

- 使用项目 `.venv` 运行知识库相关测试：218 项通过。
- 运行 `STORE_BACKEND=memory scripts/verify_backend.sh`：289 项测试、FastAPI smoke、知识库 smoke 与 `git diff --check` 全部通过。
- 新增测试覆盖 compact/full 双读、fingerprint conflict、change 重建、snapshot fallback、governance/archive duplicate 及 Postgres 查询合同。

## Gaps

- 在最终验收前统一 compact replay 的 `receiptCompacted` / `originalRevision` 标记语义。
- 进一步移除或校验 envelope 中与 receipt 表列重复的身份字段，确保结果载荷真正最小化。
- 历史 full receipt 的 dry-run/apply 迁移工具属于 P002，尚未实现；P001 不应单独部署。
- 跨仓发布 gate、部署说明与线上 Postgres 验收属于 P003，尚未实现。

## Artifacts

- 后端：`app/services/knowledge_store.py`
- 后端：`app/services/in_memory_store.py`
- 后端：`app/services/postgres_store.py`
- 后端：`app/main.py`
- 测试：`tests/test_core_services.py`
- 测试：`tests/test_postgres_store.py`
- 测试：`tests/test_knowledge_governance.py`
