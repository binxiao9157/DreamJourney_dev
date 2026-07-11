# P002: 历史知识隐私 metadata 幂等维护工具

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
已落库的 kb snapshots、changes 和 receipts 可能保存 raw source title，需要一个不泄露内容、可 dry-run、可事务 apply、可幂等复跑的清洗路径。

## Success Criteria
- maintenance 同时规范 snapshot/change graph、change mutation 和 receipt result。
- 仅安全重算 `kb.mutation` V2 receipt hash，其他 operation kind 不猜测。
- dry-run 无写入，apply 保留身份/revision，第二次 apply 更新数为 0，异常回滚。
- CLI 只输出聚合计数和 schema/action，不输出正文/source/user/token。

## Subproblems
- none

## Results
- R001

## Latest Check
C001

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R001: problems/P000/children/P002/results/R001.md
- Check C001: problems/P000/children/P002/checks/C001.md

## Follow-ups
- none
