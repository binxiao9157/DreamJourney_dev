# Round 2C1 产品决策登记册方案

## Problem Definition

产品、合规、商业、架构和外部供应商决定散落在 21 项冲突与独立评审中，缺少统一状态和开发门，工程容易把推荐、历史实现或 provider 能力当作产品确认。

## Proposed Solution

1. 创建决策登记册，定义 `CONFIRMED / RECOMMENDED_PENDING / EXTERNAL_REQUIRED / DEFERRED / REJECTED` 状态。
2. 对 C-01 至 C-21 逐项记录推荐、替代选项、安全默认、影响、责任角色和阶段截止门。
3. 增加首发成人/第三方、强身份、break-glass、地域与处理商、AI 身份/危机、成本停止线、资产可迁移性等独立决策。
4. 只把用户明确允许修订源文档、以 V4 为最终成果物的决定标记为 `CONFIRMED`；其余保持待确认或外部依赖。
5. 把可由 deny-by-default 安全落地的决定与会产生不可逆商业/合规后果的决定分开。

## Acceptance Criteria

- C-01 至 C-21 全覆盖、无缺号。
- 每项有状态、类型、证据、选项/推荐、安全默认、影响、Owner 和 Gate。
- 高风险新增决定完整且不重复掩盖。
- 只有具备 E2 证据的条目为 `CONFIRMED`。
- 可直接进入开发计划的安全默认与必须先确认的产品决定可一眼区分。

## Verification Plan

1. 脚本比较冲突 ID 集合。
2. 校验状态枚举和每行字段完整性。
3. 人工复核所有 `CONFIRMED` 的 E2 证据。
4. 对 Stage 0、Stage 1、Stage 3、Voice Beta 分别检查未决阻断项。

## Risks

- 登记册把推荐伪装成批准。
- 同一决定被多个冲突行给出不同默认值。
- 责任角色和截止门过于泛化，无法阻止提前开发。

## Assumptions

- 用户后续可以逐项确认或修改登记册，不需要本轮停下来逐项提问。
- 未确认项继续采用安全默认，不阻断可逆的文档和接口设计。
