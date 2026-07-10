# P005: iOS 时间信件调度职责收敛

Status: done
Parent: P002
Root: P000
Source Ticket: T002 (split)
Source Check: none
Package: problems/P000/children/P002/children/P005
Body: problems/P000/children/P002/children/P005/README.md
Ticket(s): T004

## Problem
iOS mailbox refresh 会主动调用全局 `/archive/time-letters/dispatch-due`，与服务器已启用的定时调度重复，也要求普通用户具备 system-only 能力。

## Success Criteria
- iOS mailbox refresh 只拉取当前用户 mailbox，不再触发全局 dispatch。
- backend client 的 system API 可保留给 QA/运维，但不在公开 App 生产路径调用。
- 静态检查固定该边界，相关时间信件 QA 不回归。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P002/children/P005/README.md
- Ticket T004: problems/P000/children/P002/children/P005/tickets/T004.md
- Result R002: problems/P000/children/P002/children/P005/results/R002.md
- Check C002: problems/P000/children/P002/children/P005/checks/C002.md

## Follow-ups
- none
