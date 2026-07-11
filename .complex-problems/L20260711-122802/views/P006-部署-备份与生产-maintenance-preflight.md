# P006: 部署、备份与生产 maintenance preflight

Status: done
Parent: P005
Root: P000
Source Ticket: T005 (split)
Source Check: none
Package: problems/P000/children/P003/children/P005/children/P006
Body: problems/P000/children/P003/children/P005/children/P006/README.md
Ticket(s): T006

## Problem
生产服务器仍需部署 `e1f06a8`，并在任何清洗写入前证明 health、版本、备份和 pre-dry-run 均满足安全条件。

## Success Criteria
- 服务器仓库和 API 容器运行 `e1f06a8`，health 为 production/Postgres。
- 不覆盖服务器私密 `.env`，不输出 token。
- 创建权限受限、非空、有校验值的 Postgres 备份。
- maintenance 默认 dry-run 在真实 Postgres 上成功，`mode=dryRun`、`invalidRecordCount=0`，报告只含聚合字段。
- 若任一条件失败，停止，不执行 apply。

## Subproblems
- none

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P003/children/P005/children/P006/README.md
- Ticket T006: problems/P000/children/P003/children/P005/children/P006/tickets/T006.md
- Result R003: problems/P000/children/P003/children/P005/children/P006/results/R003.md
- Check C003: problems/P000/children/P003/children/P005/children/P006/checks/C003.md

## Follow-ups
- none
