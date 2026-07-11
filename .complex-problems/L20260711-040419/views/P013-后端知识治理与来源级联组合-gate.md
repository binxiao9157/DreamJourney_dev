# P013: 后端知识治理与来源级联组合 Gate

Status: done
Parent: P004
Root: P000
Source Ticket: T012 (split)
Source Check: none
Package: problems/P000/children/P004/children/P013
Body: problems/P000/children/P004/children/P013/README.md
Ticket(s): T013

## Problem
后端治理、Archive 来源级联事务、Context 过滤和 fake Postgres 测试目前分散，缺少一条 deterministic runner 作为 release regression 的后端证据。

## Success Criteria
- 新增后端 smoke runner，覆盖 confirm/reject/correct/deleteSource、owner/revision/幂等/change feed、Archive owner 冲突和组合删除事务。
- runner 证明 rejected/superseded 不进入 Context，replacement 可进入目标 persona。
- runner 同时覆盖 memory 与 fake Postgres，不依赖本机真实 Postgres。
- 后端相关全量验证、compileall 和 `git diff --check` 通过。

## Subproblems
- none

## Results
- R011

## Latest Check
C011

## Bodies
- Problem: problems/P000/children/P004/children/P013/README.md
- Ticket T013: problems/P000/children/P004/children/P013/tickets/T013.md
- Result R011: problems/P000/children/P004/children/P013/results/R011.md
- Check C011: problems/P000/children/P004/children/P013/checks/C011.md

## Follow-ups
- none
