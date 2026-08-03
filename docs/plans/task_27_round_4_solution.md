# 将 V4 目标架构解析为可执行开发路线与验收门

## Problem Definition

Round 3 已形成完整目标架构、迁移 Runbook、12 个 canonical risk 和 13 个稳定工作包，但尚未形成工程团队可以逐项领取、验证、部署和回滚的路线。若只按架构章节或功能列表排期，会重新产生平行任务、跳过安全前置、把外部门误算为开发完成，或让 Publication/Voice/Family 等后置能力挤占 Owner Truth Loop。

## Proposed Solution

1. 产出唯一权威路线图 `docs/superpowers/plans/2026-07-12-dreamjourney-v4-executable-development-roadmap.md`，固定使用以下 13 个 package ID：
   - `WP-S0-01` Account & Local Isolation
   - `WP-S0-02` Identity & AuthZ Enforce
   - `WP-S0-03` Credential Stop-Loss
   - `WP-S0-04` DB Foundation & Recovery
   - `WP-S0-05` Rights & Deletion
   - `WP-S0-06` Release Scope Stop-Loss
   - `WP-S0-07` Operations Evidence
   - `WP-S1-01` Owner Truth Authority
   - `WP-S1-02` Async Effect Authority
   - `WP-S1-03` iOS Composition & Runtime
   - `WP-S3-01` Publication
   - `WP-V0-01` Voice/DH Governance
   - `WP-MIG-01` Composite Migration Drills
2. 建立显式依赖 DAG 和 critical path。Stage 0 安全止损、DB/身份/账号隔离先于 Owner Authority cutover；Async/Runtime 依赖稳定 AccountLease/Authority；Publication 与 Voice/DH 是独立后置 lane；Composite Migration 贯穿所有阶段但不能成为第二 migration authority。
3. 将每个 package 拆成有稳定 ID 的原子 work item。每项固定包含：产品目的、风险/FR/DR、依赖、iOS/后端/DB/运维代码范围、API/schema/event 合同、数据迁移、feature flag/release policy、测试与 QA 命令、部署顺序、回滚/forward-fix、完成定义、外部门、非目标。
4. 将任务按 `P0/P1/P2` 和可验收切片排序，并区分五种门：纯代码/非真机、模拟器、真实 Postgres/部署、真实 Provider、真机/产品/法律。外部门未通过时允许完成内部合同，但状态只能是 `INTERNAL_READY/EXTERNAL_BLOCKED`，不能标 Done。
5. 为每个 Stage 定义可交付 increment、进入条件、退出条件、kill switch、兼容窗和 stop-the-line 条件；Owner 文字闭环必须能在 Optional lane 全部关闭时独立发布。
6. 建立需求追踪：36 项 FR、41 项 DR、22 项 Round 3 finding、12 个 canonical risk 均映射到至少一个 work item 或明确外部门；同一风险不得在不相关 package 中重复造 Authority。
7. 增加 `product-v4-roadmap-check.py`，精确验证 13 个 package、稳定 work item ID、必填字段、依赖引用、优先级、验证类型、FR/DR/CR/finding 映射和禁用状态；检查不能把开放 DR 或外部门解释为已完成。
8. 运行全部 Product V4 checks、路线图检查、Markdown 链接检查和 `git diff --check`，并记录路线图仍是计划而非生产实施的边界。

## Acceptance Criteria

- 路线图恰好覆盖 13 个稳定 package ID，不丢失、不重复、不改名；每个 package 至少有一个可独立验收的 work item。
- 每个 work item 有唯一 ID、单一主要结果和完整的代码/合同/迁移/flag/测试/部署/回滚/DoD 字段，不使用“完善、优化、支持全部”等不可验收措辞替代结果。
- 存在可机读依赖关系和无环 critical path；任何 authority cutover、真实数据发送、公开入口、schema contract 或 credential revoke 都有前置门。
- P0 只包含生产止损和 Owner 核心前置；Publication、公开 Voice/DH、复杂 Family/Care/TimeLetter 不阻断 Owner 文字闭环。
- 明确区分非真机、模拟器、真实 Postgres/部署、Provider、真机和产品/法律门；内部测试不能关闭外部门。
- 36 FR、41 DR、22 finding 和 CR-01..CR-12 均可从路线图追踪；开放 Decision 保持原状态。
- 每个 Stage 有进入/退出、证据、rollback/forward-fix 和 release increment；路线图能直接给后续开发 agent 选择“下一个最高优先级小闭环”。
- `product-v4-roadmap-check.py`、全部既有 Product V4 checks、链接检查和 `git diff --check` 通过。

## Verification Plan

1. 从 Round 3 评审响应提取 13 个 package 与 22 项 finding，建立固定基线。
2. 从 Evidence Matrix 提取 36 项 FR 和成熟度/发布状态，从 Decision Register 提取 DR-001..041 和外部门。
3. 人工审查 DAG：验证无环、P0 前置正确、Optional lane 可关闭、Owner core 可独立运行。
4. 对每个 work item 做字段完整性和单一结果检查；抽样验证其代码路径、API/schema 和 QA 命令在当前双仓中真实存在或明确标记为新增。
5. 运行路线图静态检查、全部 Product V4 检查、链接检查和 diff gate。

## Risks

- 路线图过细会伪造工期和实施确定性；只固定依赖、证据和完成定义，不在无真实基线时承诺人日。
- 一个 work item 同时跨太多模块会失去小闭环特征；按可单独部署/验证边界继续拆分，但保持 package authority 唯一。
- 为追求覆盖率可能把未确认产品选项塞入 P0；开放 DR 必须只形成 decision/external gate，不进入不可逆实现。
- 静态字段齐全不等于任务可执行；必须引用当前代码路径、测试入口和明确新增位置。
- `WP-MIG-01` 可能演变为第二套编排系统；它只能编排既有 W/I/P/Q/O/V/C 门和证据，不拥有业务状态。

## Assumptions

- 本轮产出开发路线和静态验收，不修改生产功能代码、不部署、不跑真机。
- 当前 iOS 分支和后端 `main` 源码是代码范围与现状证据基线。
- 具体人员、日期、Provider SLA、RPO/RTO 和 cohort 阈值只有在真实组织/环境数据可用后填写，不在路线图中伪造。
- Round 5 会独立复审路线图的产品价值、隐私伦理、成本、运维、可迁移性和过度设计风险。
