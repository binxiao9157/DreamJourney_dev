# P003: Task 17 跨仓 QA、文档与非真机验收

Status: done
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T003

## Problem
后端 receipt 与 iOS 恢复只有被组合门禁和发布回归持续执行，才能防止后续知识功能重新引入静默去重或 poisoned queue。

## Success Criteria
- 新 payload conflict 场景进入知识治理组合 gate 和 release regression。
- canonical 知识架构、Task 17、状态和 QA 命令文档一致。
- 后端全量测试、git diff --check、iOS release regression、Simulator workspace build、generic iPhoneOS build 全部通过。
- 后端和 iOS 分仓提交，工作树干净；不推送、不部署、不做真机。

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
