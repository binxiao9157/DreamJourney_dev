# P001: 后端权威 operation receipt 与事务幂等

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
知识同步、治理和 Archive 删除只按 operation ID 去重，无法确认重放 payload 是否一致，且无 KB 级联删除没有持久化幂等凭据。

## Success Criteria
- canonical fingerprint 稳定覆盖 operation kind、schema 和规范化 payload，并排除 baseRevision。
- Memory/Postgres 在业务写入同一事务内保存 receipt；相同指纹重放，不同指纹 409。
- Governance 在构造 snapshot-dependent mutation 前识别 receipt。
- Archive 无级联删除原样重放，并拒绝同 ID 删除另一 item。
- legacy change 继续兼容并标记未验证，purge 清理 receipt。
- 后端单测、Postgres fake 与知识治理 smoke 通过。

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
