# Complex Problem Ledger

Ledger: L20260710-231102-12
Schema: v6
Root: P000 - P0 统一知识库主链路
Status: done
Updated: 2026-07-10T16:28:47+00:00

## Problem Tree
- [done] P000: P0 统一知识库主链路
  - [done] P001: 后端知识 revision 与增量同步合同
  - [done] P002: iOS KBLite 用户隔离、同步与后端提取
  - [done] P003: Context Packet 驱动真实 Echo 生成
    - [done] P005: 后端生成上下文合同
    - [done] P006: iOS 每轮 Echo RAG 注入
  - [done] P004: 统一知识管线验证与交付收敛

## Active

## Blocked

## Done
- [x] P000: P0 统一知识库主链路
- [x] P001: 后端知识 revision 与增量同步合同
- [x] P002: iOS KBLite 用户隔离、同步与后端提取
- [x] P003: Context Packet 驱动真实 Echo 生成
- [x] P004: 统一知识管线验证与交付收敛
- [x] P005: 后端生成上下文合同
- [x] P006: iOS 每轮 Echo RAG 注入

## Tickets
- [done] T000: 收敛 KBLite、后端 KB 与 Echo Context 的 P0 主链路 -> P000 (split)
- [done] T001: 在现有 KB snapshot 上增加兼容的增量同步层 -> P001 (one_go)
- [done] T002: 为 KBLite 增加按用户生命周期、自动同步与 backend-first extraction -> P002 (one_go)
- [done] T003: Context Packet 驱动真实 Echo 生成 -> P003 (split)
- [done] T004: 后端生成上下文合同 -> P005 (one_go)
- [done] T005: iOS 每轮 Echo RAG 注入 -> P006 (one_go)
- [done] T006: 统一知识管线跨仓库验证与交付票 -> P004 (one_go)

## Latest Checks
- [success] C000: P001 结果 R000 满足 P001 的本地实现与验证标准：双 store 行为一致，旧合同兼容，新合同具备幂等、冲突和 ownership 证据。
- [success] C001: P002 R001 覆盖 P002 的代码合同和非真机构建要求，消除了已确认的用户切换残留、客户端直连提取与同步无调用点问题。
- [success] C002: P005 成功。实现满足 additive 合同、安全来源、稳定哈希、长度约束和现有 Context V2 兼容要求。
- [success] C003: P006 本轮实现满足 P006 的代码合同与非真机验收范围：Echo 在最终 ASR 后优先使用后端 `generationContext`，超时或失败时按当前 query 使用当前用户 KBLite 降级，并通过 turn、用户和生命周期门禁避免旧异步结果污染当前轮次。
- [success] C004: P003 P003 已在非真机范围内闭环。后端 generation context 与 iOS turn-scoped RAG 形成单一知识注入路径，超时降级、旧回调隔离和现有 Echo 状态兼容均有实现与回归证据。
- [success] C005: P004 P004 的非真机交付标准已满足。两仓库均有完整验证证据，部署态合同已固化为可选 gate，状态文档没有把基础增量知识管线夸大为向量检索或线上真机验收完成。
- [success] C006: P000 根目标已在约定的 P0 与非真机范围内完成。知识写入、增量同步、用户隔离、受控上下文构建和 Echo 当前轮生成已成为一条可观察、可降级、可回归的主链路，同时保留旧客户端兼容。
