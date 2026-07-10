# P001: 后端知识 revision 与增量同步合同

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
后端只保存整份 KB snapshot，缺少统一 revision、幂等 mutation 和 change feed，无法证明多设备重试不会重复写入，也无法让 iOS 稳定增量拉取。需要在 InMemory/Postgres 中实现兼容现有 `/kb/sync` 和 snapshot 的最小增量合同，并保持 route ownership 分类完整。

## Success Criteria
- InMemory/Postgres 使用同一 revision 与 operationId 幂等语义。
- 新增 mutation/change-feed API，现有 sync/snapshot 合同继续通过。
- owner principal 不能写入或读取其他用户 KB。
- 单测和 FastAPI smoke 覆盖首次写入、重复 mutation、sinceRevision、错误 principal 和旧 snapshot 兼容。

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
