# 后端保留水位与压缩实现结果

## Summary

已在 memory/Postgres store 实现每用户 change-feed 水位和原子分页读取；`/kb/changes` 对早于水位的请求返回结构化 410，并保持正常 legacy/paginated 200 合同。新增默认 dry-run 的维护脚本，apply 使用 session 维护锁和用户级短事务，只删除连续、满足双窗口保留策略且已有 operation receipt 的历史 change，删除与水位推进同事务；无 receipt legacy change 阻断前缀，receipts 不删除。Purge、mutation、读取和 compactor 统一使用用户知识锁；锁/语句超时只跳过当前用户并可由后续幂等补扫。

## Done

- 原子 change-page、水位、410、短事务 compaction、超时隔离和 purge 锁协议已实现。
- 维护脚本、后端 smoke 与部署说明已更新。

## Verification

- `bash scripts/run-backend-knowledge-change-feed-pagination-smoke.sh`：17 个测试及 API smoke 通过。
- 后端 worker 全量 `unittest discover`：281 个测试通过。
- 后端 worker `scripts/verify_backend.sh`：通过。
- `git diff --check`：通过。
- 独立审查提出的全库长事务、无界锁等待和非法窗口响应漂移均已修复。

## Known Gaps

本地环境无 Docker，真实 Postgres SQL/锁行为需在交付子问题中通过部署环境 smoke 验证；维护 apply 在部署前仍保持人工显式执行。

## Artifacts

- `scripts/maintain_knowledge_change_feed.py`
- `tests/test_knowledge_change_feed_compaction.py`
- `scripts/run-backend-knowledge-change-feed-pagination-smoke.sh`
