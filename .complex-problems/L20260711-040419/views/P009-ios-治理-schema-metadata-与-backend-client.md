# P009: iOS 治理 Schema、Metadata 与 Backend Client

Status: done
Parent: P003
Root: P000
Source Ticket: T007 (split)
Source Check: none
Package: problems/P000/children/P003/children/P009
Body: problems/P000/children/P003/children/P009/README.md
Ticket(s): T008

## Problem
iOS 无法强类型表达四类治理 action，KBLite Codable 会丢弃后端 governance metadata，也没有治理 endpoint consumer。

## Success Criteria
- 强类型 action/correction/reference/summary 模型覆盖 confirm/reject/correct/deleteSource。
- 四类实体 optional governanceMetadata 可往返编码。
- Backend client 编码 schemaVersion=1、解析权威 graph/revision/summary。
- Archive delete client 支持稳定 operationId。
- Swift model smoke 和静态 guard 通过。

## Subproblems
- none

## Results
- R006

## Latest Check
C006

## Bodies
- Problem: problems/P000/children/P003/children/P009/README.md
- Ticket T008: problems/P000/children/P003/children/P009/tickets/T008.md
- Result R006: problems/P000/children/P003/children/P009/results/R006.md
- Check C006: problems/P000/children/P003/children/P009/checks/C006.md

## Follow-ups
- none
