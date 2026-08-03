# 以路由、表和部署证据重建后端能力矩阵

## Problem Definition

后端包含真实 Postgres 功能、provider HTTP adapter、合同壳层和 mock fallback。仅凭 200 响应或路由存在不能证明最新 PRD 所需的身份、媒体、公开域、任务和删除生命周期。

## Proposed Solution

盘点路由、ownership registry、Postgres 表、service/provider、后台脚本和测试；按 Account、Archive/Source、Knowledge/Context、Family/Persona、TimeLetter/Message、Voice、DigitalHuman、Publication/Visitor、Data Rights/Operations 分类，并记录部署状态、成熟度、P0 安全风险与迁移约束。

## Acceptance Criteria

- 路由和表数量有当前源码证据。
- 每个产品域明确 production component、contract-only、mock/fallback 或 missing。
- 身份、跨 owner、供应商凭据、删除和任意 JSONB 等 P0 风险有代码证据。
- 数据迁移顺序保留现有 revision/receipt/ownership 合同。

## Verification Plan

独立 explorer 审计并运行后端全量测试；主 agent 抽查关键路由、表定义和 provider fallback；使用当前部署提交与历史 smoke 作为已部署边界。

## Risks

- 单元测试大量使用 memory/fake cursor，不能替代真实 Postgres、对象存储、APNs 和 provider 验收。

## Assumptions

- 后端 `main` 的 `4c0538b` 是当前审计和生产部署基线。
