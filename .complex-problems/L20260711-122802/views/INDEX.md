# Complex Problem Ledger

Ledger: L20260711-122802
Schema: v6
Root: P000 - Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization
Status: doing
Updated: 2026-07-11T06:30:34+00:00

## Problem Tree
- [todo] P000: Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization
  - [done] P001: 新 V2 mutation 单一 canonical 隐私合同
  - [done] P002: 历史知识隐私 metadata 幂等维护工具
  - [todo] P003: 跨仓 QA、提交部署与线上存量验收
    - [todo] P004: 跨仓隐私 QA、构建与提交发布
    - [todo] P005: 后端部署与生产 Postgres 存量隐私验收

## Active
- [ ] P000: Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization (todo)
- [ ] P003: 跨仓 QA、提交部署与线上存量验收 (todo)
- [ ] P004: 跨仓隐私 QA、构建与提交发布 (todo)
- [ ] P005: 后端部署与生产 Postgres 存量隐私验收 (todo)

## Blocked

## Done
- [x] P001: 新 V2 mutation 单一 canonical 隐私合同
- [x] P002: 历史知识隐私 metadata 幂等维护工具

## Tickets
- [splitting] T000: 统一知识 mutation 隐私格式并清洗持久化历史 -> P000 (split)
- [done] T001: 在知识 mutation 入口 canonicalize 隐私 metadata -> P001 (one_go)
- [done] T002: 以单事务维护服务规范历史知识隐私 metadata -> P002 (one_go)
- [splitting] T003: 固化隐私 gate 并完成双仓发布与线上清洗验收 -> P003 (split)
- [classified] T004: 增加知识隐私组合 gate 并发布双仓提交 -> P004 (one_go)

## Latest Checks
- [success] C000: P001 P001 成功。新写入所有持久化和回放表面均由 normalize 后的单一 canonical mutation 驱动。
- [success] C001: P002 R001 满足 P002 的实现与非线上验证边界。维护工具覆盖 snapshot/change/receipt，默认 dry-run，显式 apply 才更新；所有 apply 更新处于同一事务，且无效记录和 SQL 中途失败都会回滚。
