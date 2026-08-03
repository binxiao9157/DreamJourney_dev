# Round 3C4A 组合 Cutover、Rollback 与 Retirement Runbook 结果

## Summary

已在 Product Spec 新增第 34 节，将 W/I/P/Q/O/V 分域迁移编排为唯一的 C00-C11 组合 Runbook。该层只负责依赖、批准、观测、暂停、恢复和退役，不创建第二套 migration Authority；所有生产参数和真实演练继续保持 UNKNOWN/no-go。

## Done

- 定义组合 Authority、五条功能 lane 与 single-Authority/epoch/data-rights/UNKNOWN 不变量。
- 定义 UI exposure、client routing、API traffic、worker/provider、schema/data 五类 rollback plane，各自包含 Authority、允许/禁止动作和完成证据。
- 定义 10 类不可逆事实与 compensation/reconcile 规则，禁止通过数据库回滚抹除 MemoryVersion、Inbox、APNs、Voice、Provider/Object delete、rights purge 等历史。
- 映射 W/I/P/Q/O/V 的跨域依赖，明确身份/账户、UoW/migrator、outbox、object/provider、W08/P08 和 Q09→W10 的顺序。
- 定义 C00-C11 组合波次；每行均包含 prerequisites、change、owner、observability、threshold、cutover、rollback/compensation、max recovery time 和 exit evidence。
- 定义 CompositeMigrationGoNoGoRecord、自动 pause/no-go 条件、批准角色和不可修改原 no-go 记录的规则。
- 定义 emergency fence、cutover point 判断、隔离恢复、稳定 ID 重放和 maxRecoveryTime 实测边界。
- 建立七类 Legacy Retirement Manifest：schema、route、timer/effect、credential、feature flag、local store、transition code。
- 增加 24 个跨域故障演练和实现阶段 UNKNOWN 清单。
- 采纳独立只读审查意见，修正 shadow/canary 重复编排，并明确 Q09 timer drain 先于 W10 retirement candidate。

## Verification

- `rg` 确认组合 wave 精确为 C00-C11，无缺号。
- `awk` 验证 C00-C11 的每一行均为相同的 11 个业务单元格。
- 第 34.9 节故障演练计数为 24，超过至少 18 个的要求。
- 独立 agent 只读审查第 28-33 节依赖、rollback plane、不可逆事实、retirement evidence 和故障场景；其唯一需要补强的顺序项 Q09→W10 已纳入正文。
- 本子问题未修改 iOS/后端生产代码，也未运行或宣称生产迁移、restore 或 Provider 演练。

## Known Gaps

- Evidence Matrix、Decision Register 映射和组合 migration 静态门由独立 3C4B 子问题完成，当前不在本结果中自证。
- 真实 build/client/timer/provider/object/credential inventory、阈值、观察窗、RPO/RTO、MRT-C00-C11、restore/replay 和 contract 演练仍待 Round 4 实施与外部环境验证。

## Artifacts

- `docs/product/DreamJourney_V4_产品定义与目标架构_Product_Spec_V4.0.md` 第 34 节。
- `docs/plans/task_27_round_3c4a-combined-runbook-problem.md`。
- `docs/plans/task_27_round_3c4a_solution.md`。
- 独立 agent 只读审查记录（未修改工作区）。
