# 后端知识治理与来源级联组合 Gate

## Problem

后端治理、Archive 来源级联事务、Context 过滤和 fake Postgres 测试目前分散，缺少一条 deterministic runner 作为 release regression 的后端证据。

## Success Criteria

- 新增后端 smoke runner，覆盖 confirm/reject/correct/deleteSource、owner/revision/幂等/change feed、Archive owner 冲突和组合删除事务。
- runner 证明 rejected/superseded 不进入 Context，replacement 可进入目标 persona。
- runner 同时覆盖 memory 与 fake Postgres，不依赖本机真实 Postgres。
- 后端相关全量验证、compileall 和 `git diff --check` 通过。
