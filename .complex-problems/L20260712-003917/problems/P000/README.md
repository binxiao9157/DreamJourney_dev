# Task 27：DreamJourney 产品成果物与可执行开发路线 V4

## Problem

Close the Lodestar task represented by `/Users/yxj/Documents/Codex/Video/DreamJourney_dev/docs/plans/task_27_product-architecture-and-executable-roadmap.md` using recursive problem, ticket, result, and check state.

Task context:

# Task 27：DreamJourney 产品成果物与可执行开发路线 V4

## 目标

基于最新产品附件、Hermes-Skills-All/AOS Memory 资料以及当前 iOS/后端真实实现，经过多轮证据审计和独立复审，形成一套可以替代零散历史文档、直接指导后续产品决策和工程开发的统一成果物。

## 输入

- `/Users/yxj/Documents/Codex/AI/Hermes-Skills-All`
- `docs/product/Hermes-Skills-All_AOS-Memory_Analysis.md`
- `docs/product/寻梦环游_iOS工程_PRD_目标架构一致性分析_V1.0.md`
- `docs/product/寻梦环游_个人记忆库与数字分身平台_PRD_V1.0.md`
- `docs/product/DreamJourney_V3_产品蓝图_Product_Blueprint_V3.0.md`
- 当前 `DreamJourney_dev` iOS 源码、QA、历史计划与状态证据
- 当前 `DreamJourneyBackend` 后端源码、测试、部署和运维证据

## 来源优先级

1. 当前可运行源码、数据库合同、自动化测试和部署证据。
2. 用户明确确认的最新产品决策。
3. 最新 PRD 中可验收且不与已确认决策冲突的要求。
4. Blueprint、架构一致性分析和既有 canonical architecture。
5. Hermes/AOS Memory 的可验证源码机制。
6. 无源码支撑的分析性主张与推测，仅作为候选方案，不作为事实。

任何结论必须标记为 `已实现事实 / 已确认产品决策 / 推荐方案 / 外部依赖 / 待决策` 之一。

## 固定成果物

1. `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
2. `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
3. `docs/product/DreamJourney_V4_产品决策登记册_V1.0.md`
4. `docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`
5. `docs/product/DreamJourney_V4_评审与验收清单_V1.0.md`

## 迭代轮次

### Round 1：来源与事实基线

- 盘点全部输入资料及其权威性、时间、范围和相互依赖。
- 建立 iOS/后端真实实现证据矩阵。
- 识别文档冲突、过度承诺、历史结论失效和未验证推断。

### Round 2：产品模型收敛

- 收敛产品定位、北极星、用户角色、核心闭环、信息架构和领域词典。
- 明确 Source、Memory、Knowledge Projection、Persona、Conversation、Publication、Visitor、Voice、Digital Human、Family/Care/TimeLetter 的边界。
- 将冲突项写入产品决策登记册，不用技术实现替产品做隐性决定。

### Round 3：目标架构与迁移路径

- 给出模块化单体后端与 iOS 分层的目标边界。
- 明确数据权威、同步、权限、删除、审计、AI provider、对象存储、异步任务和可观测性。
- 采用增量迁移，禁止无证据的大规模重写、平行 Domain 和供应商锁死。

### Round 4：可执行开发计划

- 按 P0/P1/P2 和依赖关系拆成单一小闭环任务。
- 每项包含代码范围、合同、迁移、feature flag、测试、部署、回滚、退出门槛和产品依赖。
- 区分非真机、真机、真实 provider、生产部署和产品决策门。

### Round 5：独立复审与定稿

- 从产品价值、隐私伦理、安全、成本、延迟、运维、可迁移性和过度设计角度反向审查。
- 对每个 P0 做失败模式和不可逆决策检查。
- 修正文档内部矛盾，生成最终验收清单和后续执行顺序。

## 成功标准

- 每个重要产品要求都能映射到源码、后端合同、缺口或明确产品决策，不存在“文档声称已完成但代码无证据”。
- 私人记忆与公开人格域、Owner 与 Visitor、Memory 与 Knowledge Projection、Persona 与 Digital Human Runtime 边界清晰且一致。
- 成果物不要求推倒现有 iOS/后端重建，迁移任务具有明确兼容和回滚策略。
- 路线图中的每个 P0 都有依赖、代码范围、验收脚本、部署门和完成定义。
- 供应商、声音克隆、数字人、AI/知识库和对象存储均通过 adapter/contract 隔离，并明确真实验收边界。
- 至少完成两轮独立复审，所有高风险异议被解决或进入决策登记册。
- 文档通过链接、术语、状态、需求覆盖和自相矛盾静态检查。

## 非目标

- 本任务先不直接重构生产代码或改变公开 UI。
- 不把 Hermes/AOS Memory 的不完整实现照搬进工程。
- 不在产品未决时默认开放 Family、Care、TimeLetter、Visitor 或公开克隆声音。
- 不把真机、真实 provider 或生产规模能力误标为已验收。


## Success Criteria

- 每个重要产品要求都能映射到源码、后端合同、缺口或明确产品决策，不存在“文档声称已完成但代码无证据”。
- 私人记忆与公开人格域、Owner 与 Visitor、Memory 与 Knowledge Projection、Persona 与 Digital Human Runtime 边界清晰且一致。
- 成果物不要求推倒现有 iOS/后端重建，迁移任务具有明确兼容和回滚策略。
- 路线图中的每个 P0 都有依赖、代码范围、验收脚本、部署门和完成定义。
- 供应商、声音克隆、数字人、AI/知识库和对象存储均通过 adapter/contract 隔离，并明确真实验收边界。
- 至少完成两轮独立复审，所有高风险异议被解决或进入决策登记册。
- 文档通过链接、术语、状态、需求覆盖和自相矛盾静态检查。
