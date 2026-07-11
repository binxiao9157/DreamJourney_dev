# Complex Problem Ledger

Ledger: L20260711-191536
Schema: v6
Root: P000 - Task 24：P1 知识变更历史保留与快照恢复
Status: doing
Updated: 2026-07-11T11:46:54+00:00

## Problem Tree
- [todo] P000: Task 24：P1 知识变更历史保留与快照恢复
  - [done] P001: 后端 change-feed 保留水位与安全压缩
  - [done] P002: iOS snapshot fallback 与游标恢复
  - [doing] P003: Task 24 跨仓库 QA、文档与部署验收

## Active
- [ ] P000: Task 24：P1 知识变更历史保留与快照恢复 (todo)
- [ ] P003: Task 24 跨仓库 QA、文档与部署验收 (doing)

## Blocked

## Done
- [x] P001: 后端 change-feed 保留水位与安全压缩
- [x] P002: iOS snapshot fallback 与游标恢复

## Tickets
- [splitting] T000: 实现知识变更历史压缩与快照恢复闭环 -> P000 (split)
- [done] T001: 实现后端知识变更保留水位和安全压缩 -> P001 (one_go)
- [done] T002: 实现 iOS 知识 snapshot 单次恢复 -> P002 (one_go)
- [executing] T003: 完成 Task 24 跨仓库交付与线上验收 -> P003 (one_go)

## Latest Checks
- [success] C000: P001 P001 的代码、合同、维护入口和本地验证均满足原问题；真实 Postgres 部署验收明确属于 P003，不阻断本子问题成功。
- [success] C001: P002 P002 满足严格解析、精确错误分类、单次恢复、并发身份保护和恢复后继续同步的全部标准。
