# Complex Problem Ledger

Ledger: L20260711-122802
Schema: v6
Root: P000 - Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization
Status: done
Updated: 2026-07-11T06:47:32+00:00

## Problem Tree
- [done] P000: Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization
  - [done] P001: 新 V2 mutation 单一 canonical 隐私合同
  - [done] P002: 历史知识隐私 metadata 幂等维护工具
  - [done] P003: 跨仓 QA、提交部署与线上存量验收
    - [done] P004: 跨仓隐私 QA、构建与提交发布
    - [done] P005: 后端部署与生产 Postgres 存量隐私验收
      - [done] P006: 部署、备份与生产 maintenance preflight
      - [done] P007: 生产 apply、归零与线上 sentinel 验收

## Active

## Blocked

## Done
- [x] P000: Task 20：P0 Knowledge Mutation / Receipt 隐私 Canonicalization
- [x] P001: 新 V2 mutation 单一 canonical 隐私合同
- [x] P002: 历史知识隐私 metadata 幂等维护工具
- [x] P003: 跨仓 QA、提交部署与线上存量验收
- [x] P004: 跨仓隐私 QA、构建与提交发布
- [x] P005: 后端部署与生产 Postgres 存量隐私验收
- [x] P006: 部署、备份与生产 maintenance preflight
- [x] P007: 生产 apply、归零与线上 sentinel 验收

## Tickets
- [done] T000: 统一知识 mutation 隐私格式并清洗持久化历史 -> P000 (split)
- [done] T001: 在知识 mutation 入口 canonicalize 隐私 metadata -> P001 (one_go)
- [done] T002: 以单事务维护服务规范历史知识隐私 metadata -> P002 (one_go)
- [done] T003: 固化隐私 gate 并完成双仓发布与线上清洗验收 -> P003 (split)
- [done] T004: 增加知识隐私组合 gate 并发布双仓提交 -> P004 (one_go)
- [done] T005: 部署 Task 20 并安全清洗生产知识隐私 metadata -> P005 (split)
- [done] T006: 安全部署并证明生产清洗可执行 -> P006 (one_go)
- [done] T007: 执行生产清洗并证明线上 canonical 合同 -> P007 (one_go)

## Latest Checks
- [success] C000: P001 P001 成功。新写入所有持久化和回放表面均由 normalize 后的单一 canonical mutation 驱动。
- [success] C001: P002 R001 满足 P002 的实现与非线上验证边界。维护工具覆盖 snapshot/change/receipt，默认 dry-run，显式 apply 才更新；所有 apply 更新处于同一事务，且无效记录和 SQL 中途失败都会回滚。
- [success] C002: P004 R002 满足跨仓隐私 QA、非真机构建与双仓发布要求。新增 gate 能检测 canonical mutation、maintenance 默认 dry-run、回滚测试和 release 接线缺失；完整 release regression 与两种 iOS 构建均通过，提交已推送远端。
- [success] C003: P006 R003 满足部署、备份与只读 preflight 的全部条件，且未越界执行生产 apply。真实 Postgres dry-run 无无效记录，备份可验证，服务版本和运行环境明确。
- [success] C004: P007 R004 证明生产历史清洗和新写入 canonical 合同均已完成。apply 前置备份有效，更新量与 pre-dry-run 一致，apply 后及 sentinel 写入后均保持零待清洗项。
- [success] C005: P005 R005 及子问题 P006/P007 的独立检查共同证明部署与生产 Postgres 验收完成，没有用本地 fixture 替代线上证据。
- [success] C006: P003 R006 及 P004/P005 检查证明跨仓 QA、非真机构建、提交推送、部署和线上存量验收全部完成。
- [success] C007: P000 R007 和三个子问题检查充分证明 Task 20 已完成。证据覆盖新写入语义、历史存量、失败/幂等行为、跨仓发布及真实生产数据库，没有以单一测试或意图替代完成证明。
