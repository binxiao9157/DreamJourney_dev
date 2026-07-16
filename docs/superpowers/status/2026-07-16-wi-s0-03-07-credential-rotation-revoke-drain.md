# WI-S0-03-07 Credential Rotation / Revoke / Drain 记录

日期：2026-07-16
Work Item：`WI-S0-03-07`
状态：`CLOSED_WITH_RISK_EXCEPTION`
Decision：`CONTINUE_WITH_RISK_EXCEPTION`
Execution owner：`codex-goal:019ece6b-2c15-7521-b160-c42e95d1dd5a`
Authority lock：`CREDENTIAL_CONTROL`
Lease：`HELD`

## 1. 依赖与 Gate

- `WI-S0-03-01/02/03/04/05/06` 已完成内部 containment 或关闭路径。
- Registry 要求 `G0`。产品负责人于 2026-07-16 明确接受旧凭据未轮换、未吊销以及历史/私密备份仍保留的剩余风险，执行层结论为 `G0=PRESENT_BY_RISK_EXCEPTION`。
- Provider 控制台真实 rotation/revoke 仍未发生；本回执不会把源码删除、服务重启、mock 或风险豁免描述成 Provider 验证。
- 风险例外只解除本 Work Item 对后续开发的停止条件，不得作为 Provider 安全验收证据，也不关闭后续 G3、生产安全审计或凭据轮换待办。

## 2. 本轮无值基线

- scanner report：`tmp/visual-qa/prd-stitch-ui/credential-inventory/20260716-wi-s0-03-07-final/credential-inventory.json`。
- SHA-256：`f1bb5f637b933237d93281a35eb4752618f5d929392b856608e9338bf88e998b`。
- 唯一候选 `286`，唯一阻断候选 `30`，阻断 observation `47`。
- 当前 `SOURCE` 阻断 observation 已降为 `0`；剩余仅为 `HISTORY=38`、`CONTAINER=9`。
- `GENERIC_SECRET` 仍有 `2` 条历史/私密面 observation 待 `SECURITY_TRIAGE_OWNER` 分类。
- 报告与本文不包含 credential 原值、Authorization header、Provider response 正文或完整私有配置。

## 3. 已完成的内部 containment

- response credential boundary：Backend `1be115a`、iOS `a15ba2b`。
- mobile credential injection 退役：iOS `1aa7146`。
- QA credential artifact 路径退役：iOS `8860fe9`。
- realtime direct mobile 关闭：Backend `2fafa50`、iOS `55a791a`。
- digital-human direct mobile 关闭：Backend `d23b940`、iOS `551590c`。
- 数字人旧 lease drain：Backend `7839583` 已推送和部署；启动时幂等清理超过 `expiresAt` 的 active lease。
- 当前源码字面量 containment：Backend `85902bd` 已推送和部署；示例配置改为显式 `YOUR_*`，测试值改为 `fixture-*`，旧 QA 证据改为 `REDACTED`，Compose 不再硬编码数据库密码。

## 4. Drain 部署证据

- 部署前 Postgres：`active + elapsed=1`、`expired=5`、`released=56`。
- 部署后 Postgres：`active=0`、`expired=6`、`released=56`。
- 线上 credential response deployed smoke 继续通过，数字人和 realtime response 仍为 value-free blocked contract。
- drain 只更新超时 lease 状态，不删除记录，不接触 Provider credential 原值。

## 5. 产品风险豁免与保留待办

风险决策 ID：`RA-WI-S0-03-07-20260716-01`。以下 credential family 均已写入无值 receipt，但真实 rotation/revoke 状态仍为 `RISK_ACCEPTED_NOT_ROTATED / RISK_ACCEPTED_NOT_REVOKED`：

- `BACKEND_SHARED_TOKEN`
- `BEARER_TOKEN`
- `DEEPSEEK_API_KEY`
- `TENCENT_CLOUD_SECRET_KEY`
- `TENCENT_DIGITAL_HUMAN_ACCESS_TOKEN`
- `VOLCENGINE_ACCESS_TOKEN`
- `VOLCENGINE_APP_TOKEN`
- `VOLCENGINE_SECRET_KEY`

这些 family 未来仍可由对应资产 Owner 在受控控制台完成新版本启用和旧版本撤销，并只回填无值 `providerEvidenceIds`。当前产品负责人明确选择延后该动作，继续开发不以轮换为前置条件。

本次接受的范围包括：Provider rotation 延后、旧 credential revoke 延后、Git 历史与私密备份保留风险。约束保持不变：当前源码阻断必须继续为零，iOS 长期凭据/直连路径必须保持关闭，不允许后续提交重新引入明文 credential。

## 6. 验证与完成边界

- Backend：311 项单测、Postgres store targeted tests、FastAPI smoke、credential response boundary smoke 通过。
- Backend：`7839583 security(WI-S0-03-07): drain expired digital-human leases` 已推送、部署，线上 Postgres drain 通过。
- Backend：`85902bd security(WI-S0-03-07): remove current credential literals` 已推送、部署；Compose config、Postgres readiness、`/health store=postgres` 与线上 credential response boundary smoke 通过。
- iOS/release：credential inventory、rotation receipt、release QA package、静态 guards、标准模拟器构建通过；窄版 regression 使用 `RUN_SIMULATOR_SMOKE=0`。
- 默认 Archive -> Echo 模拟器 smoke 仍因旧 harness 未建立新 auth session 收到 `401`；不得通过恢复共享 token 修复，需在后续 QA auth harness Work Item 单独收敛。
- value-free receipt：`docs/superpowers/status/2026-07-16-wi-s0-03-07-credential-rotation-receipt.json`。
- iOS control-plane commit：本文所在提交。
- receipt truthfulness gate 会拒绝 credential 原值字段，也会拒绝把风险豁免伪装成 Provider 已轮换或已撤销。
- 当前源码阻断为零，但 Git 历史与私密容器仍保留旧版本指纹；风险由产品负责人显式接受，Work Item 以 `CLOSED_WITH_RISK_EXCEPTION` 收敛并允许进入 Slice 1D。
