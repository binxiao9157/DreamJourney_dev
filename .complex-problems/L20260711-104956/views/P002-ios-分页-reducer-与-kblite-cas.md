# P002: iOS 分页 reducer 与 KBLite CAS

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P002
Body: problems/P000/children/P002/README.md
Ticket(s): T002

## Problem
iOS 没有 typed page/reducer，`didApplyChanges` 带副作用且只接受终页；KBLite export/merge/apply 之间没有本地 mutation version CAS。

## Success Criteria
- Typed page 与纯 reducer 严格验证 target、revision、hasMore、进展、页数和 legacy 单页。
- Reducer 只保留最终权威 graph，不写任何 store。
- KBLite graph snapshot 带 mutation version，所有保存/用户切换推进版本。
- CAS apply 发现版本变化时拒绝覆盖，model smoke 证明重算后保留本地知识。

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
