# Complex Problem Ledger

Ledger: L20260711-113033
Schema: v6
Root: P000 - Task 19：P1 Canonical Knowledge Source Identity 与历史来源审计
Status: doing
Updated: 2026-07-11T04:09:23+00:00

## Problem Tree
- [todo] P000: Task 19：P1 Canonical Knowledge Source Identity 与历史来源审计
  - [done] P001: 后端 canonical 来源与只读审计
  - [done] P002: iOS canonical 来源生成与 typed audit consumer
  - [todo] P003: 跨仓交付、文档与部署验收
    - [done] P004: Canonical 来源跨仓 gate 与文档交付
    - [todo] P005: 双仓提交推送与线上只读审计验收

## Active
- [ ] P000: Task 19：P1 Canonical Knowledge Source Identity 与历史来源审计 (todo)
- [ ] P003: 跨仓交付、文档与部署验收 (todo)
- [ ] P005: 双仓提交推送与线上只读审计验收 (todo)

## Blocked

## Done
- [x] P001: 后端 canonical 来源与只读审计
- [x] P002: iOS canonical 来源生成与 typed audit consumer
- [x] P004: Canonical 来源跨仓 gate 与文档交付

## Tickets
- [splitting] T000: 实现 canonical 来源身份与历史来源只读审计 -> P000 (split)
- [done] T001: 实现后端 canonical conversation-turn 来源与只读 source audit -> P001 (one_go)
- [done] T002: 实现 iOS canonical source identity 与 typed audit consumer -> P002 (one_go)
- [splitting] T003: 固化 canonical 来源合同并完成双仓交付部署 -> P003 (split)
- [done] T004: 固化来源身份验证入口和产品知识库口径 -> P004 (one_go)
- [classified] T005: 提交双仓并部署认证只读来源审计合同 -> P005 (one_go)

## Latest Checks
- [success] C000: P001 后端 canonical 来源与只读审计满足 P001
- [success] C001: P002 P002 已满足成功条件。新文本与照片来源均由稳定 canonical 规则生成，typed audit consumer 严格校验聚合响应，且没有自动迁移历史来源。
- [success] C002: P004 P004 成功。跨仓合同已有确定性入口、release 防回退保护、准确文档与完整非真机构建证据。
