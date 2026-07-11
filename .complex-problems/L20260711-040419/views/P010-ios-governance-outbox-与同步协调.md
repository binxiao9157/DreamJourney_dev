# P010: iOS Governance Outbox 与同步协调

Status: done
Parent: P003
Root: P000
Source Ticket: T007 (split)
Source Check: none
Package: problems/P000/children/P003/children/P010
Body: problems/P000/children/P003/children/P010/README.md
Ticket(s): T009

## Problem
显式治理动作缺少按用户持久化、revision retry 和 user/persona generation 边界，直接网络调用会在离线或切换角色时丢动作或应用旧回调。

## Success Criteria
- 独立 per-user outbox 原子持久化并可重启恢复。
- KnowledgeSyncCoordinator 串行治理与普通 graph sync。
- 409 刷新后以同 operation ID 重试，成功删除 outbox，失败保留。
- 用户/角色切换后的旧回调不直接应用当前图谱，改走 change-feed refresh。
- 模型/静态 smoke 覆盖队列、隔离、retry 和 metadata 保真。

## Subproblems
- P011: iOS Governance Outbox 持久化模型
- P012: iOS Governance 串行提交与 Generation Gate

## Results
- R009

## Latest Check
C009

## Bodies
- Problem: problems/P000/children/P003/children/P010/README.md
- Ticket T009: problems/P000/children/P003/children/P010/tickets/T009.md
- Result R009: problems/P000/children/P003/children/P010/results/R009.md
- Check C009: problems/P000/children/P003/children/P010/checks/C009.md

## Follow-ups
- none
