# P003: Audit Gate、提交与部署证据

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T005

## Problem
全路由策略需要稳定 QA、文档和线上 Postgres 证据，否则路由新增或部署漂移会绕过审计。

## Success Criteria
- 新增静态审计 guard、HTTP smoke 和 release 可选 gate。
- 后端全量测试、simulator/generic iPhoneOS build、diff check 通过。
- 两仓库提交推送，后端重新部署并确认 commit/store/shadow/runtime。
- 线上 owner mismatch、system-only 和 delegated smoke 通过且不泄漏 token/正文。

## Subproblems
- P006: Ownership Audit Gate 固化
- P007: Ownership 版本提交部署与线上证据

## Results
- R006

## Latest Check
C006

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T005: problems/P000/children/P003/tickets/T005.md
- Result R006: problems/P000/children/P003/results/R006.md
- Check C006: problems/P000/children/P003/checks/C006.md

## Follow-ups
- none
