# P001: 后端稳定 target revision 分页

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
`/kb/changes` 和两个 store 当前返回 sinceRevision 后全部记录，没有响应上界、limit 或固定读取水位。

## Success Criteria
- 无 limit 保持 legacy 响应；显式 limit 返回 target/next/hasMore/pageLimit。
- 首次固定 target，后续只读到该 target，不追逐新写入。
- Memory/Postgres 使用相同边界和 revision ASC。
- 参数异常、三页、固定 target、空终页和用户隔离测试通过。
- 后端全量验证通过。

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
