# P004: 后端 Principal 强绑定

Status: done
Parent: P002
Root: P000
Source Ticket: T002 (split)
Source Check: none
Package: problems/P000/children/P002/children/P004
Body: problems/P000/children/P002/children/P004/README.md
Ticket(s): T003

## Problem
路由 ownership 目前已分类但尚未参与中间件决策，user bearer 在 shadow 模式下仍可能跨 owner 访问，或调用 system-only 任务。

## Success Criteria
- ownerBody/ownerPath mismatch 在 shadow 模式下即时返回 403。
- systemOnly 对 user principal 即时返回 403，backend system token 保持可用。
- owner match 与 family/time-letter/invitation/care delegated 访问保持可用。
- profile、archive、mailbox、voice、KB、session、push、echo、family 有代表性正负向测试。
- 授权拒绝日志继续只记录 hash。

## Subproblems
- none

## Results
- R001

## Latest Check
C001

## Bodies
- Problem: problems/P000/children/P002/children/P004/README.md
- Ticket T003: problems/P000/children/P002/children/P004/tickets/T003.md
- Result R001: problems/P000/children/P002/children/P004/results/R001.md
- Check C001: problems/P000/children/P002/children/P004/checks/C001.md

## Follow-ups
- none
