# P002: 子问题：Postgres Receipt Dry-run/Apply 维护

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T003

## Problem
需要可审计、可重复、默认不写库的维护路径，把超过保留窗口的 full receipt result 转换为 compact envelope，同时与在线 mutation 和 change compaction 共用锁边界。

## Success Criteria
- Store 提供 dry-run-first 维护方法，按用户 advisory lock 和独立事务运行。
- CLI 支持 keep-days、timeout、apply 和结构化报告。
- apply 失败只回滚当前用户，重复执行无额外修改。
- compact 后结果字节数下降且正文/graph 不存在。
- fake Postgres 和 Store 测试覆盖 dry-run、apply、锁超时、回滚和幂等。

## Subproblems
- P005: Receipt 历史转换与隐私维护兼容合同
- P006: Postgres Receipt 用户级维护与 CLI
- P007: Receipt 维护组合回归与运维边界

## Results
- R006

## Latest Check
C007

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T003: problems/P000/children/P002/tickets/T003.md
- Result R006: problems/P000/children/P002/results/R006.md
- Check C007: problems/P000/children/P002/checks/C007.md

## Follow-ups
- none
