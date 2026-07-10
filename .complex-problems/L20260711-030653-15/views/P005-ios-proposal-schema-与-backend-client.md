# P005: iOS Proposal Schema 与 Backend Client

Status: done
Parent: P003
Root: P000
Source Ticket: T003 (split)
Source Check: none
Package: problems/P000/children/P003/children/P005
Body: problems/P000/children/P003/children/P005/README.md
Ticket(s): T004

## Problem
iOS 没有 proposal/persona metadata 的兼容模型，backend client 只能返回裸 `KBExtractionResult`。

## Success Criteria
- KBLite 实体 optional 增加 owner/persona/evidence/sourceTurn metadata，旧 JSON 可解码。
- 新增 proposal/envelope Codable 模型，覆盖所有 upsert/关系字段。
- backend client 请求发送 persona identity，响应优先解码 proposal 并验证基本 schema。
- Swift model smoke 覆盖完整 proposal 和 legacy extraction envelope。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P003/children/P005/README.md
- Ticket T004: problems/P000/children/P003/children/P005/tickets/T004.md
- Result R002: problems/P000/children/P003/children/P005/results/R002.md
- Check C002: problems/P000/children/P003/children/P005/checks/C002.md

## Follow-ups
- none
