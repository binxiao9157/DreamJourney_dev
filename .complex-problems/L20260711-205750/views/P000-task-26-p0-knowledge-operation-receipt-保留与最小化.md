# P000: Task 26：P0 Knowledge Operation Receipt 保留与最小化

Status: todo
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_26_p0-knowledge-operation-receipt-minimization.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 26：P0 Knowledge Operation Receipt 保留与最小化

## Success Criteria
- compact 后 receipt 不包含 `graph`、实体正文或原始 mutation upserts。
- 同 operationId + 同 payload 重放返回 duplicate、verified，并携带当前权威 graph；revision 不增加。
- 同 operationId + 不同 payload 仍返回冲突。
- governance 重放仍返回合法 summary；archive delete 重放不再次删除或级联。
- change-feed compactor 仍把 compact receipt 视为 receipt，不形成新屏障。
- dry-run 不修改数据库；apply 按用户锁执行、失败按用户回滚并可重复运行。
- 后端测试、跨仓 gate、默认 release regression 与 iOS 两类非真机构建通过。

## Subproblems
- P001: 子问题：Compact Receipt 与安全重放合同
- P002: 子问题：Postgres Receipt Dry-run/Apply 维护
- P003: 子问题：Receipt 最小化跨仓 Gate 与部署收口

## Results
- none

## Latest Check
none

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md

## Follow-ups
- none
