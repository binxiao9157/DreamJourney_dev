# P006: iOS Identity-bound Proposal 合并与 Persona 本地策略

Status: done
Parent: P003
Root: P000
Source Ticket: T003 (split)
Source Check: none
Package: problems/P000/children/P003/children/P006
Body: problems/P000/children/P003/children/P006/README.md
Ticket(s): T005

## Problem
KBLiteManager 没有 proposal-first merge、ID remap 或 persona-bound async guard，summary/local fallback 可能跨角色使用知识。

## Success Criteria
- proposal-first 合并复用 exact/local natural match，关系 ID 完成 remap，metadata 持久化。
- 旧 extraction 和 quick fallback 仍工作，并给新实体写 captured identity。
- 会话结束捕获 canonical identity；完成时 identity 已切换则丢弃。
- existingSummary 和 generation fallback 执行 personal legacy/family strict 过滤。
- 静态/模型 smoke 覆盖竞态、persona 过滤和 legacy compatibility。

## Subproblems
- none

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P003/children/P006/README.md
- Ticket T005: problems/P000/children/P003/children/P006/tickets/T005.md
- Result R003: problems/P000/children/P003/children/P006/results/R003.md
- Check C003: problems/P000/children/P003/children/P006/checks/C003.md

## Follow-ups
- none
