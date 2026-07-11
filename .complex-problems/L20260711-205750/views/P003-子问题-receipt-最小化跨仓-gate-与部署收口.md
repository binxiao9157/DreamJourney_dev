# P003: 子问题：Receipt 最小化跨仓 Gate 与部署收口

Status: todo
Parent: P000
Root: P000
Source Ticket: T000 (split)
Source Check: none
Package: problems/P000/children/P003
Body: problems/P000/children/P003/README.md
Ticket(s): T008

## Problem
Receipt 压缩会影响后端幂等响应和 iOS V2 解析，需要固定跨仓合同、部署 smoke、维护文档和 release regression，避免后续回归或误操作生产数据。

## Success Criteria
- 后端 smoke 验证 full -> compact -> replay、payload conflict 和 change compaction 兼容。
- iOS 静态/模型检查验证 compact duplicate 响应仍能生成 authoritative snapshot 与 governance response。
- 跨仓 gate 接入可选 release regression，默认静态保护不依赖部署环境。
- 部署文档明确先 dry-run、备份、apply、post-check 和回滚边界。
- 后端全测、release regression、Simulator/generic iPhoneOS build 通过。

## Subproblems
- P009: Receipt 最小化跨仓 Gate 与非真机构建
- P010: 双仓提交部署与线上 Postgres Receipt 验收

## Results
- none

## Latest Check
none

## Bodies
- Problem: problems/P000/children/P003/README.md
- Ticket T008: problems/P000/children/P003/tickets/T008.md

## Follow-ups
- none
