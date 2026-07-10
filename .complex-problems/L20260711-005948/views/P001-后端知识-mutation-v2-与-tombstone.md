# P001: 后端知识 Mutation V2 与 Tombstone

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
后端当前只接受完整 graph replacement，`kb_changes` 也只保存快照，无法表达实体删除或让其他客户端区分 upsert/tombstone。需要在保持 v1 合同、ownership 和 revision/operationId 语义不变的前提下增加 v2 delta。

## Success Criteria
- `/kb/mutations` 接受固定的 v2 upserts/tombstones 合同并严格校验类型、ID、scope 和时间字段。
- InMemory/Postgres 在同一 revision 事务内原子应用 delta，重复 operation 不重复执行，stale base 返回 409。
- `kb_changes` 幂等迁移 nullable mutation metadata，历史 v1 记录和响应保持兼容。
- v2 响应返回权威 graph 和 mutation 摘要；change feed 可回放删除。
- 后端单测、FastAPI smoke、v1 knowledge smoke 和新增 v2 smoke 通过。

## Subproblems
- none

## Results
- R000

## Latest Check
C000

## Bodies
- Problem: problems/P000/children/P001/README.md
- Ticket T001: problems/P000/children/P001/tickets/T001.md
- Result R000: problems/P000/children/P001/results/R000.md
- Check C000: problems/P000/children/P001/checks/C000.md

## Follow-ups
- none
