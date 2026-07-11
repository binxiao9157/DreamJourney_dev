# P003: Task 24 跨仓库 QA、文档与部署验收

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
把后端压缩合同与 iOS 恢复行为接入一键 gate，更新部署文档，完成提交、推送、部署和线上 Postgres 验收。

该问题属于父任务，因为跨仓库合同只有在组合 gate、构建、提交、部署和线上 Postgres 验收后才能证明可交付。

## Success Criteria
- 知识专项 gate、默认 release regression、后端全量相关测试通过。
- 模拟器和 generic iPhoneOS 构建通过，`git diff --check` 通过。
- 两仓库提交推送；后端部署后线上 smoke 证明 200/410/snapshot 合同。
- Lodestar 与递归 ledger 状态、验证报告和版本证据更新完整。

## Subproblems
- none

## Results
- R002

## Latest Check
C002

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T003: problems/P000/children/P003/tickets/T003.md
- Result R002: problems/P000/children/P003/results/R002.md
- Check C002: problems/P000/children/P003/checks/C002.md

## Follow-ups
- none
