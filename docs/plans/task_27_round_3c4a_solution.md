# 编写 Round 3C4A 组合迁移 Runbook

## Problem Definition

需要把第 28-33 节的分域迁移合同编排成唯一的组合执行顺序，避免 rollout 时出现多套 Authority、数据前进但代码后退、旧客户端继续写、不可逆 effect 被错误回滚或 contract 过早等跨域失败。

## Proposed Solution

在 Product Spec 新增第 34 节，包含：组合运行原则、五个 rollback plane、不可逆事实/补偿矩阵、wave dependency map、C00-C11 组合 wave、统一 go/no-go record、pause/emergency/restore、legacy retirement manifest、跨域演练和 UNKNOWN 参数。组合 wave 仅引用 W/I/P/Q/O/V 的进入条件和退出证据，不取代各分域迁移 runner。

## Acceptance Criteria

- 五个 rollback plane 均有 Authority、允许动作、禁止动作和证据。
- C00-C11 每行包含 prerequisites、change、owner、observability、threshold、cutover、rollback/compensation、max recovery time、exit evidence。
- wave dependency 明确 identity/account、data shadow、object/provider、worker/outbox、API/client cohort、authority epoch、contract/retirement 的先后关系。
- MemoryVersion、Inbox delivery、Voice train/delete、Provider delete/publication 等不可逆事实有 compensation/reconcile 规则。
- go/no-go record 可审计，包含 build/schema/epoch/cohort/provider/backup/metrics/approvals/no-go/recovery fields。
- retirement manifest 覆盖七类 legacy surface，且 contract/revoke 后禁止恢复不安全旧路径。
- 至少 18 个跨域演练和明确 UNKNOWN 参数。

## Verification Plan

先人工核对既有 W/I/P/Q/O/V 编号与依赖，再统计 C wave、rollback plane、retirement 类型和故障场景；由 3C4B 编写独立静态门并回归所有分域检查。

## Risks

- 组合 Runbook 可能与分域 wave 冲突；用引用和 gate 编排，禁止复制实现状态机。
- 未实测 threshold/max recovery time 可能被误作承诺；使用参数名、owner、测量方法和 no-go 默认。
- rollback 可能抹除不可逆事实；对每类 effect 明确只能补偿/对账。

## Assumptions

- DR-040 仍未确认，Runbook 是推荐设计而非生产批准。
- 当前不执行迁移、不创建 DDL、不部署服务、不改客户端路由。
- 3C4B 单独负责 Evidence/Decision/静态门，避免执行者自证。
