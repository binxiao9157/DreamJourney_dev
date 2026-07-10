# Complex Problem Ledger

Ledger: L20260711-030653-15
Schema: v6
Root: P000 - P1 知识 Mutation Proposal 与 Persona 归属
Status: done
Updated: 2026-07-10T19:57:33+00:00

## Problem Tree
- [done] P000: P1 知识 Mutation Proposal 与 Persona 归属
  - [done] P001: 后端 Mutation Proposal Builder
  - [done] P002: 后端 Persona Context Policy
  - [done] P003: iOS Proposal 消费与 Identity-bound 合并
    - [done] P005: iOS Proposal Schema 与 Backend Client
    - [done] P006: iOS Identity-bound Proposal 合并与 Persona 本地策略
  - [done] P004: 跨仓库 QA、构建与交付收敛

## Active

## Blocked

## Done
- [x] P000: P1 知识 Mutation Proposal 与 Persona 归属
- [x] P001: 后端 Mutation Proposal Builder
- [x] P002: 后端 Persona Context Policy
- [x] P003: iOS Proposal 消费与 Identity-bound 合并
- [x] P004: 跨仓库 QA、构建与交付收敛
- [x] P005: iOS Proposal Schema 与 Backend Client
- [x] P006: iOS Identity-bound Proposal 合并与 Persona 本地策略

## Tickets
- [done] T000: 落地可审计知识 Proposal 与 Persona 归属 -> P000 (split)
- [done] T001: 实现后端 Knowledge Mutation Proposal Builder -> P001 (one_go)
- [done] T002: 实现后端 Persona-scoped KB Context Policy -> P002 (one_go)
- [done] T003: iOS 消费 Mutation Proposal 并绑定 Persona Identity -> P003 (split)
- [done] T004: 实现 iOS Proposal Schema 与 Client Envelope -> P005 (one_go)
- [done] T005: 实现 iOS Identity-bound Proposal 合并与 Persona 本地策略 -> P006 (one_go)
- [done] T006: 收敛 Knowledge Proposal/Persona 跨仓库 QA 与交付 -> P004 (one_go)

## Latest Checks
- [success] C000: P001 P001 成功。实现满足稳定身份、权威快照去重、关系解析、metadata 和非持久化 endpoint 合同，且没有扩大旧接口权限。
- [success] C001: P002 P002 成功。实体级 persona/evidence 策略覆盖 personal legacy 与 family strict 两条路径，并统一 Context 输出口径。
- [success] C002: P005 P005 成功。新 schema/client 合同可独立编译，旧图谱与旧服务端兼容，显式坏 proposal 不会静默污染合并路径。
- [success] C003: P006 P006 成功。核心编译错误已修复，identity 由会话开始到提取、合并和 Echo fallback 一致贯穿，旧合同兼容边界保留。
- [success] C004: P003 P003 成功。两个拆分子问题均已通过独立 check，组合后形成完整且兼容的 iOS proposal 消费链路。
- [success] C005: P004 P004 成功。新合同具有常态化、无外部依赖的回归入口，并通过完整后端、release 和 generic device 编译门。
- [success] C006: P000 P000 成功。原始问题的 proposal、persona、iOS 合并和 QA 标准全部由关闭子问题与最终自动化证据覆盖。
