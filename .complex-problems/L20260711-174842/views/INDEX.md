# Complex Problem Ledger

Ledger: L20260711-174842
Schema: v6
Root: P000 - Task 23：P1 本地知识文件保护与语义缓存隔离
Status: done
Updated: 2026-07-11T10:23:01+00:00

## Problem Tree
- [done] P000: Task 23：P1 本地知识文件保护与语义缓存隔离
  - [done] P001: 语义缓存账号、代次与内容隔离
  - [done] P002: 统一知识本地文件保护策略
  - [done] P003: 收口 persona 可见检索与默认发布门

## Active

## Blocked

## Done
- [x] P000: Task 23：P1 本地知识文件保护与语义缓存隔离
- [x] P001: 语义缓存账号、代次与内容隔离
- [x] P002: 统一知识本地文件保护策略
- [x] P003: 收口 persona 可见检索与默认发布门

## Tickets
- [done] T000: 实现本地知识文件保护与语义缓存隔离 -> P000 (split)
- [done] T001: 实现 generation-bound 语义缓存 -> P001 (one_go)
- [done] T002: 接入统一知识文件保护策略 -> P002 (one_go)
- [done] T003: 在 ranking 前隔离 persona 候选并接入发布门 -> P003 (one_go)

## Latest Checks
- [success] C000: P001 R000 满足 P001。cache scope、key 和并发边界均由生产代码与纯模型/static gate 直接证明；旧账号或旧 generation 的异步预热不能通过最终写入 guard，同 ID 内容更新不会命中旧向量。
- [success] C001: P002 R001 满足 P002。所有目标 writer 都通过唯一策略写入，host smoke 证明 atomic replacement 后最终 inode 保留 backup exclusion 和 first-unlock protection；既有 store 行为和两种非真机构建均通过。
- [not_success] C002: P000 R002 尚未完全满足 P000。P001/P002 的核心实现成立，但根验收明确要求新增 gates 接入 release regression/release QA；当前尚未接线。独立审计发现 persona 过滤晚于 semantic top-K，也与“检索治理和账号/persona 隔离”的最终目标存在差距。
- [success] C003: P003 R003 满足 P003。候选过滤顺序、snapshot scope、排名后二次过滤和默认发布门均由源码 gate 与 final3 直接证明；独立审查指出的并发和提交语义问题已纳入最终代码而非仅记录为风险。
- [success] C004: P000 R002 与 R003 共同满足 P000。R002 已完成 cache/storage 核心实现，R003 关闭 persona ranking、默认发布门和独立审查发现的并发/提交语义缺口；final3 与两种非真机构建提供最终一致代码证据。
