# 规划 Strong Identity、AuthZ Enforce 与 Credential Stop-Loss

## Problem Definition

当前后端已有部分 access/refresh、route registry、ownership shadow 和 Provider adapter，但仍需把 anonymous/system/shared fallback、payload owner、长期客户端 credential 与假短期 token 收敛为可部署路线。iOS 只能消费 user session和安全能力合同，不能成为身份或Provider secret Authority。

## Proposed Solution

1. 为 `WP-S0-02` 建立 6 个单结果任务：strong challenge/identity binding、session/token family、principal/route matrix、server-derived resource AuthZ、delegated grant lifecycle、iOS typed cutover；production readiness和shadow→enforce分别作为相关任务的部署门。
2. 为 `WP-S0-03` 建立 7 个单结果任务：credential inventory、incident rotation/revoke、source/artifact/header/log/backup scan、response redaction、backend proxy/true short-term broker、credential version/canary、legacy credential retirement。
3. 使用独立 backend explorer 核实当前 route、service、config、test 与 iOS client路径；不读取或复制credential值。
4. 每项填写路线图16字段，明确G0内部合同、G2 production enforce、G3 Provider broker和G4 identity/product门。
5. 部署顺序坚持先inventory/rotation/readiness、再shadow corpus、再cohort enforce、最后revoke/retire；rollback不恢复anonymous/shared/system或客户端长期key。

## Acceptance Criteria

- `WI-S0-02-01..06` 与 `WI-S0-03-01..07` 连续唯一，16字段完整。
- Strong identity、session rotation/reuse/revoke、principal taxonomy、route/resource AuthZ、iOS typed migration和old-client策略均覆盖。
- Credential inventory、scan、rotation、broker/proxy、response redaction、version和retirement均覆盖，且无secret值。
- 每项引用当前/新增路径，含测试、部署、rollback/forward-fix、DoD与外部门。
- `shadow`、`anonymous`、payload owner、shared/system token或Provider配置存在均不能作为production success。

## Verification Plan

1. 核对独立 explorer 的路径/行号、现有测试和明确缺口。
2. 检查13个ID、208个字段、路径与依赖。
3. 对照 IAR-03、BAR-01/03/06、SOR-01/02/04/06 和 CR-02/03。
4. 运行API/AuthZ、rollout、review、architecture、link和diff检查。

## Risks

- 强身份Provider未决可能阻塞生产但不能阻塞typed contract和fake corpus。
- credential rotation过早会中断query/delete reconciliation；必须先建立版本和drain。
- route registry全量不等于resource AuthZ；两者分项验收。

## Assumptions

- 本票只写路线图，不修改认证或Provider生产代码。
- Provider/secret资产Owner负责实际轮换证据，工程文档不保存值。
