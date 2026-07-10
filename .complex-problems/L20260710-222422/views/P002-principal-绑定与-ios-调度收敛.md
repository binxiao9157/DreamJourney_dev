# P002: Principal 绑定与 iOS 调度收敛

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
多数 owner/system 路由只记录 shadow mismatch，user bearer 仍可能访问其他用户资源；iOS 仍主动触发全局时间信件 dispatch。

## Success Criteria
- owner-bound mismatch 和 user 调用 system-only 即时 403，global mode 仍为 shadow。
- owner match、delegated family/time-letter/invitation 和 legacy system token 继续通过。
- iOS mailbox refresh 不再调用 dispatch-due。
- profile/archive/mailbox/voice/KB/session/push/echo/family 等代表性读写有负向测试。

## Subproblems
- P004: 后端 Principal 强绑定
- P005: iOS 时间信件调度职责收敛

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P002/README.md
- Ticket T002: problems/P000/children/P002/tickets/T002.md
- Result R003: problems/P000/children/P002/results/R003.md
- Check C003: problems/P000/children/P002/checks/C003.md

## Follow-ups
- none
