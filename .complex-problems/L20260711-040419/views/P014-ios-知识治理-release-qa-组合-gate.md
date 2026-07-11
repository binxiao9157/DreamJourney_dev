# P014: iOS 知识治理 Release QA 组合 Gate

Status: done
Parent: P004
Root: P000
Source Ticket: T012 (split)
Source Check: none
Package: problems/P000/children/P004/children/P014
Body: problems/P000/children/P004/children/P014/README.md
Ticket(s): T014

## Problem
iOS governance model/client/outbox/coordinator 检查已存在但尚未纳入 release QA package，后续修改可能绕过 identity、operation ID 或公开 UI 边界。

## Success Criteria
- release QA package 默认执行 governance model/client/coordinator 轻量 guard。
- release regression 新增 `RUN_KNOWLEDGE_GOVERNANCE_GATE=1` 可选组合开关，运行完整 iOS governance/outbox/three-way smoke 和后端 runner。
- 静态 guard 证明公开 UI 没有新增治理入口或治理状态文案。
- 标准 release QA、开启组合 gate、Simulator Debug workspace build 和 generic iPhoneOS 无签名 build 通过。

## Subproblems
- none

## Results
- R012

## Latest Check
C012

## Bodies
- Problem: problems/P000/children/P004/children/P014/README.md
- Ticket T014: problems/P000/children/P004/children/P014/tickets/T014.md
- Result R012: problems/P000/children/P004/children/P014/results/R012.md
- Check C012: problems/P000/children/P004/children/P014/checks/C012.md

## Follow-ups
- none
