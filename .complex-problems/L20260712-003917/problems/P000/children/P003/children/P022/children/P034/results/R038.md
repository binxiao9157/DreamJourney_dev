# Round 3C4 组合 Cutover、Rollback 与 Legacy 退役 Runbook 结果

## Summary

Round 3C4 已完成组合迁移 Runbook、Evidence/Decision 边界和静态门闭环。第 34 节将数据、iOS、API/AuthZ、Job、Object 与 Provider 分域波次编排成 C00-C11，明确五类 rollback plane、不可逆补偿、go/no-go、恢复和退役证据；真实参数与生产演练保持 no-go/外部验收。

## Done

- 一个组合 migration Authority 和五条功能 lane，禁止第二状态机与跨 lane 回滚核心 Authority。
- 五类 rollback plane，各自具备 Authority/fence、允许/禁止动作和完成证据。
- 10 类不可逆事实与 compensation/reconcile，原 receipt 不可改写为“未发生”。
- W/I/P/Q/O/V 跨域依赖映射及 C00-C11 组合波次，每 wave 九类执行字段和 MRT-Cxx。
- CompositeMigrationGoNoGoRecord、自动 pause/no-go、批准角色、emergency fence、隔离 restore/replay。
- 七类 legacy retirement manifest 和固定退役顺序。
- 24 个跨域故障演练及生产 UNKNOWN 清单。
- Evidence Matrix 7.9、Decision Register 3.2 和组合 migration checker。
- 独立只读审查发现的 shadow/canary 重叠与 Q09→W10 顺序已修正。

## Verification

- Composite checker：5 planes、12 waves、7 retirement surfaces、24 scenarios，通过。
- Data backfill/cutover、iOS account/store、API/AuthZ rollout、Job/Outbox、Object/Media、Provider migration：全部通过。
- Data contract、API/AuthZ、jobs/provider、V4 docs、36项 Evidence Matrix：全部通过。
- `git diff --check`：通过。

## Known Gaps

- 组合 migration controller、runner、schema/production cohort 和 retirement manifest 生产实现尚未开发。
- build/client/timer/provider/object/credential inventory、阈值、观察窗、RPO/RTO、MRT-C00-C11 与批准角色尚未实测/确认。
- backup restore/replay、rights/provider delete/exit、schema contract 和旧客户端/旧binary退役尚无真实演练证据。

## Artifacts

- Product Spec 第 34 节。
- Evidence Matrix 第 7.9 节。
- Decision Register 第 3.2 节。
- R036：组合 Runbook 本体。
- R037：Evidence、Decision 与静态门。
- `Scripts/QA/product-v4/product-v4-composite-migration-runbook-check.py`。
