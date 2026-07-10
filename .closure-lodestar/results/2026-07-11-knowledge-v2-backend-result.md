# 后端知识 Mutation V2 与 Tombstone 结果

## Summary

后端知识写入已从全量 graph 合同扩展为兼容 v1 的 Mutation V2，覆盖增量 upsert、tombstone、幂等重放和 Postgres 变更元数据。

## Done

- `/kb/mutations` 新增 `mutationSchemaVersion=2` 增量合同，支持 `people`、`places`、`events`、`facts` 的按 ID upsert。
- 新增带时区 ISO-8601 `deletedAt` 的 tombstone，并确保相同 ID 在不同实体类型之间互不误删。
- v2 upsert 强制要求同步许可隐私范围，拒绝 `localOnly`、缺失 metadata、未知类型、空 ID 和空 mutation。
- 保持 v1 全量 graph 合同兼容；重复 `operationId` 优先返回首次持久化的 schema 与 mutation，跨 schema 重放不改写历史。
- InMemory 与 Postgres 存储均持久化 mutation schema/metadata，change feed 可回传 v2 变更摘要。
- 新增独立 v2 smoke 并接入后端统一验证脚本。

## Verification

- `./scripts/verify_backend.sh`：195 项单测通过。
- FastAPI smoke、知识库 v1 delta smoke、知识库 v2 tombstone smoke 均通过。
- `py_compile`、部署文件检查和 `git diff --check` 均通过。

## Known Gaps

- 本轮未部署服务器，也未运行线上 Postgres smoke；该步骤留在跨仓库交付阶段执行。
- 本轮只提供知识图谱增量与删除合同，不引入向量数据库或公开 UI。

## Artifacts

- `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/app/services/knowledge_store.py`
- `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/backend-knowledge-v2-smoke.py`
- `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/run-backend-knowledge-v2-smoke.sh`
