# P012: 后端部署与真实 Postgres Receipt 验收

Status: done
Parent: P010
Root: P000
Source Ticket: T010 (split)
Source Check: none
Package: problems/P000/children/P003/children/P010/children/P012
Body: problems/P000/children/P003/children/P010/children/P012/README.md
Ticket(s): T012

## Problem
远端提交需要部署到现有服务器，并用真实 Postgres 验证 maintenance SQL、锁/JSONB 行为、dry-run/apply 幂等和线上 replay 合同。

## Success Criteria
- 服务器运行目标后端提交，health 200 且 store=postgres。
- 线上 dry-run 报告脱敏保存；status=ok、failed=0、kind 合法才允许 apply。
- 小 batch apply 成功，不删除 receipt identity；二次运行 candidate/updated=0。
- Duplicate/conflict、privacy maintenance dry-run 与 change-feed receipt barrier 验收通过。
- 状态文档记录部署版本、报告路径、结果和 remaining risk。

## Subproblems
- P013: Reader-first 后端部署与健康验证
- P014: 真实 Postgres Receipt Dry-run、Apply 与幂等验收

## Results
- R013

## Latest Check
C014

## Bodies
- Problem: problems/P000/children/P003/children/P010/children/P012/README.md
- Ticket T012: problems/P000/children/P003/children/P010/children/P012/tickets/T012.md
- Result R013: problems/P000/children/P003/children/P010/children/P012/results/R013.md
- Check C014: problems/P000/children/P003/children/P010/children/P012/checks/C014.md

## Follow-ups
- none
