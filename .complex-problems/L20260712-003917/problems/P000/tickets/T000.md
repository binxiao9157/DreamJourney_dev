# 五轮证据收敛与产品路线定稿

## Problem Definition

DreamJourney 当前同时存在最新 PRD、V3 Blueprint、iOS 架构一致性分析、Hermes/AOS Memory 分析、历史 canonical architecture 和大量已实现代码。它们的时间、范围和产品优先级不同，部分内容直接冲突。若直接按某一文档开发，会重复实现已有能力、暴露未验收功能，或对现有稳定架构进行无收益重写。

## Proposed Solution

将任务拆成五个依赖明确的审计与定稿阶段：来源事实基线、产品模型收敛、目标架构与迁移、可执行路线图、独立复审与定稿。每阶段都产生持久化文档和可检查的决策，不允许后续阶段绕过前一阶段未解决的 P0 冲突。最终形成 Product Spec、实现证据矩阵、决策登记册、开发路线图和验收清单五件套。

## Acceptance Criteria

- 四份附件、Hermes/AOS 资料、iOS 和后端均有证据化来源清单。
- 最新 PRD 每个 P0/P1 要求均映射到实现、缺口、外部验收或产品决策。
- 领域词典和目标架构不存在 Source/Archive、Memory/Knowledge、Persona/Profile/Digital Human、Private/Publication 混用。
- 路线图按依赖拆成可独立提交、测试、部署和回滚的小闭环。
- 至少两轮独立复审，P0 异议全部解决或登记为明确 blocker/产品决策。
- 五份成果物完成静态一致性、链接、状态和术语检查。

## Verification Plan

使用多 agent 独立审计和交叉复核；用 `rg`/结构化脚本检查需求 ID 覆盖、术语、链接和状态；引用真实源码路径与测试/部署证据；最终运行 `git diff --check`、文档静态 gate 和 Closure validation。

## Risks

- 新 PRD 可能尚未经过产品确认，不能把评审稿自动升级为发布承诺。
- Hermes/AOS Memory 资料不完整，架构名词不能冒充可直接复用的实现。
- 现有工程已积累大量兼容合同，领域收敛必须增量迁移，不能大爆炸重构。
- 文档容易过长而失去执行性，必须把产品真相、证据矩阵、决策和任务拆成独立但互相链接的成果物。

## Assumptions

- 当前本地 iOS 与后端仓库代表最新可审计实现。
- 本轮以文档、计划和静态分析为主，不直接改变生产行为。
- 用户后续可以对决策登记册中的重大产品取舍逐项确认。
