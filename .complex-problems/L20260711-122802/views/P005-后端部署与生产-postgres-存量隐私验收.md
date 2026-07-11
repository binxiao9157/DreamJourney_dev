# P005: 后端部署与生产 Postgres 存量隐私验收

Status: done
Parent: P003
Root: P000
Source Ticket: T003 (split)
Source Check: none
Package: problems/P000/children/P003/children/P005
Body: problems/P000/children/P003/children/P005/README.md
Ticket(s): T005

## Problem
本地测试不能证明真实 Postgres 的锁、JSONB 更新和存量数据状态。需要部署已推送后端，并在确认备份后按 dry-run/apply/dry-run 完成生产维护，同时验证新写入 mutation 的四个对外/持久化表面都使用 canonical title。

## Success Criteria
- 服务器拉取目标后端提交、重建服务，health 显示 production/Postgres 且版本与远端一致。
- apply 前确认可恢复备份，并先执行 dry-run；若 invalidRecordCount 非零则拒绝 apply，记录为明确阻断。
- dry-run 报告不含用户、source/entity ID、正文或 token。
- apply 成功后再次 dry-run，所有 changed 计数为 0，invalidRecordCount 为 0。
- 线上合成 sentinel mutation 的首次响应、change feed、receipt replay 均不含 raw title，且 canonical mutation 一致。
- 保存脱敏聚合证据，不做真机、不修改 UI 或其他产品模块。

## Subproblems
- P006: 部署、备份与生产 maintenance preflight
- P007: 生产 apply、归零与线上 sentinel 验收

## Results
- R005

## Latest Check
C005

## Bodies
- Problem: problems/P000/children/P003/children/P005/README.md
- Ticket T005: problems/P000/children/P003/children/P005/tickets/T005.md
- Result R005: problems/P000/children/P003/children/P005/results/R005.md
- Check C005: problems/P000/children/P003/children/P005/checks/C005.md

## Follow-ups
- none
