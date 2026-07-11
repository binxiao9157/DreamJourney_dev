# 子问题：Postgres Receipt Dry-run/Apply 维护

## Problem

需要可审计、可重复、默认不写库的维护路径，把超过保留窗口的 full receipt result 转换为 compact envelope，同时与在线 mutation 和 change compaction 共用锁边界。

## Success Criteria

- Store 提供 dry-run-first 维护方法，按用户 advisory lock 和独立事务运行。
- CLI 支持 keep-days、timeout、apply 和结构化报告。
- apply 失败只回滚当前用户，重复执行无额外修改。
- compact 后结果字节数下降且正文/graph 不存在。
- fake Postgres 和 Store 测试覆盖 dry-run、apply、锁超时、回滚和幂等。
