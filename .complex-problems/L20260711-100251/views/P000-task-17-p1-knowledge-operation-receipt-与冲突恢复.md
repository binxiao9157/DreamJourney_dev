# P000: Task 17：P1 Knowledge Operation Receipt 与冲突恢复

Status: done
Parent: none
Root: P000
Source Ticket: none (none)
Source Check: none
Package: problems/P000
Body: problems/P000/README.md
Ticket(s): T000

## Problem
Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_17_p1-knowledge-operation-payload-hash.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 17：P1 Knowledge Operation Receipt 与冲突恢复

## Success Criteria
- 新 operation ID 不会把不同 kind/payload 静默当成 duplicate。
- 相同语义 payload 即使 base revision 改变也能安全重放。
- legacy 操作继续兼容，但明确为未验证。
- iOS 不会永久重放 poisoned item，治理隔离项不阻塞后续队列。
- 现有知识、治理、release QA 与非真机构建全部通过。

## Subproblems
- P001: 后端权威 operation receipt 与事务幂等
- P002: iOS payload conflict 恢复与治理隔离
- P003: Task 17 跨仓 QA、文档与非真机验收

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/README.md
- Ticket T000: problems/P000/tickets/T000.md
- Result R003: problems/P000/results/R003.md
- Check C003: problems/P000/checks/C003.md

## Follow-ups
- none
