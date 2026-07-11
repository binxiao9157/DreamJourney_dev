# P001: 新 V2 mutation 单一 canonical 隐私合同

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P001
Body: problems/P000/children/P001/README.md
Ticket(s): T001

## Problem
新 V2 mutation 的 graph 与 mutation metadata 分叉，客户端原始 source title 会进入响应、change feed 和 receipt，并影响 operation payload hash。

## Success Criteria
- normalize/fingerprint/apply/persist/response 使用同一 canonical mutation。
- raw/canonical title 重试幂等，kind/id/正文变化仍冲突。
- InMemory 与 Postgres sentinel tests 覆盖 response/change/receipt/replay，无 raw title。

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
