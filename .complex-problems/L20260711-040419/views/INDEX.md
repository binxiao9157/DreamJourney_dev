# Complex Problem Ledger

Ledger: L20260711-040419
Schema: v6
Root: P000 - Task 16：P1 知识治理与来源删除级联
Status: done
Updated: 2026-07-11T01:51:41+00:00

## Problem Tree
- [done] P000: Task 16：P1 知识治理与来源删除级联
  - [done] P001: 后端知识治理动作合同
  - [done] P002: 来源删除级联与 Archive 归属安全
    - [done] P005: Archive ID 跨 Owner 冲突保护
    - [done] P006: Archive 删除与知识撤销组合事务
      - [done] P007: Store 组合删除事务原语
      - [done] P008: DeleteSource Endpoint 编排与 Context 证明
  - [done] P003: iOS 知识治理 Consumer 与同步串行化
    - [done] P009: iOS 治理 Schema、Metadata 与 Backend Client
    - [done] P010: iOS Governance Outbox 与同步协调
      - [done] P011: iOS Governance Outbox 持久化模型
      - [done] P012: iOS Governance 串行提交与 Generation Gate
  - [done] P004: 跨仓库治理 QA 与交付收敛
    - [done] P013: 后端知识治理与来源级联组合 Gate
    - [done] P014: iOS 知识治理 Release QA 组合 Gate
    - [done] P015: 知识治理文档、证据与双仓提交收敛

## Active

## Blocked

## Done
- [x] P000: Task 16：P1 知识治理与来源删除级联
- [x] P001: 后端知识治理动作合同
- [x] P002: 来源删除级联与 Archive 归属安全
- [x] P003: iOS 知识治理 Consumer 与同步串行化
- [x] P004: 跨仓库治理 QA 与交付收敛
- [x] P005: Archive ID 跨 Owner 冲突保护
- [x] P006: Archive 删除与知识撤销组合事务
- [x] P007: Store 组合删除事务原语
- [x] P008: DeleteSource Endpoint 编排与 Context 证明
- [x] P009: iOS 治理 Schema、Metadata 与 Backend Client
- [x] P010: iOS Governance Outbox 与同步协调
- [x] P011: iOS Governance Outbox 持久化模型
- [x] P012: iOS Governance 串行提交与 Generation Gate
- [x] P013: 后端知识治理与来源级联组合 Gate
- [x] P014: iOS 知识治理 Release QA 组合 Gate
- [x] P015: 知识治理文档、证据与双仓提交收敛

## Tickets
- [done] T000: 实现知识治理权威动作与来源删除级联 -> P000 (split)
- [done] T001: 构建后端知识治理状态机与权威 Mutation -> P001 (one_go)
- [done] T002: 让 Archive 删除安全级联撤销知识来源 -> P002 (split)
- [done] T003: 阻止 Archive ID 跨用户接管 -> P005 (one_go)
- [done] T004: 原子化 Archive 删除与知识来源撤销 -> P006 (split)
- [done] T005: 实现 Archive 与 Knowledge 的单事务删除原语 -> P007 (one_go)
- [done] T006: 将 Archive DELETE 编排到 deleteSource 与 Context -> P008 (one_go)
- [done] T007: 实现 iOS 知识治理模型、Outbox 与权威消费 -> P003 (split)
- [done] T008: 落地 iOS 治理模型与 Backend Client -> P009 (one_go)
- [done] T009: 实现持久化 Governance Outbox 与串行重试 -> P010 (split)
- [done] T010: 建立按用户持久化的 Governance Outbox -> P011 (one_go)
- [done] T011: 串行提交治理 Outbox 并处理 Revision/Generation -> P012 (one_go)
- [done] T012: 跨仓库知识治理组合 Gate 与交付证据 -> P004 (split)
- [done] T013: 固化后端 Knowledge Governance Source Cascade Gate -> P013 (one_go)
- [done] T014: 接入 iOS Knowledge Governance Release QA Gate -> P014 (one_go)
- [done] T015: 收敛知识治理设计状态与双仓提交 -> P015 (one_go)

## Latest Checks
- [success] C006: P009 P009 成功；schema 安全性、metadata round-trip、严格响应和 client path 均有可执行证据。
- [success] C007: P011 P011 成功；存储原语的顺序、隔离、去重、删除和损坏路径均有真实文件 smoke。
- [success] C008: P012 R008 覆盖了 P012 的全部成功标准。治理请求现在具备持久化先行、单一网络 owner、revision conflict 重放、权威响应合并和 user/persona generation 防污染机制，且目标 workspace 已完整编译。
- [success] C009: P010 R009 汇总的两个子问题均已通过独立成功检查，完整覆盖 P010 的持久化、串行化、幂等重试和身份边界标准。
- [success] C010: P003 R010 由已通过检查的 P009 和 P010 汇总，完整解决 iOS 缺少治理模型、后端 consumer 和同步串行化的问题，且没有改变公开 UI。
- [success] C011: P013 R011 提供了单一 deterministic runner，并用 217 条组合测试及 243 条后端全量测试证明 P013 成功标准，真实 Postgres 未执行属于明确非目标。
- [success] C012: P014 R012 满足 P014 的全部 gate、公开边界和构建标准。完整 release regression 在修复两个由 Task 16 引起的旧 guard 漂移后通过，最终脚本和 package 再次检查无误。
- [success] C013: P015 R013 完成了 P015 的设计状态同步、提交卫生和双仓本地提交。根问题关闭后追加 ledger-only 提交是工作流预期，不构成当前交付缺口。
- [success] C014: P004 R014 汇总的三个子问题均有独立成功检查，P004 的后端、iOS、release、构建、文档和提交标准全部满足。
- [success] C015: P000 R015 由四个已独立成功检查的主子问题汇总，Task 16 的全部原始成功标准均有代码、自动化回归、构建和交付证据。剩余项均明确属于公开体验、历史迁移或部署生产化，不应阻塞本任务关闭。
