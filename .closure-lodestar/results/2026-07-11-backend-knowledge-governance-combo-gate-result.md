# 后端知识治理与来源级联组合 Gate 结果

## Summary

已在后端新增 deterministic 组合 runner，将四类治理、权限、Archive 来源级联、Context 过滤和 memory/fake Postgres 事务证据收敛为单一可复用 gate。

## Done

- 新增 `scripts/run-backend-knowledge-governance-source-cascade-smoke.sh`。
- runner 自动选择 `.venv/bin/python` 或 `python3`，先执行 compileall。
- 强制 `STORE_BACKEND=memory`，运行 governance、archive store、auth、route registry、core services 和 fake Postgres 测试模块。
- 覆盖 confirm/reject/correct/deleteSource、幂等、revision conflict、change feed、跨 owner ID、sealed time letter、组合事务回滚和 Context 过滤。
- runner 可从后端仓库直接调用，退出码可供 iOS release regression 组合开关复用。

## Verification

- 新增组合 runner 通过，共运行 217 个 deterministic tests。
- `scripts/verify_backend.sh` 通过，共运行 243 个 tests，并通过 FastAPI、knowledge delta/v2/evidence smoke。
- 后端 compileall 和 `git diff --check` 通过。

## Known Gaps

- 未连接真实 Postgres 或部署环境；本任务成功标准明确使用 memory/fake Postgres，线上 deployed smoke 留给后续部署验收。

## Artifacts

- `/Users/yxj/Documents/Codex/Video/DreamJourneyBackend/scripts/run-backend-knowledge-governance-source-cascade-smoke.sh`
