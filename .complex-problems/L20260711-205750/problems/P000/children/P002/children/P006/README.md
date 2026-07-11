# Postgres Receipt 用户级维护与 CLI

## Problem

需要在真实 Postgres 上默认只读地盘点历史 full receipt，并通过显式 apply 按用户安全转换，避免全表事务、锁等待或单用户坏数据影响整个维护任务。

## Success Criteria

- Postgres store 提供 keep-days/batch-size/timeout/apply 参数化维护方法。
- Dry-run 不执行 UPDATE，不提交数据变化。
- Apply 每个用户独立事务并获取 knowledge user advisory lock；锁超时、statement timeout 或转换失败只记录该用户并继续。
- Payload hash、kind/schema 和 receipt identity 行保持不变。
- 报告只含计数/字节/用户摘要，不含知识正文。
- 第二次 apply 不再更新已 compact 行。
- CLI 默认 dry-run，显式 `--apply` 才写库。
- Fake Postgres 测试覆盖 dry-run、apply、锁超时、回滚、幂等和结构化报告。
