# 委托后端/数据/异步独立架构复审

## Problem Definition

需要一份由独立评审者基于当前 DreamJourneyBackend 代码形成的报告，验证 V4 模块化单体、Authority、typed API/AuthZ、migration、Job/Outbox、Object/Provider 设计是否增量可行，并识别事务、幂等、数据丢失和运维风险。

## Proposed Solution

委托独立 explorer 只读指定 Product Spec 章节、Evidence Matrix、后端 main/store/auth/archive/time-letter/context/knowledge/provider 代码和关键测试。报告使用 BAR-01...，每项含严重度、分类、路径/行号、Spec章节、问题/影响、建议，并提供 crash/concurrency/rollback 压力测试。

## Acceptance Criteria

- 至少引用 8 个不同后端文件/测试和 5 个 Product Spec 章节。
- 覆盖 identity/vault、Source/Memory/Projection、Conversation/Inbox/TimeLetter、rights、worker/outbox、object/provider、migration/rollback。
- 显式检查共享 connection/启动DDL、payload owner、跨vault AuthZ、非原子effect、Provider unknown、历史不可恢复和 schema contract。
- findings 有完整字段并区分目标缺陷、实现缺口、产品决定和外部验收。
- 至少一个 crash/concurrency/rollback 压力测试和残余风险；不修改工作区。

## Verification Plan

主控核对报告 ID、字段、文件/行号存在性与主题覆盖；不在本票修复发现，统一交给 3D4。

## Risks

- 后端单体文件较大，评审需限制高信号路径，避免超时。
- 已有 smoke 不能证明生产事务/并发；报告必须区分测试合同与生产证据。

## Assumptions

- 后端当前 `main@4c0538b` 是实现基线。
- Agent 只读两个仓库，不修改文件。
