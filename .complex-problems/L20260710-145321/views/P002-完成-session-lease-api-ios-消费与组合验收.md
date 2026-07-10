# P002: 完成 Session Lease API、iOS 消费与组合验收

Status: done
Parent: P000
Root: P000
Source Ticket: none (none)
Source Check: C001
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
Store 已具备 lease 能力，但尚未对外暴露 v2 session、heartbeat/release/runtime capability，iOS 也没有持有、续租和释放 lease，缺少非真机端到端证据。

## Success Criteria
- 后端 v2 API、runtime capability、heartbeat/release 与结构化容量冲突测试通过。
- iOS 解析 lease，当前 session heartbeat，页面/context/background/provider/stale-response release，用户 stop 保留。
- 新增后端 smoke、iOS guard、模拟器 gate、构建和 diff check。
- 文档和 release regression 开关更新。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R002: problems/P000/children/P002/results/R002.md
- Check C002: problems/P000/children/P002/checks/C002.md

## Follow-ups
- none
