# P004: Task 14 QA、文档与非真机交付

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P004
Body: problems/P000/children/P004/README.md
Ticket(s): T004

## Problem
证据和 Context 政策跨越 iOS/后端，如果不进入统一 gate 和状态文档，后续同步、Echo 或 PRD 改动容易绕过门禁。

## Success Criteria
- 新增后端 evidence/context smoke 和 iOS policy smoke，接入现有 verify/release regression。
- Task 12/13 mutation、tombstone、三方合并和旧合同回归继续通过。
- generic Simulator、generic iPhoneOS、后端全量验证与两个仓库 `git diff --check` 通过。
- canonical 架构、Task 14 状态、验证命令和剩余 P1/P2 缺口更新完整。
- 分别提交 iOS 与后端，不推送或部署。

## Subproblems
- none

## Results
- R003

## Latest Check
C003

## Bodies
- Problem: problems/P000/children/P004/README.md
- Ticket T004: problems/P000/children/P004/tickets/T004.md
- Result R003: problems/P000/children/P004/results/R003.md
- Check C003: problems/P000/children/P004/checks/C003.md

## Follow-ups
- none
