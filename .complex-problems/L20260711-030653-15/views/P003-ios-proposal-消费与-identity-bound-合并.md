# P003: iOS Proposal 消费与 Identity-bound 合并

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
iOS 当前只解码 extraction 并随机生成 ID，且会话结束提取没有捕获 persona identity。

## Success Criteria
- iOS 可解码 proposal/persona metadata 并优先使用 proposal ID、关联和来源字段。
- 异步完成时 user/persona/digital-human identity 不匹配则丢弃结果。
- 旧 extraction 和旧本地 KBLite 文件保持兼容，family 不推断旧 personal 数据。

## Subproblems
- P005: iOS Proposal Schema 与 Backend Client
- P006: iOS Identity-bound Proposal 合并与 Persona 本地策略

## Results
- R004

## Latest Check
C004

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T003: problems/P000/children/P003/tickets/T003.md
- Result R004: problems/P000/children/P003/results/R004.md
- Check C004: problems/P000/children/P003/checks/C004.md

## Follow-ups
- none
