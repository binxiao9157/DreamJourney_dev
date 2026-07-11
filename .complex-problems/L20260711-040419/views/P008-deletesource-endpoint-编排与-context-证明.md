# P008: DeleteSource Endpoint 编排与 Context 证明

Status: done
Parent: P006
Root: P000
Source Ticket: T004 (split)
Source Check: none
Package: problems/P000/children/P002/children/P006/children/P008
Body: problems/P000/children/P002/children/P006/children/P008/README.md
Ticket(s): T006

## Problem
底层组合事务需要由 Archive DELETE 使用 canonical source ref 正确构建 mutation，并对无引用、旧客户端和 Context 过滤提供兼容行为。

## Success Criteria
- DELETE endpoint 构建 `memoryArchiveItem + itemId` deleteSource action 并调用组合原语。
- 响应增加无正文 cascade summary/revision，同时保留旧字段。
- 无知识引用可删除；revision conflict、sealed、missing 映射稳定。
- source 命中四类实体均 superseded，Context/Echo generation 不再包含相关知识。
- API/smoke/change-feed 测试通过。

## Subproblems
- none

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P002/children/P006/children/P008/README.md
- Ticket T006: problems/P000/children/P002/children/P006/children/P008/tickets/T006.md
- Result R003: problems/P000/children/P002/children/P006/children/P008/results/R003.md
- Check C003: problems/P000/children/P002/children/P006/children/P008/checks/C003.md

## Follow-ups
- none
