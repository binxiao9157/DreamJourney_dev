# P006: Archive 删除与知识撤销组合事务

Status: done
Parent: P002
Root: P000
Source Ticket: T002 (split)
Source Check: none
Package: problems/P000/children/P002/children/P006
Body: problems/P000/children/P002/children/P006/README.md
Ticket(s): T004

## Problem
素材删除和知识 mutation 当前分离，可能出现素材已删但知识仍进入 Echo。需要在一致的锁/revision 边界内应用 deleteSource mutation 并删除 archive。

## Success Criteria
- store 提供组合删除能力；Postgres 在同一 transaction 中锁定 owner knowledge、应用 mutation/change feed 并删除 archive，InMemoryStore 使用同一锁语义。
- endpoint 根据 `memoryArchiveItem + itemId` 构建 deleteSource mutation；无命中也在 revision/锁边界下删除。
- mutation 或 archive 删除失败整体回滚，sealed timeLetter 仍拒绝。
- 删除成功响应含无正文 cascade summary/revision；Context 不再选择受影响实体。
- 覆盖重复/并发/无引用/rollback 和 change feed 测试。

## Subproblems
- P007: Store 组合删除事务原语
- P008: DeleteSource Endpoint 编排与 Context 证明

## Results
- R004

## Latest Check
C004

## Bodies
- Problem: problems/P000/children/P002/children/P006/README.md
- Ticket T004: problems/P000/children/P002/children/P006/tickets/T004.md
- Result R004: problems/P000/children/P002/children/P006/results/R004.md
- Check C004: problems/P000/children/P002/children/P006/checks/C004.md

## Follow-ups
- none
