# 用事务 Outbox、Job Lease 与 Inbox Receipt 收敛所有异步副作用

## Problem Definition

当前时间信件、Echo 延迟回信、本地/APNs提醒、知识同步和Provider调用由多个timer、callback、脚本与route触发。它们已有局部幂等和smoke，但没有统一区分业务提交、调度、Provider accepted、通知送达与最终业务完成，也无法在crash、duplicate、late callback和unknown timeout下给出单一结论。

## Proposed Solution

为 `WP-S1-02` 建立十个连续 Work Item：

1. `WI-S1-02-01`：Outbox/Job/Inbox/BusinessReceipt核心schema与状态机。
2. `WI-S1-02-02`：业务aggregate与outbox同一UoW提交。
3. `WI-S1-02-03`：scheduler、worker lease、heartbeat与attempt边界。
4. `WI-S1-02-04`：consumer Inbox dedupe与business completion receipt。
5. `WI-S1-02-05`：TimeLetter到期dispatch与mailbox原子闭环。
6. `WI-S1-02-06`：Echo delayed reply生成、持久化与统一消息闭环。
7. `WI-S1-02-07`：Provider request/accepted/unknown/query/reconcile合同。
8. `WI-S1-02-08`：业务完成、应用内消息、本地通知和APNs delivery分层。
9. `WI-S1-02-09`：dead-letter、受权replay、worker readiness与evidence。
10. `WI-S1-02-10`：legacy timer/cron/callback inventory、shadow/drain、zero-use与retirement gate。

每项填满16字段，明确S0/S1前置、stable idempotency key、authorityEpoch、operation/attempt、unknown与rollback。S1-02只拥有effect执行和receipt，不拥有Source/Memory/TimeLetter/Echo等业务聚合状态；Provider不可用时Owner文字核心仍能用明确失败或synthetic合同完成内部闭环。

## Acceptance Criteria

- 十个Work Item连续唯一、16字段完整，无第二业务Authority。
- aggregate state与outbox同一UoW；consumer以Inbox和business key去重，重复delivery不重复业务结果。
- TimeLetter、Echo delayed reply、notification和至少一个Provider effect均有当前→目标→迁移路径。
- `accepted/timeout/unknown`不会被当作失败盲重试；通过query/callback/reconcile得到terminal或honest unknown。
- crash-before/after-commit、lease expiry、duplicate、late callback、dead-letter/replay有明确测试语料。
- 旧timer在新worker启用前完成shadow、drain、zero-use和retirement；不能双调度。

## Verification Plan

1. 对照Product Spec的Q/J/V迁移、TimeLetter/Echo/notification/Provider合同与Round3异步评审。
2. 用当前backend timers/routes/stores和iOS delayed reply/message/notification证据校准scope。
3. 结构检查10个ID、160字段、依赖、稳定key、unknown、legacy drain与G0–G4。
4. 运行现有jobs/provider/timeLetter/Echo/Product V4 checks和`git diff --check`。
5. Round4E补全FR/DR/finding追踪，Round5独立审查effect/业务Authority混淆与过度平台化。

## Risks

- 一次性引入外部队列会扩大运维面；首版使用Postgres outbox/job/inbox，不新增Kafka/Redis依赖。
- 旧timer与新worker并存会双投递；必须先shadow和稳定job key，再按type drain。
- Provider accepted后timeout不可安全重试；没有query能力的effect必须进入manual/unknown而不是伪success。
- 通知未到达不等于业务未完成，业务已完成也不等于APNs已送达，状态必须分层。

## Assumptions

- 本票据只完善路线图，不修改生产代码或部署worker。
- TimeLetter/Family/Care壳层只用于验证通用effect模型，不因此改变公开产品优先级。
- Provider真实质量、配额、成本和设备到达仍由G3/G4关闭。
