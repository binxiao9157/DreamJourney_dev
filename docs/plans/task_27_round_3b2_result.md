# Round 3B2 Identity、AuthZ 与 /v2 API 合同结果

## Summary

已形成 fail-closed 的强身份、session、principal、六类授权公式和 typed `/v2` API 目标合同。目标退役 anonymous/shared system token 与静态 provider credential，下游 machine/data-rights 操作必须同时匹配短期 credential、job、purpose、resource 和专用 authorization。

## Done

- 定义 challenge/verify/restore 强身份流程和账号枚举防护，不冻结 SMS/Apple 商业 provider。
- 定义 access/refresh rotation/reuse、session list/revoke-all、delete/restore credential 生命周期。
- 定义 user/delegated/visitor/machine/operator/break-glass 六类 principal，移除通用 system principal。
- 定义 Owner、Delegated、Machine、DataRights、Visitor、Operator 可执行授权公式。
- 定义 strict DTO、commandId/expectedVersion/receipt、cursor、async/cancel 和 problem+json error。
- 编制 36 个核心 `/v2` endpoint、10 类错误和 capability 四维状态。
- 定义 legacy 58 route facade/shadow/cutover，禁止随机补新 authority command ID。
- 增加 13 个 Auth/API 验收场景和 `product-v4-api-authz-check.py`。
- 独立安全复审确认当前代码 2 个 blocker/5 个 high；目标合同补强 production no-shadow、policy exception deny 和中性账号响应。

## Verification

- API/AuthZ check 通过：6 principals、36 endpoints、10 errors、13 acceptance scenarios。
- Product V4 docs check 通过。
- `git diff --check` 通过。
- 当前实现证据矩阵同步记录 shadow/fallback 与账号枚举风险。

## Known Gaps

- `/v2`、OTP provider、service credential 和 AuthZ engine 尚未实现。
- 首发强身份 provider 仍需 DR-023 确认；合同只固定证明等级和接口。
- 旧客户端 cutover 阈值、token TTL 最终值和 Operator SSO 属实现/运营决策。
- Round 3D 仍需对字段与安全组合做最终独立审查。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `Scripts/QA/product-v4/product-v4-api-authz-check.py`
- `docs/plans/task_27_round_3b2-api-authz-contracts.md`
- `docs/plans/task_27_round_3b2_solution.md`
- `docs/plans/task_27_round_3b2_result.md`
