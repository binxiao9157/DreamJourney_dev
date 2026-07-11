# P009: 家庭授权撤销后的 Echo Context 主动回退

Status: done
Parent: P006
Root: P000
Source Ticket: T006 (split)
Source Check: none
Package: problems/P000/children/P005/children/P006/children/P009
Body: problems/P000/children/P005/children/P006/children/P009/README.md
Ticket(s): T010

## Problem
选中 family context 失效时 getter 虽返回 self，但没有持久化或发送 context change，Echo UI/runtime 可能保留旧角色。

## Success Criteria
- FamilyRepository authority generation 变化后触发 DigitalHumanContextStore reconcile。
- 失效 family context 被持久化为当前用户 self context，并发送 `djDigitalHumanContextDidChange`。
- Echo 复用现有 context observer 取消旧 gate/session request 并重建 self runtime。
- 正常 accepted family context 不产生多余通知或重置。

## Subproblems
- none

## Results
- R008

## Latest Check
C009

## Bodies
- Problem: problems/P000/children/P005/children/P006/children/P009/README.md
- Ticket T010: problems/P000/children/P005/children/P006/children/P009/tickets/T010.md
- Result R008: problems/P000/children/P005/children/P006/children/P009/results/R008.md
- Check C009: problems/P000/children/P005/children/P006/children/P009/checks/C009.md

## Follow-ups
- none
