# P008: Round 1C：后端真实实现与部署证据审计

Status: done
Parent: P001
Root: P000
Source Ticket: T001 (split)
Source Check: none
Package: problems/P000/children/P001/children/P008
Body: problems/P000/children/P001/children/P008/README.md
Ticket(s): T004

## Problem
后端同时包含真实 Postgres 业务、provider adapter、合同壳层和 mock/fallback，必须重新映射到最新 PRD，并区分已部署与仅本地实现。

## Success Criteria
- 路由、模型/表、授权、任务、provider、运维和测试形成证据矩阵。
- 每项标注已部署、production-ready、合同壳层、mock/fallback 或缺失。
- 数据迁移、后台任务和跨账号安全风险明确。
- 所有结论附真实文件路径与符号或行号。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P001/children/P008/README.md
- Ticket T004: problems/P000/children/P001/children/P008/tickets/T004.md
- Result R002: problems/P000/children/P001/children/P008/results/R002.md
- Check C002: problems/P000/children/P001/children/P008/checks/C002.md

## Follow-ups
- none
