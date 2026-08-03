# Round 3B 数据、API、授权、任务与 Provider 合同结果

## Summary

Round 3B 已将 V4 目标架构从模块边界推进为可实施合同：核心数据 Authority、强身份与 fail-closed 授权、typed `/v2` API、事务 outbox、异步 Job、对象存储生命周期和外部 Provider Adapter 已形成同一套一致模型。合同明确区分当前实现、目标状态和迁移责任，不把现有 JSONB 路由、共享 token、同步调用或 mock Provider 包装成完成态。

## Done

- P028 / R021：定义 38 个核心逻辑对象、跨 vault 约束和 Source → Candidate → DecisionReceipt → immutable MemoryVersion Authority 链。
- 固定 Conversation、Answer、Citation、DataRights、Audit 以及可选 Family/Care/TimeLetter/Voice/DigitalHuman 的边界。
- P029 / R022：定义 challenge/verify 强身份、session/refresh rotation、6 类 principal 和 Owner/Delegated/Machine/DataRights/Visitor/Operator 授权公式。
- 编制 36 个 `/v2` endpoint、10 类错误、command/expectedVersion/receipt、分页、取消和 legacy route cutover 合同。
- P030 / R023：定义事务 outbox、Job/attempt/lease/retry/reconcile/dead-letter、业务幂等和稳定 Provider request ID。
- 编制 15 类 Job、对象存储隔离验证删除生命周期和 10 类 Provider Adapter。
- 明确应用内业务完成与 APNs、腾讯数智人、声音复刻质量、Provider 删除等外部完成状态的区别。
- 为三部分分别增加静态门禁和总计 37 个验收场景。
- 独立复审发现的 fail-open、weak identity、跨用户 ownership、单连接 Postgres、非原子 TimeLetter、静态 Provider credential 等当前风险已写回 CURRENT EVIDENCE，并作为 Round 3C/路线图输入。

## Verification

- Data contract check 通过：38 rows、9 acceptance scenarios。
- API/AuthZ check 通过：6 principals、36 endpoints、10 errors、13 acceptance scenarios。
- Job/Provider check 通过：15 jobs、10 providers、15 acceptance scenarios。
- Product V4 docs check 通过：36 requirements、21 conflicts、39 decisions、43 review responses、4 lifecycle banners。
- `git diff --check` 在子轮结果记录前通过；本轮没有修改 iOS/后端生产代码、部署服务或执行真机验证。

## Known Gaps

- 目标 schema、`/v2`、AuthZ engine、worker/outbox 和真实对象存储仍未实现。
- 强身份首发 Provider、最终 token TTL、外部 Provider SLA/配额和删除能力仍需产品或环境确认。
- 现有数据如何 backfill、旧 route 如何 shadow/cutover、失败如何 rollback 尚需 Round 3C 固定。
- 组合合同仍需 Round 3D 独立安全、数据和可运维性审查。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md`
- `docs/product/DreamJourney_V4_当前实现证据矩阵_V1.0.md`
- `Scripts/QA/product-v4/product-v4-data-contract-check.py`
- `Scripts/QA/product-v4/product-v4-api-authz-check.py`
- `Scripts/QA/product-v4/product-v4-jobs-provider-check.py`
- `docs/plans/task_27_round_3b1_result.md`
- `docs/plans/task_27_round_3b2_result.md`
- `docs/plans/task_27_round_3b3_result.md`
- `docs/plans/task_27_round_3b_result.md`
